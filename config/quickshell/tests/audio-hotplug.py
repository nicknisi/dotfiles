#!/usr/bin/env python3
"""Exercise Audio.qml against a private PipeWire server, never the session's audio."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-audio-') as directory:
    tmp = Path(directory)
    env = dict(os.environ, PIPEWIRE_RUNTIME_DIR=directory, PIPEWIRE_REMOTE='pipewire-0', QT_QPA_PLATFORM='offscreen')
    env.pop('WAYLAND_DISPLAY', None)
    config = tmp / 'pipewire.conf'
    config.write_text('''
context.properties = { core.daemon = true core.name = pipewire-0 }
context.spa-libs = { support.* = support/libspa-support audio.convert.* = audioconvert/libspa-audioconvert }
context.modules = [
 { name = libpipewire-module-protocol-native }
 { name = libpipewire-module-access }
 { name = libpipewire-module-metadata }
 { name = libpipewire-module-spa-node-factory }
 { name = libpipewire-module-adapter }
]
context.objects = [ { factory = metadata args = { metadata.name = default } } ]
''')
    shutil.copy(root / 'Audio.qml', tmp / 'Audio.qml')
    (tmp / 'qmldir').write_text('singleton Audio 1.0 Audio.qml\n')
    (tmp / 'shell.qml').write_text('''import Quickshell
ShellRoot {
    property var inputs: Audio.sources.map(n => n.name)
    property var outputs: Audio.sinks.map(n => n.name)
    onInputsChanged: console.log("INPUTS", JSON.stringify(inputs))
    onOutputsChanged: console.log("OUTPUTS", JSON.stringify(outputs))
}
''')
    processes = []
    with (tmp / 'server.log').open('w+') as server_log, (tmp / 'shell.log').open('w+') as shell_log:
        def run(*args):
            return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT, timeout=5)
        try:
            processes.append(subprocess.Popen(['pipewire', '-c', str(config)], env=env, stdout=server_log, stderr=subprocess.STDOUT, start_new_session=True))
            for _ in range(50):
                if (tmp / 'pipewire-0').exists():
                    break
                time.sleep(.1)
            assert (tmp / 'pipewire-0').exists(), 'private server did not start'
            processes.append(subprocess.Popen(['qs', '-p', directory, '--no-color'], env=env, stdout=shell_log, stderr=subprocess.STDOUT, start_new_session=True))
            time.sleep(1)
            for cycle in range(5):
                for kind in ['Sink', 'Source']:
                    name = f'fixture_{kind.lower()}'
                    run('pw-cli', 'create-node', 'adapter', '{ factory.name = support.null-audio-sink node.name = "' + name + '" media.class = "Audio/' + kind + '" audio.position = [ FL FR ] object.linger = true }')
                    run('pw-metadata', '0', 'default.audio.' + kind.lower(), json.dumps({'name': name}), 'Spa:String:JSON')
                    time.sleep(.15)
                graph = json.loads(run('pw-dump'))
                nodes = [n['id'] for n in graph if n.get('info', {}).get('props', {}).get('node.name', '').startswith('fixture_')]
                assert len(nodes) == 2, 'test nodes missing'
                for node in nodes:
                    run('pw-cli', 'destroy', str(node))
                time.sleep(.25)
            for kind in ['Sink', 'Source']:
                name = f'fixture_{kind.lower()}'
                run('pw-cli', 'create-node', 'adapter', '{ factory.name = support.null-audio-sink node.name = "' + name + '" media.class = "Audio/' + kind + '" audio.position = [ FL FR ] object.linger = true }')
                run('pw-metadata', '0', 'default.audio.' + kind.lower(), json.dumps({'name': name}), 'Spa:String:JSON')
            time.sleep(.5)
            processes[0].terminate()
            processes[0].wait(timeout=3)
            time.sleep(1)
            shell_log.seek(0)
            output = shell_log.read()
            assert 'fixture_source' in output and 'fixture_sink' in output, 'audio menus did not discover fixture nodes\n' + output
            assert not any(s in output for s in ['Binding loop', 'has crashed', 'TypeError', 'Failed to load']), 'audio hotplug failed\n' + output
            assert processes[-1].poll() is None, 'Quickshell exited\n' + output
            print('PASS: 5 default sink/source hotplug cycles and server disconnect without binding loops or crashes')
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
