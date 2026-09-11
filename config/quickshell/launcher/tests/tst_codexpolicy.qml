import QtQuick
import QtTest
import "../codex/Policy.js" as Policy
TestCase {
  name: "CodexPolicy"
  function test_full_request() {
    var text = "Open the document, please.\n" + "Long dictation 🐈 ".repeat(400)
    compare(Policy.textInput(text)[0].text, text)
    verify(Policy.textInput(text)[0].text.length > 2000)
  }
  function test_capability_isolation() {
    var p = Policy.start("/home/test", {}, {mcp_servers: {dangerous: {}, "a.b": {}}})
    compare(p.sandbox, "read-only");compare(p.environments.length, 0)
    compare(p.config["features.shell_tool"], false)
    compare(p.config["features.code_mode_host"], false)
    compare(p.config["mcp_servers.dangerous.enabled"], false)
    compare(p.config['mcp_servers."a.b".enabled'], false)
    compare(p.config.web_search, "live")
  }
  function test_handoff_id() {
    compare(Policy.externalUrl("a-b_123"), "codex://threads/a-b_123")
    compare(Policy.externalUrl("../new?prompt=other"), "")
  }
}
