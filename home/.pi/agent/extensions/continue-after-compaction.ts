import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const buildContinuationPrompt = (
  sessionFile: string | undefined,
  compactionEntryId: string,
): string => {
  const sessionSource =
    sessionFile === undefined
      ? "This session is ephemeral, so no persisted session file is available."
      : [
          `The persisted session JSONL is ${JSON.stringify(sessionFile)}.`,
          "Inspect it directly with the read and bash tools.",
          "Do not launch a nested Pi process or open the session with `pi --session`.",
        ].join(" ");

  return `Compaction has just completed. Resume the existing task rather than waiting for another user prompt.

${sessionSource}
The new compaction entry ID is ${JSON.stringify(compactionEntryId)}.

Before continuing:

1. Review the active session branch leading to the compaction entry. Focus first on messages and tool calls immediately before compaction, searching earlier history only as needed. Remember that JSONL append order can include abandoned branches, so follow parentId links rather than blindly treating every entry as active.
2. Reconstruct the original goal, user constraints, decisions made, files changed, commands and tests run, unresolved issues, and intended next action.
3. Reconcile the recovered history with the compaction summary and current repository state. Treat the current worktree as authoritative for file state and the original session history as authoritative for user intent.
4. Briefly state the context you recovered.
5. Immediately perform the next unfinished step. Do not stop after the recap and do not ask the user to repeat prior context unless the session data is genuinely unavailable or ambiguous.`;
};

/**
 * Automatically resumes work after every successful Pi compaction.
 *
 * The continuation is deferred by one event-loop turn so manual compaction can
 * finish reconnecting the agent runtime before a new prompt begins. During an
 * active automatic-compaction recovery, it is delivered as a follow-up.
 */
export default function continueAfterCompaction(pi: ExtensionAPI): void {
  const pendingTimers = new Set<ReturnType<typeof setTimeout>>();

  pi.on("session_compact", (event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    const prompt = buildContinuationPrompt(sessionFile, event.compactionEntry.id);

    const timer = setTimeout(() => {
      pendingTimers.delete(timer);
      pi.sendUserMessage(prompt, { deliverAs: "followUp" });
    }, 0);

    pendingTimers.add(timer);
  });

  pi.on("session_shutdown", () => {
    for (const timer of pendingTimers) {
      clearTimeout(timer);
    }
    pendingTimers.clear();
  });
}
