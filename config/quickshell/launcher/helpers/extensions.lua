#!/usr/bin/env luajit
-- Native Keystroke API 1 extension manager. No downloaded scripts are executed.
local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*)/') or '.'
package.path = here .. '/?.lua;' .. package.path
local U = require('runtime')
local ffi, C = U.ffi, U.C
local bit = require('bit')

-- Private aliases avoid coupling these descriptor-relative operations to the
-- shared runtime's declarations. Linux dirent64 has the same layout on LP64 ABIs.
ffi.cdef[[
struct ext_dirent { uint64_t ino; int64_t off; unsigned short reclen; unsigned char type; char name[256]; };
void *ext_fdopendir(int fd) __asm__("fdopendir");
struct ext_dirent *ext_readdir(void *dir) __asm__("readdir64");
int ext_closedir(void *dir) __asm__("closedir");
int ext_openat(int fd, const char *path, int flags, ...) __asm__("openat");
int ext_close(int fd) __asm__("close");
int ext_flock(int fd, int operation) __asm__("flock");
int ext_poll(void *fds, unsigned long count, int timeout) __asm__("poll");
int ext_unlinkat(int fd, const char *path, int flags) __asm__("unlinkat");
int ext_renameat(int oldfd, const char *oldpath, int newfd, const char *newpath) __asm__("renameat");
unsigned int ext_getuid(void) __asm__("getuid");
char *ext_strerror(int err) __asm__("strerror");
extern char **ext_environ __asm__("environ");
]]
local E = { TIMEOUT = 60 }
local DIRECTORY, NOFOLLOW, CLOEXEC = 65536, 131072, 524288
local RDWR, CREAT, NONBLOCK, REMOVEDIR = 2, 64, 2048, 512
local MAX_JSON = 1024 * 1024
local function fail(message) error(message, 0) end
local function system_error(message) fail(message .. ': ' .. ffi.string(C.ext_strerror(ffi.errno()))) end
local function trim(s) return s:match('^%s*(.-)%s*$') end
local unicode_spaces = { '\194\133', '\194\160', '\225\154\128', '\226\128\168', '\226\128\169', '\226\128\175', '\226\129\159', '\227\128\128' }
for n = 128, 138 do unicode_spaces[#unicode_spaces + 1] = '\226\128' .. string.char(n) end
local function blank_name(s)
    s = s:gsub('[%s\28-\31]', '')
    for _, space in ipairs(unicode_spaces) do s = s:gsub(space, '') end
    return s == ''
end
local function is_object(t) return type(t) == 'table' and getmetatable(t) and getmetatable(t).__jsontype == 'object' end
local function is_array(t) return type(t) == 'table' and getmetatable(t) and getmetatable(t).__jsontype == 'array' end
local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
local function split(s, separator)
    local out, start = {}, 1
    while true do
        local at = s:find(separator, start, true)
        if not at then out[#out + 1] = s:sub(start); return out end
        out[#out + 1], start = s:sub(start, at - 1), at + #separator
    end
end

function E.identity(value)
    if type(value) ~= 'string' or #value > 120 or not value:find('.', 1, true) then
        fail('Extension ID must be a dotted identifier without traversal')
    end
    for _, part in ipairs(split(value, '.')) do
        if not part:match('^[a-z0-9][a-z0-9_-]*$') then fail('Extension ID must be a dotted identifier without traversal') end
    end
    return value
end

local function absolute(value)
    if type(value) ~= 'string' or value:sub(1, 1) ~= '/' or value:find('\0', 1, true) then
        fail('Expected an absolute path without traversal')
    end
    local parts = {}
    for part in value:gmatch('[^/]+') do
        if part == '..' then fail('Expected an absolute path without traversal') end
        if part ~= '.' then parts[#parts + 1] = part end
    end
    return '/' .. table.concat(parts, '/')
end
local function no_links(path)
    path = absolute(path)
    local current = ''
    for part in path:gmatch('[^/]+') do
        current = current .. '/' .. part
        local st = U.stat(current, true)
        if st and st.type == 'link' then fail('Symlink refused: ' .. current) end
    end
    return path
end
local function open_dir(path)
    path = absolute(path)
    local fd = C.ext_openat(-100, '/', bit.bor(DIRECTORY, NOFOLLOW, CLOEXEC))
    if fd < 0 then system_error('Cannot open /') end
    for part in path:gmatch('[^/]+') do
        local nextfd = C.ext_openat(fd, part, bit.bor(DIRECTORY, NOFOLLOW, CLOEXEC))
        local err = ffi.errno()
        C.ext_close(fd)
        if nextfd < 0 then ffi.errno(err); system_error('Cannot open directory ' .. path) end
        fd = nextfd
    end
    return fd
end
local function fd_path(fd, name) return '/proc/self/fd/' .. fd .. (name and '/' .. name or '') end
local function with_fd(fd, fn)
    local ok, result = pcall(fn, fd)
    C.ext_close(fd)
    if not ok then fail(result) end
    return result
end
local function private_dir(path)
    path = no_links(path)
    U.mkdir_p(path, 448)
    with_fd(open_dir(path), function(fd)
        local st = assert(U.stat(fd_path(fd)))
        if st.type ~= 'directory' or st.uid ~= tonumber(C.ext_getuid()) or bit.band(st.mode, 18) ~= 0 then
            fail('Directory must be owned by you and not writable by others: ' .. path)
        end
    end)
    return path
end
local function xdg(name, fallback)
    local value = os.getenv(name)
    return absolute(value and value ~= '' and value or assert(os.getenv('HOME'), 'HOME is required') .. '/' .. fallback)
end
local function managed_dir() return xdg('XDG_DATA_HOME', '.local/share') .. '/keystroke/extensions' end
local function jobs_dir()
    local runtime = os.getenv('XDG_RUNTIME_DIR')
    return runtime and runtime ~= '' and absolute(runtime) .. '/keystroke/extensions'
        or xdg('XDG_STATE_HOME', '.local/state') .. '/keystroke/extensions-jobs'
end
local function lock(directory, fn, wait_for_scan)
    private_dir(directory)
    return with_fd(open_dir(directory), function(dfd)
        local fd = C.ext_openat(dfd, '.lock', bit.bor(RDWR, CREAT, NOFOLLOW, NONBLOCK, CLOEXEC), ffi.new('int', 384))
        if fd < 0 then system_error('Cannot open lock file') end
        return with_fd(fd, function()
            local st = assert(U.stat(fd_path(fd)))
            if st.type ~= 'file' or st.uid ~= tonumber(C.ext_getuid()) then fail('Unsafe lock file') end
            -- Enabling code triggers a registry scan and a follow-up job at once.
            -- Jobs briefly wait for that scan, but scans and competing jobs keep
            -- their nonblocking locks. Never wait through a long network job.
            for attempt = 1, wait_for_scan and 100 or 1 do
                if C.ext_flock(fd, 6) == 0 then return fn(dfd) end
                if ffi.errno() ~= 11 then system_error('Cannot lock extension directory') end
                if not wait_for_scan or attempt == 100 then break end
                C.ext_poll(nil, 0, 10)
            end
            fail('Another extension operation is still running')
        end)
    end)
end
local function names_fd(fd)
    local copy = C.ext_openat(fd, '.', bit.bor(DIRECTORY, NOFOLLOW, CLOEXEC))
    if copy < 0 then system_error('Cannot read directory') end
    local dir = C.ext_fdopendir(copy)
    if dir == nil then C.ext_close(copy); system_error('Cannot read directory') end
    local names = {}
    while true do
        ffi.errno(0)
        local entry = C.ext_readdir(dir)
        if entry == nil then
            local err = ffi.errno()
            C.ext_closedir(dir)
            if err ~= 0 then ffi.errno(err); system_error('Cannot read directory') end
            table.sort(names)
            return names
        end
        local name = ffi.string(entry.name)
        if name ~= '.' and name ~= '..' then names[#names + 1] = name end
    end
end
local function regular(path)
    path = no_links(path)
    local st, err = U.stat(path)
    if not st or st.type ~= 'file' then fail('Expected a regular file: ' .. path .. (err and ': ' .. err or '')) end
    return path
end
local function read_json(path)
    regular(path)
    if assert(U.stat(path)).size > MAX_JSON then fail('JSON file is too large') end
    local bytes = assert(U.read(path))
    if #bytes > MAX_JSON then fail('JSON file is too large') end
    return U.decode(bytes)
end
local function tree_safe(root)
    no_links(root)
    local function walk(fd, path)
        for _, name in ipairs(names_fd(fd)) do
            local st = assert(U.stat(fd_path(fd, name), true))
            if st.type == 'directory' then
                local child = C.ext_openat(fd, name, bit.bor(DIRECTORY, NOFOLLOW, CLOEXEC))
                if child < 0 then system_error('Cannot open directory ' .. path .. '/' .. name) end
                with_fd(child, function(childfd) walk(childfd, path .. '/' .. name) end)
            elseif st.type ~= 'file' then
                fail('Symlinks and special files are not supported: ' .. path .. '/' .. name)
            end
        end
    end
    with_fd(open_dir(root), function(fd) walk(fd, root) end)
end
function E.manifest(root, expected)
    root = absolute(root)
    tree_safe(root)
    local m = read_json(root .. '/manifest.json')
    if not is_object(m) then fail('manifest.json must be an object') end
    local mid = E.identity(m.id)
    if expected ~= nil and mid ~= expected then fail('Manifest identity does not match ' .. expected) end
    local marker = m['x-keystroke']
    if not is_object(marker) or marker.apiVersion ~= 1 then fail('Manifest must declare x-keystroke provider API 1') end
    if type(m.name) ~= 'string' or blank_name(m.name) then fail('Manifest must declare a name') end
    local service = false
    if is_array(m.kinds) then for _, kind in ipairs(m.kinds) do if kind == 'service' then service = true end end end
    if not service then fail('Manifest must declare kind "service"') end
    local points = m.entryPoints
    if not is_object(points) or not points.service or points.service == U.null then fail('Manifest must declare entryPoints.service') end
    for _, ep in pairs(points) do
        if type(ep) ~= 'string' or ep == '' then fail('Entry points must be relative paths inside the extension') end
        for _, part in ipairs(split(ep, '/')) do
            if not part:match('^[A-Za-z0-9_][A-Za-z0-9_.-]*$') then fail('Entry points must be relative paths inside the extension') end
        end
        regular(root .. '/' .. ep)
    end
    if points.service:sub(-4) ~= '.qml' then fail('Service entry point must be a QML file') end
    for key in pairs(m) do if key:sub(1, 2) == '__' then m[key] = nil end end
    return m
end

local function url_parts(value)
    if type(value) ~= 'string' or value == '' or #value > 2048 or value:sub(1, 1) == '-' or value:find('[%s%c\\]') then fail('Unsafe repository URL') end
    for _, space in ipairs(unicode_spaces) do if value:find(space, 1, true) then fail('Unsafe repository URL') end end
    if value:find('[?#]') then fail('Repository URLs cannot include credentials, queries or fragments') end
    local scheme, host, path = value:match('^([A-Za-z]+)://([^/]*)(/.*)$')
    if not scheme then fail('Use https or an explicit file:/// repository for local development') end
    scheme = scheme:lower()
    if host:find('@', 1, true) then fail('Repository URLs cannot include credentials, queries or fragments') end
    if scheme == 'https' then
        local hostname, port = host:match('^([^:]+):([0-9]+)$')
        hostname = hostname or host
        if not hostname:match('^[A-Za-z0-9][A-Za-z0-9.-]*$') or path == '/' or (port and (#port > 5 or tonumber(port) < 1 or tonumber(port) > 65535)) then
            fail('Expected an https repository URL')
        end
    elseif scheme ~= 'file' or host ~= '' or value:sub(1, 8) ~= 'file:///' then
        fail('Use https or an explicit file:/// repository for local development')
    end
    local decoded = path:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
    if decoded:find('[%c\\]') then fail('Repository path traversal refused') end
    for _, part in ipairs(split(decoded, '/')) do
        if part == '.' or part == '..' then fail('Repository path traversal refused') end
    end
    return scheme, decoded
end

function E.git(args, opts)
    opts = opts or {}
    -- U.run accepts environment overrides. env -u removes every inherited GIT_*
    -- variable before applying the fixed environment, including indexed config.
    local command = { 'env' }
    local env = C.ext_environ
    local i = 0
    while env[i] ~= nil do
        local name = ffi.string(env[i]):match('^(GIT_[^=]+)=')
        if name then command[#command + 1] = '-u'; command[#command + 1] = name end
        i = i + 1
    end
    local fixed = {
        '--', 'GIT_CONFIG_NOSYSTEM=1', 'GIT_CONFIG_SYSTEM=/dev/null', 'GIT_CONFIG_GLOBAL=/dev/null',
        'GIT_TERMINAL_PROMPT=0', 'GIT_NO_REPLACE_OBJECTS=1', 'GIT_ATTR_NOSYSTEM=1', 'GIT_CEILING_DIRECTORIES=/',
        'git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false',
        '-c', 'core.attributesFile=/dev/null', '-c', 'credential.helper=',
        '-c', 'protocol.allow=never', '-c', 'protocol.https.allow=always',
        '-c', 'protocol.file.allow=always', '-c', 'http.followRedirects=false', '-c', 'submodule.recurse=false',
    }
    for _, value in ipairs(fixed) do command[#command + 1] = value end
    for _, value in ipairs(args) do command[#command + 1] = value end
    local result = U.run(command, { cwd = opts.cwd or '/', timeout = E.TIMEOUT })
    if result.code == 124 or result.code == 137 then fail('Git operation timed out') end
    local accepted = false
    for _, code in ipairs(opts.accepted or { 0 }) do if result.code == code then accepted = true end end
    if not accepted then
        local message = trim(result.stderr)
        fail((message ~= '' and message or 'Git operation failed'):sub(-2000))
    end
    -- NUL-delimited tree/index output must retain whitespace in filenames.
    return result.stdout, result.code
end
local function git_text(args, opts)
    local out, code = E.git(args, opts)
    return trim(out), code
end
function E.git_config_safe(gd)
    tree_safe(gd)
    for _, name in ipairs({ 'objects/info/alternates', 'objects/info/http-alternates', 'info/grafts', 'commondir' }) do
        if U.stat(gd .. '/' .. name, true) then fail('External git object stores and grafts are not supported') end
    end
    -- Ask Git to parse only this file, without includes or repository discovery.
    -- No command that can execute hooks/helpers is run against unvalidated config.
    local raw = E.git({ 'config', '--no-includes', '--file', regular(gd .. '/config'), '--null', '--list' })
    local config = {}
    local core = { repositoryformatversion = true, bare = true, filemode = true, logallrefupdates = true, ignorecase = true, precomposeunicode = true }
    for _, record in ipairs(split(raw, '\0')) do
        if record ~= '' then
            local key, value = record:match('^([^\n]+)\n(.*)$')
            if not key or config[key] ~= nil then fail('Unsupported git config: duplicate or valueless key') end
            local section, option = key:match('^(.*)%.([^.]+)$')
            local ok = false
            if section == 'core' and core[option] then
                ok = option == 'repositoryformatversion' and value == '0'
                    or option ~= 'repositoryformatversion' and (value:lower() == 'true' or value:lower() == 'false')
            elseif section == 'remote.origin' then
                ok = option == 'url' or option == 'fetch'
            elseif section and section:match('^branch%.[A-Za-z0-9_./-]+$') then
                ok = option == 'remote' and value == 'origin' or option == 'merge' and value:sub(1, 11) == 'refs/heads/'
            elseif section == 'user' then
                ok = option == 'name' or option == 'email'
            end
            if not ok then fail('Unsupported git config: ' .. key) end
            config[key] = value
        end
    end
    return config
end
function E.repository_url(value)
    local scheme, path = url_parts(value)
    if scheme == 'file' then
        local localdir = no_links(path)
        local st = U.stat(localdir)
        if not st or st.type ~= 'directory' then fail('Local repository does not exist') end
        E.git_config_safe(U.stat(localdir .. '/.git', true) and localdir .. '/.git' or localdir)
    end
    return value
end
local function checkout(root)
    E.git_config_safe(root .. '/.git')
    local files = E.git({ 'ls-tree', '-rz', 'HEAD' }, { cwd = root })
    for _, record in ipairs(split(files, '\0')) do
        local mode = record:match('^(%S+) ')
        if record ~= '' and mode ~= '100644' and mode ~= '100755' then fail('Symlinks and submodules are not supported') end
    end
    E.git({ 'checkout', '--quiet', '--force', 'HEAD' }, { cwd = root })
end
local function clone(url, stage)
    E.git({ 'clone', '--quiet', '--no-checkout', '--no-hardlinks', '--no-recurse-submodules', '--template=', '--', url, stage })
    checkout(stage)
end
local function target(root, mid)
    local path = no_links(root .. '/' .. E.identity(mid))
    local st = U.stat(path)
    if not st or st.type ~= 'directory' then fail('Extension is not installed: ' .. mid) end
    return path
end
local function clean(root)
    E.git_config_safe(root .. '/.git')
    local status = git_text({ 'status', '--porcelain=v1', '--untracked-files=all', '--ignored' }, { cwd = root })
    if status ~= '' then fail('Checkout has local edits or untracked/ignored files; update refused') end
    local head = git_text({ 'rev-parse', 'HEAD' }, { cwd = root })
    local entries = E.git({ 'ls-files', '--stage', '-z' }, { cwd = root })
    for _, record in ipairs(split(entries, '\0')) do
        if record ~= '' then
            local mode, blob, stage, name = record:match('^(%d+) (%x+) (%d+)\t(.*)$')
            if (mode ~= '100644' and mode ~= '100755') or stage ~= '0' then fail('Unsupported index entry') end
            local path = regular(root .. '/' .. name)
            local actual = git_text({ 'hash-object', '--no-filters', '--', path }, { cwd = root })
            if actual ~= blob or (bit.band(assert(U.stat(path)).mode, 64) ~= 0) ~= (mode == '100755') then
                fail('Checkout has local edits; update refused')
            end
        end
    end
    return head
end
local function origin(root)
    local config = E.git_config_safe(root .. '/.git')
    return E.repository_url(config['remote.origin.url'] or '')
end
local function unlink_at(fd, name, missing)
    if C.ext_unlinkat(fd, name, 0) ~= 0 and not (missing and ffi.errno() == 2) then system_error('Cannot remove ' .. name) end
end
local function remove_at(fd, name)
    local st = U.stat(fd_path(fd, name), true)
    if not st then return end
    if st.type == 'directory' then
        local child = C.ext_openat(fd, name, bit.bor(DIRECTORY, NOFOLLOW, CLOEXEC))
        if child < 0 then system_error('Cannot open cleanup directory') end
        with_fd(child, function(childfd)
            for _, entry in ipairs(names_fd(childfd)) do remove_at(childfd, entry) end
        end)
        if C.ext_unlinkat(fd, name, REMOVEDIR) ~= 0 then system_error('Cannot remove directory ' .. name) end
    else
        unlink_at(fd, name)
    end
end
local function temporary(root, prefix, fn)
    local temp = U.tmpdir(root, prefix)
    local ok, result = pcall(fn, temp)
    local cleaned, err = pcall(function()
        with_fd(open_dir(root), function(fd) remove_at(fd, temp:match('([^/]+)$')) end)
    end)
    if not ok then fail(result) end
    if not cleaned then fail(err) end
    return result
end
local function rename(old, new)
    local oldparent, oldname = old:match('^(.*)/([^/]+)$')
    local newparent, newname = new:match('^(.*)/([^/]+)$')
    with_fd(open_dir(oldparent), function(oldfd)
        with_fd(open_dir(newparent), function(newfd)
            if C.ext_renameat(oldfd, oldname, newfd, newname) ~= 0 then system_error('Cannot rename ' .. old) end
        end)
    end)
end
local function install(root, url, expected, emit)
    url = E.repository_url(url)
    if expected ~= '' then E.identity(expected) end
    local m, dest
    temporary(root, '.stage-', function(temp)
        local stage = temp .. '/checkout'
        clone(url, stage)
        m = E.manifest(stage, expected ~= '' and expected or nil)
        dest = root .. '/' .. m.id
        if U.stat(dest, true) then fail('Extension is already installed: ' .. m.id) end
        rename(stage, dest)
    end)
    emit('Added ' .. m.id .. ' into ' .. dest .. '\n')
end
local function update(root, mid, emit)
    local dest = target(root, mid)
    E.manifest(dest, mid)
    local head, url = clean(dest), origin(dest)
    temporary(root, '.stage-', function(temp)
        local stage = temp .. '/checkout'
        clone(url, stage)
        E.manifest(stage, mid)
        local _, code = E.git({ 'merge-base', '--is-ancestor', head, 'HEAD' }, { cwd = stage, accepted = { 0, 1, 128 } })
        if code ~= 0 then fail('Update is not a fast-forward; local commits are preserved') end
        if clean(dest) ~= head then fail('Checkout changed during update') end
        local backup = temp .. '/previous'
        rename(dest, backup)
        local ok, err = pcall(rename, stage, dest)
        if not ok then rename(backup, dest); fail(err) end
    end)
    emit('Updated ' .. mid .. '; restart the launcher shell to load its new code\n')
end
local function remove(root, mid, emit)
    local dest = target(root, mid)
    E.manifest(dest, mid)
    temporary(root, '.remove-', function(temp) rename(dest, temp .. '/' .. mid) end)
    emit('Removed ' .. mid .. '\n')
end
local function scan(root, enabled, emit)
    if not is_array(enabled) then fail('Enabled IDs must be a JSON array') end
    local enabled_ids = {}
    for _, mid in ipairs(enabled) do enabled_ids[E.identity(mid)] = true end
    local found, problems = U.object(), U.array()
    local names = with_fd(open_dir(root), names_fd)
    for _, mid in ipairs(names) do
        if mid:sub(1, 1) ~= '.' then
            local ok, result = pcall(function()
                local path = target(root, mid)
                local m = E.manifest(path, mid)
                m.__enabled = enabled_ids[mid] == true
                m.__validated = true
                local st = U.stat(path .. '/.git')
                m.__git = st ~= nil and st.type == 'directory'
                if m.__enabled then m.__sourceDir = path end
                return m
            end)
            if ok then found[mid] = result else problems[#problems + 1] = U.object({ pluginId = mid, message = tostring(result) }) end
        end
    end
    emit(U.encode(U.object({ manifests = found, problems = problems })) .. '\n')
end
local function check(root, ids, emit)
    local failures = {}
    for _, mid in ipairs(ids) do
        local ok, err = pcall(function()
            local path = target(root, mid)
            E.manifest(path, mid)
            if not U.stat(path .. '/.git', true) then emit(mid .. '\t\t\t\n'); return end
            local url = origin(path)
            local head = git_text({ 'rev-parse', 'HEAD' }, { cwd = path })
            local remote = git_text({ 'ls-remote', '--exit-code', '--', url, 'HEAD' })
            emit(table.concat({ mid, head, remote:match('^%S+') or '', url }, '\t') .. '\n')
        end)
        if not ok then failures[#failures + 1] = mid .. ': ' .. tostring(err) end
    end
    if #failures > 0 then fail(table.concat(failures, '; ')) end
end
local function atomic_json(fd, name, data)
    local path = fd_path(fd, name)
    local st = U.stat(path, true)
    if st and st.type == 'link' then fail('Symlink refused: ' .. name) end
    U.atomic_write(path, U.encode(data), 384)
end
local function parse(argv)
    local op, args, options = argv[1], {}, { id = '', enabled_json = '[]' }
    if not ({ install = true, update = true, remove = true, check = true, scan = true, job = true, ack = true })[op] then
        fail('Expected install, update, remove, check, scan, job or ack')
    end
    if op == 'job' then
        if not argv[2] or not argv[3] then fail('Expected job directory, metadata and command') end
        for i = 4, #argv do args[#args + 1] = argv[i] end
        return op, { directory = argv[2], job = argv[3], command = args }
    end
    local i, positional = 2, false
    while i <= #argv do
        local value = argv[i]
        if not positional and value == '--' then positional = true
        elseif not positional and ((op == 'install' and (value == '--id' or value:match('^%-%-id=')))
            or (op == 'scan' and (value == '--enabled-json' or value:match('^%-%-enabled%-json=')))) then
            local key = op == 'install' and 'id' or 'enabled_json'
            local inline = value:match('^[^=]+=(.*)$')
            if inline == nil then i = i + 1; inline = argv[i] end
            if inline == nil then fail('Missing option value') end
            options[key] = inline
        elseif not positional and value:sub(1, 1) == '-' and not (op == 'ack' and tonumber(value)) then fail('Unknown option: ' .. value)
        else args[#args + 1] = value end
        i = i + 1
    end
    local count = op == 'scan' and 0 or 1
    if op ~= 'check' and #args ~= count then fail('Wrong number of arguments for ' .. op) end
    options.args = args
    return op, options
end
local function stdout(text) io.stdout:write(text); io.stdout:flush() end
local function stderr(text) io.stderr:write(text); io.stderr:flush() end
function E.main(argv, emit, emit_error, wait_for_scan)
    emit, emit_error = emit or stdout, emit_error or stderr
    local ok, code = pcall(function()
        local op, options = parse(argv)
        if op == 'job' then
            if absolute(options.directory) ~= jobs_dir() then fail('Job directory must be the native Keystroke runtime directory') end
            local job = U.decode(options.job)
            if not is_object(job) or not ({ install = true, update = true, remove = true, check = true })[job.kind] or not finite(job.startedAt) then fail('Invalid job metadata') end
            local command = options.command
            if command[1] == '--' then table.remove(command, 1) end
            if command[1] ~= job.kind then fail('Job command does not match its kind') end
            return lock(jobs_dir(), function(fd)
                unlink_at(fd, 'result.json', true)
                atomic_json(fd, 'job.json', job)
                local output = {}
                local function capture(text) output[#output + 1] = text end
                local result = E.main(command, capture, capture, true)
                atomic_json(fd, 'result.json', U.object({ job = job, code = result, output = table.concat(output) }))
                unlink_at(fd, 'job.json')
                return result
            end)
        elseif op == 'ack' then
            local started = tonumber(options.args[1])
            if not finite(started) then fail('Invalid job timestamp') end
            lock(jobs_dir(), function(fd)
                local path = jobs_dir() .. '/result.json'
                if U.stat(path, true) then
                    local result = read_json(path)
                    if is_object(result) and is_object(result.job) and result.job.startedAt == started then unlink_at(fd, 'result.json') end
                end
            end)
        else
            local root = managed_dir()
            lock(root, function()
                if op == 'scan' then scan(root, U.decode(options.enabled_json), emit)
                elseif op == 'install' then install(root, options.args[1], options.id, emit)
                elseif op == 'update' then update(root, options.args[1], emit)
                elseif op == 'remove' then remove(root, options.args[1], emit)
                elseif op == 'check' then check(root, options.args, emit) end
            end, wait_for_scan)
        end
        return 0
    end)
    if ok then return code end
    emit_error('extensions: ' .. U.text(tostring(code), 8192) .. '\n')
    return 1
end

-- Requiring the module lets regression checks exercise validation and inject
-- bounded subprocess failures without a production-only testing command.
if ... == 'extensions' and package.loaded.extensions then return E end
os.exit(E.main(arg))
