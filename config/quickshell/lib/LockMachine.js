// LockMachine.js - the lock screen's password and its PAM conversation
// (PLAN M8, control-lock 4.6).
//
//   idle ──Enter (non-empty)──▶ authenticating ──Success──▶ unlocking
//     ▲                              │
//     └── Failed / MaxTries / Error ─┘   (shake, message, buffer cleared)
//
// Pure functions over a small record, so tests/lock-machine.cjs drives it
// under node against a fake PamContext, and Lock/LockAuth.qml only wires the
// real PamContext's signals to it:
//
//   { phase, buffer, pending, held, message, error, prompt, shake, attempts,
//     pamError }
//
//   phase     idle | authenticating | answering | unlocking
//             answering: PAM asked a question the buffer has not answered yet
//             (a second prompt, e.g. a one-time code); the field is open again.
//   buffer    what has been typed. The only copy of the password the lock
//             keeps: the field draws its length, never its text.
//   pending   the buffer was submitted and waits for PAM's prompt.
//   held      the length that was submitted, so the bullets stay while PAM
//             checks (bullets()). A count, never text.
//   message   the hint line, "" for the default ("Enter unlocks · Esc clears").
//   error     the message is an error (drawn in `bad`).
//   prompt    PAM's question while answering, "" otherwise.
//   shake     bumps on every failure, so the card replays the shake.
//   attempts  failed attempts since the lock started.
//   pamError  the last error text PAM sent during this conversation.
//
// Every function returns a new record and never changes the one it was given.
// What PAM has to do comes back in `fx` on that record, a list of
//   { do: "start" } | { do: "respond", value } | { do: "abort" }
// which perform() runs against a PamContext-shaped object and then drops, so the
// stored record never holds a response.
//
// Security rules this file owns (tests/lock-machine.cjs checks each):
//   - the buffer is "" whenever the phase is not idle or answering (except a
//     submitted one waiting for PAM's prompt), and on every exit path:
//     success, failure, max tries, error, timeout, Esc and the card moving to
//     another screen (clear()), the lock going away (wipe());
//   - only Success while a conversation is running leads to unlocking; every
//     other outcome, and any late or repeated signal, keeps the session locked;
//   - nothing here logs.

var PHASES = ["idle", "authenticating", "answering", "unlocking"];

// PamResult values (Quickshell.Services.Pam, checked against 0.3.2:
// Success 0, Failed 1, Error 2, MaxTries 3).
var SUCCESS = 0;
var FAILED = 1;
var ERROR = 2;
var MAX_TRIES = 3;

// How long a conversation may run before it is aborted [GUESS]: pam_unix
// waits about 2 s after a wrong password and faillock adds nothing, so a
// minute means something is stuck. The card says so instead of "Checking…"
// forever.
var TIMEOUT = 60000;

var TEXT = {
    hint: "Enter unlocks · Esc clears",
    checking: "Checking…",
    wrong: "Wrong password",
    maxTries: "Too many attempts. Wait a few minutes, then try again.",
    broken: "Authentication isn't working. Try a TTY.",
    timeout: "Authentication timed out. Try again."
};

function initial() {
    return { phase: "idle", buffer: "", pending: false, held: 0, message: "", error: false, prompt: "", shake: 0, attempts: 0, pamError: "" };
}

function copy(m) {
    return {
        phase: m.phase, buffer: m.buffer, pending: m.pending, held: m.held || 0, message: m.message, error: m.error,
        prompt: m.prompt, shake: m.shake, attempts: m.attempts, pamError: m.pamError
    };
}

// How many bullets the field shows: what is typed while it is editable, and
// while PAM checks (or the card leaves) the length that was submitted. The
// buffer itself is gone by then (handed to PAM); only the count is kept.
function bullets(m) {
    if (!m) return 0;
    if (editable(m)) return String(m.buffer || "").length;
    return m.phase === "authenticating" || m.phase === "unlocking" ? (m.held || 0) : 0;
}

// Whether keys edit the buffer.
function editable(m) {
    return m.phase === "idle" || m.phase === "answering";
}

// Whether a PAM conversation is running.
function running(m) {
    return m.phase === "authenticating" || m.phase === "answering";
}

// The hint line as drawn: the message, else "Checking…" while PAM works,
// else the default.
function hint(m) {
    if (m.message !== "") return m.message;
    return m.phase === "authenticating" ? TEXT.checking : TEXT.hint;
}

// ---- keys ----------------------------------------------------------------------

// Printable text typed into the field. A message from the last attempt stays
// until the next keystroke (control-lock 4.6), so typing clears it.
function type(m, text) {
    var t = String(text || "");
    if (!editable(m) || t === "") return m;
    var r = copy(m);
    r.buffer = m.buffer + t;
    if (!running(m)) {
        r.message = "";
        r.error = false;
    }
    return r;
}

// Backspace: the last character.
function erase(m) {
    if (!editable(m) || m.buffer === "") return m;
    var r = copy(m);
    r.buffer = m.buffer.slice(0, -1);
    return r;
}

// Esc, Ctrl+U, the card moving to another screen: what is being typed goes.
// A submitted attempt is not touched: it keeps running (control-lock 4.6:
// Esc does not abort it), with the buffer it was submitted with.
function clear(m) {
    if (!editable(m) || m.buffer === "") return m;
    var r = copy(m);
    r.buffer = "";
    return r;
}

// The lock going away: nothing kept, whatever the phase, and a running
// conversation aborted.
function wipe(m) {
    var r = copy(m);
    r.buffer = "";
    r.pending = false;
    r.held = 0;
    r.prompt = "";
    if (running(m)) {
        r.phase = "idle";
        r.fx = [{ do: "abort" }];
    }
    return r;
}

// Enter. An empty field only shakes. Otherwise the buffer goes to PAM: a new
// conversation from idle (responded to when PAM prompts), or the answer to
// the question PAM is waiting on.
function submit(m) {
    if (m.phase === "idle") {
        var r = copy(m);
        if (m.buffer === "") {
            r.shake = m.shake + 1;
            return r;
        }
        r.phase = "authenticating";
        r.pending = true;
        r.held = m.buffer.length;
        r.message = "";
        r.error = false;
        r.prompt = "";
        r.pamError = "";
        r.fx = [{ do: "start" }];
        return r;
    }
    if (m.phase === "answering") {
        var a = copy(m);
        if (m.buffer === "") {
            a.shake = m.shake + 1;
            return a;
        }
        a.phase = "authenticating";
        a.buffer = "";
        a.held = m.buffer.length;
        a.prompt = "";
        a.fx = [{ do: "respond", value: m.buffer }];
        return a;
    }
    return m;
}

// ---- PAM -------------------------------------------------------------------------

// PamContext.start() returned false (no such PAM config, a conversation
// already up): nothing is running, so the attempt fails as an error.
function startFailed(m) {
    return fail(m, ERROR);
}

// A PAM message: { text, isError, responseRequired, responseVisible }.
// The first prompt after a submit takes the buffer; a later one opens the
// field again with PAM's question as its label. Other messages show on the
// hint line, errors in `bad`.
function message(m, msg) {
    if (!running(m)) return m;
    var text = String(msg && msg.text || "").trim();
    var r = copy(m);
    if (msg && msg.responseRequired) {
        if (m.pending) {
            r.pending = false;
            r.buffer = "";
            r.phase = "authenticating";
            r.fx = [{ do: "respond", value: m.buffer }];
            return r;
        }
        r.phase = "answering";
        r.prompt = text.replace(/:\s*$/, "");
        r.message = "";
        r.error = false;
        return r;
    }
    if (text === "") return m;
    r.message = text;
    r.error = msg.isError === true;
    if (r.error) r.pamError = text;
    return r;
}

// PamContext.completed(result). Success unlocks only while a conversation is
// running; anything else fails and stays locked.
function completed(m, result) {
    if (!running(m)) return m;
    if (result === SUCCESS) {
        var r = copy(m);
        r.phase = "unlocking";
        r.buffer = "";
        r.pending = false;
        r.message = "";
        r.error = false;
        r.prompt = "";
        r.pamError = "";
        return r;
    }
    return fail(m, result);
}

// PamContext.error(e). Quickshell sends completed(Error) after it as well;
// whichever comes second finds the conversation over and changes nothing.
function errored(m) {
    return fail(m, ERROR);
}

// The conversation ran past TIMEOUT: abort it, stay locked.
function timeout(m) {
    if (!running(m)) return m;
    var r = fail(m, -1);
    r.fx = [{ do: "abort" }];
    return r;
}

// Back to idle with the buffer cleared, the card shaking and a message.
function fail(m, result) {
    if (!running(m)) return m;
    var r = copy(m);
    r.phase = "idle";
    r.buffer = "";
    r.pending = false;
    r.held = 0;
    r.prompt = "";
    r.error = true;
    r.shake = m.shake + 1;
    r.attempts = m.attempts + 1;
    if (result === FAILED) r.message = m.pamError || TEXT.wrong;
    else if (result === MAX_TRIES) r.message = m.pamError || TEXT.maxTries;
    else if (result === -1) r.message = TEXT.timeout;
    else r.message = TEXT.broken;
    r.pamError = "";
    return r;
}

// ---- effects -----------------------------------------------------------------------

// Runs r.fx against pam (start(), respond(value), abort()) and returns the
// record to keep, without fx. A start() that returns false fails the attempt.
function perform(r, pam) {
    if (!r || !r.fx) return r;
    var fx = r.fx;
    var next = copy(r);
    for (var i = 0; i < fx.length; i++) {
        var e = fx[i];
        if (e.do === "start") {
            var ok = false;
            try {
                ok = pam.start() === true;
            } catch (err) {
                ok = false;
            }
            if (!ok) next = startFailed(next);
        } else if (e.do === "respond") {
            pam.respond(e.value);
        } else if (e.do === "abort") {
            pam.abort();
        }
    }
    return next;
}

if (typeof module !== "undefined")
    module.exports = {
        PHASES: PHASES, SUCCESS: SUCCESS, FAILED: FAILED, ERROR: ERROR, MAX_TRIES: MAX_TRIES, TIMEOUT: TIMEOUT, TEXT: TEXT,
        initial: initial, editable: editable, running: running, hint: hint, bullets: bullets,
        type: type, erase: erase, clear: clear, wipe: wipe, submit: submit,
        startFailed: startFailed, message: message, completed: completed, errored: errored, timeout: timeout,
        perform: perform
    };
