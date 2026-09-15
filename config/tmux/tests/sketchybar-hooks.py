#!/usr/bin/python3
"""Run with python3 config/tmux/tests/sketchybar-hooks.py. Uses a private tmux server."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]


def main():
    sockets = Path(os.environ.get('TMPDIR', '/tmp')) / 'claude-tmux-sockets'
    sockets.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sb.', dir=sockets) as work:
        work = Path(work)
        socket = str(work / 'tmux.sock')
        log = work / 'refreshes'
        log.touch()
        bindir = work / 'bin'
        bindir.mkdir()
        stub = bindir / 'sketchybar'
        stub.write_text('#!/bin/sh\nprintf "refresh\\n" >> "$HOOK_TEST_LOG"\n')
        stub.chmod(0o755)
        home = work / 'home'
        home.mkdir()
        env = dict(os.environ, HOME=str(home), PATH=f"{bindir}:{os.environ['PATH']}",
                   HOOK_TEST_LOG=str(log))
        env.pop('TMUX', None)
        env.pop('TMUX_PANE', None)
        client = None

        def tmux(*args):
            return subprocess.check_output(['tmux', '-S', socket, *args], env=env, text=True).strip()

        def calls():
            return len(log.read_text().splitlines())

        def wait_for(predicate):
            deadline = time.monotonic() + 3
            while not predicate():
                if time.monotonic() >= deadline:
                    raise AssertionError('timed out waiting for tmux hook postcondition')
                time.sleep(0.02)

        def settle():
            tmux('run-shell', '-d', '0.35')

        def clear_calls():
            settle()
            log.write_text('')

        try:
            active = tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'visible', '-n', 'main',
                          '-P', '-F', '#{pane_id}', 'sleep 300')
            print(f'Temporary test server: tmux -S {socket} attach -t visible', flush=True)
            tmux('set-option', '-g', 'default-shell', '/bin/sh')
            inactive = tmux('split-window', '-d', '-t', active, '-P', '-F', '#{pane_id}', 'sleep 300')
            hidden = tmux('new-window', '-d', '-t', 'visible', '-n', 'hidden',
                          '-P', '-F', '#{pane_id}', 'sleep 300')
            detached = tmux('new-session', '-d', '-s', 'detached', '-P', '-F', '#{pane_id}', 'sleep 300')
            client = subprocess.Popen(['tmux', '-S', socket, '-C', 'attach-session', '-t', 'visible'],
                                      env=env, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)
            wait_for(lambda: tmux('display-message', '-p', '-t', active, '#{window_active_clients}') == '1')
            client_name = tmux('list-clients', '-F', '#{client_name}')

            # Load only the actual SketchyBar section, never personal plugins or Fleet.
            config = (ROOT / 'config/tmux/tmux.conf').read_text()
            start = config.index("# Nudge sketchybar's")
            end = config.index('\nif-shell ', start)
            hooks = work / 'hooks.conf'
            hooks.write_text(config[start:end])
            foreign = 'set-option -g @foreign_hook preserved'
            for event in ('pane-title-changed', 'after-select-window', 'client-session-changed'):
                tmux('set-hook', '-g', f'{event}[42]', foreign)
            for _ in range(3):
                tmux('source-file', str(hooks))
            installed = tmux('show-hooks', '-g') + '\n' + tmux('show-hooks', '-gw')
            for event in ('after-select-window', 'client-session-changed', 'pane-title-changed'):
                handlers = re.findall(rf'^{event}\[\d+\].*sketchybar.*$', installed, re.MULTILINE)
                assert len(handlers) == 1, f'{event}: {len(handlers)} handlers after three reloads'
                assert f'{event}[42] {foreign}' in installed, f'{event}: unrelated hook was removed'

            # Every title change targets the real pane. Twelve events must yield
            # one refresh, not twelve delayed shell/sleep processes.
            clear_calls()
            batch = []
            for i in range(12):
                if batch:
                    batch.append(';')
                batch.extend(['select-pane', '-t', active, '-T', f'burst-{i}'])
            tmux(*batch)
            wait_for(lambda: calls() >= 1)
            settle()
            assert calls() == 1, f'burst produced {calls()} refreshes'

            clear_calls()
            for pane in (inactive, hidden, detached):
                tmux('select-pane', '-t', pane, '-T', 'background title')
            settle()
            assert calls() == 0, 'background title caused a refresh'

            # Existing titles must refresh when a pane/window/session becomes active.
            tmux('select-pane', '-t', inactive)
            wait_for(lambda: calls() >= 1)
            clear_calls()
            tmux('select-window', '-t', hidden)
            wait_for(lambda: calls() >= 1)
            clear_calls()
            tmux('switch-client', '-c', client_name, '-t', 'detached')
            wait_for(lambda: calls() >= 1)

            # Closing the event's pane before its delayed callback must not leave
            # the shared pending flag stuck and suppress future refreshes.
            clear_calls()
            tmux('switch-client', '-c', client_name, '-t', 'visible')
            tmux('kill-pane', '-t', hidden)
            settle()
            clear_calls()
            tmux('select-pane', '-t', inactive, '-T', 'after closing a pane')
            wait_for(lambda: calls() >= 1)
            assert tmux('show-options', '-gqv', '@sketchybar_pending') != '1'
            print('SketchyBar hooks passed: reload-safe, foreign hooks preserved, '
                  '12 events to one refresh, background filtering, focus updates, closed-pane recovery.')
        finally:
            subprocess.run(['tmux', '-S', socket, 'kill-server'], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if client is not None:
                client.communicate(timeout=3)
            print('Temporary test server cleaned up.')


if __name__ == '__main__':
    main()
