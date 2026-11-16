// FindBin.js - where one of the dotfiles' bin/ scripts is, for a Process
// (PLAN M10: ThemePicker's bin/theme).
//
// The shell used to name Quickshell.shellDir + "/../../bin/<name>", which
// finds the script only while the config dir is a link into a checkout (the
// kernel walks .. from the link's target). In order, the first executable
// file of:
//   1. `local`, that same path: the checkout this shell runs from
//      (~/.config/quickshell, a worktree, the sandbox), so each runs its own;
//   2. $DOTFILES/bin/<name> (home/.zshenv exports it, and the session's
//      systemd environment carries it);
//   3. <name> on PATH ($DOTFILES/bin is on it).
// 2 and 3 only with `fallbacks` (fallbacksFor below): a copy of the config
// (check.sh's, shoot.sh's) gets its own ../../bin or nothing, so a test or a
// sandbox can never reach the live checkout's script.
// The answer is printed through realpath, so every later run names one file.
// Exit 1 when none is there. sh and coreutils only.
var SCRIPT = 'n=$1; fb=$2; shift 2; ' +
    'if [ "$fb" = 1 ]; then set -- "$@" "${DOTFILES:+$DOTFILES/bin/$n}" "$(command -v -- "$n" 2>/dev/null)"; fi; ' +
    'for b in "$@"; do ' +
    'if [ -n "$b" ] && [ -f "$b" ] && [ -x "$b" ]; then realpath -- "$b" 2>/dev/null || printf "%s\\n" "$b"; exit 0; fi; done; exit 1';

// Whether 2 and 3 may answer: only for the shell the session runs, the
// config at $XDG_CONFIG_HOME/quickshell (~/.config/quickshell when that is
// unset), and never in the sandbox or a dry run (`blocked`). That config is
// a link into the checkout today; a link farm in its place has no ../../bin.
function fallbacksFor(shellDir, home, xdgConfig, blocked) {
    if (blocked) return false;
    var strip = function (p) {
        return String(p || "").replace(/\/+$/, "");
    };
    var base = strip(xdgConfig) !== "" ? strip(xdgConfig) : strip(home) !== "" ? strip(home) + "/.config" : "";
    return base !== "" && strip(shellDir) === base + "/quickshell";
}

// argv for a Process: prints the path (one line) or exits 1.
function command(name, local, fallbacks) {
    return ["sh", "-c", SCRIPT, "sh", String(name), fallbacks ? "1" : "0", String(local || "")];
}

if (typeof module !== "undefined")
    module.exports = { SCRIPT: SCRIPT, command: command, fallbacksFor: fallbacksFor };
