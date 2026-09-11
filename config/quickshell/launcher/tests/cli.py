#!/usr/bin/env python3
"""Exercise the picker CLI without connecting to the desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

launcher = Path(__file__).resolve().parents[4] / 'bin/launcher'
luajit = shutil.which('luajit')
assert luajit, 'LuaJIT is required for the launcher CLI'
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    tools = root / 'bin'
    tools.mkdir()
    fake = tools / 'qs'
    fake.write_text(f'''#!{sys.executable}
import json, os, pathlib, sys
method=sys.argv[4]
if method == 'summon':
    data=json.loads(sys.argv[5])
    assert data['doneFile'].startswith(os.environ['XDG_RUNTIME_DIR']+'/quickshell-launcher/')
    assert data['prompt']=='Literal <b>prompt</b>'
    if os.environ.get('NO_REPLY'): sys.exit(0)
    if not os.environ.get('CANCEL'):
        result=data['options'][-1] if data['mode']=='select' else 'literal $(not-executed)'
        pathlib.Path(data['selectionFile']).write_text(result+'\\n')
    pathlib.Path(data['doneFile']).touch()
elif method=='query':
    assert sys.argv[5]=='literal $(not-executed)'
elif method!='cancelPicker': sys.exit(2)
''')
    fake.chmod(0o700)
    env = dict(os.environ, PATH=str(tools), XDG_RUNTIME_DIR=str(root))
    def run(command, extra=(), data='', **flags):
        return subprocess.run([luajit, str(launcher), command, '--prompt', 'Literal <b>prompt</b>', *extra],
                              input=data, env=dict(env, **flags), text=True, capture_output=True, timeout=5)
    result = run('select', data='First\nLiteral <b>last</b>\n')
    assert result.returncode == 0 and result.stdout == 'Literal <b>last</b>\n', result
    result = run('input')
    assert result.returncode == 0 and result.stdout == 'literal $(not-executed)\n', result
    assert run('select', data='First\n', CANCEL='1').returncode == 1
    assert run('input', ['--timeout', '0.1'], NO_REPLY='1').returncode == 2
    assert run('input', ['--timeout', '-1']).returncode == 2
    assert run('select', data='bad\0value').returncode == 2
    assert run('query', ['literal $(not-executed)']).returncode == 0
    assert list((root / 'quickshell-launcher').iterdir()) == []
print('LAUNCHER_CLI_PASS: select, input, cancel, timeout, validation, literals and cleanup')
