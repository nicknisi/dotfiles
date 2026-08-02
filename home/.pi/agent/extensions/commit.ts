/**
 * Commit — AI-powered git commits.
 *
 * Analyzes the staged/unstaged diff, generates a conventional commit message
 * (+ optional changelog), and runs `git commit` (and optionally `git push`).
 *
 * Usage:
 *   /commit                    — generate message from staged changes, commit
 *   /commit --push             — commit and push
 *   /commit --dry-run          — show the message without committing
 *   /commit --no-changelog     — skip changelog generation
 *   /commit -c "extra context" — pass context to the model
 *
 * Ported from omp's commit pipeline. Uses the session model + pi-ai complete().
 */

import { complete, type Message } from "@earendil-works/pi-ai";
import {
  BorderedLoader,
  convertToLlm,
  serializeConversation,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const SYSTEM_PROMPT = `You are a commit message generator. Given a git diff and optional context, produce a clear, conventional commit message.

Rules:
- Use conventional commit format: type(scope): description
- Types: feat, fix, docs, style, refactor, perf, test, chore, build, ci
- The scope is optional — omit it if the change is broad or doesn't fit a single area
- Keep the subject line under 72 characters, imperative mood ("add" not "added")
- Add a body if the change needs explanation (what + why), wrapped at 80 chars
- Do NOT add Claude/AI co-author footers or "Generated with" lines
- Output ONLY the commit message — no markdown fences, no preamble, no explanation

If a changelog is requested, append it after a line containing only "---CHANGELOG---" as a single bullet suitable for a CHANGELOG.md entry.`;

interface CommitArgs {
  push: boolean;
  dryRun: boolean;
  noChangelog: boolean;
  context: string | null;
}

function parseArgs(args: string): CommitArgs {
  const parts = args.trim().split(/\s+/).filter(Boolean);
  const result: CommitArgs = {
    push: false,
    dryRun: false,
    noChangelog: false,
    context: null,
  };

  const contextParts: string[] = [];

  for (let i = 0; i < parts.length; i++) {
    const raw = parts[i] ?? "";
    switch (raw) {
      case "--push":
      case "-p":
        result.push = true;
        break;
      case "--dry-run":
      case "-n":
        result.dryRun = true;
        break;
      case "--no-changelog":
        result.noChangelog = true;
        break;
      case "-c":
      case "--context":
        // Grab the rest of the args as context
        contextParts.push(...parts.slice(i + 1));
        i = parts.length;
        break;
      default:
        // Unknown — treat as context if it's not a flag
        if (!raw.startsWith("-")) {
          contextParts.push(raw);
        }
        break;
    }
  }

  result.context = contextParts.length > 0 ? contextParts.join(" ") : null;
  return result;
}

interface DiffResult {
  staged: string;
  unstaged: string;
  untracked: string[];
  status: string;
}

async function getDiff(cwd: string): Promise<DiffResult> {
  const { execSync } = await import("node:child_process");

  const run = (cmd: string): string => {
    try {
      return execSync(cmd, { cwd, encoding: "utf-8", maxBuffer: 1024 * 1024 * 10 }).trim();
    } catch {
      return "";
    }
  };

  const staged = run("git diff --cached --no-color");
  const unstaged = run("git diff --no-color");
  const status = run("git status --porcelain=v1");

  let untracked: string[] = [];
  try {
    untracked = execSync("git ls-files --others --exclude-standard", {
      cwd,
      encoding: "utf-8",
    })
      .trim()
      .split("\n")
      .filter(Boolean);
  } catch {
    untracked = [];
  }

  return { staged, unstaged, untracked, status };
}

function buildDiffPrompt(diff: DiffResult, context: string | null, noChangelog: boolean): string {
  const sections: string[] = [];

  if (diff.staged) {
    sections.push(`## Staged changes (git diff --cached)\n\n\`\`\`diff\n${diff.staged}\n\`\`\``);
  }

  if (diff.unstaged) {
    sections.push(`## Unstaged changes (git diff)\n\n\`\`\`diff\n${diff.unstaged}\n\`\`\``);
  }

  if (diff.untracked.length > 0) {
    sections.push(`## Untracked files\n\n${diff.untracked.map((f) => `- ${f}`).join("\n")}`);
  }

  if (diff.status) {
    sections.push(`## Git status\n\n\`\`\`\n${diff.status}\n\`\`\``);
  }

  if (context) {
    sections.push(`## Additional context\n\n${context}`);
  }

  if (!noChangelog) {
    sections.push("## Changelog\n\nAlso generate a single changelog bullet after ---CHANGELOG---");
  }

  if (!diff.staged && !diff.unstaged && diff.untracked.length === 0) {
    return "There are no changes to commit. Respond with: NO_CHANGES";
  }

  // If there are unstaged but no staged changes, note that we'll stage all
  if (!diff.staged && (diff.unstaged || diff.untracked.length > 0)) {
    sections.push(
      "Note: No changes are staged. I will stage all changes (git add -A) before committing. Base the commit message on all changes shown above.",
    );
  }

  return sections.join("\n\n");
}

interface GenerateResult {
  message: string | null;
  changelog: string | null;
}

async function generateMessage(
  ctx: ExtensionCommandContext,
  prompt: string,
  signal: AbortSignal | undefined,
): Promise<GenerateResult> {
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model!);
  if (!auth.ok) throw new Error(`No API key configured for ${ctx.model!.provider}/${ctx.model!.id}: ${auth.error}`);
  const { apiKey, headers } = auth;

  const conversation = serializeConversation(ctx.sessionManager);
  const userMessage: Message = {
    role: "user",
    content: [{ type: "text", text: prompt, timestamp: Date.now() }],
  };

  const llmMessages = [...convertToLlm(conversation), userMessage];

  const response = await complete(
    ctx.model!,
    { systemPrompt: SYSTEM_PROMPT, messages: llmMessages },
    { apiKey, headers, signal },
  );

  if (response.stopReason === "aborted") {
    return { message: null, changelog: null };
  }

  if (response.stopReason === "error" || !response.content) {
    throw new Error(response.error || "Model returned an error");
  }

  const text = response.content
    .filter((c): c is { type: "text"; text: string } => c.type === "text")
    .map((c) => c.text)
    .join("\n")
    .trim();

  if (text === "NO_CHANGES" || !text) {
    return { message: null, changelog: null };
  }

  // Split commit message and changelog if present
  const parts = text.split("---CHANGELOG---");
  const message = parts[0]!.trim();
  const changelog = parts[1]?.trim() || null;

  return { message, changelog };
}

async function runGitCommit(cwd: string, message: string, push: boolean): Promise<string> {
  const { execSync } = await import("node:child_process");

  // Stage all if nothing is staged
  const hasStaged = execSync("git diff --cached --name-only", { cwd, encoding: "utf-8" }).trim();
  if (!hasStaged) {
    execSync("git add -A", { cwd, encoding: "utf-8" });
  }

  // Write message to a temp file to avoid shell escaping issues
  const { writeFileSync, mkdtempSync, rmSync } = await import("node:fs");
  const { join } = await import("node:path");
  const { tmpdir } = await import("node:os");
  const tmpDir = mkdtempSync(join(tmpdir(), "pi-commit-"));
  const msgFile = join(tmpDir, "COMMIT_MSG");
  writeFileSync(msgFile, message, { mode: 0o600 });

  try {
    const result = execSync(`git commit -F "${msgFile}"`, {
      cwd,
      encoding: "utf-8",
      maxBuffer: 1024 * 1024 * 10,
    }).trim();

    if (push) {
      const pushResult = execSync("git push", {
        cwd,
        encoding: "utf-8",
        maxBuffer: 1024 * 1024 * 10,
      }).trim();
      return `${result}\n\n${pushResult}`;
    }

    return result;
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("commit", {
    description: "AI-powered git commit — generates a message from the diff and commits",
    handler: async (args, ctx) => {
      const opts = parseArgs(args);
      const cwd = ctx.cwd;

      // Check we're in a git repo
      const { execSync } = await import("node:child_process");
      try {
        execSync("git rev-parse --is-inside-work-tree", { cwd, encoding: "utf-8", stdio: "pipe" });
      } catch {
        ctx.ui.notify("Not a git repository", "error");
        return;
      }

      // Gather diff
      const diff = await getDiff(cwd);

      if (!diff.staged && !diff.unstaged && diff.untracked.length === 0) {
        ctx.ui.notify("No changes to commit", "info");
        return;
      }

      const prompt = buildDiffPrompt(diff, opts.context, opts.noChangelog);

      // Generate commit message with a loader
      const result = await ctx.ui.custom<{
        message: string | null;
        changelog: string | null;
        error?: string;
      }>((tui, theme, _kb, done) => {
        const loader = new BorderedLoader(tui, theme, "Generating commit message...");
        loader.onAbort = () => done({ message: null, changelog: null });

        const doGenerate = async () => {
          try {
            const result = await generateMessage(ctx, prompt, loader.signal);
            done(result);
          } catch (err) {
            done({
              message: null,
              changelog: null,
              error: err instanceof Error ? err.message : String(err),
            });
          }
        };

        void doGenerate();
      });

      if (result.error) {
        ctx.ui.notify(`Failed to generate commit message: ${result.error}`, "error");
        return;
      }

      if (!result.message) {
        ctx.ui.notify("No commit message generated", "info");
        return;
      }

      // Show the generated message
      const display = result.changelog
        ? `${result.message}\n\n--- changelog ---\n${result.changelog}`
        : result.message;

      if (opts.dryRun) {
        ctx.ui.notify(`Dry run — message:\n\n${display}`, "info");
        return;
      }

      // Confirm before committing (unless auto-approved)
      const confirmed = await ctx.ui.confirm(
        "Commit with this message?",
        result.message.split("\n")[0] ?? result.message,
      );

      if (!confirmed) {
        ctx.ui.notify("Commit cancelled", "info");
        return;
      }

      // Run the commit
      try {
        const output = await runGitCommit(cwd, result.message, opts.push);
        ctx.ui.notify(output, "success");
      } catch (err) {
        ctx.ui.notify(
          `git commit failed: ${err instanceof Error ? err.message : String(err)}`,
          "error",
        );
      }
    },
  });
}
