#!/usr/bin/env python3
# Run with: python3 config/tmux/tests/hyperlinks.py
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

config = (Path(__file__).resolve().parents[1] / "tmux.conf").read_text()
binding = next(
    line for line in config.replace("\\\n", "").splitlines()
    if line.startswith("bind-key -n MouseDown1Pane ")
)
tokens = shlex.split(binding)
assert tokens[3:6] == ["if-shell", "-F", "#{mouse_hyperlink}"]
assert tokens[7] == "select-pane -t = ; send-keys -M"
command = shlex.split(tokens[6])
assert command[:2] == ["run-shell", "-b"]

urls = [
    "https://github.com/nicknisi/diffdad/pull/85",
    "https://example.com/?q=a b&quote='\"&literal=$(printf injected);#fragment",
]
for openers, expected, status in [
    (["xdg-open"], "xdg-open", 0),
    (["open"], "open", 0),
    (["xdg-open", "open"], "xdg-open", 0),
    (["xdg-open", "open"], "xdg-open", 42),
]:
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        log = work / "calls"
        for opener in openers:
            stub = work / opener
            stub.write_text(
                "#!/bin/sh\n"
                f"printf '%s\\0' '{opener}' \"$@\" >> \"$OPEN_LOG\"\n"
                f"exit {status if opener == expected else 0}\n"
            )
            stub.chmod(0o755)
        for url in urls:
            log.write_bytes(b"")
            # Model tmux's q: format with shell quoting, then run the real command.
            shell = command[2].replace("#{q:mouse_hyperlink}", shlex.quote(url))
            result = subprocess.run(
                ["/bin/sh", "-c", shell], capture_output=True, text=True,
                env={**os.environ, "PATH": directory, "OPEN_LOG": str(log)},
            )
            assert result.returncode == status, result.stderr
            assert log.read_bytes().split(b"\0") == [
                expected.encode(), url.encode(), b"",
            ], log.read_bytes()

print("Hyperlink checks passed: Linux, macOS fallback, URL arguments, opener failures.")
