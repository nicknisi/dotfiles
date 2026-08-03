import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pin the user's last prompt as a 1-line widget above the input editor,
// so it stays visible even when the response scrolls it off-screen.
// Truncates with ellipsis to fit the terminal width.

const WIDGET_ID = "pin-last-prompt";
let lastPrompt = "";
let active = false;
let requestRender: (() => void) | null = null;

function truncate(text: string, width: number, budget: number): string {
  // Ellipsis if it overflows the budget (in visible cells).
  if (text.length <= budget) return text;
  return text.slice(0, Math.max(0, budget - 1)).trimEnd() + "…";
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, _ctx) => {
    if (typeof event.prompt === "string" && event.prompt.trim()) {
      lastPrompt = event.prompt.replace(/\n+/g, " ").trim();
      active = true;
      requestRender?.();
    }
  });

  pi.on("agent_end", async (_event, _ctx) => {
    active = false;
    requestRender?.();
  });

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setWidget(WIDGET_ID, (tui, theme) => {
      requestRender = () => tui.requestRender();
      // Nerd font user glyph () in accent, prompt text in muted.
      const icon = theme.fg("accent", "\uf007");
      const gap = " ";
      const indent = " ";
      const prefixWidth = 3; // indent (1) + icon (1) + gap (1)
      return {
        render(width: number): string[] {
          if (!lastPrompt || !active) return [];
          const text = theme.fg("muted", truncate(lastPrompt, width, Math.max(0, width - prefixWidth)));
          return [indent + icon + gap + text];
        },
        invalidate() {},
      };
    });
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setWidget(WIDGET_ID, undefined);
    lastPrompt = "";
    active = false;
    requestRender = null;
  });
}
