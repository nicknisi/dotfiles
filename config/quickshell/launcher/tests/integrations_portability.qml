import QtQuick
import QtTest
import "../codex/Policy.js" as Policy
import "../core/Files.js" as Files

TestCase {
  name: "IntegrationPortability"
  function test_codex_current_default_and_literal_handoff() {
    compare(Policy.start("/fixture", {}, {}).model, null)
    compare(Policy.start("/fixture", {model: "explicit"}, {}).model, "explicit")
    var prompt = " --help $(id) `id` \"quoted\"\n" + "full request ".repeat(500)
    compare(Policy.cliArgv("", prompt, "/tmp/folder with spaces"),
      ["uwsm-app", "--", "ghostty", "-e", "codex", "--cd", "/tmp/folder with spaces", "--", prompt])
    compare(Policy.cliArgv("thread-id", "", "/fixture"),
      ["uwsm-app", "--", "ghostty", "-e", "codex", "resume", "thread-id", "--cd", "/fixture"])
    compare(Policy.cliArgv("../unsafe", "", ""), [])
  }
  function test_files_use_ghostty_with_literal_workdir() {
    compare(Files.terminalEffect({dir: false, path: "/fixture/folder $(id)/file.txt"}).argv,
      ["uwsm-app", "--", "ghostty", "--working-directory=/fixture/folder $(id)"])
    compare(Files.terminalEffect({dir: true, path: "/fixture/folder with spaces"}).argv,
      ["uwsm-app", "--", "ghostty", "--working-directory=/fixture/folder with spaces"])
  }
}
