// Audio.qml - the default sink, wrapped so the rest of the shell does not repeat
// the null checks. PipeWire objects arrive unbound: their `audio` sub-object stays
// empty until something declares interest, which is what PwObjectTracker does.
// Without it `sink.audio.volume` reads as undefined forever.
pragma Singleton
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

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
