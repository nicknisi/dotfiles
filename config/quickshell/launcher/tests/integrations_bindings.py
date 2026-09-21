#!/usr/bin/env python3
"""Evaluate only the dedicated Lua file with a recording hl API, never Hyprland IPC."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
hypr = root.parents[1] / 'hypr'
with tempfile.TemporaryDirectory(prefix='launcher-bindings-') as temp:
    env = dict(HOME=temp, PATH=os.environ['PATH'])
    rendered = subprocess.check_output(['node', '-e', '''
const fs=require('fs'), vm=require('vm'), ctx={}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace('.pragma library',''),ctx);
process.stdout.write(ctx.apply('', 'SUPER + SPACE'));
''', str(root / 'core/VoiceBindings.js')], env=env, text=True)
    assert (hypr / 'launcher-voice.lua').read_text() == rendered
    assert 'pcall(dofile, hypr .. "/launcher-voice.lua")' in (hypr / 'hyprland.lua').read_text()
    code = '''
local binds = {}
hl = { dsp = { exec_cmd = function(s) return s end },
  bind = function(key, command, options) table.insert(binds, {key, command, options}) end }
dofile(%s)
assert(#binds == 4)
assert(binds[1][1] == "SUPER + SPACE" and binds[1][2] == "qs ipc call launcher voiceHold")
assert(binds[1][3].long_press)
for i, key in ipairs({"SPACE", "Super_L", "Super_R"}) do
  local b = binds[i + 1]
  assert(b[1] == key and b[2] == "qs ipc call launcher voiceRelease")
  assert(b[3].release and b[3].ignore_mods and b[3].submap_universal and b[3].non_consuming)
end
print("PASS native hl.bind, universal modifier releases, dedicated source and generated block agreement")
''' % json.dumps(str(hypr / 'launcher-voice.lua'))
    result = subprocess.run(['lua', '-'], input=code, env=env, text=True, capture_output=True, check=True)
    print(result.stdout.strip())

    # Palette hotkeys: the tracked file is the empty block; a generated line is one native bind.
    hyprland = (hypr / 'hyprland.lua').read_text()
    assert 'pcall(dofile, hypr .. "/launcher-hotkeys.lua")' in hyprland
    assert 'hl.define_submap("keystroke-capture", function()' in hyprland
    generated = json.loads(subprocess.check_output(['node', '-e', '''
const fs=require('fs'), vm=require('vm');
const strip=(p,imports)=>imports.reduce((s,i)=>s.replace(i,''),fs.readFileSync(p,'utf8').replace('.pragma library',''));
const hotkeys={}; vm.createContext(hotkeys); vm.runInContext(strip(process.argv[1],['.import "Match.js" as Match']),hotkeys);
const ctx={Hotkeys:hotkeys}; vm.createContext(ctx); vm.runInContext(strip(process.argv[2],['.import "Hotkeys.js" as Hotkeys']),ctx);
const one=[{combo:'SUPER + B',route:'applications/firefox.desktop',label:'Fire "fox"'}];
process.stdout.write(JSON.stringify({empty:ctx.apply('',[],[]),one:ctx.apply('',one,[]),back:ctx.parse(ctx.apply('',one,[])).entries}));
''', str(root / 'core/Hotkeys.js'), str(root / 'core/UserHotkeys.js')], env=env, text=True))
    assert (hypr / 'launcher-hotkeys.lua').read_text() == generated['empty']
    assert generated['back'] == [{'combo': 'SUPER + B', 'route': 'applications/firefox.desktop', 'label': 'Fire "fox"'}]
    one = Path(temp) / 'launcher-hotkeys.lua'
    one.write_text(generated['one'])
    code = '''
local binds = {}
hl = { dsp = { exec_cmd = function(s) return s end },
  bind = function(key, command, options) table.insert(binds, {key, command, options}) end }
dofile(%s)
assert(#binds == 1)
assert(binds[1][1] == "SUPER + B" and binds[1][2] == "qs ipc call launcher run applications/firefox.desktop")
assert(binds[1][3].description == 'Fire "fox"')
print("PASS palette hotkeys: tracked empty block, native bind with description, round trip")
''' % json.dumps(str(one))
    result = subprocess.run(['lua', '-'], input=code, env=env, text=True, capture_output=True, check=True)
    print(result.stdout.strip())
