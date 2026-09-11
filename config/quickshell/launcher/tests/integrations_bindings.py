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
