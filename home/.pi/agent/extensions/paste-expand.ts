/**
 * Paste-again-to-expand (Claude Code style).
 *
 * Pi collapses large pastes (>10 lines or >1000 chars) into a `[paste #N ...]`
 * marker. With this extension, pasting the same content again while the marker
 * is present expands it inline so you can see and edit the actual text.
 *
 * NOTE: reaches into pi-tui Editor internals (state, pastes registry) that are
 * TS-private but runtime-accessible. May need updating if pi-tui changes its
 * paste-marker format or registry bookkeeping.
 */

import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PASTE_MARKER_REGEX = /\[paste #(\d+)( (\+\d+ lines|\d+ chars))?\]/g;

/** Replicates pi-tui's paste cleanup so an incoming paste can be compared
 * against already-collapsed paste content. */
function cleanPastedText(text: string): string {
	// Decode CSI-u Ctrl+<letter> sequences some terminals emit inside bracketed paste
	const decoded = text.replace(/\x1b\[(\d+);5u/g, (match, code) => {
		const cp = Number(code);
		if (cp >= 97 && cp <= 122) return String.fromCharCode(cp - 96);
		if (cp >= 65 && cp <= 90) return String.fromCharCode(cp - 64);
		return match;
	});
	// normalizeText: CRLF/CR -> LF, tabs -> 4 spaces
	const normalized = decoded.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\t/g, "    ");
	// Strip non-printables except newline
	return normalized
		.split("")
		.filter((c) => c === "\n" || c.charCodeAt(0) >= 32)
		.join("");
}

// pi-tui Editor privates we touch at runtime
interface EditorInternals {
	state: { lines: string[]; cursorLine: number; cursorCol: number };
	pastes: Map<number, string>;
	pasteCounter: number;
	lastAction: unknown;
	pushUndoSnapshot(): void;
	cancelAutocomplete(): void;
	exitHistoryBrowsing(): void;
	setCursorCol(col: number): void;
}

class PasteExpandEditor extends CustomEditor {
	handlePaste(pastedText: string): void {
		const self = this as unknown as EditorInternals;
		if (self.pastes.size > 0) {
			const cleaned = cleanPastedText(pastedText);
			for (const [id, content] of self.pastes) {
				// handlePaste may have prepended a space to path-like pastes
				if (content !== cleaned && content !== ` ${cleaned}`) continue;
				const markerRe = new RegExp(`\\[paste #${id}( (\\+\\d+ lines|\\d+ chars))?\\]`);
				if (!markerRe.test(this.getText())) continue;
				this.expandCollapsedPaste(id, content);
				return;
			}
		}
		super.handlePaste(pastedText);
	}

	/** Replace the collapsed marker for paste `id` with its real content,
	 * keeping the paste registry dense (same bookkeeping as marker deletion). */
	private expandCollapsedPaste(id: number, content: string): void {
		const self = this as unknown as EditorInternals;
		self.cancelAutocomplete();
		self.exitHistoryBrowsing();
		self.lastAction = null;
		self.pushUndoSnapshot();

		const markerRe = new RegExp(`\\[paste #${id}( (\\+\\d+ lines|\\d+ chars))?\\]`);

		// Markers are atomic single-line segments; find the line containing it
		let lineIdx = -1;
		let match: RegExpExecArray | null = null;
		for (let i = 0; i < self.state.lines.length; i++) {
			const m = markerRe.exec(self.state.lines[i]);
			if (m) {
				lineIdx = i;
				match = m;
				break;
			}
		}
		if (lineIdx === -1 || !match) return;

		const line = self.state.lines[lineIdx];
		const before = line.slice(0, match.index);
		const after = line.slice(match.index + match[0].length);
		self.state.lines.splice(lineIdx, 1, ...(before + content + after).split("\n"));

		// Remove registry entry, shift higher ids down, renumber their markers
		self.pastes.delete(id);
		self.pasteCounter--;
		const higher = [...self.pastes.keys()].filter((k) => k > id).sort((a, b) => a - b);
		for (const k of higher) {
			self.pastes.set(k - 1, self.pastes.get(k)!);
			self.pastes.delete(k);
		}
		self.state.lines = self.state.lines.map((l) =>
			l.replace(PASTE_MARKER_REGEX, (full, idGroup, suffix) =>
				Number(idGroup) <= id ? full : `[paste #${Number(idGroup) - 1}${suffix}]`,
			),
		);

		// Cursor to end of the expanded content
		const contentLines = content.split("\n");
		self.state.cursorLine = lineIdx + contentLines.length - 1;
		self.setCursorCol(
			contentLines.length === 1 ? before.length + content.length : contentLines[contentLines.length - 1].length,
		);

		if (this.onChange) this.onChange(this.getText());
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setEditorComponent((tui, theme, keybindings) => new PasteExpandEditor(tui, theme, keybindings));
	});
}
