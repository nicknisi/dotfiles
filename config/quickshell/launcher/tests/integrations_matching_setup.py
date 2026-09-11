#!/usr/bin/env python3
"""Lua setup regression checks with synthetic files and fake tools, never models."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
helper = root / 'helpers/matching-start.lua'


def wait_for(check, message, seconds=6):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if check():
            return
        time.sleep(.025)
    raise AssertionError(message)


def alive(pid):
    try:
        return Path(f'/proc/{pid}/stat').read_text().split(') ')[1][0] != 'Z'
    except FileNotFoundError:
        return False


with tempfile.TemporaryDirectory(prefix='launcher-matching-setup-') as temp:
    work = Path(temp)
    tools = work / 'tools'
    tools.mkdir()
    env = dict(os.environ, HOME=str(work), XDG_DATA_HOME=str(work), PATH=str(tools) + ':/usr/bin:/bin', FIXTURE=str(work))
    prefix = f"package.path={json.dumps(str(root / 'helpers') + '/?.lua;')}..package.path; local U=require('runtime'); local M=require('matching-start'); "

    def lua(code, *, extra=None, timeout=10):
        result = subprocess.run(['luajit', '-e', prefix + code], env=dict(env, **(extra or {})), text=True, capture_output=True, timeout=timeout)
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    def tool(name, body):
        path = tools / name
        path.write_text('#!/bin/sh\nset -eu\n' + body)
        path.chmod(0o755)

    tool('curl', 'echo unexpected-download >> "$FIXTURE/network"\nexit 99\n')
    tool('mise', 'echo unexpected-tool-install >> "$FIXTURE/network"\nexit 99\n')
    result = subprocess.run(['luajit', str(helper), '--offline', '--data-dir', str(work / 'empty')], env=env, text=True, capture_output=True, timeout=5)
    assert result.returncode == 1 and 'Retry Smart Match' in result.stdout, result
    assert not list((work / 'empty').rglob('*.safetensors')) and not (work / 'network').exists()
    assert not (root / 'matching/bin/keystroke-matching').exists(), 'Checkout intentionally omits the prebuilt binary'
    source = root / 'matching/engine'
    digest = hashlib.sha256()
    for path in sorted(list(source.glob('Cargo.*')) + list((source / 'src').glob('*.rs'))):
        digest.update(path.name.encode() + b'\0' + path.read_bytes() + b'\0')
    fingerprint = digest.hexdigest()[:16]
    lua(f"assert(M.engine_fingerprint()=={json.dumps(fingerprint)}); assert(M.shipped_engine(M.engine_fingerprint())==nil)")

    # Keep module-level cache/digest assertions without importing production Python.
    data = work / 'data'
    data.mkdir()
    content = b'synthetic fixture, not model weights'
    expected = hashlib.sha256(content).hexdigest()
    unusual = data / "literal ' name\\with\nnewline"
    unusual.write_bytes(content)
    lua(f'assert(M.sha256({json.dumps(str(unusual))})=={json.dumps(expected)})')
    fixture = "M.MODELS.small={repo='fixture/repo',revision='fixed',files={['config.json']='%s'}}; local data=%s; " % (expected, json.dumps(str(data)))
    lua(fixture + "local ok,e=pcall(M.prepare_model,'small',data,true); assert(not ok and e:find('not set up')); assert(M.prepare_engine(data,{},true)==nil)")
    cached = data / 'models/small/fixed/config.json'
    cached.write_bytes(content)
    lua(fixture + "assert(M.prepare_model('small',data,true)==data..'/models/small/fixed')")
    cached.write_bytes(b'corrupt')
    lua(fixture + "assert(not pcall(M.prepare_model,'small',data,true))")
    legacy = data / 'models/models--fixture--repo/snapshots/fixed/config.json'
    legacy.parent.mkdir(parents=True)
    blob = data / 'models/blob'
    blob.write_bytes(content)
    legacy.symlink_to(blob)
    lua(fixture + "assert(M.prepare_model('small',data,true)==data..'/models/small/fixed')")
    assert cached.read_bytes() == content and not cached.is_symlink()
    legacy.unlink()
    cached.write_bytes(b'keep until verified replacement')
    tool('curl', '''printf '%s\\n' "$@" > "$FIXTURE/curl-argv"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then output=$2; shift; fi
  shift
done
printf '%s' "${DOWNLOAD_CONTENT:-corrupt}" > "$output"
''')
    lua(fixture + "local ok,e=pcall(M.prepare_model,'small',data,false); assert(not ok and e:find('pinned digest'))")
    assert cached.read_bytes() == b'keep until verified replacement'
    assert not list(cached.parent.glob('.download-*'))
    lua(fixture + "M.prepare_model('small',data,false)", extra={'DOWNLOAD_CONTENT': content.decode()})
    args = (work / 'curl-argv').read_text().splitlines()
    assert '--proto' in args and '=https' in args and '--proto-redir' in args and '-q' in args
    assert args[-1] == 'https://huggingface.co/fixture/repo/resolve/fixed/config.json'
    assert cached.read_bytes() == content

    # A cache symlink must not redirect an atomic model replacement or lock write.
    outside = work / 'outside'
    outside.write_bytes(b'outside')
    cached.unlink()
    cached.symlink_to(outside)
    lua(fixture + "M.prepare_model('small',data,false)", extra={'DOWNLOAD_CONTENT': content.decode()})
    assert not cached.is_symlink() and outside.read_bytes() == b'outside'
    (data / 'install.lock').symlink_to(outside)
    result = subprocess.run(['luajit', str(helper), '--offline', '--data-dir', str(data)], env=env, text=True, capture_output=True, timeout=5)
    assert result.returncode == 1 and outside.read_bytes() == b'outside'
    (data / 'install.lock').unlink()
    cached.parent.rename(cached.parent.with_name('real'))
    cached.parent.symlink_to(cached.parent.with_name('real'), target_is_directory=True)
    lua(fixture + "local ok,e=pcall(M.prepare_model,'small',data,true); assert(not ok and e:find('Unsafe'))")
    cached.parent.unlink()
    cached.parent.with_name('real').rename(cached.parent)

    # A fake compiler exercises the actual guarded build, lock, and atomic rename.
    tool('cargo', '''if [ "$1" = --version ]; then
  if [ "${BUILD_MODE:-}" = shim ]; then exit 1; fi
  echo 'cargo fixture'; exit 0
fi
printf '%s\\n' "$@" > "$FIXTURE/cargo-argv"
echo build >> "$FIXTURE/builds"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --target-dir ]; then target=$2; shift; fi
  shift
done
mkdir -p "$target/release"
printf 'partial' > "$target/release/keystroke-matching"
if [ "${BUILD_MODE:-}" = fail ]; then exit 42; fi
if [ "${BUILD_MODE:-}" = cancel ]; then
  trap '' TERM INT HUP
  sh -c 'trap "" TERM INT HUP; echo $$ >> "$FIXTURE/pids"; sleep 30 & echo $! >> "$FIXTURE/pids"; wait' &
  echo $$ >> "$FIXTURE/pids"
  wait
fi
sleep .15
cat > "$target/release/keystroke-matching" <<'ENGINE'
#!/bin/sh
printf '%s\\n' '{"type":"installed","model":"small"}'
ENGINE
''')
    # Shipped engines require source, architecture AND the binary digest.
    shipped = work / 'prebuilt'
    shipped.write_text('#!/bin/sh\nexit 0\n')
    shipped.chmod(0o755)
    manifest = dict(machine=os.uname().machine, source=fingerprint, sha256=hashlib.sha256(shipped.read_bytes()).hexdigest())
    shipped.with_suffix('.json').write_text(json.dumps(manifest))
    shipped_code = f'M.SHIPPED_ENGINE={json.dumps(str(shipped))}; '
    lua(shipped_code + 'assert(M.shipped_engine(M.engine_fingerprint())==M.SHIPPED_ENGINE)')
    for key in ('source', 'machine', 'sha256'):
        shipped.with_suffix('.json').write_text(json.dumps(dict(manifest, **{key: 'wrong'})))
        lua(shipped_code + 'assert(M.shipped_engine(M.engine_fingerprint())==nil)')
    shipped.with_suffix('.json').write_text('null')
    lua(shipped_code + 'assert(M.shipped_engine(M.engine_fingerprint())==nil)')

    lua(fixture + "local engine=M.prepare_engine(data,{},false); assert(engine); assert(M.prepare_engine(data,{},true)==engine)")
    built = data / 'engine' / fingerprint / 'keystroke-matching'
    assert built.is_file() and os.access(built, os.X_OK)
    args = (work / 'cargo-argv').read_text().splitlines()
    assert all(flag in args for flag in ('build', '--release', '--locked', '--target-dir'))
    assert (work / 'builds').read_text().count('build') == 1 and not (data / 'engine/.build').exists()
    lua(fixture + "M.engine_fingerprint=function() return 'changed-source' end; assert(M.prepare_engine(data,{},true)==nil); M.prepare_engine(data,{},false)")
    assert not built.exists() and (data / 'engine/changed-source/keystroke-matching').exists()
    lua(fixture + "local ok,e=pcall(M.prepare_engine,data,{},false); assert(not ok and e:find('Could not build'))", extra={'BUILD_MODE': 'fail'})
    assert not (data / 'engine/.build').exists() and not built.exists()
    lua(fixture + "M.which=function() return nil end; assert(M.prepare_engine(data,{},true)==nil); local ok,e=pcall(M.prepare_engine,data,{},false); assert(not ok and e:find('cargo %(Rust%) or mise'))")
    assert not (data / 'runtime').exists(), 'No Python fallback after native failure'

    # Explicit online setup may use mise only when cargo is unavailable.
    tool('mise', 'printf "%s\\n" "$@" > "$FIXTURE/mise-argv"\nshift 4\nexec "$FIXTURE/tools/cargo" "$@"\n')
    lua(fixture + "M.prepare_engine(data,{},false)", extra={'BUILD_MODE': 'shim'})
    assert (work / 'mise-argv').read_text().splitlines()[:4] == ['exec', 'rust@stable', '--', 'cargo']

    # The CLI still replaces itself with the native worker after releasing its lock.
    wrapper = work / 'start.lua'
    wrapper.write_text(prefix + fixture + "M.main(arg)\n")
    for signum in (signal.SIGTERM, signal.SIGKILL):
        built.unlink(missing_ok=True)
        (work / 'pids').unlink(missing_ok=True)
        process = subprocess.Popen(['luajit', str(wrapper), '--data-dir', str(data), '--install-only'], env=dict(env, BUILD_MODE='cancel'), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            wait_for(lambda: (work / 'pids').exists() and len((work / 'pids').read_text().splitlines()) == 3, 'fake compiler did not start descendants')
            pids = [int(line) for line in (work / 'pids').read_text().splitlines()]
            process.send_signal(signum)
            process.communicate(timeout=5)
            wait_for(lambda: not any(alive(pid) for pid in pids), 'cancelled build leaked descendants')
            wait_for(lambda: not (data / 'engine/.build').exists(), 'cancelled build left incomplete objects')
            assert not built.exists()
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    before = (work / 'builds').read_text().count('build')
    processes = [subprocess.Popen(['luajit', str(wrapper), '--data-dir', str(data), '--install-only'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
    for process in processes:
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == 0, stdout + stderr
        assert json.loads(stdout.splitlines()[-1]) == {'type': 'installed', 'model': 'small'}, stdout
    assert (work / 'builds').read_text().count('build') == before + 1, 'setup lock did not serialize builders'
    assert not list(data.rglob('.build')) and not list(data.rglob('.download-*'))
    assert not (work / 'network').exists(), 'offline startup attempted provisioning'
    print('PASS Lua matching setup: offline/cache/digests, legacy cache, safe atomic files, source cache, native/mise builds, failures, locks and TERM/KILL descendant cleanup')
