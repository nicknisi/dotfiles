import QtQuick
import QtTest
import "../providers"

TestCase {
  name: "DictationProvider"
  Dictation { id: extension }
  function test_discoverable_and_scoped() {
    var root = extension.provider.query({scope: "", query: "dictate"})
    compare(root.length, 2)
    compare(root[0].action.type, "dictate")
    compare(extension.provider.query({scope: "files", query: "dictate"}).length, 0)
  }
  function test_query_fallback_uses_original_dictation() {
    var raw = "Open the document, please.\nKeep  two spaces!"
    var rows = extension.provider.query({scope: "", query: "document", rawQuery: raw})
    compare(rows.length, 1)
    compare(rows[0].tier, "fallback")
    compare(rows[0].title, "Copy to Clipboard")
    compare(rows[0].action.text, raw)
    compare(rows[0].altAction.text, raw)
    compare(rows[0].altAction.paste, true)
    compare(extension.provider.query({scope: "", query: ""}).length, 1) // launcher only
    compare(extension.provider.query({scope: "", query: "typed prose"})[0].action.text, "typed prose")
  }
  function test_preserves_exact_prose_and_literal_shell_text() {
    var text = "Open the document, please.\nKeep  two spaces! $(touch /tmp/no) 🐈"
    var rows = extension.provider.query({scope: "dictation", query: text})
    compare(rows.length, 1)
    compare(rows[0].preview, text)
    compare(rows[0].action.text, text)
    compare(rows[0].altAction.text, text)
    compare(rows[0].altAction.paste, true)
    compare(rows[0].disabled, false)
    compare(extension.provider.query({scope: "dictation", query: "  "})[0].disabled, true)
  }
}
