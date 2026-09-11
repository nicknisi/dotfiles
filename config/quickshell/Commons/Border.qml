pragma Singleton
import QtQuick
import qs

QtObject {
    function none() { return { width: 0, color: "transparent" } }
    function surfaceSpec(surface, token, color, width) {
        return { width: Math.max(0, width), color: color }
    }
    function controlSpec(state, foreground, accent) {
        return { width: state === "focus" ? 2 : 1,
                 color: state === "focus" ? accent : Theme.borderIdle }
    }
}
