import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth, type OverlayHandle, type TUI } from "@earendil-works/pi-tui";

// Pin the relevant user prompt while scrolling back (fullscreen, pi >= 0.84):
// whenever the transcript is scrolled back, a full-width bar pins to the top
// of the screen showing the prompt that "owns" the content at the top of the
// viewport (sticky-section-header behavior, a la Claude Code). It updates as
// you scroll across exchanges and disappears when you return to the live tail
// (any live overlay blocks runtime TUI-mode switching, so it must not linger).
//
// The registered widget renders nothing; it exists only as a per-frame hook
// so the overlay can track scroll state. Note: the blank line above the
// editor is stock pi (a hardcoded Spacer in the widget container, present
// even with no extensions); this extension neither adds nor removes it.
//
// The sticky lookup walks pi's transcript component tree (UserMessageComponent
// leaves inside plain Containers) to compute document line offsets. That leans
// on pi internals; if a pi update renames things, the bar gracefully falls
// back to the last prompt sent this session.

const WIDGET_ID = "pin-last-prompt";
let lastPrompt = "";
let requestRender: (() => void) | null = null;

interface RenderableLike {
  render(width: number): string[];
  children?: unknown[];
  text?: unknown;
}

interface ScrollViewLike {
  scrollTop: number;
  getContentWidth(width: number): number;
  child?: unknown;
  contentHeight?: number;
}

type TuiInternals = TUI & {
  isFollowingOutput?: boolean;
  getPrimaryScrollView?: () => ScrollViewLike | undefined;
};

interface PromptEntry {
  start: number;
  text: string;
}

function collapse(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function padToWidth(text: string, width: number): string {
  const pad = width - visibleWidth(text);
  return pad > 0 ? text + " ".repeat(pad) : text;
}

function componentName(child: unknown): string {
  return (child as { constructor?: { name?: string } })?.constructor?.name ?? "";
}

/** Accumulate document line offsets of every UserMessageComponent.
 *  Recurses only into plain Containers (pure concatenation of children), so
 *  offsets match the exact lines the transcript ScrollView renders. */
function collectPrompts(children: unknown[], width: number, offset: number, out: PromptEntry[]): number {
  for (const child of children) {
    const name = componentName(child);
    const component = child as RenderableLike;
    if (name === "UserMessageComponent") {
      if (typeof component.text === "string") {
        out.push({ start: offset, text: collapse(component.text) });
      }
      offset += component.render(width).length;
    } else if (name === "Container" && Array.isArray(component.children)) {
      offset = collectPrompts(component.children, width, offset, out);
    } else {
      offset += component.render(width).length;
    }
  }
  return offset;
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, _ctx) => {
    if (typeof event.prompt === "string" && event.prompt.trim()) {
      lastPrompt = collapse(event.prompt);
      requestRender?.();
    }
  });

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setWidget(WIDGET_ID, (tui, theme) => {
      requestRender = () => tui.requestRender();
      const internals = tui as TuiInternals;

      let pinnedText = "";
      let overlay: OverlayHandle | null = null;
      let syncQueued = false;

      // Offset cache, invalidated when the transcript's width or total
      // rendered height changes (streaming, tool expand/collapse, resize).
      let cache: { width: number; contentHeight: number | undefined; entries: PromptEntry[] } | null = null;

      const promptEntries = (sv: ScrollViewLike): PromptEntry[] => {
        const doc = sv.child as RenderableLike | undefined;
        if (!doc || !Array.isArray(doc.children)) return [];
        const width = sv.getContentWidth(Math.max(1, tui.terminal.columns));
        if (!cache || cache.width !== width || cache.contentHeight !== sv.contentHeight) {
          const entries: PromptEntry[] = [];
          collectPrompts(doc.children, width, 0, entries);
          cache = { width, contentHeight: sv.contentHeight, entries };
        }
        return cache.entries;
      };

      /** The prompt owning the content at the top of the viewport. */
      const stickyPrompt = (): string => {
        const sv = internals.getPrimaryScrollView?.();
        if (!sv) return lastPrompt;
        const entries = promptEntries(sv);
        if (entries.length === 0) return lastPrompt;
        let current = entries[0]!; // clamp: above the first prompt, keep showing it
        for (const entry of entries) {
          if (entry.start > sv.scrollTop) break;
          current = entry;
        }
        return current.text;
      };

      // Full-width bar pinned to the top of the fullscreen transcript.
      // selectedBg (lighter than message panels) with an accent icon: distinct
      // from transcript messages without shouting.
      const topBar = {
        render(width: number): string[] {
          if (!pinnedText) return [];
          const label = truncateToWidth(pinnedText, Math.max(0, width - 4), "…");
          const line = ` ${theme.fg("accent", "\uf007")} ${theme.fg("text", label)}`;
          return [theme.bg("selectedBg", padToWidth(line, width))];
        },
        invalidate() {},
      };

      // isFollowingOutput only exists on the fullscreen renderer (TuiAltScreen).
      const scrolledBack = (): boolean =>
        tui.mode === "fullscreen" && internals.isFollowingOutput === false;

      // Called from render(), which runs every frame — that's where scroll
      // state is observable. The overlay composites after the dock renders,
      // so pinnedText updates land in the same frame; only overlay stack
      // mutations are deferred out of the render pass.
      const syncTopBar = () => {
        if (scrolledBack()) pinnedText = stickyPrompt();
        const want = scrolledBack() && !!pinnedText;
        if (syncQueued || want === (overlay !== null)) return;
        syncQueued = true;
        queueMicrotask(() => {
          syncQueued = false;
          const wantNow = scrolledBack() && !!pinnedText;
          if (wantNow && !overlay) {
            overlay = tui.showOverlay(topBar, {
              anchor: "top-left",
              row: 0,
              col: 0,
              width: "100%",
              nonCapturing: true,
            });
            tui.requestRender();
          } else if (!wantNow && overlay) {
            overlay.hide();
            overlay = null;
            tui.requestRender();
          }
        });
      };

      return {
        render(_width: number): string[] {
          syncTopBar();
          return [];
        },
        invalidate() {
          cache = null;
        },
        dispose() {
          overlay?.hide();
          overlay = null;
          requestRender = null;
        },
      };
    });
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setWidget(WIDGET_ID, undefined);
    lastPrompt = "";
    requestRender = null;
  });
}
