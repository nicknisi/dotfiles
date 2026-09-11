import QtQuick
import QtTest
import "../core/SettingsTree.js" as SettingsTree
import "../core/Match.js" as Match

TestCase {
    name: "SettingsTree"
    function model() {
        return {
            configPath: "/home/x/.config/keystroke/keystroke.json",
            paletteSchema: [
                { key: "density", type: "enum", label: "Layout density", "default": "compact", options: ["compact", "comfortable"], description: "Compact uses a narrower window" },
                { key: "showPreview", type: "boolean", label: "Show result previews", "default": true }
            ],
            paletteValues: { density: "compact", showPreview: true },
            entries: [
                { key: "ai", name: "AI & Web Search", description: "Continue any query in Claude, ChatGPT/Codex or Google", icon: "✳", iconFont: "", color: "#e79c85",
                  source: "bundled", pluginId: "", enabled: true,
                  schemas: [
                      { key: "provider", type: "enum", label: "Preferred assistant", "default": "chatgpt", options: ["chatgpt", "claude"], description: "Listed first among the fallbacks" },
                      { key: "mode", type: "enum", label: "Open conversations in", "default": "desktop", options: ["desktop", "cli", "browser"] },
                      { key: "autoSend", type: "boolean", label: "Send immediately in the browser", "default": false }
                  ],
                  values: { provider: "chatgpt", mode: "desktop", autoSend: false } },
                { key: "clipboard", name: "Clipboard History", description: "Uses the native clipboard history", icon: "", iconFont: "", color: "", source: "bundled", pluginId: "", enabled: true,
                  schemas: [{ key: "limit", type: "number", label: "Maximum entries", "default": 100, min: 1, max: 300, integer: true }], values: { limit: 100 } },
                { key: "example.hello", name: "Hello", description: "Says hello", icon: "", iconFont: "", color: "", source: "community", pluginId: "example.hello", enabled: false,
                  schemas: [], values: {} }
            ],
            problems: [{ pluginId: "broken.plugin", message: "no provider" }]
        }
    }
    function search(scope, query) {
        var t = SettingsTree.build(model())
        return Match.rank(SettingsTree.rows(t.nodes, scope, query), null)
    }
    function titles(rows) { return rows.map(function(r) { return r.title }) }

    function test_global_search_does_not_offer_emoji_settings() {
        var m = model()
        m.entries.push({ key: "emoji", name: "Emoji Picker", enabled: true, source: "bundled", schemas: [], values: {} })
        var t = SettingsTree.build(m)
        compare(SettingsTree.rows(t.nodes, "", "emoji").length, 0)
        compare(titles(SettingsTree.rows(t.nodes, "", "settings")), ["Keystroke Settings"])
        var scoped = SettingsTree.rows(t.nodes, "settings", "emoji")
        verify(scoped.some(function(r) { return r.action.scope === "settings/emoji" }))
        compare(titles(SettingsTree.rows(t.nodes, "settings/emoji", "")), ["Enabled"])
    }
    function test_global_catalog_contains_only_the_settings_entry() {
        var t = SettingsTree.build(model())
        compare(titles(SettingsTree.catalog(t, "")), ["Keystroke Settings"])
        verify(SettingsTree.catalog(t, "settings").some(function(r) { return r.title === "Preferred assistant" }))
        compare(SettingsTree.catalog(t, "settings/clipboard/limit").length, 0)
    }

    function test_abbreviations_reach_a_deep_setting_inside_settings() {
        // The setting's config key is `provider`, so "pro"/"prv" reach it
        // through the key even though its label says "assistant".
        var abbreviations = ["prefp", "preferred", "ai prov", "prov ai", "aiprefp", "pref"]
        for (var i = 0; i < abbreviations.length; i++) {
            var rows = search("settings", abbreviations[i])
            verify(rows.length > 0, abbreviations[i] + " found nothing")
            compare(rows[0].title, "Preferred assistant", abbreviations[i])
            compare(rows[0].subtitle, "AI & Web Search")
            compare(rows[0].action.type, "navigate")
            compare(rows[0].action.scope, "settings/ai/provider")
            compare(rows[0].accessory, "chatgpt")
        }
    }
    function test_choices_are_reachable_and_selectable_inside_settings() {
        var rows = search("settings", "prefcla")
        compare(rows[0].title, "Claude")
        compare(rows[0].icon, "○")
        compare(rows[0].action.type, "setting")
        compare(rows[0].action.value, "claude")
        compare(rows[0].action.path, ["providers", "ai"])
        compare(rows[0].previewDetail, "Keystroke Settings › AI & Web Search › Preferred assistant › Claude")
        rows = search("settings", "ai cla")
        compare(rows[0].title, "Claude")
        compare(rows[0].subtitle, "AI & Web Search › Preferred assistant")          // breadcrumb below the current screen
        rows = search("settings/ai", "cla")
        compare(rows[0].subtitle, "Preferred assistant")
        rows = search("settings", "dens comf")
        compare(rows[0].title, "Comfortable")
        compare(rows[0].action.path, ["palette"])
        rows = search("settings", "enable emoji")
        compare(rows.length, 0)                                                       // no such provider in the model
        rows = search("settings", "enable clip")
        compare(rows[0].title, "Enabled")
        compare(rows[0].subtitle, "Clipboard History")
        compare(rows[0].action.value, false)
        rows = search("settings", "hello")
        compare(rows[0].title, "Hello")
        compare(rows[0].badge, "plugin")
    }
    function test_listings_show_one_screen_and_value_screens_are_registered() {
        var t = SettingsTree.build(model())
        var root = SettingsTree.rows(t.nodes, "", "")
        compare(titles(root), ["Keystroke Settings"])
        compare(root[0].score, 20)
        compare(titles(SettingsTree.rows(t.nodes, "settings", "")), ["Appearance", "Open config file", "AI & Web Search", "Clipboard History", "Hello", "broken.plugin"])
        compare(titles(SettingsTree.rows(t.nodes, "settings/ai", "")), ["Enabled", "Preferred assistant", "Open conversations in", "Send immediately in the browser"])
        var hello = SettingsTree.rows(t.nodes, "settings/example.hello", "")
        verify(hello[0].confirm.indexOf("unsandboxed") > 0)
        compare(hello[1].title, "Manage extension")
        compare(hello[1].action.type, "navigate")
        compare(hello[1].action.scope, "extensions/example.hello")
        compare(SettingsTree.rows(t.nodes, "settings/example.hello", "manext").length, 0)   // "Manage extension" is list-only, never a search hit
        var options = SettingsTree.rows(t.nodes, "settings/ai/provider", "").map(function(r) { return r.title + " " + r.icon })
        compare(options, ["Chatgpt ✓", "Claude ○"])
        verify(t.screens["settings/clipboard/limit"] !== undefined)
        compare(t.screens["settings/clipboard/limit"].value, 100)
        compare(t.screens["settings/ai/provider"], undefined)
        var seen = ({})
        for (var i = 0; i < t.nodes.length; i++) { verify(!seen[t.nodes[i].id], "duplicate id " + t.nodes[i].id); seen[t.nodes[i].id] = true }
    }
    function voiceModel(detected, bindings) {
        var m = model()
        m.voice = { detected: detected, version: "1.0.1", daemonState: "idle", bindings: bindings, bindingsPath: "~/.config/hypr/launcher-voice.lua",
                    schemas: [
                        { key: "enabled", type: "boolean", label: "Voxtype voice command integration", "default": true, description: "Hold the palette hotkey to dictate" },
                        { key: "secondTap", type: "enum", label: "Second tap of the hotkey", "default": "voice", options: ["voice", "close"] },
                        { key: "keys", type: "string", label: "Hotkeys to hold", "default": "SUPER + SPACE" }
                    ],
                    values: { enabled: true, secondTap: "voice", keys: "SUPER + SPACE" } }
        return m
    }

    function test_voice_screen_lists_its_settings_and_the_bindings_row() {
        var t = SettingsTree.build(voiceModel(true, "missing"))
        compare(titles(SettingsTree.rows(t.nodes, "settings", "")).slice(0, 3), ["Appearance", "Voice", "Open config file"])
        var screen = SettingsTree.rows(t.nodes, "settings/voice", "")
        compare(titles(screen), ["Voxtype voice command integration", "Second tap of the hotkey", "Hotkeys to hold", "Hold-to-talk bindings", "Voxtype 1.0.1"])
        compare(screen[0].accessory, "On")
        compare(screen[0].action.path, ["voice"])
        compare(screen[0].action.value, false)
        compare(screen[3].accessory, "Missing")
        compare(screen[3].verb, "Install")
        compare(screen[3].action.type, "voice-bindings")
        verify(screen[3].confirm.indexOf("Add the Keystroke voice block") === 0)
        verify(screen[3].confirm.indexOf("~/.config/hypr/launcher-voice.lua") > 0)
        verify(screen[4].disabled)
        verify(t.screens["settings/voice/keys"] !== undefined)
        var rows = Match.rank(SettingsTree.rows(t.nodes, "settings", "voice"), null)
        compare(rows[0].title, "Voice")
        rows = Match.rank(SettingsTree.rows(t.nodes, "settings", "voxtype"), null)
        verify(["Voice", "Voxtype voice command integration"].indexOf(rows[0].title) >= 0, rows[0].title)
        rows = Match.rank(SettingsTree.rows(t.nodes, "settings", "hold bind"), null)
        compare(rows[0].title, "Hold-to-talk bindings")
        compare(rows[0].subtitle, "Voice")
        rows = Match.rank(SettingsTree.rows(t.nodes, "settings", "second tap clo"), null)
        compare(rows[0].title, "Close")
        compare(rows[0].action.path, ["voice"])
        compare(rows[0].action.value, "close")
        t = SettingsTree.build(voiceModel(true, "outdated"))
        var bindings = SettingsTree.rows(t.nodes, "settings/voice", "")[3]
        compare(bindings.accessory, "Outdated")
        compare(bindings.verb, "Update")
        verify(bindings.confirm.indexOf("Rewrite") === 0)
    }
    function test_voice_screen_without_voxtype_offers_native_configuration() {
        var t = SettingsTree.build(voiceModel(false, "missing"))
        var entry = SettingsTree.rows(t.nodes, "settings", "")[1]
        compare(entry.title, "Voice")
        compare(entry.subtitle, "Voxtype is not installed")
        var screen = SettingsTree.rows(t.nodes, "settings/voice", "")
        compare(titles(screen), ["Voxtype is not installed", "Open voice configuration"])
        verify(screen[0].disabled)
        compare(screen[1].action.type, "edit")
        verify(screen[1].subtitle.indexOf("install voxtype separately") > 0)
        var custom = voiceModel(false, "missing")
        custom.voice.configurationAction = { type: "exec", argv: ["xdg-open", "/home/x/.config/voxtype/config.toml"] }
        compare(SettingsTree.rows(SettingsTree.build(custom).nodes, "settings/voice", "")[1].action, custom.voice.configurationAction)
        compare(SettingsTree.rows(t.nodes, "settings", "hold bind").length, 0)
        compare(t.screens["settings/voice/keys"], undefined)
        t = SettingsTree.build(model())                                              // no voice model at all: nothing changes
        compare(titles(SettingsTree.rows(t.nodes, "settings", "")).slice(0, 2), ["Appearance", "Open config file"])
    }
    function test_community_schema_remains_searchable_with_option_labels() {
        var m = model()
        var e = m.entries[2]
        e.enabled = true
        e.schemas = [{ key: "greeting", type: "string", label: "Greeting", "default": "Hi" },
                     { key: "format", type: "enum", label: "Greeting format", options: ["short", "full"], optionLabels: { short: "Brief", full: "Complete" } }]
        e.values = { greeting: "Hello", format: "short" }
        var t = SettingsTree.build(m)
        var rows = SettingsTree.rows(t.nodes, "settings", "hello greeting")
        verify(rows.length > 0)
        verify(t.screens["settings/example.hello/greeting"] !== undefined)
        compare(t.screens["settings/example.hello/greeting"].value, "Hello")
        var choices = SettingsTree.rows(t.nodes, "settings/example.hello/format", "")
        compare(titles(choices), ["Brief", "Complete"])
        compare(choices[1].action.value, "full")
        compare(choices[1].action.path, ["providers", "example.hello"])
        compare(SettingsTree.rows(t.nodes, "settings/example.hello", "")[0].confirm, "")
        var fallback = voiceModel(true, "missing")
        delete fallback.voice.bindingsPath
        verify(SettingsTree.rows(SettingsTree.build(fallback).nodes, "settings/voice", "")[3].subtitle.indexOf("launcher-voice.lua") > 0)
    }
    function test_unrelated_queries_find_nothing() {
        compare(search("", "chrome").length, 0)
        compare(search("", "zzzz").length, 0)
        compare(search("settings/clipboard", "prefp").length, 0)                      // scoped search stays inside its subtree
    }
}
