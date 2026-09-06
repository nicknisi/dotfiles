#!/usr/bin/env python3
import json
import os
import time
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TAILDROP = ROOT / 'bin' / 'taildrop'

FAKE_TAILSCALE = r'''#!/usr/bin/env python3
import json, os, pathlib, shutil, signal, sys, time
log = pathlib.Path(os.environ['TAILDROP_LOG'])
args = sys.argv[1:]
log.write_text(log.read_text() + json.dumps(args) + '\n' if log.exists() else json.dumps(args) + '\n')
mode = os.environ.get('TAILDROP_FAKE_MODE', '')
if args[:3] == ['file', 'cp', '--update-interval=0']:
    if mode == 'cp_fail':
        print('copy failed safely', file=sys.stderr); raise SystemExit(9)
    raise SystemExit(0)
if args[:2] == ['file', 'get']:
    staging = pathlib.Path(args[-1])
    staging.mkdir(parents=True, exist_ok=True)
    if mode == 'get_wait':
        (log.parent / 'child-pid').write_text(str(os.getpid()))
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        time.sleep(30)
    if mode in ('get_ok', 'get_partial'):
        (staging / 'new file.txt').write_text('new')
        (staging / '-hostile\nname.txt').write_text('hostile')
    if mode == 'get_partial':
        print('tailnet down after receive', file=sys.stderr); raise SystemExit(7)
    raise SystemExit(0)
raise SystemExit(3)
'''

FAKE_NOTIFY = '#!/bin/sh\nprintf "%s\\n" "$@" >> "$TAILDROP_NOTIFY_LOG"\nexit 0\n'
FAKE_OPEN = '#!/bin/sh\nprintf "%s\\n" "$@" >> "$TAILDROP_OPEN_LOG"\nexit 0\n'
FAKE_XDG = '#!/bin/sh\nexit 1\n'


def lines(out):
    return [json.loads(x) for x in out.splitlines() if x.strip()]


class TaildropTest(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.tmp = Path(self.td.name)
        self.bin = self.tmp / 'bin'
        self.bin.mkdir()
        for name, text in {'tailscale': FAKE_TAILSCALE, 'notify-send': FAKE_NOTIFY,
                           'xdg-open': FAKE_OPEN, 'xdg-user-dir': FAKE_XDG}.items():
            p = self.bin / name
            p.write_text(text)
            p.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            'PATH': str(self.bin) + os.pathsep + self.env.get('PATH', ''),
            'TAILDROP_LOG': str(self.tmp / 'tailscale.log'),
            'TAILDROP_NOTIFY_LOG': str(self.tmp / 'notify.log'),
            'TAILDROP_OPEN_LOG': str(self.tmp / 'open.log'),
            'HOME': str(self.tmp / 'home'),
            'XDG_RUNTIME_DIR': str(self.tmp / 'runtime'),
        })

    def tearDown(self):
        self.td.cleanup()

    def run_taildrop(self, *args, **kw):
        return subprocess.run([sys.executable, str(TAILDROP), *args], text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              env=self.env, **kw)

    def test_send_uses_argv_and_rejects_hostile_target(self):
        f = self.tmp / 'a file;$(no).txt'
        f.write_text('x')
        ok = self.run_taildrop('send', 'host-1.example.ts.net', str(f))
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertEqual(lines(ok.stdout), [{'event': 'sent', 'target': 'host-1.example.ts.net', 'files': [str(f)]}])
        argv = json.loads((self.tmp / 'tailscale.log').read_text().splitlines()[0])
        self.assertEqual(argv, ['file', 'cp', '--update-interval=0', '--', str(f), 'host-1.example.ts.net:'])

        bad = self.run_taildrop('send', '--login-server=x', str(f))
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn('unsafe target', bad.stderr)

    def test_send_rejects_non_regular_file_without_tailscale(self):
        d = self.tmp / 'dir'
        d.mkdir()
        bad = self.run_taildrop('send', 'target', str(d))
        self.assertNotEqual(bad.returncode, 0)
        self.assertFalse((self.tmp / 'tailscale.log').exists())

    def test_receive_recovers_and_collides_without_overwrite(self):
        dest = self.tmp / 'Downloads'
        staging = dest / '.taildrop'
        staging.mkdir(parents=True)
        (dest / 'same.txt').write_text('old')
        (staging / 'same.txt').write_text('recovered')
        (staging / 'dangling.txt').write_text('safe')
        os.symlink(dest / 'missing-target', dest / 'dangling.txt')
        self.env['TAILDROP_FAKE_MODE'] = 'get_ok'

        got = self.run_taildrop('receive', '--once', str(dest))
        self.assertEqual(got.returncode, 0, got.stderr)
        events = lines(got.stdout)
        received = [e['path'] for e in events if e['event'] == 'received']
        self.assertIn(str(dest / 'same-1.txt'), received)
        self.assertIn(str(dest / 'dangling-1.txt'), received)
        self.assertEqual((dest / 'same.txt').read_text(), 'old')
        self.assertTrue((dest / 'dangling.txt').is_symlink())
        self.assertFalse((staging / 'same.txt').exists())
        self.assertFalse((staging / 'dangling.txt').exists())

    def test_receive_drains_after_partial_failure_and_reports_error(self):
        dest = self.tmp / 'Downloads'
        self.env['TAILDROP_FAKE_MODE'] = 'get_partial'
        got = self.run_taildrop('receive', '--once', str(dest))
        self.assertEqual(got.returncode, 7)
        events = lines(got.stdout)
        self.assertTrue(any(e['event'] == 'error' and 'tailnet down' in e['message'] for e in events))
        self.assertEqual((dest / 'new file.txt').read_text(), 'new')
        self.assertEqual((dest / '-hostile\nname.txt').read_text(), 'hostile')
        self.assertFalse((dest / '.taildrop' / 'new file.txt').exists())

    def test_receiver_rejects_symlink_lock_without_truncating_target(self):
        lockdir = self.tmp / 'runtime' / 'taildrop'
        lockdir.mkdir(parents=True)
        victim = self.tmp / 'important.txt'
        victim.write_text('keep this')
        (lockdir / 'receive.lock').symlink_to(victim)
        result = self.run_taildrop('receive', '--once', str(self.tmp / 'Downloads'))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(victim.read_text(), 'keep this')
        self.assertFalse((self.tmp / 'tailscale.log').exists())

    def test_receiver_exclusion_and_bounded_child_shutdown(self):
        self.env['TAILDROP_FAKE_MODE'] = 'get_wait'
        first = subprocess.Popen([sys.executable, str(TAILDROP), 'receive', str(self.tmp / 'one')],
                                 env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            marker = self.tmp / 'child-pid'
            deadline = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(marker.exists(), 'receiver child started')
            second = self.run_taildrop('receive', '--once', str(self.tmp / 'two'))
            self.assertNotEqual(second.returncode, 0)
            self.assertIn('already running', second.stderr)
            first.terminate()
            first.communicate(timeout=5)
            with self.assertRaises(ProcessLookupError):
                os.kill(int(marker.read_text()), 0)
        finally:
            if first.poll() is None:
                first.kill()
                first.communicate()

    def test_abrupt_reload_cannot_orphan_inbox_waiter(self):
        self.env['TAILDROP_FAKE_MODE'] = 'get_wait'
        receiver = subprocess.Popen([sys.executable, str(TAILDROP), 'receive', str(self.tmp / 'Downloads')],
                                    env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            marker = self.tmp / 'child-pid'
            deadline = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(marker.exists())
            receiver.kill()
            receiver.communicate(timeout=5)
            state = Path('/proc') / marker.read_text() / 'stat'
            deadline = time.monotonic() + 2
            while state.exists() and state.read_text().split()[2] != 'Z' and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(not state.exists() or state.read_text().split()[2] == 'Z', 'inbox waiter exited with its parent')
        finally:
            if receiver.poll() is None:
                receiver.kill()
                receiver.communicate()

    def test_receive_keeps_staged_file_when_publish_cap_exhausted(self):
        dest = self.tmp / 'Downloads'
        staging = dest / '.taildrop'
        staging.mkdir(parents=True)
        (staging / 'full.txt').write_text('keep')
        for i in range(1000):
            name = 'full.txt' if i == 0 else f'full-{i}.txt'
            (dest / name).write_text('taken')
        self.env['TAILDROP_FAKE_MODE'] = 'get_ok'
        got = self.run_taildrop('receive', '--once', str(dest))
        self.assertEqual(got.returncode, 1)
        self.assertEqual((staging / 'full.txt').read_text(), 'keep')
        self.assertTrue(any(e['event'] == 'error' and 'too many collisions' in e['message'] for e in lines(got.stdout)))


if __name__ == '__main__':
    unittest.main()
