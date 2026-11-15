import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// SoundSheet.qml - outputs, inputs and per-app volume (control-lock 3.4,
// Control board): the volume row's device button, and the launcher's System >
// Audio page in place of AudioMenu.qml.
//
// Output: every sink, the default one on; a press makes it the default.
// Input: every source; the default one says "In use by <app>" while
// something records. The default output and input carry their volume (a 110
// px slider) and a press on either mutes it [GUESS]: AudioMenu's faders and
// mute toggles, so the launcher's System > Audio keeps them. Apps: each
// playing stream with a 110 px slider. The
// header's state is the default sink's short name and its switch is sound on
// (the sink's mute, inverted) [GUESS]. No footer: no mixer app is installed
// [NEEDS CHECK].
//
// PLAN risk 6 (the PipeWire `pw_proxy_destroy` crash class): this reads
// Audio's lists and writes only through Audio's own setters and the node's
// audio object, as AudioMenu did; Audio.qml is untouched.
//
// A fixture's `sheets.sound` stands in for Audio, and then, as under
// Fixture.dryRun, nothing reaches PipeWire.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.sound
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined

    function nodeShape(n) {
        return { name: n.name, description: Audio.labelFor(n), props: n.properties };
    }
    readonly property var live: {
        const sinkNames = Audio.sinks.map(n => CcData.outputName(sheet.nodeShape(n)));
        const recorders = [];
        for (const r of Audio.recorders) {
            const name = Audio.appFor(r);
            if (name && recorders.indexOf(name) < 0) recorders.push(name);
        }
        return {
            sink: Audio.sink ? CcData.outputName(sheet.nodeShape(Audio.sink)) : "",
            muted: Audio.muted,
            volume: Audio.volume,
            micVolume: Audio.micVolume,
            micMuted: Audio.micMuted,
            // Two sinks with the same short name keep their own labels.
            sinks: Audio.sinks.map((n, i) => ({
                        key: String(n.id),
                        name: sinkNames.filter(x => x === sinkNames[i]).length > 1 ? Audio.labelFor(n) : sinkNames[i],
                        transport: CcData.transport(n.properties),
                        isDefault: Audio.isDefault(n) === true,
                        headphones: CcData.outputKind(sheet.nodeShape(n)) !== "speakers" && CcData.outputKind(sheet.nodeShape(n)) !== "hdmi"
                    })),
            sources: Audio.sources.map(n => ({
                        key: String(n.id),
                        name: Audio.labelFor(n),
                        transport: CcData.transport(n.properties),
                        isDefault: Audio.isDefaultSource(n) === true
                    })),
            recorders: recorders,
            streams: Audio.streams.map(n => ({
                        key: String(n.id),
                        app: Audio.appFor(n),
                        volume: n.audio?.volume ?? 0
                    }))
        };
    }

    objectName: "ccSheet-sound"
    title: "Sound"
    switchLabel: "Sound on"
    sheetData: CcData.sound(sheet.fixture ?? sheet.live)

    function node(list, key) {
        return list.find(n => String(n.id) === key) ?? null;
    }

    onSwitchToggled: on => {
        if (!sheet.dry && Audio.sink?.audio) Audio.sink.audio.muted = !on;
    }
    onActivated: row => {
        if (sheet.dry) return;
        if (row.action === "sink") Audio.setDefault(sheet.node(Audio.sinks, row.key));
        else if (row.action === "source") Audio.setDefaultSource(sheet.node(Audio.sources, row.key));
        else if (row.action === "outputMute" && Audio.sink?.audio) Audio.sink.audio.muted = !Audio.muted;
        else if (row.action === "micMute" && Audio.source?.audio) Audio.source.audio.muted = !Audio.micMuted;
    }
    onSlid: (row, value) => {
        if (sheet.dry) return;
        if (row.action === "outputMute") Audio.setVolume(Audio.sink, value);
        else if (row.action === "micMute") Audio.setVolume(Audio.source, value);
        else Audio.setVolume(sheet.node(Audio.streams, row.key), value);
    }
}
