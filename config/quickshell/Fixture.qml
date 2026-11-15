pragma Singleton
// Fixture.qml - canned data for sandbox screenshots. Inert unless SHELL_SANDBOX=1.
//
// The sandbox (.shell-rebuild/tmp/sandbox.sh, driven by shoot.sh) has no input,
// no windows and no live services, so states worth shooting are made from
// fixtures: `qs -p <config> ipc call fixture load <name>` reads
// tests/fixtures/<name>.json into Fixture.data. New surfaces read
// `Fixture.data.<key> ?? <live service value>` at the Island/Panels level, so
// the service singletons never learn about fixtures.
//
// Outside the sandbox the IPC target is not registered, load() refuses and
// data stays {}, so every `Fixture.data.x ?? live` falls through to live.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Set by shoot.sh. Also the one place new code asks "am I in the sandbox?".
    readonly property bool sandbox: Quickshell.env("SHELL_SANDBOX") === "1"
    readonly property string dir: Quickshell.shellDir + "/tests/fixtures"

    // The loaded fixture's contents, {} when none is loaded.
    property var data: ({})
    // Its name, "" when none is loaded.
    property string name: ""
    // Why the last load() failed, "" after a good one.
    property string error: ""

    // Reads tests/fixtures/<name>.json synchronously and replaces data.
    // Returns true on success; on failure data is left as it was.
    function load(name: string): bool {
        if (!root.sandbox) return root.fail("fixtures load only under SHELL_SANDBOX=1");
        if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(name) || name.includes(".."))
            return root.fail(`bad fixture name "${name}"`);
        // Clearing the path first is what makes text() read again: assigning a
        // new path and reading in the same call returns the previous file's
        // text, and a missing file would come back as the last good fixture.
        const path = `${root.dir}/${name}.json`;
        reader.path = "";
        reader.path = path;
        const text = reader.text();
        if (!reader.loaded || text === "") return root.fail(`no fixture ${path}`);
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            return root.fail(`${name}.json is not JSON: ${e.message}`);
        }
        if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
            return root.fail(`${name}.json must hold an object`);
        root.error = "";
        root.name = name;
        root.data = parsed;
        return true;
    }

    function clear(): void {
        root.error = "";
        root.name = "";
        root.data = ({});
    }

    function fail(message: string): bool {
        root.error = message;
        console.warn("Fixture:", message);
        return false;
    }

    // Synchronous reads (blockLoading), so `qs ipc call fixture load` can
    // answer with the result.
    FileView {
        id: reader
        blockLoading: true
        printErrors: false
        watchChanges: false
    }

    IpcHandler {
        target: "fixture"
        enabled: root.sandbox

        // "ok <name>: <top-level keys>" or "error: <why>".
        function load(name: string): string {
            return root.load(name) ? `ok ${root.name}: ${Object.keys(root.data).join(" ")}` : `error: ${root.error}`;
        }
        function clear(): void { root.clear() }
        function inspect(): string {
            return JSON.stringify({ sandbox: root.sandbox, name: root.name, error: root.error, data: root.data });
        }
    }
}
