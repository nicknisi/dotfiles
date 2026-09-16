#!/usr/bin/python3
"""One top-up, then restore Dell's saved Custom charging settings.

A transient system service outlives the bar and restores on stop/shutdown.
Persistent recovery state lets the UI offer restoration after a power loss.
No polkit rule is installed: starting and stopping require authorization.
"""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

BATTERY = Path('/sys/class/power_supply/BAT0')
SUPPLIES = BATTERY.parent
STATE = Path('/var/lib/quickshell-battery-top-up/state.json')
UNIT = 'quickshell-battery-top-up.service'
SCRIPT = str(Path(__file__).resolve())


def read(name):
    return (BATTERY / name).read_text().strip()


def mode():
    return read('charge_types').split('[')[1].split(']')[0]


def plugged_in():
    return any(p.read_text().strip() == '1' for p in SUPPLIES.glob('*/online'))


def saved():
    return json.loads(STATE.read_text()) if STATE.exists() else None


def status():
    try:
        modes = read('charge_types')
        result = dict(supported='Standard' in modes and 'Custom' in modes,
                      mode=mode(), start=int(read('charge_control_start_threshold')),
                      end=int(read('charge_control_end_threshold')), target=0, recovery=False)
        state = saved()
        if state:
            result['target'] = state['target']
            service = subprocess.run(['/usr/bin/systemctl', 'is-active', UNIT],
                                     capture_output=True, text=True).stdout.strip()
            result['recovery'] = service not in ('active', 'activating', 'deactivating')
        return result
    except (OSError, ValueError, IndexError):
        return dict(supported=False, target=0, recovery=False)


def set_mode(value):
    (BATTERY / 'charge_types').write_text(value + '\n')
    if mode() != value:
        raise RuntimeError('Battery firmware did not accept ' + value + ' mode')


def set_start(value):
    (BATTERY / 'charge_control_start_threshold').write_text(str(value) + '\n')
    if int(read('charge_control_start_threshold')) != value:
        raise RuntimeError('Battery firmware did not accept the start threshold')


def restore():
    state = saved()
    if state:
        if state['mode'] != 'Custom':
            raise RuntimeError('Invalid saved battery mode')
        set_start(state['start'])
        set_mode(state['mode'])
        STATE.unlink()  # Keep recovery state if the firmware write fails.


def run(target):
    if target not in (80, 100):
        raise ValueError('Choose 80 or 100 percent')
    if mode() != 'Custom':
        raise RuntimeError('Select Custom battery care mode before topping up')
    if not plugged_in():
        raise RuntimeError('Connect the charger first')
    if int(read('capacity')) >= target:
        raise RuntimeError('Battery is already at the requested level')
    if target == 80 and (int(read('charge_control_end_threshold')) != 80 or int(read('capacity')) >= 75):
        raise RuntimeError('An 80% top-up needs an 80% cap and a battery below 75%')
    STATE.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    STATE.parent.chmod(0o755)  # The unprivileged bar reads recovery status.
    # Exclusive creation also rejects overlapping requests and stale recovery state.
    with STATE.open('x') as output:
        json.dump(dict(mode='Custom', start=int(read('charge_control_start_threshold')), target=target), output)
        output.flush()
        os.fsync(output.fileno())
    STATE.chmod(0o644)
    directory = os.open(STATE.parent, os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    try:
        # Keep the 80% ceiling in firmware: a userspace monitor cannot enforce
        # it while asleep. Dell requires a five-point start/stop gap.
        if target == 80:
            set_start(75)
        else:
            set_mode('Standard')
        # ponytail: five-second polling misses brief unplug/replug cycles;
        # use power-supply events if those must cancel a top-up too.
        while plugged_in() and int(read('capacity')) < target:
            time.sleep(5)
    finally:
        restore()


def main(args):
    if args == ['status']:
        print(json.dumps(status()))
        return
    if os.geteuid() != 0:
        raise RuntimeError('Administrator authorization is required')
    if len(args) == 2 and args[0] in ('start', 'run') and args[1] in ('80', '100'):
        if args[0] == 'run':
            run(int(args[1]))
            return
        if saved():
            raise RuntimeError('Restore battery care before starting another top-up')
        if mode() != 'Custom' or not plugged_in():
            raise RuntimeError('Connect the charger and select Custom battery care mode')
        if int(read('capacity')) >= int(args[1]):
            raise RuntimeError('Battery is already at the requested level')
        command = ['/usr/bin/python3', '-I', SCRIPT]
        cleanup = shlex.join(command + ['restore']).replace('%', '%%')
        subprocess.run(['/usr/bin/systemd-run', '--quiet', '--collect', '--unit=' + UNIT,
                        '--property=Type=exec', '--property=RuntimeMaxSec=12h',
                        '--property=TimeoutStopSec=30s', '--property=ExecStopPost=' + cleanup,
                        '--', *command, 'run', args[1]], check=True)
        for _ in range(50):
            if saved() and (mode() == 'Standard' if args[1] == '100' else int(read('charge_control_start_threshold')) == 75):
                return
            time.sleep(0.1)
        raise RuntimeError('Top-up did not start. Check journalctl -u ' + UNIT)
    elif args == ['stop']:
        stopped = subprocess.run(['/usr/bin/systemctl', 'stop', UNIT], capture_output=True, text=True)
        if stopped.returncode:
            active = subprocess.run(['/usr/bin/systemctl', 'is-active', UNIT], capture_output=True, text=True)
            if active.stdout.strip() not in ('inactive', 'failed', 'unknown'):
                raise RuntimeError(stopped.stderr.strip() or 'Could not stop top-up service')
        restore()
    elif args == ['restore']:
        restore()
    else:
        raise ValueError('Usage: battery-top-up status | start 80|100 | stop')


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
