import QtQuick
import QtTest
import "../core/Intent.js" as Intent
import "../core/Match.js" as Match

TestCase {
    name: "Intent"
    property var items: [
        { title: "Google Chrome", detail: "Web Browser" },
        { title: "Keystroke Settings", detail: "" },
        { title: "Night Light", detail: "Toggle › Display" },
        { title: "Lock Screen", detail: "System" }
    ]

    function test_transcripts_become_matcher_friendly_queries() {
        compare(Intent.normalize("Chrome."), "Chrome")
        compare(Intent.normalize("Launch Chrome."), "Chrome")
        compare(Intent.normalize("open up the settings, please"), "settings")
        compare(Intent.normalize("Turn on night light."), "night light")
        compare(Intent.normalize("Lock the screen!"), "Lock screen")
        compare(Intent.normalize("  Keystroke   settings.  "), "Keystroke settings")
        compare(Intent.normalize("Open."), "Open")          // a verb alone stays a query
        compare(Intent.normalize(""), "")
        compare(Intent.normalize("…"), "")
    }
    function test_normalized_transcripts_reach_the_fuzzy_matcher() {
        verify(Match.match("Chrome.", "Google Chrome", "browser", "", "") === 0)
        verify(Match.match(Intent.normalize("Chrome."), "Google Chrome", "browser", "", "") >= 99)
        verify(Match.match(Intent.normalize("Launch Chrome."), "Google Chrome", "browser", "", "") >= 99)
        verify(Match.match(Intent.normalize("Open Spotify"), "Spotify", "", "", "") >= 100)
    }
}
