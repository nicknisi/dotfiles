-- Shared Linux/LuaJIT primitives. All process arguments are literal argv.
local ffi = require('ffi')
local bit = require('bit')
local newdecoder = require('vendor.lunajson.decoder')
local parse = newdecoder()
local stringify = require('vendor.lunajson.encoder')()
local json = {null={}}
ffi.cdef[[
typedef int pid_t;
typedef unsigned int mode_t;
typedef unsigned int uid_t;
struct timespec { long tv_sec; long tv_nsec; };
struct pollfd { int fd; short events; short revents; };
struct statx_timestamp { int64_t tv_sec; uint32_t tv_nsec; int32_t __reserved; };
struct statx {
 uint32_t stx_mask; uint32_t stx_blksize; uint64_t stx_attributes;
 uint32_t stx_nlink; uint32_t stx_uid; uint32_t stx_gid; uint16_t stx_mode; uint16_t __spare0;
 uint64_t stx_ino; uint64_t stx_size; uint64_t stx_blocks; uint64_t stx_attributes_mask;
 struct statx_timestamp stx_atime, stx_btime, stx_ctime, stx_mtime;
 uint32_t stx_rdev_major, stx_rdev_minor, stx_dev_major, stx_dev_minor;
 uint64_t __spare2[14];
};
int statx(int, const char *, int, unsigned int, struct statx *);
int open(const char *, int, ...); int openat(int, const char *, int, ...);
int close(int); long read(int, void *, unsigned long); long write(int, const void *, unsigned long);
int mkdir(const char *, mode_t); int mkdirat(int, const char *, mode_t);
int unlink(const char *); int unlinkat(int, const char *, int); int rmdir(const char *);
int rename(const char *, const char *); int renameat(int, const char *, int, const char *);
int fchmod(int, mode_t); int chmod(const char *, mode_t); int fsync(int);
char *realpath(const char *, char *); void free(void *); char *strerror(int);
char *mkdtemp(char *); int mkstemp(char *); int symlink(const char *, const char *);
uid_t getuid(void); pid_t getpid(void); pid_t getppid(void);
int setenv(const char *, const char *, int); int unsetenv(const char *);
int chdir(const char *); int pipe2(int[2], int); int dup2(int, int); int fcntl(int, int, ...);
pid_t fork(void); int execvp(const char *, char *const[]); void _exit(int);
int waitpid(pid_t, int *, int); int kill(pid_t, int); int setpgid(pid_t, pid_t);
int pidfd_open(pid_t, unsigned int);
int prctl(int, ...); int poll(struct pollfd *, unsigned long, int);
int clock_gettime(int, struct timespec *); int nanosleep(const struct timespec *, struct timespec *);
typedef void (*sighandler_t)(int); sighandler_t signal(int, sighandler_t);
int sigemptyset(void *); int sigaddset(void *, int); int sigprocmask(int, const void *, void *);
int signalfd(int, const void *, int);
]]
local C = ffi.C
local U = {ffi=ffi, C=C, json=json, null=json.null}
local objectmeta, arraymeta = {__jsontype='object'}, {__jsontype='array'}
function U.object(t) return setmetatable(t or {}, objectmeta) end
function U.array(t) return setmetatable(t or {}, arraymeta) end
local function utf8(text)
  local i = 1
  while true do
    i = text:find('[\128-\255]', i)
    if not i then return true end
    local b = text:byte(i)
    local n = b >= 194 and b <= 223 and 2 or b >= 224 and b <= 239 and 3 or b >= 240 and b <= 244 and 4 or 0
    if n == 0 then return false end
    for offset = 1, n - 1 do
      local v = text:byte(i + offset)
      if not v or v < 128 or v > 191 or (offset == 1 and
        ((b == 224 and v < 160) or (b == 237 and v > 159) or (b == 240 and v < 144) or (b == 244 and v > 143))) then return false end
    end
    i = i + n
  end
end
local function validate(v, seen)
  if type(v) == 'number' then assert(v == v and v ~= math.huge and v ~= -math.huge, 'Non-finite JSON number') end
  if type(v) == 'string' then assert(utf8(v), 'Invalid UTF-8 in JSON') end
  if type(v) == 'table' and v ~= json.null then
    seen = seen or {}; assert(not seen[v], 'Cyclic JSON value'); seen[v] = true
    for k, value in pairs(v) do validate(k, seen); validate(value, seen) end
    seen[v] = nil
  end
end
local function wire(v)
  if type(v) ~= 'table' or v == json.null then return v end
  local out, meta = {}, getmetatable(v)
  for k, value in pairs(v) do
    if meta == objectmeta then assert(type(k) == 'string', 'JSON object keys must be strings') end
    out[k] = wire(value)
  end
  if meta == arraymeta or (meta ~= objectmeta and next(v) == nil) then out[0] = #v end
  return out
end
local function annotate(v)
  if type(v) == 'table' and v ~= json.null then
    setmetatable(v, v[0] ~= nil and arraymeta or objectmeta)
    v[0] = nil
    for _, value in pairs(v) do annotate(value) end
  end
  return v
end
function U.encode(v) validate(v); return stringify(wire(v), json.null) end
function U.decode(text)
  assert(type(text) == 'string' and utf8(text), 'Expected UTF-8 JSON text')
  local ok, value = pcall(parse, text, nil, json.null, true)
  -- A malformed surrogate can leave decoder state set. Never reuse it after an error.
  if not ok then parse = newdecoder(); error(value, 0) end
  validate(value); return annotate(value)
end
json.encode, json.decode = U.encode, U.decode
-- Human-readable external text uses replacement. Protocol JSON stays strict.
function U.text(data, limit)
  local out, i, count = {}, 1, 0
  while i <= #data and count < limit do
    local b = data:byte(i)
    local n = b < 128 and 1 or b >= 194 and b <= 223 and 2 or b >= 224 and b <= 239 and 3 or b >= 240 and b <= 244 and 4 or 0
    local used = 1
    if n > 1 then
      while used < n do
        local v = data:byte(i + used)
        if not v or v < 128 or v > 191 or (used == 1 and
          ((b == 224 and v < 160) or (b == 237 and v > 159) or (b == 240 and v < 144) or (b == 244 and v > 143))) then break end
        used = used + 1
      end
    end
    out[#out + 1] = (n > 0 and used == n) and data:sub(i, i + n - 1) or '\239\191\189'
    i = i + used; count = count + 1
  end
  return table.concat(out), i <= #data
end
-- Helpers produce JSON lines, including long-lived IPC helpers.
io.stdout:setvbuf('no')
function U.error() return ffi.string(C.strerror(ffi.errno())) end
local function check(rc) if rc == -1 then error(U.error(), 2) end; return rc end
local function pathcheck(path) assert(type(path) == 'string' and not path:find('\0', 1, true), 'Invalid path'); return path end
function U.read(path)
  local f, err = io.open(pathcheck(path), 'rb'); if not f then return nil, err end
  local data, why = f:read('*a'); f:close(); return data, why
end
function U.write(path, data)
  local f = assert(io.open(pathcheck(path), 'wb')); local ok, err = f:write(data)
  local closed, cerr = f:close(); assert(ok, err); assert(closed, cerr)
end
function U.realpath(path)
  local ptr = C.realpath(pathcheck(path), nil); if ptr == nil then return nil, U.error() end
  local result = ffi.string(ptr); C.free(ptr); return result
end
local types = {[32768]='file', [16384]='directory', [40960]='link', [4096]='fifo', [49152]='socket', [8192]='character', [24576]='block'}
function U.stat_at(fd, path, flags)
  local st = ffi.new('struct statx[1]')
  if C.statx(fd, pathcheck(path), flags or 0, 0x7ff, st) ~= 0 then return nil, U.error() end
  return {type=types[bit.band(st[0].stx_mode, 61440)] or 'other', mode=tonumber(st[0].stx_mode), uid=tonumber(st[0].stx_uid), size=tonumber(st[0].stx_size), mtime=tonumber(st[0].stx_mtime.tv_sec) + tonumber(st[0].stx_mtime.tv_nsec)/1e9}
end
function U.stat(path, nofollow) return U.stat_at(-100, path, nofollow and 256 or 0) end
function U.mkdir_p(path, mode)
  pathcheck(path); mode = mode or 448
  local current = path:sub(1,1) == '/' and '' or '.'
  for part in path:gmatch('[^/]+') do
    current = current .. '/' .. part
    if C.mkdir(current, mode) ~= 0 then
      local info = U.stat(current); assert(info and info.type == 'directory', U.error())
    end
  end
end
function U.write_fd(fd, data)
  local at = 0
  while at < #data do
    local n = C.write(fd, ffi.cast('const char *', data) + at, #data - at)
    if n < 0 then if ffi.errno() ~= 4 then error(U.error()) end else assert(n > 0, 'Short write'); at = at + tonumber(n) end
  end
end
function U.atomic_write(path, data, mode)
  pathcheck(path)
  local tmp = ffi.new('char[?]', #path + 12, path .. '.tmp.XXXXXX')
  local fd = check(C.mkstemp(tmp)); local name = ffi.string(tmp)
  local ok, err = pcall(function() check(C.fchmod(fd, mode or 384)); U.write_fd(fd, data); check(C.fsync(fd)); check(C.rename(name, path)) end)
  C.close(fd); if not ok then C.unlink(name); error(err) end
end
function U.tmpdir(parent, prefix)
  parent = assert(U.realpath(parent)); prefix = prefix or 'tmp-'
  assert(not prefix:find('[/%z]'), 'Invalid temporary prefix')
  local template = parent .. '/' .. prefix .. 'XXXXXX'
  local buf = ffi.new('char[?]', #template + 1, template)
  assert(C.mkdtemp(buf) ~= nil, U.error()); return ffi.string(buf)
end
function U.monotime()
  local t = ffi.new('struct timespec[1]'); check(C.clock_gettime(1,t)); return tonumber(t[0].tv_sec) + tonumber(t[0].tv_nsec)/1e9
end
function U.sleep(seconds)
  local t = ffi.new('struct timespec[1]'); t[0].tv_sec = math.floor(seconds); t[0].tv_nsec = math.floor((seconds % 1)*1e9)
  while C.nanosleep(t,t) ~= 0 and ffi.errno() == 4 do end
end
local function cargv(argv)
  assert(type(argv) == 'table' and #argv > 0, 'Expected argv')
  local v = ffi.new('char *[?]', #argv + 1)
  for i, s in ipairs(argv) do assert(type(s) == 'string' and not s:find('\0',1,true), 'Invalid argv'); v[i-1] = ffi.cast('char *', s) end
  return v
end
local function environment(env)
  for k,v in pairs(env or {}) do
    assert(type(k) == 'string' and k ~= '' and not k:find('[=%z]'), 'Invalid environment key')
    if v == false then check(C.unsetenv(k)) else assert(type(v) == 'string' and not v:find('\0',1,true), 'Invalid environment value'); check(C.setenv(k,v,1)) end
  end
end
local function child_signals()
  local empty = ffi.new('uint8_t[128]'); C.sigemptyset(empty); C.sigprocmask(2,empty,nil)
  C.signal(13,nil)
end
function U.exec(argv, env)
  local v = cargv(argv); environment(env); child_signals(); C.execvp(v[0],v); error(U.error())
end
function U.run(argv, opts)
  opts = opts or {}; cargv(argv)
  local timeout, maximum = opts.timeout or 60, opts.max_output or 4*1024*1024
  assert(timeout > 0 and timeout < math.huge and maximum >= 0 and maximum < math.huge, 'Invalid process limits')
  local input = opts.input or ''; assert(type(input) == 'string', 'Invalid stdin')
  -- timeout is the process-group supervisor. Its parent-death SIGTERM also
  -- starts its kill-after timer when the QML helper is killed with SIGKILL.
  local command = {'/usr/bin/timeout', '--signal=TERM', '--kill-after=1', tostring(timeout)}
  for _, s in ipairs(argv) do command[#command+1] = s end
  local v = cargv(command)
  local pipes = {}; for i=1,3 do
    pipes[i] = ffi.new('int[2]')
    if C.pipe2(pipes[i], 524288) ~= 0 then
      for j=1,i-1 do C.close(pipes[j][0]); C.close(pipes[j][1]) end
      return {code=127, stdout='', stderr=U.error()}
    end
  end
  local parent = C.getpid()
  C.signal(13, ffi.cast('sighandler_t', 1)) -- Ignore SIGPIPE, never enter Lua from a signal.
  local pid = C.fork()
  if pid == 0 then
    C.setpgid(0,0)
    C.prctl(1, ffi.cast('unsigned long',15), ffi.cast('unsigned long',0), ffi.cast('unsigned long',0), ffi.cast('unsigned long',0))
    if C.getppid() ~= parent then C._exit(125) end
    C.dup2(pipes[1][0],0); C.dup2(pipes[2][1],1); C.dup2(pipes[3][1],2)
    for i=1,3 do C.close(pipes[i][0]); C.close(pipes[i][1]) end
    child_signals()
    local ok = pcall(function() environment(opts.env); if opts.cwd then check(C.chdir(pathcheck(opts.cwd))) end end)
    if not ok then C._exit(126) end
    C.execvp(v[0],v); C._exit(127)
  end
  C.close(pipes[1][0]); C.close(pipes[2][1]); C.close(pipes[3][1])
  local fds = {tonumber(pipes[1][1]),tonumber(pipes[2][0]),tonumber(pipes[3][0])}
  if pid < 0 then for _, fd in ipairs(fds) do C.close(fd) end; return {code=127,stdout='',stderr=U.error()} end
  local exitfd = C.pidfd_open(pid, 0)
  C.setpgid(pid,pid)
  for _,fd in ipairs(fds) do C.fcntl(fd,4,ffi.cast('int',2048)) end
  local function close(i) if fds[i] >= 0 then C.close(fds[i]); fds[i] = -1 end end
  if #input == 0 then close(1) end
  local chunks = {{},{}}; local sizes = {0,0}; local at, forced = 0, nil
  local poll = ffi.new('struct pollfd[4]'); local buf = ffi.new('char[65536]'); local status = ffi.new('int[1]')
  local deadline, reaped = U.monotime() + timeout + 2, false
  local function stop(code) if not forced then forced = code; C.kill(-pid,9); C.kill(pid,9); close(1) end end
  while not reaped or fds[2] >= 0 or fds[3] >= 0 do
    -- Optional cooperative cancellation is polled here, never in a signal handler.
    if opts.cancel then local code = opts.cancel(); if code then stop(code) end end
    if U.monotime() >= deadline then stop(124); close(2); close(3) end
    for i=1,3 do poll[i-1].fd=fds[i]; poll[i-1].events=i==1 and 4 or 1; poll[i-1].revents=0 end
    -- Pipe EOF can precede waitpid readiness. Wake on exit rather than sleeping
    -- through the polling interval after every short-lived command.
    poll[3].fd=exitfd; poll[3].events=1; poll[3].revents=0
    C.poll(poll,4,50)
    for i=1,3 do if fds[i] >= 0 and poll[i-1].revents ~= 0 then
      if i==1 then
        local n=C.write(fds[1],ffi.cast('const char *',input)+at,math.min(65536,#input-at))
        if n>0 then at=at+tonumber(n); if at==#input then close(1) end
        elseif n<0 and ffi.errno()~=11 and ffi.errno()~=4 then close(1) end
      else
        local n=C.read(fds[i],buf,65536)
        if n>0 then
          n=tonumber(n); local keep=math.min(n,math.max(0,maximum-sizes[1]-sizes[2]))
          if keep>0 then local t=chunks[i-1]; t[#t+1]=ffi.string(buf,keep); sizes[i-1]=sizes[i-1]+keep end
          if keep<n then stop(125) end
        elseif n==0 or (ffi.errno()~=11 and ffi.errno()~=4) then close(i) end
      end
    end end
    if not reaped then
      local r=C.waitpid(pid,status,1); reaped=r==pid or (r<0 and ffi.errno()~=4)
      if reaped and exitfd>=0 then C.close(exitfd); exitfd=-1 end
    end
  end
  close(1)
  local raw=tonumber(status[0]); local code=bit.band(raw,127)==0 and bit.rshift(raw,8) or 128+bit.band(raw,127)
  return {code=forced or code,stdout=table.concat(chunks[1]),stderr=table.concat(chunks[2])}
end
-- Fork must not occur in a compiled trace.
require('jit').off(U.run, true)
return U
