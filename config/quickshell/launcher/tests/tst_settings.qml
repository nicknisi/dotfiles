import QtQuick
import QtTest
import "../core/Settings.js" as Settings

TestCase {
    name: "Settings"
    property var schema: [{key: "mode", type: "enum", options: ["a", "b"], "default": "a"},
                          {key: "n", type: "number", integer: true, "default": 10, min: 1, max: 20}]
    function test_defaults_validation_and_unknown_fields() {
        var parsed = Settings.parse(JSON.stringify({version: 1, future: {x: 1}, providers: {"test.one": {n: 2.5, mode: "b"}}}))
        compare(parsed.error, "")
        var v = Settings.values(parsed.config, ["providers", "test.one"], schema)
        compare(v.mode, "b")
        compare(v.n, 10)   // non-integer falls back
        var next = Settings.withValue(parsed.config, ["providers", "test.one"], "n", 7, schema[1])
        compare(Settings.values(next, ["providers", "test.one"], schema).n, 7)
        compare(next.future.x, 1)
        compare(parsed.config.providers["test.one"].n, 2.5)  // original untouched
        var threw = false
        try { Settings.withValue(next, ["providers", "test.one"], "mode", "zzz", schema[0]) } catch (e) { threw = true }
        verify(threw)
    }
    function test_broken_config_is_reported_not_replaced() {
        var parsed = Settings.parse("{ broken")
        compare(parsed.config, null)
        verify(parsed.error.indexOf("kept at last valid version") >= 0)
        compare(Settings.parse("").error, "")
        compare(Settings.parse(JSON.stringify({version: 2})).config, null)
    }
    function test_enabled_defaults() {
        var c = Settings.parse(JSON.stringify({version: 1, providers: {"x": {enabled: false}}})).config
        compare(Settings.isEnabled(c, ["providers", "x"], true), false)
        compare(Settings.isEnabled(c, ["providers", "y"], true), true)
        compare(Settings.isEnabled(c, ["providers", "y"], false), false)
    }
}
