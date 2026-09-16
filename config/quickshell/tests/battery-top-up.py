#!/usr/bin/python3
"""Battery top-up checks with fake sysfs. Never writes real firmware."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('topup', Path(__file__).resolve().parents[1] / 'battery-top-up.py')
topup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(topup)


class TopUpTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        topup.SUPPLIES = root / 'power'
        topup.BATTERY = topup.SUPPLIES / 'BAT0'
        topup.STATE = root / 'state' / 'state.json'
        topup.BATTERY.mkdir(parents=True)
        (topup.SUPPLIES / 'AC').mkdir()
        self.ac = topup.SUPPLIES / 'AC' / 'online'
        self.ac.write_text('1')
        for name, value in dict(capacity='61', charge_types='Standard [Custom]',
                                charge_control_start_threshold='50', charge_control_end_threshold='80').items():
            (topup.BATTERY / name).write_text(value)
        self.modes = []
        self.mode_patch = patch.object(topup, 'set_mode', side_effect=self.set_mode)
        self.mode_patch.start()
        self.addCleanup(self.mode_patch.stop)

    def set_mode(self, value):
        self.modes.append(value)
        (topup.BATTERY / 'charge_types').write_text('[' + value + ']')

    def assert_restored(self, target=80):
        self.assertEqual(self.modes, ['Standard', 'Custom'] if target == 100 else ['Custom'])
        self.assertFalse(topup.STATE.exists())
        self.assertEqual(topup.read('charge_control_start_threshold'), '50')
        self.assertEqual(topup.read('charge_control_end_threshold'), '80')

    def test_targets_restore_without_changing_thresholds(self):
        for target in (80, 100):
            with self.subTest(target=target):
                self.modes = []
                (topup.BATTERY / 'capacity').write_text('61')
                def charge(_):
                    if target == 80:
                        self.assertEqual(topup.mode(), 'Custom')
                        self.assertEqual(topup.read('charge_control_end_threshold'), '80')
                        self.assertEqual(topup.read('charge_control_start_threshold'), '75')
                    (topup.BATTERY / 'capacity').write_text(str(target))
                with patch.object(topup.time, 'sleep', side_effect=charge):
                    topup.run(target)
                self.assert_restored(target)

    def test_unplug_restores(self):
        with patch.object(topup.time, 'sleep', side_effect=lambda _: self.ac.write_text('0')):
            topup.run(80)
        self.assert_restored()

    def test_read_failure_restores(self):
        with patch.object(topup.time, 'sleep', side_effect=OSError('Device disappeared')):
            with self.assertRaises(OSError):
                topup.run(80)
        self.assert_restored()

    def test_rejects_unplugged_full_and_invalid_targets(self):
        for target, capacity, online in [(81, '61', '1'), (80, '80', '1'), (80, '75', '1'), (80, '61', '0')]:
            with self.subTest(target=target, capacity=capacity, online=online):
                (topup.BATTERY / 'capacity').write_text(capacity)
                self.ac.write_text(online)
                with self.assertRaises((ValueError, RuntimeError)):
                    topup.run(target)
                self.assertFalse(topup.STATE.exists())
                self.assertEqual(self.modes, [])

    def test_recovery_survives_failed_restore(self):
        topup.STATE.parent.mkdir()
        topup.STATE.write_text(json.dumps(dict(mode='Custom', start=50, target=100)))
        with patch.object(topup, 'set_mode', side_effect=OSError('Firmware unavailable')):
            with self.assertRaises(OSError):
                topup.restore()
        self.assertTrue(topup.STATE.exists())
        with patch.object(topup.subprocess, 'run', return_value=subprocess.CompletedProcess([], 3, 'inactive\n')):
            self.assertTrue(topup.status()['recovery'])
        topup.restore()
        self.assertFalse(topup.STATE.exists())

    def test_duplicate_request_preserves_saved_state(self):
        topup.STATE.parent.mkdir()
        data = json.dumps(dict(mode='Custom', start=50, target=100))
        topup.STATE.write_text(data)
        with self.assertRaises(FileExistsError):
            topup.run(80)
        self.assertEqual(topup.STATE.read_text(), data)
        self.assertEqual(self.modes, [])

    def test_stop_restores_after_reboot_without_transient_unit(self):
        topup.STATE.parent.mkdir()
        topup.STATE.write_text(json.dumps(dict(mode='Custom', start=50, target=100)))
        results = [subprocess.CompletedProcess([], 5, '', 'Unit not loaded'),
                   subprocess.CompletedProcess([], 4, 'inactive\n', '')]
        with patch.object(topup.os, 'geteuid', return_value=0), patch.object(topup.subprocess, 'run', side_effect=results):
            topup.main(['stop'])
        self.assertEqual(self.modes, ['Custom'])
        self.assertFalse(topup.STATE.exists())

    def test_service_has_cleanup_and_time_limit(self):
        def launched(command, **kwargs):
            self.assertIn('--property=RuntimeMaxSec=12h', command)
            self.assertTrue(any(arg.startswith('--property=ExecStopPost=') and arg.endswith(' restore') for arg in command))
            self.assertEqual(command[-2:], ['run', '80'])
            topup.STATE.parent.mkdir()
            topup.STATE.write_text(json.dumps(dict(mode='Custom', start=50, target=80)))
            topup.set_start(75)
        with patch.object(topup.os, 'geteuid', return_value=0), patch.object(topup.subprocess, 'run', side_effect=launched):
            topup.main(['start', '80'])
        topup.restore()
        self.assertEqual(topup.read('charge_control_start_threshold'), '50')

    def test_privilege_required_and_no_hardware_fallback(self):
        with patch.object(topup.os, 'geteuid', return_value=1000):
            with self.assertRaises(RuntimeError):
                topup.main(['start', '80'])
        (topup.BATTERY / 'charge_types').unlink()
        self.assertFalse(topup.status()['supported'])


if __name__ == '__main__':
    unittest.main()
