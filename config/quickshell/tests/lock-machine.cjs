// lib/LockMachine.js with a fake PamContext (PLAN M8): Success, Failed,
// MaxTries and Error; the buffer cleared on every exit; only Success while a
// conversation runs unlocks; late and repeated signals change nothing.
//
// The fake behaves as Quickshell 0.3.2's PamContext did against real PAM
// stacks (tests/lock-pam.qml runs the real one): start() returns false for a
// missing config and true while one is already active; the first message is
// the "Password: " prompt with responseRequired; abort() ends the
// conversation with no signal; an error() is followed by completed(Error).
const assert = require('node:assert/strict')
const L = require('../lib/LockMachine.js')

const SECRET = 'hunter2'

// A PamContext stand-in. `script` decides how a conversation ends:
//   { result, messages: [{ text, isError }], error: bool, prompts: n }
function fakePam(script) {
    const pam = {
        active: false, config: 'hyprlock', missing: false, started: 0, responses: [], aborted: 0,
        queue: [], host: null,
        start() {
            if (pam.missing) return false;
            if (pam.active) return true;
            pam.active = true;
            pam.started++;
            pam.asked = 0;
            pam.later(() => pam.prompt());
            return true;
        },
        prompt() {
            pam.asked++;
            pam.host.message({ text: pam.asked === 1 ? 'Password: ' : 'Verification code: ', isError: false, responseRequired: true, responseVisible: false });
        },
        respond(value) {
            pam.responses.push(value);
            pam.later(() => {
                if (!pam.active) return;
                const s = pam.script;
                if ((s.prompts || 1) > pam.asked) return pam.prompt();
                for (const m of s.messages || []) pam.host.message({ text: m.text, isError: m.isError === true, responseRequired: false, responseVisible: true });
                pam.active = false;
                if (s.error) {
                    pam.host.errored();
                    pam.host.completed(L.ERROR);
                    return;
                }
                const ok = pam.responses.slice(-1)[0] === SECRET;
                pam.host.completed(ok ? (s.result ?? L.SUCCESS) : (s.result ?? L.FAILED));
            });
        },
        abort() {
            pam.active = false;
            pam.aborted++;
            pam.queue = [];
        },
        later(fn) { pam.queue.push(fn) },
        // Delivers queued signals, as the event loop would.
        flush() {
            let n = 0;
            while (pam.queue.length > 0 && n++ < 50) pam.queue.shift()();
        },
        script: script || {}
    };
    return pam;
}

// The glue Lock/LockAuth.qml has: a record, each event through perform().
function host(script) {
    const pam = fakePam(script);
    const h = {
        m: L.initial(), pam, history: [],
        step(next) {
            const kept = L.perform(next, pam);
            assert.equal(kept.fx, undefined, 'the kept record never carries effects');
            h.m = kept;
            h.history.push(kept);
            return kept;
        },
        type(t) { return h.step(L.type(h.m, t)) },
        erase() { return h.step(L.erase(h.m)) },
        clear() { return h.step(L.clear(h.m)) },
        wipe() { return h.step(L.wipe(h.m)) },
        submit() { return h.step(L.submit(h.m)) },
        message(msg) { return h.step(L.message(h.m, msg)) },
        completed(r) { return h.step(L.completed(h.m, r)) },
        errored() { return h.step(L.errored(h.m)) },
        timeout() { return h.step(L.timeout(h.m)) }
    };
    pam.host = h;
    return h;
}

// Outside idle and answering, a record holds a buffer only while it waits
// for PAM's prompt (pending); unlocking never does. Once an attempt is over
// the secret is nowhere in the record.
function invariants(h) {
    for (const r of h.history) {
        if (!L.editable(r) && !r.pending) assert.equal(r.buffer, '', 'no buffer while ' + r.phase);
        if (r.pending) assert.equal(r.phase, 'authenticating', 'only a submitted attempt is pending');
        if (r.phase === 'unlocking') assert.ok(r.buffer === '' && !r.pending, 'unlocking holds nothing');
        assert.ok(L.PHASES.includes(r.phase), 'a known phase: ' + r.phase);
    }
    if (!L.editable(h.m) && !h.m.pending) assert.ok(!JSON.stringify(h.m).includes(SECRET), 'the secret is gone from the record');
}

// ---- Success ---------------------------------------------------------------------
{
    const h = host({ result: L.SUCCESS })
    h.type('hunter'); h.type('2')
    assert.equal(h.m.buffer, SECRET)
    assert.equal(L.hint(h.m), 'Enter unlocks · Esc clears')
    h.submit()
    assert.equal(h.m.phase, 'authenticating')
    assert.equal(h.pam.started, 1, 'Enter starts PAM')
    assert.equal(L.hint(h.m), 'Checking…')
    assert.equal(L.bullets(h.m), SECRET.length, 'the bullets stay while checking')
    h.type('x')
    assert.equal(h.m.buffer, SECRET, 'typing while PAM works changes nothing')
    h.pam.flush()
    assert.deepEqual(h.pam.responses, [SECRET], 'the prompt is answered with exactly what was typed')
    assert.equal(h.m.phase, 'unlocking', 'Success unlocks')
    assert.equal(h.m.buffer, '', 'the buffer is cleared before unlocking')
    assert.equal(h.m.attempts, 0)
    invariants(h)
    // Nothing after unlocking moves it again.
    assert.equal(L.completed(h.m, L.FAILED), h.m)
    assert.equal(L.type(h.m, 'a'), h.m)
    assert.equal(L.submit(h.m), h.m)
}

// ---- Failed ------------------------------------------------------------------------
{
    const h = host({})
    h.type('wrong'); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'idle', 'a wrong password keeps the session locked')
    assert.equal(h.m.buffer, '', 'and clears the buffer')
    assert.equal(h.m.message, 'Wrong password')
    assert.ok(h.m.error)
    assert.equal(h.m.shake, 1, 'the card shakes')
    assert.equal(h.m.attempts, 1)
    // The message stays until the next keystroke.
    assert.equal(L.clear(h.m), h.m, 'Esc on an empty field changes nothing')
    h.type('h')
    assert.equal(h.m.message, '')
    assert.ok(!h.m.error)
    h.erase()
    assert.equal(h.m.buffer, '')
    h.type(SECRET); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'unlocking', 'the next try can still succeed')
    invariants(h)
}
// PAM's own error text wins over "Wrong password" (faillock's lockout notice).
{
    const h = host({ messages: [{ text: 'The account is locked due to 10 failed logins.', isError: true }, { text: '(2 minutes left to unlock)', isError: true }] })
    h.type('nope'); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'idle')
    assert.equal(h.m.message, '(2 minutes left to unlock)', 'the last PAM error shows')
    invariants(h)
}
// An info message while PAM works shows on the hint line, then "Wrong password".
{
    const h = host({ messages: [{ text: 'auth=auth_err', isError: false }] })
    h.type('nope'); h.submit(); h.pam.flush()
    assert.equal(h.m.message, 'Wrong password', 'an info message is not an error')
}

// ---- MaxTries --------------------------------------------------------------------------
{
    const h = host({ result: L.MAX_TRIES })
    h.type(SECRET); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'idle', 'MaxTries keeps the session locked, even with the right password')
    assert.equal(h.m.buffer, '')
    assert.equal(h.m.message, L.TEXT.maxTries)
    assert.equal(h.m.shake, 1)
    invariants(h)
    h.pam.script = { result: L.MAX_TRIES, messages: [{ text: 'The account is locked due to 10 failed logins.', isError: true }] }
    h.type(SECRET); h.submit(); h.pam.flush()
    assert.equal(h.m.message, 'The account is locked due to 10 failed logins.')
    assert.equal(h.m.attempts, 2, 'the field stays usable')
}

// ---- Error -------------------------------------------------------------------------------
{
    const h = host({ error: true })
    h.type(SECRET); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'idle', 'a PAM error keeps the session locked')
    assert.equal(h.m.buffer, '')
    assert.equal(h.m.message, "Authentication isn't working. Try a TTY.")
    assert.equal(h.m.shake, 1, 'error() then completed(Error) shake once')
    assert.equal(h.m.attempts, 1, 'and count once')
    invariants(h)
}
// start() refusing (no such PAM config): an error, nothing running.
{
    const h = host({})
    h.pam.missing = true
    h.type(SECRET); h.submit()
    assert.equal(h.m.phase, 'idle')
    assert.equal(h.m.buffer, '', 'a failed start clears the buffer')
    assert.equal(h.m.message, L.TEXT.broken)
    assert.equal(h.pam.responses.length, 0)
    invariants(h)
}
// start() throwing is the same.
{
    const h = host({})
    h.pam.start = () => { throw new Error('boom') }
    h.type(SECRET); h.submit()
    assert.equal(h.m.phase, 'idle')
    assert.equal(h.m.buffer, '')
}

// ---- timeout -----------------------------------------------------------------------------
{
    const h = host({})
    h.type(SECRET); h.submit()
    // PAM never prompts (a module hangs): the watchdog aborts it.
    h.pam.queue = []
    h.timeout()
    assert.equal(h.pam.aborted, 1, 'the conversation is aborted')
    assert.equal(h.m.phase, 'idle')
    assert.equal(h.m.buffer, '', 'the pending buffer goes with it')
    assert.equal(h.m.message, L.TEXT.timeout)
    assert.ok(!h.m.pending)
    // A late Success from the aborted conversation does not unlock.
    h.completed(L.SUCCESS)
    assert.equal(h.m.phase, 'idle', 'a late Success after a timeout stays locked')
    h.message({ text: 'Password: ', responseRequired: true })
    assert.equal(h.m.phase, 'idle', 'a late prompt is ignored')
    assert.equal(L.timeout(h.m), h.m, 'no timeout while idle')
    invariants(h)
}

// ---- late and stray signals ------------------------------------------------------------------
{
    const h = host({})
    assert.equal(L.completed(h.m, L.SUCCESS).phase, 'idle', 'Success with no conversation never unlocks')
    h.type(SECRET)
    assert.equal(L.completed(h.m, L.SUCCESS).phase, 'idle', 'not even with a buffer typed')
    assert.equal(L.message(h.m, { text: 'Password: ', responseRequired: true }), h.m, 'a prompt with no conversation is ignored')
    assert.equal(L.errored(h.m), h.m)
    // A failure, then a stray Success for it: still locked.
    h.clear(); h.type('nope'); h.submit(); h.pam.flush()
    h.completed(L.SUCCESS)
    assert.equal(h.m.phase, 'idle', 'a second completed after Failed changes nothing')
    for (const bad of [undefined, null, 7, -1, '0', 'Success']) {
        const r = host({}); r.type(SECRET); r.submit()
        r.pam.queue = []
        r.step(L.message(r.m, { text: 'Password: ', responseRequired: true }))
        r.completed(bad)
        assert.equal(r.m.phase, 'idle', 'an unknown result fails: ' + String(bad))
        assert.equal(r.m.buffer, '')
    }
}

// ---- Esc, empty Enter ---------------------------------------------------------------------------
{
    const h = host({})
    h.submit()
    assert.equal(h.m.phase, 'idle', 'Enter with an empty field does not start PAM')
    assert.equal(h.pam.started, 0)
    assert.equal(h.m.shake, 1, 'it shakes once')
    assert.equal(h.m.attempts, 0, 'and is not an attempt')
    h.type(SECRET)
    h.clear()
    assert.equal(h.m.buffer, '', 'Esc clears the buffer')
    // Esc while PAM works keeps the conversation (control-lock 4.6).
    h.type(SECRET); h.submit(); h.clear()
    assert.equal(h.m.phase, 'authenticating')
    assert.ok(h.m.pending, 'Esc does not abort a running conversation')
    h.pam.flush()
    assert.deepEqual(h.pam.responses, [SECRET], 'nor change what was submitted')
    assert.equal(h.m.phase, 'unlocking')
}

// ---- the lock going away ----------------------------------------------------------------------------
{
    const h = host({})
    h.type(SECRET); h.wipe()
    assert.equal(h.m.buffer, '', 'wipe clears what is typed')
    h.type(SECRET); h.submit(); h.wipe()
    assert.equal(h.pam.aborted, 1, 'and aborts a running conversation')
    assert.ok(h.m.phase === 'idle' && h.m.buffer === '' && !h.m.pending, 'with nothing pending')
    h.pam.flush()
    assert.equal(h.pam.responses.length, 0, 'the aborted prompt is never answered')
    assert.ok(!JSON.stringify(h.m).includes(SECRET))
    invariants(h)
}

// ---- a second question (one-time code) --------------------------------------------------------------
{
    const h = host({ prompts: 2 })
    h.type(SECRET); h.submit(); h.pam.flush()
    assert.equal(h.m.phase, 'answering', 'a second prompt opens the field again')
    assert.equal(h.m.prompt, 'Verification code', 'with PAM\'s question, colon trimmed')
    assert.equal(h.m.buffer, '')
    h.submit()
    assert.equal(h.m.phase, 'answering', 'an empty answer only shakes')
    h.type(SECRET); h.submit()
    assert.equal(h.m.phase, 'authenticating')
    assert.equal(h.m.buffer, '', 'the answer leaves the buffer')
    h.pam.flush()
    assert.deepEqual(h.pam.responses, [SECRET, SECRET])
    assert.equal(h.m.phase, 'unlocking')
    invariants(h)
}

// ---- fuzz: any order of events --------------------------------------------------------------------------
// Seeded, so a failure reproduces. Unlocking happens only through a
// completed(SUCCESS) that arrives while a conversation runs.
{
    let seed = 20261115
    const rand = n => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n }
    const events = ['type', 'erase', 'clear', 'wipe', 'submit', 'flush', 'prompt', 'success', 'failed', 'maxtries', 'error', 'errored', 'timeout', 'info', 'bad']
    for (let run = 0; run < 400; run++) {
        const h = host({ result: [L.SUCCESS, L.FAILED, L.MAX_TRIES][rand(3)], error: rand(5) === 0 })
        for (let i = 0; i < 30 && h.m.phase !== 'unlocking'; i++) {
            const e = events[rand(events.length)]
            const before = h.m
            if (e === 'type') h.type(rand(2) ? SECRET : 'x')
            else if (e === 'erase') h.erase()
            else if (e === 'clear') h.clear()
            else if (e === 'wipe') h.wipe()
            else if (e === 'submit') h.submit()
            else if (e === 'flush') h.pam.flush()
            else if (e === 'prompt') h.message({ text: 'Password: ', responseRequired: true })
            else if (e === 'info') h.message({ text: 'info', isError: false })
            else if (e === 'bad') h.message({ text: 'bad', isError: true })
            else if (e === 'errored') h.errored()
            else if (e === 'timeout') h.timeout()
            else h.completed({ success: L.SUCCESS, failed: L.FAILED, maxtries: L.MAX_TRIES, error: L.ERROR }[e])
            if (h.m.phase === 'unlocking' && before.phase !== 'unlocking')
                assert.ok(L.running(before) && (e === 'success' || e === 'flush'), 'unlocking only from a running conversation\'s Success (' + e + ' from ' + before.phase + ')')
            if (h.m.phase === 'idle' && L.running(before)) assert.equal(h.m.buffer, '', 'every way out of a conversation clears the buffer')
            invariants(h)
        }
    }
}

// ---- bullets: a count kept while PAM checks, never the text ----------------------
{
    let m = L.type(L.initial(), SECRET)
    assert.equal(L.bullets(m), SECRET.length)
    m = L.submit(m); delete m.fx
    m = L.message(m, { text: 'Password: ', responseRequired: true }); delete m.fx
    assert.equal(m.buffer, '', 'the buffer went to PAM')
    assert.equal(L.bullets(m), SECRET.length, 'the bullets stay while PAM checks')
    assert.ok(!JSON.stringify(m).includes(SECRET), 'only the count is kept')
    const failed = L.completed(m, L.FAILED)
    assert.equal(L.bullets(failed), 0, 'a failure empties the field')
    assert.equal(L.bullets(L.wipe(m)), 0, 'so does a wipe')
    assert.equal(L.bullets(L.type(failed, 'ab')), 2)
    assert.equal(L.bullets(L.completed(m, L.SUCCESS)), SECRET.length, 'the bullets stay while the card leaves')
    assert.equal(L.bullets(null), 0)
}

// ---- the capsule springs from the island only where it draws the 360 pill --------
{
    const S = L.springsFromIsland
    assert.equal(S(null), true, 'no main shell prefs: the spring, as before M10')
    assert.equal(S({}), true, 'no bar mode in them either')
    assert.equal(S({ barMode: 'island' }), true)
    assert.equal(S({ barMode: 'island', islandForm: 'float', look: 'crew' }), true, 'the plain island floating')
    for (const mode of ['pill', 'full', 'rail', 'unknown'])
        assert.equal(S({ barMode: mode, islandForm: 'float', look: 'crew' }), false, mode + ': no pill there (M10)')
    assert.equal(S({ barMode: 'island', islandForm: 'notch', look: 'crew' }), false, 'the notch hangs from the edge (M9)')
    for (const look of L.LOOKS)
        assert.equal(S({ barMode: 'island', islandForm: 'float', look }), false, look + ' packs its own bar (M9)')
    assert.equal(S({ barMode: 'island', islandForm: 'sideways', look: 'disco' }), true, 'values Prefs refuses are its defaults')
    assert.equal(S({ barMode: 7 }), true, 'a bar mode that is not a string is no mode')
    // Every look but the plain island, as LookModel and Prefs name them.
    const LM = require('../lib/LookModel.js')
    assert.deepEqual(L.LOOKS, LM.LOOKS.filter(n => n !== 'crew'), 'LockMachine.LOOKS follows LookModel.LOOKS')
}

console.log('LOCK_MACHINE_PASS')
