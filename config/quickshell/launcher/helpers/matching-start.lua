#!/usr/bin/env luajit
-- Prepare pinned local Model2Vec files and a source-fingerprinted Rust worker.
local script = debug.getinfo(1, 'S').source:sub(2)
package.path = (script:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local U = require('runtime')
local bit = require('bit')
local C, ffi = U.C, U.ffi
ffi.cdef[[int flock(int, int); int access(const char *, int);]]
local ROOT = assert(U.realpath(script)):match('^(.*)/helpers/[^/]+$')
local M = {
  ENGINE_SOURCE = ROOT .. '/matching/engine',
  SHIPPED_ENGINE = ROOT .. '/matching/bin/keystroke-matching',
  MODELS = {
    small = {
      repo = 'minishlab/potion-base-2M', revision = '389b9f64be5aa4ae7a6bc6fe95ef20ce485ae5da',
      files = {
        ['config.json'] = 'b2a89173391ca774c2d7323090a993a9a1553faa5b40eb37bb7cec6685fbea47',
        ['tokenizer.json'] = 'e67e803f624fb4d67dea1c730d06e1067e1b14d830e2c2202569e3ef0f70bb50',
        ['model.safetensors'] = 'f95ffde02ad06f63ae38eb9d400038cd5ccaf8411ec3cb650c6025113f96cbb8',
      },
    },
    large = {
      repo = 'minishlab/potion-base-8M', revision = 'bf8b056651a2c21b8d2565580b8569da283cab23',
      files = {
        ['config.json'] = '2a6ac0e9aaa356a68a5688070db78fc3a464fefe85d2f06a1905ce3718687553',
        ['tokenizer.json'] = 'e67e803f624fb4d67dea1c730d06e1067e1b14d830e2c2202569e3ef0f70bb50',
        ['model.safetensors'] = 'f65d0f325faadc1e121c319e2faa41170d3fa07d8c89abd48ca5358d9a223de2',
      },
    },
  },
}
local function fail(message) error(message, 0) end
local function emit(value) io.stdout:write(U.encode(value), '\n'); io.stdout:flush() end
local function checked(argv, opts, message)
  local result = U.run(argv, opts)
  if result.code ~= 0 then fail(message or result.stderr) end
  return result.stdout
end
local function safe_owner(info)
  return info and info.uid == tonumber(C.getuid()) and bit.band(info.mode, 18) == 0
end
local function directory(path)
  C.mkdir(path, 448)
  local fd = C.open(path, bit.bor(65536, 131072, 524288)) -- DIRECTORY, NOFOLLOW, CLOEXEC
  if fd < 0 then fail('Unsafe matching cache directory: ' .. path) end
  local info = U.stat('/proc/self/fd/' .. fd)
  C.close(fd)
  if not safe_owner(info) then fail('Unsafe matching cache directory: ' .. path) end
  return path
end
local function subdir(parent, name) return directory(parent .. '/' .. name) end
function M.sha256(path)
  -- sha256sum prefixes escaped filenames with a backslash. Only read its digest.
  local digest = checked({'sha256sum', '--', path}, nil, 'Could not verify matching file'):match('^\\?([a-f0-9]+) ')
  assert(digest and #digest == 64, 'Invalid SHA-256 output')
  return digest
end
function M.verified(path, expected, legacy)
  local info = U.stat(path, not legacy)
  return info and info.type == 'file' and M.sha256(path) == expected or false
end
function M.which(name)
  for path in ((os.getenv('PATH') or '') .. ':'):gmatch('(.-):') do
    local file = (path == '' and '.' or path) .. '/' .. name
    local info = U.stat(file)
    if info and info.type == 'file' and C.access(file, 1) == 0 then return assert(U.realpath(path == '' and '.' or path)) .. '/' .. name end
  end
end

-- These fixed shell programs only receive literal positional arguments. The
-- runtime's process-group supervisor sends TERM on parent death, including
-- SIGKILL of the Lua process. Traps remove partial files while the inherited
-- installation lock still excludes the next setup. No Lua signal callbacks.
local MODEL_JOB = [[
set -eu
work=$1; destination=$2; digest=$3; operation=$4; source=$5
cleanup() { rm -rf -- "$work"; }
# Do not let an early shell exit disarm timeout's descendant supervision.
cancel() { trap '' TERM HUP INT; kill -TERM 0; cleanup; kill -KILL 0; }
trap cleanup EXIT
trap cancel TERM HUP INT
rm -rf -- "$work"
mkdir -m 700 -- "$work"
if [ "$operation" = download ]; then
  curl -q --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 60 --user-agent keystroke-matching --output "$work/file" "$source" &
else
  cp -- "$source" "$work/file" &
fi
wait "$!"
actual=$(sha256sum < "$work/file")
[ "${actual%% *}" = "$digest" ] || exit 65
chmod 600 -- "$work/file"
mv -fT -- "$work/file" "$destination"
]]
local function acquire(target, filename, digest, operation, source)
  local result = U.run({'sh', '-c', MODEL_JOB, 'matching-model', target .. '/.download-' .. filename,
    target .. '/' .. filename, digest, operation, source}, {timeout = 90})
  if result.code == 65 then fail('Downloaded matching model did not match its pinned digest') end
  if result.code ~= 0 then
    fail(operation == 'download' and 'Could not download the matching model; check your connection and retry' or 'Could not reuse the cached matching model')
  end
end
function M.prepare_model(name, data, offline)
  local spec = assert(M.MODELS[name], 'Invalid matching model')
  local models = subdir(data, 'models')
  local target = subdir(subdir(models, name), spec.revision)
  local snapshot = models .. '/models--' .. spec.repo:gsub('/', '--') .. '/snapshots/' .. spec.revision
  local missing = {}
  for filename, digest in pairs(spec.files) do
    if not M.verified(target .. '/' .. filename, digest) then
      if M.verified(snapshot .. '/' .. filename, digest, true) then
        acquire(target, filename, digest, 'copy', snapshot .. '/' .. filename)
      else
        missing[#missing + 1] = filename
      end
    end
  end
  if #missing > 0 and offline then
    fail('Smart Match is not set up. Choose Retry Smart Match to download the pinned model and runtime, or turn matching off.')
  end
  table.sort(missing)
  if #missing > 0 then emit({type = 'status', message = 'Downloading ' .. name .. ' matching model'}) end
  for _, filename in ipairs(missing) do
    acquire(target, filename, spec.files[filename], 'download',
      'https://huggingface.co/' .. spec.repo .. '/resolve/' .. spec.revision .. '/' .. filename)
  end
  return target
end
function M.engine_fingerprint()
  local files = {}
  for _, spec in ipairs({{M.ENGINE_SOURCE, 'Cargo.*'}, {M.ENGINE_SOURCE .. '/src', '*.rs'}}) do
    local output = checked({'find', spec[1], '-maxdepth', '1', '-type', 'f', '-name', spec[2], '-print0'}, nil, 'Matching engine source is missing')
    for path in output:gmatch('([^%z]+)%z') do files[#files + 1] = path end
  end
  table.sort(files)
  assert(#files >= 3, 'Matching engine source is missing')
  local parts = {}
  for _, path in ipairs(files) do
    parts[#parts + 1] = path:match('[^/]+$') .. '\0' .. assert(U.read(path)) .. '\0'
  end
  return checked({'sha256sum'}, {input = table.concat(parts)}, 'Could not fingerprint matching engine'):match('^([a-f0-9]+)'):sub(1, 16)
end
local function executable(path, owned)
  local info = U.stat(path, true)
  return info and info.type == 'file' and bit.band(info.mode, 18) == 0 and (not owned or safe_owner(info)) and C.access(path, 1) == 0
end
function M.shipped_engine(fingerprint)
  if not executable(M.SHIPPED_ENGINE) then return nil end
  local text = U.read(M.SHIPPED_ENGINE .. '.json')
  if not text then return nil end
  local ok, info = pcall(U.decode, text)
  if not ok or type(info) ~= 'table' then return nil end
  local machine = checked({'uname', '-m'}):gsub('%s+$', '')
  if info.machine ~= machine or info.source ~= fingerprint or type(info.sha256) ~= 'string' then return nil end
  if not M.verified(M.SHIPPED_ENGINE, info.sha256) then return nil end
  return M.SHIPPED_ENGINE
end
local BUILD_JOB = [[
set -eu
work=$1; destination=$2; source=$3; shift 3
cleanup() { rm -rf -- "$work"; rmdir -- "${destination%/*}" 2>/dev/null || :; }
cancel() { trap '' TERM HUP INT; kill -TERM 0; cleanup; kill -KILL 0; }
trap cleanup EXIT
trap cancel TERM HUP INT
rm -rf -- "$work"
mkdir -m 700 -- "$work"
"$@" build --release --locked --quiet --manifest-path "$source/Cargo.toml" --target-dir "$work/target" &
wait "$!"
install -m 755 -- "$work/target/release/keystroke-matching" "$work/keystroke-matching"
mv -fT -- "$work/keystroke-matching" "$destination"
]]
function M.prepare_engine(data, env, offline)
  local fingerprint = M.engine_fingerprint()
  local shipped = M.shipped_engine(fingerprint)
  if shipped then return shipped end
  local engines = subdir(data, 'engine')
  local built = engines .. '/' .. fingerprint .. '/keystroke-matching'
  local existing = U.stat(engines .. '/' .. fingerprint, true)
  if existing then
    directory(engines .. '/' .. fingerprint)
    if executable(built, true) then return built end
  end
  if offline then return nil end
  local cargo, mise = M.which('cargo'), nil
  -- A mise/rustup shim can exist without a selected toolchain. Probe only in
  -- explicit setup, never during offline startup.
  if cargo and U.run({cargo, '--version'}, {env = env, timeout = 15}).code ~= 0 then cargo = nil end
  if not cargo then mise = M.which('mise') end
  if not cargo and not mise then fail('Smart Match needs cargo (Rust) or mise; install one and choose Retry Smart Match in Keystroke Settings') end
  emit({type = 'status', message = 'Building matching engine'})
  subdir(engines, fingerprint)
  local command = {'sh', '-c', BUILD_JOB, 'matching-build', engines .. '/.build', built, M.ENGINE_SOURCE}
  local builder = cargo and {cargo} or {mise, 'exec', 'rust@stable', '--', 'cargo'}
  for _, arg in ipairs(builder) do command[#command + 1] = arg end
  local result = U.run(command, {env = env, timeout = 240})
  if result.stderr ~= '' then io.stderr:write(result.stderr) end
  if result.code ~= 0 or not executable(built, true) then fail('Could not build the matching engine; check your Rust toolchain and choose Retry Smart Match') end
  -- Only complete binaries are retained, with one cache entry per source.
  checked({'find', engines, '-mindepth', '1', '-maxdepth', '1', '-type', 'd', '!', '-name', fingerprint,
    '-exec', 'rm', '-rf', '--', '{}', '+'}, nil, 'Could not clean the matching build cache')
  return built
end
function M.main(argv)
  local model, offline, install_only, fingerprint = 'small', false, false, false
  local data = (os.getenv('XDG_DATA_HOME') or ((os.getenv('HOME') or '') .. '/.local/share')) .. '/keystroke/matching'
  local i = 1
  while i <= #argv do
    local arg = argv[i]
    if arg == '--offline' then offline = true
    elseif arg == '--install-only' then install_only = true
    elseif arg == '--engine-fingerprint' then fingerprint = true
    elseif arg == '--model' or arg == '--data-dir' or arg == '--engine' then
      i = i + 1
      local value = argv[i]
      if not value or value == '' or value:find('\0', 1, true) then fail('Missing value for ' .. arg) end
      if arg == '--model' then model = value
      elseif arg == '--data-dir' then data = value
      elseif value ~= 'auto' and value ~= 'native' then fail('Only the native matching engine is supported') end
    elseif arg == '--help' then
      print('matching-start.lua [--model small|large] [--offline] [--install-only] [--data-dir PATH] [--engine-fingerprint]')
      return
    else fail('Unknown argument: ' .. arg) end
    i = i + 1
  end
  if not M.MODELS[model] then fail('Invalid matching model') end
  if fingerprint then print(M.engine_fingerprint()); return end
  U.mkdir_p(data)
  directory(data)
  data = assert(U.realpath(data))
  local lock = C.open(data .. '/install.lock', bit.bor(2, 64, 131072), ffi.cast('int', 384))
  if lock < 0 then fail('Could not lock matching installation') end
  local ok, command = pcall(function()
    local info = U.stat('/proc/self/fd/' .. lock)
    if not safe_owner(info) or info.type ~= 'file' then fail('Unsafe matching installation lock') end
    if C.flock(lock, 2) ~= 0 then fail('Could not lock matching installation') end
    local model_dir = M.prepare_model(model, data, offline)
    local engine = M.prepare_engine(data, {}, offline)
    if not engine then fail('Smart Match runtime is not set up. Choose Retry Smart Match to build it, or turn matching off.') end
    local result = {engine, '--model-dir', model_dir, '--model', model}
    if install_only then result[#result + 1] = '--install-only' end
    return result
  end)
  C.close(lock)
  if not ok then fail(command) end
  U.exec(command)
end
if ... == 'matching-start' then return M end
local ok, err = pcall(M.main, arg)
if not ok then emit({type = 'error', message = tostring(err)}); os.exit(1) end
