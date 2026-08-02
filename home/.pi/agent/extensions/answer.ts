import { complete, type Api, type Model, type UserMessage } from "@earendil-works/pi-ai";
import {
  BorderedLoader,
  Theme,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  type Component,
  type Focusable,
  Editor,
  type EditorTheme,
  Key,
  matchesKey,
  type TUI,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

interface ExtractedQuestion {
  question: string;
  context?: string;
}

interface ExtractionResult {
  questions: ExtractedQuestion[];
}

type ExtractionOutcome =
  | { type: "success"; result: ExtractionResult }
  | { type: "cancelled" }
  | { type: "error"; message: string };

const SYSTEM_PROMPT = `You extract questions from assistant text that still need answers from the user.

Return exactly one JSON object with this shape:
{
  "questions": [
    {
      "question": "Question text",
      "context": "Optional short context"
    }
  ]
}

Rules:
- Extract only questions that require user input.
- Keep questions in the original order.
- Each extracted question must be understandable on its own without requiring the user to reread earlier messages.
- Concisely preserve any context that the user may need to answer the question without needing to reread earlier messages.
- Prefer preserving the original wording with light cleanup over aggressive paraphrasing.
- Preserve all details that could affect the answer, including the subject, options, constraints, file/component names, and requested output format.
- Resolve ambiguous references like "it", "that", "this", or "the above" when nearby text makes the referent clear.
- Keep the question concise only if conciseness does not remove answer-relevant context.
- Do not shorten a question if the shortened version would force the user to scroll up to understand what is being asked.
- If important setup would make the question clearer, include a short context field.
- When unsure, favor completeness and clarity over brevity.
- Do not add commentary outside the JSON object.
- If there are no user-answerable questions, return {"questions": []}.`;

interface ExtractionModelPreference {
  provider: string;
  modelId: string;
}

const EXTRACTION_MODEL_PREFERENCES: readonly ExtractionModelPreference[] = [
  { provider: "openai-codex", modelId: "gpt-5.5" },
  { provider: "anthropic", modelId: "claude-haiku-4-5" },
];

function formatExtractionModelPreferences(
  preferences: readonly ExtractionModelPreference[],
): string {
  return preferences.map((candidate) => `${candidate.provider}/${candidate.modelId}`).join(", ");
}

function getTextParts(content: Array<{ type: string; text?: string }>): string[] {
  return content
    .filter(
      (part): part is { type: "text"; text: string } =>
        part.type === "text" && typeof part.text === "string",
    )
    .map((part) => part.text);
}

function getJsonCandidates(text: string): string[] {
  const candidates = new Set<string>();
  const trimmed = text.trim();

  if (trimmed) {
    candidates.add(trimmed);
  }

  for (const match of text.matchAll(/```(?:json)?\s*([\s\S]*?)```/gi)) {
    const candidate = match[1]?.trim();
    if (candidate) {
      candidates.add(candidate);
    }
  }

  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace !== -1 && lastBrace > firstBrace) {
    const candidate = text.slice(firstBrace, lastBrace + 1).trim();
    if (candidate) {
      candidates.add(candidate);
    }
  }

  return [...candidates];
}

function normalizeExtractedQuestions(result: ExtractionResult): ExtractionResult {
  const seen = new Set<string>();
  const questions: ExtractedQuestion[] = [];

  for (const item of result.questions) {
    const question = item.question.trim();
    const context = item.context?.trim() || undefined;
    if (!question) continue;

    const key = question.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);

    questions.push({ question, context });
  }

  return { questions };
}

function parseExtractionResult(text: string): ExtractionOutcome {
  for (const candidate of getJsonCandidates(text)) {
    try {
      const parsed = JSON.parse(candidate) as ExtractionResult;
      if (parsed && Array.isArray(parsed.questions)) {
        return {
          type: "success",
          result: normalizeExtractedQuestions(parsed),
        };
      }
    } catch {
      // Try the next candidate.
    }
  }

  return {
    type: "error",
    message: "Question extraction returned invalid JSON.",
  };
}

function fallbackExtractQuestions(text: string): ExtractionResult {
  const normalized = text.replace(/\r\n?/g, "\n").trim();
  const questionMatches = normalized.match(/[^\n.!?]*\?+(?:["')\]]+)?/g) ?? [];
  const questions = questionMatches
    .map((question) => question.replace(/^[\s>*-]+/, "").trim())
    .filter((question) => question.length > 0)
    .map((question) => ({ question }));

  return normalizeExtractedQuestions({ questions });
}

function findLastCompletedAssistantMessage(ctx: ExtensionContext): {
  text?: string;
  skippedIncomplete: boolean;
} {
  const branch = ctx.sessionManager.getBranch();
  let skippedIncomplete = false;

  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i]!;
    if (entry.type !== "message") continue;

    const message = entry.message;
    if (!("role" in message) || message.role !== "assistant") continue;

    const text = getTextParts(message.content).join("\n").trim();
    if (message.stopReason !== "stop") {
      skippedIncomplete = true;
      continue;
    }

    if (!text) continue;
    return { text, skippedIncomplete };
  }

  return { skippedIncomplete };
}

async function selectExtractionModel(
  modelRegistry: {
    find: (provider: string, modelId: string) => Model<Api> | undefined;
    getApiKeyAndHeaders: (
      model: Model<Api>,
    ) => Promise<
      { ok: true; apiKey?: string; headers?: Record<string, string> } | { ok: false; error: string }
    >;
  },
  preferences: readonly ExtractionModelPreference[],
): Promise<Model<Api> | undefined> {
  for (const candidate of preferences) {
    const model = modelRegistry.find(candidate.provider, candidate.modelId);
    if (!model) continue;

    const auth = await modelRegistry.getApiKeyAndHeaders(model);
    if (auth.ok) {
      return model;
    }
  }

  return undefined;
}

function buildAnswerMessage(questions: ExtractedQuestion[], answers: string[]): string {
  const lines = ["Here are my answers to your questions:", ""];

  for (let i = 0; i < questions.length; i++) {
    const question = questions[i]!;
    const answer = answers[i]?.trim() || "(no answer)";

    lines.push(`Q: ${question.question}`);
    if (question.context) {
      lines.push(`Context: ${question.context}`);
    }
    lines.push(`A: ${answer}`);

    if (i < questions.length - 1) {
      lines.push("");
    }
  }

  return lines.join("\n");
}

class AnswerComponent implements Component, Focusable {
  private _focused = false;

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.editor.focused = value;
  }

  private readonly answers: string[];
  private readonly editor: Editor;
  private currentIndex = 0;
  private showingConfirmation = false;
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(
    private readonly questions: ExtractedQuestion[],
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly done: (result: string | null) => void,
  ) {
    this.answers = questions.map(() => "");

    const editorTheme: EditorTheme = {
      borderColor: (text: string) => this.theme.fg("borderAccent", text),
      selectList: {
        selectedPrefix: (text: string) => this.theme.fg("accent", text),
        selectedText: (text: string) => this.theme.fg("accent", text),
        description: (text: string) => this.theme.fg("muted", text),
        scrollInfo: (text: string) => this.theme.fg("dim", text),
        noMatch: (text: string) => this.theme.fg("warning", text),
      },
    };

    this.editor = new Editor(this.tui, editorTheme);
    this.editor.disableSubmit = true;
    this.editor.onChange = () => {
      this.invalidate();
      this.tui.requestRender();
    };
  }

  private border(text: string): string {
    return this.theme.fg("border", text);
  }

  private saveCurrentAnswer(): void {
    this.answers[this.currentIndex] = this.editor.getText();
  }

  private answeredCount(): number {
    this.saveCurrentAnswer();
    return this.answers.filter((answer) => answer.trim().length > 0).length;
  }

  private navigateTo(index: number): void {
    if (index < 0 || index >= this.questions.length) return;
    this.saveCurrentAnswer();
    this.currentIndex = index;
    this.editor.setText(this.answers[index] || "");
    this.showingConfirmation = false;
    this.invalidate();
  }

  private submit(): void {
    this.saveCurrentAnswer();
    this.done(buildAnswerMessage(this.questions, this.answers));
  }

  private cancel(): void {
    this.done(null);
  }

  handleInput(data: string): void {
    if (this.showingConfirmation) {
      if (matchesKey(data, Key.enter) || data.toLowerCase() === "y") {
        this.submit();
        return;
      }
      if (
        matchesKey(data, Key.escape) ||
        matchesKey(data, Key.ctrl("c")) ||
        data.toLowerCase() === "n"
      ) {
        this.showingConfirmation = false;
        this.invalidate();
        this.tui.requestRender();
        return;
      }
      return;
    }

    if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
      this.cancel();
      return;
    }

    if (matchesKey(data, Key.tab)) {
      if (this.currentIndex < this.questions.length - 1) {
        this.navigateTo(this.currentIndex + 1);
        this.tui.requestRender();
      } else {
        this.saveCurrentAnswer();
        this.showingConfirmation = true;
        this.invalidate();
        this.tui.requestRender();
      }
      return;
    }

    if (matchesKey(data, Key.shift("tab"))) {
      if (this.currentIndex > 0) {
        this.navigateTo(this.currentIndex - 1);
        this.tui.requestRender();
      }
      return;
    }

    if (matchesKey(data, Key.up) && this.editor.getText() === "") {
      if (this.currentIndex > 0) {
        this.navigateTo(this.currentIndex - 1);
        this.tui.requestRender();
        return;
      }
    }

    if (matchesKey(data, Key.down) && this.editor.getText() === "") {
      if (this.currentIndex < this.questions.length - 1) {
        this.navigateTo(this.currentIndex + 1);
        this.tui.requestRender();
        return;
      }
    }

    if (matchesKey(data, Key.enter) && !matchesKey(data, Key.shift("enter"))) {
      this.saveCurrentAnswer();
      if (this.currentIndex < this.questions.length - 1) {
        this.navigateTo(this.currentIndex + 1);
      } else {
        this.showingConfirmation = true;
        this.invalidate();
      }
      this.tui.requestRender();
      return;
    }

    this.editor.handleInput(data);
    this.invalidate();
    this.tui.requestRender();
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    const lines: string[] = [];
    const boxWidth = Math.min(Math.max(width, 1), 120);
    const innerWidth = Math.max(1, boxWidth - 2);
    const contentWidth = Math.max(1, innerWidth - 2);
    const question = this.questions[this.currentIndex]!;
    const answered = this.answeredCount();
    const unanswered = this.questions.length - answered;

    const pushBoxLine = (content = "") => {
      const line = truncateToWidth(content, innerWidth, "…");
      const padding = Math.max(0, innerWidth - visibleWidth(line));
      lines.push(this.border("│") + line + " ".repeat(padding) + this.border("│"));
    };

    lines.push(this.border(`╭${"─".repeat(innerWidth)}╮`));
    pushBoxLine(
      ` ${this.theme.fg("accent", this.theme.bold("Questions"))}${this.theme.fg("dim", ` (${this.currentIndex + 1}/${this.questions.length})`)}`,
    );
    pushBoxLine(` ${this.theme.fg("muted", `Answered ${answered}/${this.questions.length}`)}`);
    pushBoxLine(
      ` ${this.questions
        .map((_, index) => {
          const label = String(index + 1);
          if (index === this.currentIndex) {
            return this.theme.bg("selectedBg", this.theme.fg("text", ` ${label} `));
          }
          if (this.answers[index]?.trim()) {
            return this.theme.fg("success", label);
          }
          return this.theme.fg("dim", label);
        })
        .join(" ")}`,
    );
    lines.push(this.border(`├${"─".repeat(innerWidth)}┤`));

    for (const line of wrapTextWithAnsi(
      `${this.theme.bold("Q: ")}${question.question}`,
      contentWidth,
    )) {
      pushBoxLine(` ${line}`);
    }

    if (question.context) {
      pushBoxLine();
      for (const line of wrapTextWithAnsi(
        this.theme.fg("muted", `Context: ${question.context}`),
        contentWidth,
      )) {
        pushBoxLine(` ${line}`);
      }
    }

    pushBoxLine();

    const answerPrefix = this.theme.bold("A: ");
    const answerPrefixWidth = visibleWidth(answerPrefix);
    const editorWidth = Math.max(1, contentWidth - answerPrefixWidth);
    const editorLines = this.editor.render(editorWidth);
    for (let i = 1; i < editorLines.length - 1; i++) {
      const prefix = i === 1 ? answerPrefix : " ".repeat(answerPrefixWidth);
      pushBoxLine(` ${prefix}${editorLines[i]}`);
    }

    pushBoxLine();
    lines.push(this.border(`├${"─".repeat(innerWidth)}┤`));

    if (this.showingConfirmation) {
      const message =
        unanswered > 0
          ? ` Submit answers? ${unanswered} unanswered ${unanswered === 1 ? "item" : "items"} will be sent as '(no answer)'. Enter/y confirm • Esc/n back`
          : " Submit answers? Enter/y confirm • Esc/n back";
      pushBoxLine(this.theme.fg("warning", truncateToWidth(message, innerWidth - 1, "…")));
    } else {
      const controls = " Tab/Enter next • Shift+Tab previous • Shift+Enter newline • Esc cancel";
      pushBoxLine(this.theme.fg("dim", truncateToWidth(controls, innerWidth - 1, "…")));
    }

    lines.push(this.border(`╰${"─".repeat(innerWidth)}╯`));

    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

export default function (pi: ExtensionAPI) {
  const answerHandler = async (ctx: ExtensionContext) => {
    if (!ctx.hasUI) {
      ctx.ui.notify("answer requires interactive mode", "error");
      return;
    }

    if (!ctx.model) {
      ctx.ui.notify("No model selected", "error");
      return;
    }

    const { text: lastAssistantText, skippedIncomplete } = findLastCompletedAssistantMessage(ctx);
    if (!lastAssistantText) {
      ctx.ui.notify(
        skippedIncomplete
          ? "No completed assistant message found yet"
          : "No assistant messages found",
        "error",
      );
      return;
    }

    if (skippedIncomplete) {
      ctx.ui.notify("Using the last completed assistant message", "warning");
    }

    const extractionModelPreferences = EXTRACTION_MODEL_PREFERENCES;
    const extractionModel = await selectExtractionModel(
      ctx.modelRegistry,
      extractionModelPreferences,
    );
    if (!extractionModel) {
      ctx.ui.notify(
        `No configured extraction model is available with a configured API key. Checked: ${formatExtractionModelPreferences(extractionModelPreferences)}`,
        "error",
      );
      return;
    }

    const extractionOutcome = await ctx.ui.custom<ExtractionOutcome>((tui, theme, _kb, done) => {
      const loader = new BorderedLoader(
        tui,
        theme,
        `Extracting questions using ${extractionModel.provider}/${extractionModel.id}...`,
      );
      loader.onAbort = () => done({ type: "cancelled" });

      const doExtract = async () => {
        const auth = await ctx.modelRegistry.getApiKeyAndHeaders(extractionModel);
        if (!auth.ok) {
          const authError = "error" in auth ? auth.error : "Unknown auth error";
          return {
            type: "error",
            message: `No auth available for ${extractionModel.provider}/${extractionModel.id}: ${authError}`,
          } as ExtractionOutcome;
        }

        const userMessage: UserMessage = {
          role: "user",
          content: [{ type: "text", text: lastAssistantText }],
          timestamp: Date.now(),
        };

        const response = await complete(
          extractionModel,
          { systemPrompt: SYSTEM_PROMPT, messages: [userMessage] },
          {
            apiKey: auth.apiKey,
            headers: auth.headers,
            signal: loader.signal,
            ...(extractionModel.provider === "openai-codex" ? { reasoningEffort: "none" } : {}),
          },
        );

        if (response.stopReason === "aborted") {
          return { type: "cancelled" } as ExtractionOutcome;
        }

        const responseText = getTextParts(response.content).join("\n").trim();
        if (!responseText) {
          const fallback = fallbackExtractQuestions(lastAssistantText);
          return {
            type: "success",
            result: fallback,
          } as ExtractionOutcome;
        }

        const parsed = parseExtractionResult(responseText);
        if (parsed.type === "error") {
          const fallback = fallbackExtractQuestions(lastAssistantText);
          if (fallback.questions.length > 0) {
            return {
              type: "success",
              result: fallback,
            } as ExtractionOutcome;
          }
        }

        return parsed;
      };

      doExtract()
        .then(done)
        .catch((error) => {
          done({
            type: "error",
            message: error instanceof Error ? error.message : String(error),
          });
        });

      return loader;
    });

    if (extractionOutcome.type === "cancelled") {
      ctx.ui.notify("Cancelled", "info");
      return;
    }

    if (extractionOutcome.type === "error") {
      ctx.ui.notify(extractionOutcome.message, "error");
      return;
    }

    if (extractionOutcome.result.questions.length === 0) {
      ctx.ui.notify("No questions found in the selected assistant message", "info");
      return;
    }

    const answersResult = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
      return new AnswerComponent(extractionOutcome.result.questions, tui, theme, done);
    });

    if (answersResult === null) {
      ctx.ui.notify("Cancelled", "info");
      return;
    }

    if (ctx.isIdle()) {
      pi.sendUserMessage(answersResult);
    } else {
      pi.sendUserMessage(answersResult, { deliverAs: "followUp" });
      ctx.ui.notify("Answers queued as a follow-up message", "info");
    }
  };

  pi.registerCommand("answer", {
    description:
      "Extract questions from the last completed assistant message into an interactive Q&A",
    handler: async (_args, ctx) => answerHandler(ctx),
  });

  pi.registerShortcut("ctrl+.", {
    description: "Extract and answer questions",
    handler: answerHandler,
  });
}
