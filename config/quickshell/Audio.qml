pragma Singleton
// Audio.qml - the default sink, wrapped so the rest of the shell does not repeat
// the null checks. PipeWire objects arrive unbound: their `audio` sub-object stays
// empty until something declares interest, which is what PwObjectTracker does.
// Without it `sink.audio.volume` reads as undefined forever.
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property bool ready: sink?.ready ?? false

    // ---- everything the audio menu picks from -----------------------------
    // Devices are matched on media.class, not on isSink. PipeWire's graph also
    // carries Midi/Bridge nodes, a Video/Source for the camera, and the
    // Dummy-Driver and Freewheel-Driver, none of which are sinks and all of
    // which turned up in the input list when it was written as "not a sink and
    // not a stream". media.class is the only field that separates them.
    readonly property var classOf: function (node) {
        return String(node?.properties?.["media.class"] ?? "");
    }

    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => root.classOf(n) === "Audio/Sink")
        .sort((a, b) => root.labelFor(a).localeCompare(root.labelFor(b)))

    readonly property var sources: (Pipewire.nodes?.values ?? [])
        .filter(n => root.classOf(n) === "Audio/Source")
        .sort((a, b) => root.labelFor(a).localeCompare(root.labelFor(b)))

    // Streams keep the flag test. An app's stream is a stream whichever way it
    // points, and isSink is what says which way that is: true for something
    // feeding a sink, false for something reading a source.
    readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n => n.isStream && n.isSink)
    readonly property var recorders: (Pipewire.nodes?.values ?? []).filter(n => n.isStream && !n.isSink)

    readonly property var labelFor: function (node) {
        return node?.nickname || node?.description || node?.name || "unknown";
    }

    // Streams describe themselves twice: the app's own name and what it is
    // playing. The app name is the useful half in a list this small.
    readonly property var appFor: function (node) {
        return node?.properties?.["application.name"] || root.labelFor(node);
    }

    readonly property real micVolume: source?.audio?.volume ?? 0

    readonly property var isDefault: function (node) {
        return node && root.sink && node.id === root.sink.id;
    }

    readonly property var isDefaultSource: function (node) {
        return node && root.source && node.id === root.source.id;
    }

    readonly property var setDefault: function (node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    readonly property var setDefaultSource: function (node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    readonly property var setVolume: function (node, v) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Nothing on a PipeWire node is populated until something declares interest,
    // so every node the menu can show has to be tracked, not just the default
    // sink. Without this their `audio` sub-objects read as undefined forever.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks, root.streams, root.sources, root.recorders)
    }
}
