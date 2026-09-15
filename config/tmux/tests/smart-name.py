#!/usr/bin/python3
"""Run with python3 config/tmux/tests/smart-name.py. No live tmux changes."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def stub(command, args):
    state_path = Path(os.environ['NAME_TEST_STATE'])
    state = json.loads(state_path.read_text())
    state['calls'].append([command, *args])
    if command == 'tmux':
        batches = [[]]
        for arg in args:
            if arg == ';':
                batches.append([])
            else:
                batches[-1].append(arg)
        for batch in batches:
            if batch[0] == 'display-message':
                print(f"{state['now']}|{state.get('next', '')}")
            elif batch[0] == 'set-option':
                state['next'] = batch[-1]
            elif batch[0] == 'list-panes':
                fmt = batch[-1]
                for pane in state['panes']:
                    print(re.sub(r'#\{([^}]+)\}', lambda m: pane.get(m[1], ''), fmt))
            elif batch[0] == 'rename-window':
                window, name = batch[batch.index('-t') + 1], batch[-1]
                state['renamed'].append([window, name])
                for pane in state['panes']:
                    if pane['window_id'] == window:
                        pane['window_name'] = name
            elif batch[0] in ('show', 'show-options'):
                pass
            elif batch[0] != 'set-window-option':
                raise AssertionError(batch)
    elif command == 'ps':
        print('ttys001 pi' if 'tty=,comm=' in args else 'pi')
    elif command == 'git':
        path = args[args.index('-C') + 1]
        print('feature' if '--abbrev-ref' in args else path.removesuffix('/src'))
    else:
        raise AssertionError(command)
    state_path.write_text(json.dumps(state))


def main():
    with tempfile.TemporaryDirectory(prefix='tmux-smart-name.') as work:
        work = Path(work)
        state_path = work / 'state.json'
        bindir = work / 'bin'
        bindir.mkdir()
        for command in ('tmux', 'ps', 'git'):
            path = bindir / command
            path.write_text('#!/bin/sh\nexec ' + ' '.join(map(shlex.quote, [
                sys.executable, str(Path(__file__).resolve()), '--stub', command
            ])) + ' "$@"\n')
            path.chmod(0o755)
        env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", NAME_TEST_STATE=str(state_path))
        env.pop('BASH_ENV', None)
        env.pop('SHELLOPTS', None)

        def pane(window, active, command, path, tty, auto='1', name='old'):
            return dict(zip(('window_id', 'pane_active', 'pane_current_command',
                             'pane_current_path', 'pane_tty', 'automatic-rename', 'window_name'),
                            (window, active, command, path, tty, auto, name)))

        state = dict(now=1000, calls=[], renamed=[], panes=[
            pane('@1', '1', 'nvim', '/repo/editor', '/dev/ttys000'),
            pane('@1', '0', 'node', '/repo/agent/src', '/dev/ttys001'),
            pane('@2', '0', 'pi', '/repo/first', '/dev/ttys002'),
            pane('@2', '1', 'pi', '/repo/active', '/dev/ttys003'),
            pane('@3', '1', 'pi', '/repo/manual', '/dev/ttys004', '0', 'My window'),
        ])
        state_path.write_text(json.dumps(state))

        def run(*args):
            result = subprocess.run(['/bin/bash', str(ROOT / 'bin/tmux-smart-name'), *args],
                                    env=env, text=True, capture_output=True, check=True)
            return result.stdout

        assert run('--refresh') == '', 'batch refresh must not print into the status bar'
        state = json.loads(state_path.read_text())
        assert state['renamed'] == [['@1', 'π agent'], ['@2', 'π active']], state
        assert sum(call[0] == 'ps' for call in state['calls']) == 1, state['calls']
        assert sum(call[0] == 'git' for call in state['calls']) == 2, state['calls']
        assert sum(call[:2] == ['tmux', 'show'] for call in state['calls']) == 0
        cold_calls = len(state['calls'])
        state['calls'] = []
        state_path.write_text(json.dumps(state))
        assert run('--refresh') == ''
        state = json.loads(state_path.read_text())
        assert len(state['calls']) == 1 and state['calls'][0][:2] == ['tmux', 'display-message'], state

        # A new batch sees command changes but never overwrites an explicit name.
        state['now'] += 6
        state['calls'] = []
        state['renamed'] = []
        state['panes'][1]['pane_current_command'] = 'fleet'
        state_path.write_text(json.dumps(state))
        run('--refresh')
        state = json.loads(state_path.read_text())
        assert state['renamed'] == [['@1', ' editor']], state
        assert not any(call[0] == 'ps' for call in state['calls'])

        # Retain standalone callers, HOME, spaces, root, version-titled Claude,
        # both supported worktree layouts, and detached-worktree fallback.
        assert run('pi', env['HOME'], '') == 'π ~\n'
        assert run('pi', '/', '') == 'π /\n'
        assert run('2.1.197', '/repo/a project/src', '') == '󱙺 a project\n'
        tree = work / 'project' / '.claude' / 'worktrees' / 'topic'
        tree.mkdir(parents=True)
        (tree / '.git').touch()
        assert run('pi', str(tree), '') == 'π project (feature)\n'
        bare = work / 'bare-project'
        (bare / '.bare').mkdir(parents=True)
        (bare / 'topic').mkdir()
        (bare / 'topic' / '.git').touch()
        assert run('pi', str(bare / 'topic'), '') == 'π bare-project (feature)\n'
        print(f'Naming checks passed: ranking, manual names, worktrees, one ps per batch, '
              f'{cold_calls} external calls for two windows, one call on a throttled refresh.')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--stub':
        stub(sys.argv[2], sys.argv[3:])
    else:
        main()
