#!/usr/bin/env python3
"""Opt-in live IPC check. Briefly switches windows, then restores original focus.

Run inside Hyprland with the updated shell loaded. This checks native global
shortcut dispatch, previews, cycling, cancellation and activation, not physical
key delivery. Hold/release Super and Escape still need an on-keyboard check.
"""
import json
import subprocess
import time


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def inspect():
    return json.loads(run("qs", "ipc", "call", "windowSwitcher", "inspect"))


def signal(name):
    run("hyprctl", "dispatch", f'hl.dsp.global("quickshell:window-switcher-{name}")')


def active():
    return json.loads(run("hyprctl", "activewindow", "-j")).get("address", "").removeprefix("0x")


def wait(read, predicate):
    for _ in range(60):
        result = read()
        if predicate(result):
            return result
        time.sleep(0.05)
    raise AssertionError(result)


def cancel():
    run("qs", "ipc", "call", "windowSwitcher", "cancel")


assert not inspect()["opened"], "Close the switcher before running the live test"
original = active()
assert original, "Focus a window before running this test"
try:
    signal("next")
    first = wait(inspect, lambda s: s["opened"] and any(p["hasContent"] for p in s["previews"]))
    count = len(first["ids"])
    assert count >= 2, "Open at least two windows for the live test"
    assert first["ids"][0] == original
    assert first["selected"] == 1, first
    signal("next")
    forward = wait(inspect, lambda s: s["selected"] == 2 % count)
    assert forward["ids"] == first["ids"], "Cycle must not reshuffle the snapshot"
    signal("previous")
    wait(inspect, lambda s: s["selected"] == 1)
    cancel()
    wait(inspect, lambda s: not s["opened"])
    wait(active, lambda address: address == original)
    signal("next")
    selected = wait(inspect, lambda s: s["opened"])
    target = selected["ids"][selected["selected"]]
    signal("commit")
    wait(inspect, lambda s: not s["opened"] and not s["ids"])
    wait(active, lambda address: address == target)
    print("WINDOW_SWITCHER_LIVE_PASS")
finally:
    cancel()
    if active() != original:
        run("qs", "ipc", "call", "windowSwitcher", "step", "1")
        state = wait(inspect, lambda s: s["opened"])
        if original in state["ids"]:
            delta = state["ids"].index(original) - state["selected"]
            run("qs", "ipc", "call", "windowSwitcher", "step", str(delta))
            run("qs", "ipc", "call", "windowSwitcher", "commit")
            wait(active, lambda address: address == original)
        else:
            cancel()
