import QtQuick
import QtTest
import "../core/SmartMatch.js" as Smart
import "../core/Intent.js" as Intent
import "../core/Calculator.js" as Calc
import "../core/Settings.js" as Settings
import "../core/SettingsTree.js" as Tree

TestCase {
  name: "SmartMatch"
  function row(provider, id, title, action) { return {providerKey:provider, id:id, uid:provider+"/"+id, title:title, action:action, tier:"item", score:1} }
  function test_modes_and_labels() {
    var values = Settings.values({}, ["matching"], Smart.SCHEMA)
    compare(values.mode, "all"); compare(values.model, "small")
    verify(!Smart.enabled("off", true)); verify(!Smart.enabled("voice", false)); verify(Smart.enabled("voice", true)); verify(Smart.enabled("all", false))
    var tree = Tree.build({matching:{schemas:Smart.SCHEMA,values:values}})
    compare(Tree.rows(tree.nodes, "settings/matching/mode", "").map(function(r) {return r.title}).join("|"), "Off|Only voice|Voice and text")
    compare(Tree.rows(tree.nodes, "settings/matching/model", "").map(function(r) {return r.title}).join("|"), "Small (2M)|Large (8M)")
  }
  function test_spoken_arithmetic_data() { return [
    {tag:"digits", text:"27 plus 90", value:117}, {tag:"question", text:"What is 27 plus 90?", value:117},
    {tag:"words", text:"twenty seven plus ninety", value:117}, {tag:"hundred", text:"one hundred and five minus five", value:100},
    {tag:"decimal", text:"two point five plus one", value:3.5}, {tag:"decimal digits", text:"two point zero five plus one", value:3.05},
    {tag:"order", text:"subtract 3 from 10", value:7}, {tag:"percent", text:"15 percent of 80", value:12},
    {tag:"negative", text:"negative five plus two", value:-3}, {tag:"power", text:"2 to the power of 3", value:8}
  ] }
  function test_spoken_arithmetic(data) { compare(Calc.calculate(Intent.normalize(data.text)), data.value) }
  function test_prose_and_ambiguous_math() {
    var texts = ["Disney plus", "C plus plus", "one plus phone", "twenty for plus six", "27 plush 90", "27 plus", "27 plus 90 and send it", "one two plus three", "1 / 0"]
    for (var i=0;i<texts.length;i++) compare(Intent.arithmetic(texts[i]), "", texts[i])
  }
  function test_launch_does_not_install() {
    var chromium = row("applications", "chromium", "Chromium", {type:"app"})
    var chrome = row("applications", "google-chrome", "Google Chrome", {type:"app"})
    var install = row("omarchy", "install.browser.chrome", "Chrome", {type:"shell"})
    var req = Smart.request("launch Chrome")
    var out = Smart.merge([install], [chromium,install], req, [{id:install.uid,score:0.99}])
    compare(out.length, 1); compare(out[0].uid, chromium.uid)
    out = Smart.merge([], [chromium,chrome], req, [])
    compare(out.length, 1); compare(out[0].uid, chrome.uid)
  }
  function test_semantics_never_replace_actions_or_exact_hits() {
    var a = row("applications", "a", "Chrome", {type:"app",id:"a"})
    var b = row("applications", "b", "Firefox", {type:"app",id:"b"})
    var req = Smart.request("chrome")
    var out = Smart.merge([], [a,b], req, [{id:b.uid,score:0.99,action:{type:"shell",command:"wrong"}},{id:"missing",score:1}])
    compare(out.length, 2); verify(out[0].score > out[1].score)
    compare(out[1].action.type, "app"); verify(out[1].smartMatch)
  }
  function test_negation_direction_and_command_family() {
    var reboot = row("omarchy","system.reboot","Reboot",{type:"shell"})
    compare(Smart.merge([reboot],[reboot],Smart.request("do not reboot"),[{id:reboot.uid,score:1}]).length,0)
    verify(Smart.request("Please don\u2019t reboot").blocked)
    var up = row("hotkeys","volume-up","Volume up",{type:"hotkey"})
    var down = row("hotkeys","volume-down","Volume down",{type:"hotkey"})
    verify(Smart.allowed(Smart.request("turn up the volume"),up,true))
    verify(!Smart.allowed(Smart.request("turn up the volume"),down,true))
    var stop = row("omarchy","trigger.capture.screenrecord.stop","Stop Screenrecording",{type:"shell"})
    verify(!Smart.allowed(Smart.request("record the screen"),stop,true))
    verify(Smart.allowed(Smart.request("stop screen recording"),stop,true))
    var remove = row("omarchy","remove.theme","Theme",{type:"shell"})
    verify(!Smart.allowed(Smart.request("change theme"),remove,false))
  }
  function test_typo_distance() {
    verify(Smart.editOne("chromiun","chromium")); verify(Smart.editOne("chnage","change"))
    verify(!Smart.editOne("crumb","chrome")); verify(!Smart.editOne("abcd","abxy"))
  }
  function test_disabled_answers_and_confirmation_dedup() {
    var partial = row("calculator", "result", "27 + ...", {type:"noop"})
    partial.tier = "answer"; partial.disabled = true; partial.score = 200
    compare(Smart.merge([partial], [], Smart.request("27 +"), []).length, 1)
    var menu = row("omarchy", "system.reboot", "Reboot", {type:"shell",command:"reboot-test"})
    menu.confirm = "Confirm reboot?"; menu.score = 100
    var key = row("hotkeys", "reboot", "Reboot", {type:"hotkey",dispatcher:"exec",arg:"reboot-test"})
    key.score = 120
    var rows = Smart.merge([key,menu], [], Smart.request("reboot"), [])
    compare(rows.length, 1); compare(rows[0].confirm, "Confirm reboot?")
  }
  function test_state_requests_do_not_restart_or_choose_opposite_setters() {
    var restart = row("omarchy", "update.hardware.bluetooth", "Bluetooth", {type:"shell",command:"restart"})
    verify(!Smart.allowed(Smart.request("please can you turn on bluetooth"), restart, true))
    var off = row("settings", "off", "Off", {type:"setting",value:false})
    verify(!Smart.allowed(Smart.request("turn on nightlight"), off, true))
    var toggle = row("omarchy", "trigger.toggle.nightlight", "Nightlight", {type:"shell",command:"omarchy-toggle-nightlight"})
    var rows = Smart.merge([], [toggle], Smart.request("turn on nightlight"), [])
    compare(rows.length, 1); compare(rows[0].verb, "Toggle")
  }
}
