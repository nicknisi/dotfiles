#!/usr/bin/env luajit
-- Descriptor-relative completion writes. Leaf links are replaced, not followed.
package.path = (debug.getinfo(1,'S').source:sub(2):match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local U = require('runtime')
local C, ffi, bit = U.C, U.ffi, require('bit')
local M = {}
local DIR = 65536 + 131072 + 524288 -- O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
local function owned(fd)
  local st = assert(U.stat_at(fd, '', 4096)) -- AT_EMPTY_PATH
  assert(st.type == 'directory' and st.uid == C.getuid() and bit.band(st.mode, 63) == 0, 'Unsafe picker directory')
  return fd
end
function M.open_base(base)
  assert(type(base) == 'string' and base:sub(1,1) == '/' and base:sub(-1) ~= '/' and not base:find('\0',1,true), 'Invalid picker base')
  local fd = C.open(base, DIR); assert(fd >= 0, U.error())
  local ok, err = pcall(owned,fd); if not ok then C.close(fd); error(err) end
  return fd
end
local function parts(base, path)
  assert(type(path) == 'string' and path:sub(1,#base+1) == base .. '/' and not path:find('\0',1,true), 'Invalid picker path')
  local out = {}; for part in (path:sub(#base+2) .. '/'):gmatch('(.-)/') do
    assert(part ~= '' and part ~= '.' and part ~= '..', 'Invalid picker path'); out[#out+1] = part
  end
  return out
end
local function parent(root, components)
  local fd = C.openat(root, '.', DIR); assert(fd >= 0, U.error())
  local ok, err = pcall(function()
    for i=1,#components-1 do
      local nextfd = C.openat(fd, components[i], DIR); assert(nextfd >= 0, U.error())
      C.close(fd); fd = nextfd; owned(fd)
    end
  end)
  if not ok then C.close(fd); error(err) end
  return {fd, components[#components]}
end
local function token()
  local f = assert(io.open('/dev/urandom','rb')); local bytes = f:read(16); f:close(); assert(bytes and #bytes == 16, 'No random bytes')
  return (bytes:gsub('.',function(c) return string.format('%02x',c:byte()) end))
end
function M.write_at(directory, name, data)
  local temporary = '.launcher-' .. token()
  local fd = C.openat(directory, temporary, 1+64+128+131072+524288, ffi.cast('mode_t',384))
  assert(fd >= 0, U.error())
  local ok, err = pcall(function()
    U.write_fd(fd,data); assert(C.fsync(fd)==0,U.error())
    assert(C.renameat(directory,temporary,directory,name)==0,U.error())
  end)
  C.close(fd); C.unlinkat(directory,temporary,0)
  if not ok then error(err) end
end
function M.complete(base, selection, done, accepted, text)
  assert(selection ~= done,'Duplicate picker paths')
  assert(accepted == '0' or accepted == '1','Invalid picker acceptance')
  local a,b = parts(base,selection),parts(base,done)
  local root = M.open_base(base); local selected, completed
  local ok, err = pcall(function()
    selected = parent(root,a); completed = parent(root,b)
    if accepted == '1' then M.write_at(selected[1],selected[2],text .. '\n') end
    M.write_at(completed[1],completed[2],'')
  end)
  if selected then C.close(selected[1]) end; if completed then C.close(completed[1]) end; C.close(root)
  if not ok then error(err) end
end
function M.main(args)
  local ok = #args == 5 and pcall(M.complete,unpack(args))
  if not ok then io.stderr:write('Picker completion failed\n'); return 1 end
  return 0
end
if ... ~= 'picker-write' then os.exit(M.main(arg)) end
return M
