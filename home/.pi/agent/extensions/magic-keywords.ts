/**
 * Magic Keywords — standalone words in a user prompt that inject hidden
 * instructions for that turn.
 *
 * Ported from omp's magic-keywords feature.
 *
 * Keywords:
 *   ultrathink   — bumps thinking to max for this turn, injects "reason
 *                  carefully through this multi-step task" guidance
 *   orchestrate  — injects "scope the full task, delegate substantial
 *                  independent work in parallel to subagents, verify each
 *                  phase" guidance
 *
 * Matching rules (same as omp):
 *   - Case-sensitive lowercase only. "Ultrathink" does NOT trigger.
 *   - Must be a standalone word. Punctuation may touch it, but identifiers,
 *     inflections, paths, and file extensions do not match.
 *     "ultrathink," matches; "ultrathinking" and "ultrathink.ts" do not.
 *   - Fenced code blocks and inline code spans are ignored.
 *   - The keyword remains visible in the prompt; only the instruction is hidden
 *     (injected into the system prompt, not the conversation).
 *
 * The keyword glows in the editor when recognized (via setStatus).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";

const KEYWORDS = {
  ultrathink: {
    instruction:
      "Reason carefully through this multi-step task. Think through each step before acting. Consider edge cases, failure modes, and alternative approaches before committing to a plan. Take your time — thoroughness is more important than speed here.",
    thinkingLevel: "max" as ThinkingLevel,
  },
  orchestrate: {
    instruction:
      "Scope the full task first, then delegate substantial independent work in parallel to subagents. Verify each phase's output before continuing. Continue until the request is complete. Use the subagent or model_workflow tool for delegation — do not try to do everything sequentially yourself.",
  },
} as const;

type KeywordName = keyof typeof KEYWORDS;

// Session-scoped state
let pendingKeywords: Set<string> = new Set();
let savedThinkingLevel: ThinkingLevel | null = null;

/** Remove fenced code blocks and inline code spans so keywords inside code don't trigger. */
function stripCode(text: string): string {
  let cleaned = text.replace(/```[\s\S]*?```/g, "");
  cleaned = cleaned.replace(/`[^`]+`/g, "");
  return cleaned;
}

/** Escape regex special characters in a literal string. */
function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Detect standalone keyword occurrences in user text.
 *
 * Uses word boundaries plus lookarounds to reject paths/identifiers:
 *   (?<![/.])   — not preceded by / or . (path component or file)
 *   \bKEYWORD\b  — standard word boundary (handles inflections like "orchestrated")
 *   (?![./]\w)  — not followed by . or / then a word char (file extension or path)
 */
function findKeywords(text: string): Set<string> {
  const found = new Set<string>();
  const cleaned = stripCode(text);

  for (const kw of Object.keys(KEYWORDS)) {
    const re = new RegExp(`(?<![/.])\\b${escapeRegex(kw)}\\b(?![./]\\w)`);
    if (re.test(cleaned)) {
      found.add(kw);
    }
  }

  return found;
}

export default function (pi: ExtensionAPI) {
  // Detect keywords in raw user input, before skill/template expansion.
  pi.on("input", async (event, ctx) => {
    pendingKeywords = findKeywords(event.text);

    if (pendingKeywords.size > 0 && ctx.hasUI) {
      ctx.ui.setStatus("magic-keywords", `✨ ${[...pendingKeywords].join(", ")}`);
    }

    return { action: "continue" };
  });

  // Inject hidden instructions into the system prompt + bump thinking level.
  pi.on("before_agent_start", async (event, ctx) => {
    if (pendingKeywords.size === 0) return;

    const instructions: string[] = [];

    // Bump thinking level for ultrathink
    if (pendingKeywords.has("ultrathink")) {
      const config = KEYWORDS.ultrathink;
      savedThinkingLevel = pi.getThinkingLevel() as ThinkingLevel;
      // Only bump if current level is lower than the target
      if (savedThinkingLevel !== config.thinkingLevel) {
        pi.setThinkingLevel(config.thinkingLevel);
      } else {
        // Already at target — nothing to restore
        savedThinkingLevel = null;
      }
    }

    // Build hidden instruction block
    for (const kw of pendingKeywords) {
      const config = KEYWORDS[kw as KeywordName];
      if (config?.instruction) {
        instructions.push(`[${kw}] ${config.instruction}`);
      }
    }

    if (instructions.length === 0) return;

    const hiddenBlock = `\n\n<keyword-guidance>\n${instructions.join("\n\n")}\n</keyword-guidance>`;

    return {
      systemPrompt: event.systemPrompt + hiddenBlock,
    };
  });

  // Restore thinking level after the full agent interaction settles (handles retries).
  pi.on("agent_settled", async (_event, ctx) => {
    if (savedThinkingLevel !== null) {
      pi.setThinkingLevel(savedThinkingLevel);
      savedThinkingLevel = null;
    }
    pendingKeywords.clear();
    if (ctx.hasUI) {
      ctx.ui.setStatus("magic-keywords", "");
    }
  });
}
