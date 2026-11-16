// FaceModel.js - the profile picture, as pure functions (Face.qml runs them;
// tests/face-model.cjs pins them under node).
//
// Where the picture comes from, first that works:
//   1. ~/.face, when it is a readable regular file of 1 byte to MAX_BYTES
//      that decodes as an image;
//   2. /var/lib/AccountsService/icons/$USER, the same way;
//   3. none: the initial in its circle, exactly as before.
// The file checks (regular, readable, size) run in one `sh` per refresh
// (checkCommand): `[ -f ]` refuses a FIFO, a device, a directory and a
// symlink loop, so nothing that could hang or flood the image reader ever
// reaches it. Whether it decodes is the drawing Image's business
// (Kit/FacePicture.qml walks `sources` in order and falls back to the
// initial).
//
// Setting it copies the chosen image to ~/.face atomically: a temp file made
// by mktemp in the same directory, filled with `cat`, then `mv -f` over
// ~/.face (rename(2): a reader sees the old file or the new one, never half
// of one). The result is always a regular file: a symlink at ~/.face is
// replaced, never followed. Clearing removes ~/.face (a symlink there goes,
// its target stays).

var MAX_BYTES = 32 * 1024 * 1024;
// What the picker lists from ~/Pictures. ~/.face itself needs no extension:
// the reader sniffs the format.
var EXTENSIONS = ["png", "jpg", "jpeg", "webp", "gif", "bmp"];
// The picker's cap: the newest this many images.
var LIST_LIMIT = 120;

function text(v) {
    return v === undefined || v === null ? "" : String(v);
}

// An absolute path with no control characters (they would break the
// line-based replies below), no NUL and no empty segment games.
function cleanPath(p) {
    var s = text(p);
    if (s.length < 2 || s.charAt(0) !== "/") return "";
    if (/[\u0000-\u001f\u007f]/.test(s)) return "";
    return s.replace(/\/+$/, "");
}

// A login name safe to put in a path.
function safeUser(user) {
    var u = text(user);
    return u !== "" && u !== "." && u !== ".." && /^[A-Za-z0-9._][A-Za-z0-9._-]*$/.test(u) ? u : "";
}

// [{ kind: "face" | "system", path }], in the order they are tried.
function candidates(home, user, iconsDir) {
    var out = [];
    var h = cleanPath(home);
    if (h !== "") out.push({ kind: "face", path: h + "/.face" });
    var u = safeUser(user);
    var d = cleanPath(iconsDir);
    if (u !== "" && d !== "") out.push({ kind: "system", path: d + "/" + u });
    return out;
}

function facePath(home) {
    var h = cleanPath(home);
    return h === "" ? "" : h + "/.face";
}

// The one-shot check: argv for Quickshell's Process. One line per path, in
// order: "ok\t<path>\t<size>\t<mtime>" or "no\t<path>\t<why>" (missing,
// type, unreadable, empty, large, stat).
var CHECK_SCRIPT = [
    'max=$1; shift',
    'for f in "$@"; do',
    '  if [ -f "$f" ]; then',
    '    if [ ! -r "$f" ]; then printf "no\\t%s\\tunreadable\\n" "$f"; continue; fi',
    '    st=$(stat -L -c "%s %Y" -- "$f" 2>/dev/null) || { printf "no\\t%s\\tstat\\n" "$f"; continue; }',
    '    s=${st%% *}; t=${st#* }',
    '    if [ "$s" -le 0 ]; then printf "no\\t%s\\tempty\\n" "$f"',
    '    elif [ "$s" -gt "$max" ]; then printf "no\\t%s\\tlarge\\n" "$f"',
    '    else printf "ok\\t%s\\t%s\\t%s\\n" "$f" "$s" "$t"; fi',
    '  elif [ -e "$f" ] || [ -L "$f" ]; then printf "no\\t%s\\ttype\\n" "$f"',
    '  else printf "no\\t%s\\tmissing\\n" "$f"; fi',
    'done'
].join("\n");

function checkCommand(paths, maxBytes) {
    var list = [];
    for (var i = 0; i < (paths || []).length; i++) {
        var p = cleanPath(paths[i]);
        if (p !== "") list.push(p);
    }
    var max = Math.max(1, Math.floor(Number(maxBytes) || MAX_BYTES));
    return ["sh", "-c", CHECK_SCRIPT, "sh", String(max)].concat(list);
}

// The check's lines -> [{ path, ok, why, size, mtime }].
function parseCheck(out) {
    var rows = [];
    var lines = text(out).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split("\t");
        if (f.length < 3 || (f[0] !== "ok" && f[0] !== "no")) continue;
        if (f[0] === "ok")
            rows.push({ path: f[1], ok: true, why: "", size: Number(f[2]) || 0, mtime: Number(f[3]) || 0 });
        else
            rows.push({ path: f[1], ok: false, why: f[2], size: 0, mtime: 0 });
    }
    return rows;
}

// A file URL for Image, each segment escaped. `version` goes in the query,
// which the reader ignores for a local file but the pixmap cache does not,
// so a replaced picture loads afresh.
function fileUrl(path, version) {
    var p = cleanPath(path);
    if (p === "") return "";
    var segs = p.split("/");
    for (var i = 0; i < segs.length; i++) segs[i] = encodeURIComponent(segs[i]);
    var v = text(version);
    return "file://" + segs.join("/") + (v !== "" ? "?v=" + encodeURIComponent(v) : "");
}

// The candidates the check let through, as the sources FacePicture tries:
// [{ kind, path, url }].
function sources(cands, checked) {
    var out = [];
    for (var i = 0; i < (cands || []).length; i++) {
        var c = cands[i];
        for (var j = 0; j < (checked || []).length; j++) {
            var r = checked[j];
            if (r.path === c.path && r.ok) {
                out.push({ kind: c.kind, path: c.path, url: fileUrl(c.path, r.mtime + "-" + r.size) });
                break;
            }
        }
    }
    return out;
}

// The initial in the circle: the display name's first letter, "?" for none.
function initial(name) {
    var n = text(name).trim();
    return n.length > 0 ? n.charAt(0).toUpperCase() : "?";
}

// What `face set PATH` accepts before it looks at the file: "" when fine,
// else why not.
function setError(path, home) {
    var p = cleanPath(path);
    if (p === "") return "the path must be absolute";
    var dst = facePath(home);
    if (dst === "") return "no home directory";
    if (p === dst) return "that is the profile picture already";
    return "";
}

// Atomic copy: argv. The temp file is in ~/.face's own directory, so the
// rename never crosses a filesystem.
var SET_SCRIPT = [
    'set -eu',
    'src=$1; dst=$2',
    '[ -f "$src" ] && [ -r "$src" ] || { echo "not a readable file: $src" >&2; exit 3; }',
    'tmp=$(mktemp "$dst.XXXXXX")',
    'trap \'rm -f -- "$tmp"\' EXIT',
    'cat -- "$src" >"$tmp"',
    'chmod 644 -- "$tmp"',
    // -T: a directory (or a symlink to one) at ~/.face is replaced or
    // refused, never moved into. Linux only, as the shell is.
    'mv -fT -- "$tmp" "$dst"',
    'trap - EXIT'
].join("\n");

function setCommand(src, home) {
    return ["sh", "-c", SET_SCRIPT, "sh", cleanPath(src), facePath(home)];
}
function clearCommand(home) {
    return ["rm", "-f", "--", facePath(home)];
}

// The picker's listing: argv for `find` under DIR (two levels, regular
// files with an image extension), newest first in parseList.
function listCommand(dir) {
    var d = cleanPath(dir);
    var names = [];
    for (var i = 0; i < EXTENSIONS.length; i++) {
        if (i > 0) names.push("-o");
        names.push("-iname", "*." + EXTENSIONS[i]);
    }
    return ["find", d === "" ? "/nonexistent" : d, "-maxdepth", "2", "-type", "f", "("].concat(names, [")", "-size", "-" + Math.floor(MAX_BYTES / 1024) + "k", "-printf", "%T@\\t%s\\t%p\\n"]);
}

// find's lines -> [{ name, path, mtime, size }], newest first, at most
// `limit`, hidden files and directories left out.
function parseList(out, dir, limit) {
    var base = cleanPath(dir);
    var rows = [];
    var lines = text(out).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split("\t");
        if (f.length < 3) continue;
        var path = f.slice(2).join("\t");
        if (cleanPath(path) === "") continue;
        var rel = base !== "" && path.indexOf(base + "/") === 0 ? path.slice(base.length + 1) : path.split("/").pop();
        if (/(^|\/)\./.test(rel)) continue;
        rows.push({ name: rel, path: path, mtime: Number(f[0]) || 0, size: Number(f[1]) || 0 });
    }
    rows.sort(function (a, b) {
        return b.mtime - a.mtime || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
    });
    var n = Math.max(0, Math.floor(Number(limit) || LIST_LIMIT));
    return rows.slice(0, n);
}

// The sheet's header and footer (Panels/Sheets/FaceSheet.qml, SheetFrame's
// sheetData): where the picture comes from, and Remove while ~/.face is it.
//   src: { kind: "face" | "system" | "", busy, error, count, loaded }
function sheet(src) {
    var s = src || {};
    var kind = text(s.kind);
    var status = s.busy ? "Saving…" : kind === "face" ? "From ~/.face" : kind === "system" ? "From AccountsService" : "Initial";
    return {
        status: status,
        hasSwitch: false,
        switchOn: false,
        switchEnabled: false,
        groups: text(s.error) !== "" ? [{ label: "", rows: [{ key: "error", title: "Profile picture", sub: text(s.error), icon: "user", bad: true, inert: true, wrap: true }] }] : [],
        footer: "Remove picture",
        footerEnabled: kind === "face" && !s.busy,
        error: text(s.error)
    };
}

// A path under home as "~/...", for labels.
function tilde(path, home) {
    var p = text(path), h = text(home).replace(/\/+$/, "");
    if (h !== "" && (p === h || p.indexOf(h + "/") === 0)) return "~" + p.slice(h.length);
    return p;
}

// The `face get` reply's shape.
function report(src) {
    var s = src || {};
    return {
        kind: text(s.kind) || "initial",
        path: text(s.path),
        busy: s.busy === true,
        error: text(s.error),
        candidates: (s.checked || []).map(function (r) {
            return r.ok ? { path: r.path, ok: true, size: r.size } : { path: r.path, ok: false, why: r.why };
        })
    };
}

if (typeof module !== "undefined")
    module.exports = {
        MAX_BYTES: MAX_BYTES, EXTENSIONS: EXTENSIONS, LIST_LIMIT: LIST_LIMIT, CHECK_SCRIPT: CHECK_SCRIPT, SET_SCRIPT: SET_SCRIPT,
        cleanPath: cleanPath, safeUser: safeUser, candidates: candidates, facePath: facePath, checkCommand: checkCommand, parseCheck: parseCheck,
        fileUrl: fileUrl, sources: sources, initial: initial, setError: setError, setCommand: setCommand, clearCommand: clearCommand,
        listCommand: listCommand, parseList: parseList, sheet: sheet, tilde: tilde, report: report
    };
