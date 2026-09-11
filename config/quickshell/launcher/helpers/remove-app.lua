#!/usr/bin/env luajit
-- Read ownership and print an interactive removal argv. Never uninstall here.
package.path=(debug.getinfo(1,'S').source:sub(2):match('^(.*)/') or '.')..'/?.lua;'..package.path
local U=require('runtime')
local M={}
local function trim(s) return s:match('^%s*(.-)%s*$') end
function M.data_dirs()
 local home=assert(os.getenv('HOME'))
 local out={os.getenv('XDG_DATA_HOME') or home..'/.local/share'}
 for p in (os.getenv('XDG_DATA_DIRS') or '/usr/local/share:/usr/share'):gmatch('[^:]+') do out[#out+1]=p end
 out[#out+1]=home..'/.local/share/flatpak/exports/share'; out[#out+1]='/var/lib/flatpak/exports/share'; return out
end
function M.desktop_file(id,directories)
 assert(type(id)=='string' and id~='' and not id:find('[/\\%z]') and id:sub(1,1)~='.', 'Invalid desktop entry identity')
 local filename=id:sub(-8)=='.desktop' and id or id..'.desktop'
 for _,directory in ipairs(directories) do
  local base=directory:gsub('/+$','')..'/applications'
  local direct=base..'/'..filename
  local st=U.stat(direct); if st and st.type=='file' then return direct end
  st=U.stat(base)
  if st and st.type=='directory' then
   local result=U.run({'find','-H',base,'-name','*.desktop','-print0'},{timeout=10})
   assert(result.code==0,'Could not enumerate desktop entries')
   local found
   for p in result.stdout:gmatch('([^%z]+)%z') do
    local info=U.stat(p)
    if info and info.type=='file' and p:sub(#base+2):gsub('/','-')==filename then assert(not found,'Ambiguous desktop entry identity'); found=p end
   end
   if found then return found end
  end
 end
 error('Desktop entry could not be found',0)
end
function M.read_command(argv)
 local r=U.run(argv,{timeout=10}); return r.code==0 and trim(r.stdout) or ''
end
local function inside(path,base) return path:sub(1,#base+1)==base..'/' and path:sub(#base+2) or nil end
local function flatpak_field(path)
 local data=assert(U.read(path)); local section,field,value
 for line in (data..'\n'):gmatch('(.-)\n') do
  if trim(line)~='' and not line:match('^%s*[#;]') then
   local nextsection=line:match('^%s*%[([^%]]+)%]')
   if nextsection then section=nextsection; field=nil
   elseif line:match('^%s') and field then
    if section=='Desktop Entry' and field=='x-flatpak' then value=value..'\n'..trim(line) end
   else
    local k,v=line:match('^%s*([^=:]+)%s*[=:]%s*(.*)$'); assert(section and k,'Invalid desktop entry')
    field=trim(k):lower(); if section=='Desktop Entry' and field=='x-flatpak' then value=trim(v) end
   end
  end
 end
 return value
end
function M.removal_plan(id,directories,run,home)
 run=run or M.read_command; home=home or assert(os.getenv('HOME'))
 local entry=M.desktop_file(id,directories or M.data_dirs())
 local owner=run({'pacman','-Qoq','--',entry})
 if type(owner)=='string' and owner:match('^[a-zA-Z0-9@_+][a-zA-Z0-9@._+%-]*$') then return {manager='pacman',package=owner,argv=U.array({'sudo','pacman','-Rns','--',owner})} end
 for _,root in ipairs({{home..'/.local/share/flatpak','--user'},{'/var/lib/flatpak','--system'}}) do
  local base,installation=root[1],root[2]
  if inside(entry,base..'/exports/share/applications') then
   local resolved,canonical=U.realpath(entry),U.realpath(base)
   local relative=resolved and canonical and inside(resolved,canonical..'/app')
   if relative then
    local parts={}; for p in relative:gmatch('[^/]+') do parts[#parts+1]=p end
    local app,arch,branch=parts[1],parts[2],parts[3]
    local valid=app and app:match('^[A-Za-z0-9_-]+%.[A-Za-z0-9_.-]+$') and not app:find('%.%.') and app:sub(-1)~='.'
    local _,dots=(app or ''):gsub('%.','')
    if #parts>=5 and valid and dots>=2 and arch:match('^[A-Za-z0-9_-][A-Za-z0-9_.-]*$') and branch:match('^[A-Za-z0-9_-][A-Za-z0-9_.-]*$') and flatpak_field(entry)==app then
     local ref='app/'..app..'/'..arch..'/'..branch
     if run({'flatpak','info',installation,'--show-ref',ref})==ref then return {manager='flatpak',package=ref,installation=installation,argv=U.array({'flatpak','uninstall',installation,'--',ref})} end
    end
   end
  end
 end
 error('This app is not owned by pacman or a verified Flatpak installation. No files were removed.',0)
end
function M.main(args)
 if args[1]=='--' then table.remove(args,1) end
 local ok,plan=pcall(function() assert(#args==1,'Expected one desktop entry ID'); return M.removal_plan(args[1]) end)
 print(U.encode(ok and plan or {error='This app is unmanaged or its ownership could not be verified. No files were removed.'})); return ok and 0 or 1
end
if ...~='remove-app' then os.exit(M.main(arg)) end
return M
