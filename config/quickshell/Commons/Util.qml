pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function alpha(color, opacity) {
        var c = Qt.color(color)
        return Qt.rgba(c.r, c.g, c.b, opacity)
    }
    function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }
    // Shell effects are explicit provider commands. Pass user data with execArgv.
    function execDetached(command) { Quickshell.execDetached(["sh", "-c", String(command)]) }
    function execArgv(argv) { if (argv && argv.length) Quickshell.execDetached(argv) }
    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }
}
