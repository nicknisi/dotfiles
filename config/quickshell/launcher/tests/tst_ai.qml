import QtQuick
import QtTest
import "../core/AiTargets.js" as Ai

TestCase {
    name: "AiTargets"
    property var all: ({ "claude-desktop": true, "chatgpt": true, "claude": true, "codex": true })

    function test_links_carry_the_prompt() {
        compare(Ai.claudeDesktopUrl("what is 2+2?"), "claude://claude.ai/new?q=what%20is%202%2B2%3F&surface=chat")
        compare(Ai.codexDesktopUrl("fix the bug"), "codex://threads/new?prompt=fix%20the%20bug")
        compare(Ai.claudeWebUrl("hi"), "https://claude.ai/new?q=hi")
        compare(Ai.chatgptWebUrl("hi", false), "https://chatgpt.com/?prompt=hi")
        compare(Ai.chatgptWebUrl("hi", true), "https://chatgpt.com/?q=hi")
        compare(Ai.googleUrl("two words"), "https://www.google.com/search?q=two+words")
    }
    function test_slash_commands_are_padded_without_truncating_prompts() {
        // Claude's URL validator refuses a q that starts with "/".
        compare(Ai.claudeDesktopUrl("/clear"), "claude://claude.ai/new?q=%20%2Fclear&surface=chat")
        compare(Ai.codexDesktopUrl("/literal"), "codex://threads/new?prompt=%2Fliteral")
        var long = new Array(3000).join("a")
        verify(decodeURIComponent(Ai.codexDesktopUrl(long).split("prompt=")[1]).length === long.length)
    }
    function test_desktop_mode_uses_the_apps_own_launchers() {
        var c = Ai.plan("claude", "desktop", false, all, "hello")
        compare(c.target, "claude-desktop")
        compare(c.effect.type, "exec")
        compare(c.effect.argv[0], "claude-desktop")
        compare(c.effect.argv[1], "claude://claude.ai/new?q=hello&surface=chat")
        var g = Ai.plan("chatgpt", "desktop", false, all, "hello")
        compare(g.title, "Ask Codex")
        compare(g.effect.argv, ["chatgpt", "codex://threads/new?prompt=hello"])
    }
    function test_missing_targets_fall_back_to_the_browser_and_say_so() {
        var c = Ai.plan("claude", "desktop", false, {}, "hello")
        compare(c.target, "claude-web")
        compare(c.effect, { type: "url", url: "https://claude.ai/new?q=hello" })
        verify(c.subtitle.indexOf("not installed") > 0)
        var g = Ai.plan("chatgpt", "cli", true, {}, "hello")
        compare(g.target, "chatgpt-web")
        compare(g.effect.url, "https://chatgpt.com/?q=hello")
        verify(g.subtitle.indexOf("sends your prompt") > 0)
    }
    function test_cli_mode_passes_the_prompt_as_a_literal_argument() {
        var payload = "--help $(touch /tmp/no) `id` \"quoted\""
        var c = Ai.plan("claude", "cli", false, all, payload)
        compare(c.effect.argv, ["uwsm-app", "--", "ghostty", "-e", "claude", "--", payload])
        compare(Ai.plan("chatgpt", "cli", false, all, "x").effect.argv[4], "codex")
    }
    function test_cli_preserves_whitespace_and_long_prompts() {
        var text = "  /literal\n" + "words 🐈 ".repeat(500) + "  "
        compare(Ai.plan("claude", "cli", false, all, text).effect.argv[6], text)
    }
    function test_scheme_handler_fallback_when_binary_missing() {
        compare(Ai.openLink("claude-desktop", "claude://x", {}), { type: "url", url: "claude://x" })
    }
}
