#!/usr/bin/env luajit
-- Read-only native fixtures. No real desktop or clipboard command is invoked.
local here=arg[0]:match('^(.*)/') or '.'
package.path=here..'/../helpers/?.lua;'..package.path
local U=require('runtime')
local C,ffi,bit=U.C,U.ffi,require('bit')
local hotkeys,remove,clipboard=require('hotkeys'),require('remove-app'),require('clipboard-preview')
local helpers=assert(U.realpath(here..'/../helpers'))
local tests,checks=0,0
local function equal(a,b)
 checks=checks+1
 local function same(x,y)
  if type(x)~=type(y) then return false end
  if type(x)~='table' then return x==y end
  for k,v in pairs(x) do if not same(v,y[k]) then return false end end
  for k in pairs(y) do if x[k]==nil then return false end end
  return true
 end
 if not same(a,b) then
  local function display(value)
   local ok,text=pcall(U.encode,value); return ok and text or string.format('%q',tostring(value))
  end
  error('Expected '..display(b)..', got '..display(a))
 end
end
local function raises(fn) checks=checks+1; assert(not pcall(fn),'Expected rejection') end
local function copy(t,changes) local out={}; for k,v in pairs(t) do out[k]=v end; for k,v in pairs(changes or {}) do out[k]=v end; return out end
local function mock(object,key,value,fn)
 local saved=object[key]; object[key]=value; local ok,result=pcall(fn); object[key]=saved; if not ok then error(result,0) end; return result
end
local function test(name,fn) fn(); tests=tests+1; print('PASS '..name) end
local temp=U.tmpdir('/tmp','launcher-native-lua-')
local home=temp..'/home'; U.mkdir_p(home)
local function entry(dir,name,content)
 local path=dir..'/applications/'..(name or 'example.desktop'); U.mkdir_p(path:match('^(.*)/')); U.write(path,content or '[Desktop Entry]\nName=Fixture\n'); return path
end
local function executable(path,source) U.write(path,source); assert(C.chmod(path,448)==0) end
local function env(key,value) assert(C.setenv(key,value,1)==0) end
local savedenv={}; for _,k in ipairs({'HOME','XDG_CACHE_HOME','PATH'}) do savedenv[k]=os.getenv(k) end
local ok,err=pcall(function()
test('live records preserve description dispatcher and combo',function()
 local rows=hotkeys.normalize({{modmask=65,key='RETURN',description='My terminal',dispatcher='exec',arg='ghostty -e printf "%s" "a b"'}})
 equal(rows[1].label,'My terminal'); equal(rows[1].combo,'SUPER SHIFT + RETURN'); equal(rows[1].argv,{'uwsm-app','--','ghostty','-e','printf','%s','a b'})
end)
test('unregistered callback and submap stay disabled',function()
 local row=hotkeys.normalize({{modmask=64,key='Q',dispatcher='__lua',arg='42'}})[1]
 equal(row.argv,{}); equal(row.label,'Close window'); equal(row.labelHint,true); equal(row.registration,U.null)
 equal(hotkeys.dispatch_argv('lua','hl.dsp.window.close()'),{})
 row=hotkeys.normalize({{modmask=64,key='Q',dispatcher='__lua',arg='42',submap='custom'}})[1]
 equal(row.labelHint,false); equal(row.submap,'custom')
end)
test('native Lua dispatch and data quoting',function()
 equal(hotkeys.dispatch_argv('movefocus','l'),{'hyprctl','dispatch','hl.dsp.focus({ direction = "l" })'})
 equal(hotkeys.dispatch_argv('movetoworkspacesilent','name:D'),{'hyprctl','dispatch','hl.dsp.window.move({ workspace = "name:D", follow = false })'})
 for _,action in ipairs({'on','off'}) do equal(hotkeys.dispatch_argv('dpms',action),{'hyprctl','dispatch','hl.dsp.dpms({ action = "'..action..'" })'}) end
 equal(hotkeys.dispatch_argv('dpms','enable'),{})
 local argv=hotkeys.dispatch_argv('workspace','name:x" }); unexpected(); --')
 assert(argv[3]:find('name:x\\" }); unexpected(); --',1,true)); equal(#argv,3)
 equal(hotkeys.lua_string('\n\0\t'),'"\\010\\000\\009"'); equal(hotkeys.dispatch_argv('workspace','name:\0'),{})
end)
test('shell constructs unknown dispatchers and invalid records fail closed',function()
 for _,command in ipairs({'echo $(id)','echo x; id','a | b','A=1 app',"unterminated '",'[float] app','x > file'}) do equal(hotkeys.dispatch_argv('exec',command),{}) end
 equal(hotkeys.dispatch_argv('made-up','argument'),{}); equal(hotkeys.dispatch_argv('movefocus','l"} bad'),{})
 equal(hotkeys.normalize({U.null,{}, {key='X',modmask='bad'}}),{})
 local row=hotkeys.normalize({{keycode=19,modmask=64,dispatcher='__lua',arg='3'}})[1]
 equal(row.combo,'SUPER + code:19'); equal(row.label,'Next theme')
end)
local binding={id=1,arg='42',key='Q',keycode=0,modmask=64,submap='',release=false,longPress=false,mouse=false,['repeat']=false}
local snapshot={generation=string.rep('a',32),bindings=U.array({binding})}
local live=copy(binding,{dispatcher='__lua',description='Configured action'})
test('registered callbacks deliberately runnable with opaque join key',function()
 local row=hotkeys.normalize({live},snapshot)[1]
 equal(row.label,'Configured action'); equal(row.registration,{generation=snapshot.generation,id=1})
 equal(row.argv,{'hyprctl','dispatch','_G.launcher_bindings.resolve("'..snapshot.generation..'", 1)'})
 assert(not row.argv[3]:find('42',1,true))
 for _,field in ipairs(hotkeys.IDENTITY_FIELDS) do
  local value=live[field]; local changed
  if type(value)=='boolean' then changed=not value elseif type(value)=='number' then changed=value+1 else changed=value..'changed' end
  equal(hotkeys.normalize({copy(live,{[field]=changed})},snapshot)[1].argv,{})
 end
end)
test('keyboard triggers and removed native registrations stay disabled',function()
 for _,dispatch in ipairs({{'__lua','42'},{'killactive',''}}) do
  for _,flags in ipairs({{release=true},{longPress=true},{mouse=true},{key='mouse:272'},{key='mouse_down'},{submap='resize'},{catch_all=true},{enabled=false}}) do
   equal(hotkeys.normalize({copy(copy(live,{dispatcher=dispatch[1],arg=dispatch[2]}),flags)},snapshot)[1].argv,{})
  end
 end
 binding['repeat']=true; live['repeat']=true; assert(#hotkeys.normalize({live},snapshot)[1].argv>0); binding['repeat']=false; live['repeat']=false
 for _,bindings in ipairs({U.array(),{copy(binding,{arg='-2'})},{copy(binding,{arg='43'})}}) do equal(hotkeys.normalize({live},copy(snapshot,{bindings=bindings}))[1].argv,{}) end
 equal(hotkeys.normalize({copy(live,{dispatcher='lua'})},snapshot)[1].argv,{})
end)
test('malformed registry fails closed for every identity field',function()
 local bad={U.null,U.array(),U.object(),copy(snapshot,{generation='x"); injected()'}),copy(snapshot,{generation=string.rep('a',33)}),copy(snapshot,{bindings={binding,binding}})}
 for _,id in ipairs({0,-1,true,1.5,'1','1); injected()',1025}) do bad[#bad+1]=copy(snapshot,{bindings={copy(binding,{id=id})}}) end
 for _,field in ipairs(hotkeys.IDENTITY_FIELDS) do
  bad[#bad+1]=copy(snapshot,{bindings={copy(binding,{[field]=U.array()})}})
  local missing=copy(binding); missing[field]=nil; bad[#bad+1]=copy(snapshot,{bindings={missing}})
 end
 for _,bad_snapshot in ipairs(bad) do equal(hotkeys.normalize({live},bad_snapshot)[1].argv,{}) end
end)
test('read-only registry generation is fetched before live binds',function()
 local function main_with(output)
  local calls,printed={},nil
  mock(U,'run',function(argv)
   calls[#calls+1]=argv
   if #calls==1 then equal(argv,hotkeys.REGISTRY_ARGV); if type(output)=='function' then return output() end; return {code=0,stdout=output,stderr=''} end
   equal(argv,{'hyprctl','binds','-j'}); return {code=0,stdout=U.encode(U.array({live})),stderr=''}
  end,function() mock(_G,'print',function(value) printed=value end,function() equal(hotkeys.main(),0) end) end)
  equal(calls,{hotkeys.REGISTRY_ARGV,{'hyprctl','binds','-j'}}); return U.decode(printed)[1]
 end
 assert(#main_with(U.encode(snapshot)).argv>0); equal(hotkeys.REGISTRY_ARGV[2],'repl')
 for _,out in ipairs({'ok','error: missing integration','{}',string.rep(' ',hotkeys.MAX_REGISTRY_OUTPUT+1),function() error('not running') end,function() return {code=124,stdout='',stderr=''} end}) do equal(main_with(out).argv,{}) end
end)
test('actual Lua registration and generated dispatch execute in the same state',function()
 local expression
 local savedarg=arg; arg={assert(U.realpath(helpers..'/../../../hypr/launcher-bindings.lua')),'--bridge'}
 local worked,why=pcall(function()
  mock(_G,'print',function(value)
   if value:sub(1,1)=='{' then
    local snap=U.decode(value); local records=U.array()
    for _,b in ipairs(snap.bindings) do records[#records+1]=copy(b,{dispatcher='__lua'}) end
    local rows=hotkeys.normalize(records,snap); equal(#rows,1); assert(#rows[1].argv>0); expression=rows[1].argv[3]
   else equal(value,'HOTKEYS_LUA_PASS') end
  end,function() mock(io,'read',function() return assert(expression) end,function() dofile(here..'/hotkeys_fixture.lua') end) end)
 end)
 arg=savedarg; assert(worked,why)
end)
test('pacman removal plan only reads selected desktop ownership',function()
 local user,system=temp..'/pacman/user',temp..'/pacman/system'; U.mkdir_p(user..'/applications'); local path=entry(system)
 local calls={}; local plan=remove.removal_plan('example',{user,system},function(argv) calls[#calls+1]=argv; return 'example-package' end)
 equal(calls,{{'pacman','-Qoq','--',path}}); equal(plan.argv,{'sudo','pacman','-Rns','--','example-package'}); assert(U.stat(path)); assert(not table.concat(plan.argv,' '):find('%-%-noconfirm'))
 local override=entry(user); calls={}
 raises(function() remove.removal_plan('example.desktop',{user,system},function(argv) calls[#calls+1]=argv; return '' end) end)
 equal(calls,{{'pacman','-Qoq','--',override}}); assert(U.stat(override))
end)
test('nested desktop IDs invalid IDs and invalid package owners',function()
 local user=temp..'/nested'; local path=entry(user,'vendor/example.desktop')
 equal(remove.desktop_file('vendor-example',{user}),path)
 for _,id in ipairs({'../example','x/y','\0','.',''}) do raises(function() remove.desktop_file(id,{user}) end) end
 entry(user)
 for _,owner in ipairs({'--help','a\nb','a;bad',''}) do raises(function() remove.removal_plan('example',{user},function() return owner end) end) end
 -- Colliding flattened IDs are ambiguous instead of choosing arbitrarily.
 entry(user,'vendor-example/nested.desktop'); entry(user,'vendor/example-nested.desktop')
 raises(function() remove.desktop_file('vendor-example-nested',{user}) end)
end)
test('Flatpak requires exact export installation metadata and installed ref',function()
 local base=home..'/.local/share/flatpak'; local app='org.example.Fixture'
 local target=entry(base..'/app/'..app..'/x86_64/stable/commit/export/share',app..'.desktop','[Desktop Entry]\nX-Flatpak='..app..'\n')
 local export=base..'/exports/share'; U.mkdir_p(export..'/applications'); assert(C.symlink(target,export..'/applications/'..app..'.desktop')==0)
 local calls,ref={},'app/'..app..'/x86_64/stable'
 local plan=remove.removal_plan(app,{export},function(argv) calls[#calls+1]=argv; return argv[1]=='flatpak' and ref or '' end,home)
 equal(plan.argv,{'flatpak','uninstall','--user','--',ref}); equal(calls[#calls],{'flatpak','info','--user','--show-ref',ref})
 raises(function() remove.removal_plan(app,{export},function() return '' end,home) end)
 local fake=temp..'/fake'; entry(fake,nil,'[Desktop Entry]\nX-Flatpak='..app..'\n')
 raises(function() remove.removal_plan('example',{fake},function() return '' end,home) end)
end)
env('HOME',home); env('XDG_CACHE_HOME',home..'/cache')
test('numeric clipboard IDs are strictly ASCII and bounded',function()
 equal(clipboard.valid_id('00123'),'00123')
 for _,id in ipairs({'-1','1\tpreview','../1','1;bad','1\n','１２','',string.rep('1',21)}) do raises(function() clipboard.valid_id(id) end) end
end)
test('text previews are bounded Unicode with replacement, never diagnostics',function()
 mock(clipboard,'decode',function() return string.rep('fixture\n',5000),false end,function()
  local result=clipboard.preview('42','text'); equal(#result.text,clipboard.TEXT_LIMIT); equal(result.truncated,true); equal(result.id,'42')
 end)
 local text,truncated=clipboard.text(string.rep('🚀',12001),12000); equal(text,string.rep('🚀',12000)); equal(truncated,true)
 equal(clipboard.text('\255\0\226\130',12000),'�\0�')
end)
test('image thumbnail is private bounded and leaves no raw cache files',function()
 local png=U.run({'/usr/bin/base64','-d'},{input='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/AAAZ4gk3AAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg=='})
 equal(png.code,0)
 mock(clipboard,'decode',function() return png.stdout,false end,function()
  local result=clipboard.preview('42','image'); local st=assert(U.stat(result.image)); equal(st.type,'file'); equal(bit.band(st.mode,511),384); assert(st.size<clipboard.IMAGE_LIMIT)
  local base=result.image:match('^(.*)/'); equal(bit.band(U.stat(base).mode,511),448)
  local files=U.run({'find',base,'-mindepth','1','-print0'}); equal(files.stdout,result.image..'\0')
  clipboard.cleanup(result.image); assert(not U.stat(result.image))
 end)
 mock(clipboard,'decode',function() return '<svg>fixture</svg>',false end,function() raises(function() clipboard.preview('42','image') end) end)
 mock(clipboard,'decode',function() return '',true end,function() assert(clipboard.preview('42','image').error) end)
end)
test('real fixture-only clipboard pipeline preserves binary bytes and MIME',function()
 local bin=home..'/bin'; U.mkdir_p(bin)
 executable(bin..'/cliphist','#!/usr/bin/luajit\nassert(arg[1]=="decode" and arg[2]=="42"); io.stdout:write("fixture text")\n')
 executable(bin..'/wl-copy','#!/usr/bin/luajit\nassert(#arg==0); local f=assert(io.open('..string.format('%q',home..'/copied')..',"wb")); f:write(io.stdin:read("*a")); f:close()\n')
 env('PATH',bin)
 local bytes,truncated=clipboard.decode('42',100); equal(#bytes,12); equal(truncated,false)
 bytes,truncated=clipboard.decode('42',4); equal(#bytes,4); equal(truncated,true)
 clipboard.copy('42',''); equal(U.stat(home..'/copied').size,12)
 local binary=string.rep('\0\255\r\n🚀',150000); U.write(home..'/binary',binary)
 executable(bin..'/cliphist','#!/usr/bin/luajit\nassert(arg[1]=="decode" and arg[2]=="42"); local f=assert(io.open('..string.format('%q',home..'/binary')..',"rb")); io.stdout:write(f:read("*a")); f:close()\n')
 executable(bin..'/wl-copy','#!/usr/bin/luajit\nassert(arg[1]=="--type" and arg[2]=="application/octet-stream"); local f=assert(io.open('..string.format('%q',home..'/copied')..',"wb")); f:write(io.stdin:read("*a")); f:close()\n')
 clipboard.copy('42','application/octet-stream'); equal(U.read(home..'/copied'),binary)
 raises(function() clipboard.copy('42','text/plain;bad') end)
 env('PATH',savedenv.PATH)
end)
test('clipboard cleanup refuses arbitrary paths links and foreign cache scope',function()
 local path=home..'/do-not-delete'; U.write(path,'fixture')
 local r=U.run({'/usr/bin/luajit',helpers..'/clipboard-preview.lua','cleanup',path}); assert(r.code~=0); assert(U.stat(path))
 local link=home..'/cache/quickshell/clipboard-preview-link.png'; assert(C.symlink(path,link)==0)
 raises(function() clipboard.cleanup(link) end); equal(U.read(path),'fixture'); C.unlink(link)
end)
test('JSON null object array and non-finite numbers remain distinct',function()
 equal(U.encode(U.object()),'{}'); equal(U.encode(U.array()),'[]'); equal(U.encode(U.null),'null')
 local value=U.decode('{"o":{},"a":[],"n":null,"b":false}'); equal(value.n,U.null); equal(value.b,false)
 equal(U.encode(value.o),'{}'); equal(U.encode(value.a),'[]')
 for _,text in ipairs({'{} trailing','[1e999]','NaN','Infinity','{"n":NaN}',
  '{/* comment */"a":1}','{"a":1 "b":2}','[1,]','{"a":1,}','"\\q"','"line\nbreak"','"\255"',
  '"\\ud800\\uXXXX"','"\\udc00"'}) do raises(function() U.decode(text) end) end
 equal(U.decode('"\\ud83d\\ude00"'),'😀')
 equal(U.encode(U.decode('[{},[],null,false]')),'[{},[],null,false]')
 raises(function() U.encode({n=0/0}) end); raises(function() U.encode({n=math.huge}) end)
 raises(function() U.encode({text='\255'}) end)
end)
test('runtime literal argv cwd env exit code and separated binary streams',function()
 local r=U.run({'/usr/bin/luajit','-e','io.stdout:write(arg[0],"\\0",os.getenv("FIXTURE")); io.stderr:write("err\\255"); os.exit(7)','--','$(not executed); literal'},{cwd=temp,env={FIXTURE='value'}})
 equal(r.code,7); equal(r.stdout,'$(not executed); literal\0value'); equal(r.stderr,'err\255')
 r=U.run({'/bin/pwd'},{cwd=temp}); equal(r.stdout,temp..'\n')
 assert(U.run({'/missing/launcher-command'}).code~=0)
 assert(U.run({'/bin/true'},{cwd=temp..'/missing'}).code~=0)
 local function descriptors()
  local count=0; for fd=0,255 do if U.stat('/proc/self/fd/'..fd) then count=count+1 end end; return count
 end
 local before=descriptors()
 for _=1,20 do equal(U.run({'/bin/true'}).code,0) end
 equal(descriptors(),before)
end)
test('large simultaneous stdin stdout stderr cannot deadlock',function()
 local input=string.rep('\0\255abc\n',200000)
 local r=U.run({'/usr/bin/luajit','-e','io.stdout:write(string.rep("x",300000)); io.stderr:write(string.rep("y",300000)); io.stdout:write(io.stdin:read("*a"))'},{input=input,max_output=2000000,timeout=5})
 equal(r.code,0); equal(r.stdout,string.rep('x',300000)..input); equal(r.stderr,string.rep('y',300000))
 local limited=U.run({'/usr/bin/luajit','-e','while true do io.write(string.rep("x",65536)) end'},{max_output=1000,timeout=5})
 equal(limited.code,125); equal(#limited.stdout,1000)
end)
test('symlinked launcher discovery and signal cancellation clean picker requests',function()
 local bin=temp..'/cli-bin'; U.mkdir_p(bin)
 local launcher=assert(U.realpath(helpers..'/../../../../bin/launcher'))
 assert(C.symlink(launcher,bin..'/launcher-link')==0)
 local marker=temp..'/cli-marker'; local runtime=temp..'/cli-runtime'; U.mkdir_p(runtime)
 executable(bin..'/qs','#!/usr/bin/luajit\nlocal f=assert(io.open(os.getenv("FIXTURE_MARKER"),"wb")); f:write(arg[4],"\\n",arg[5] or ""); f:close()\n')
 local environment={PATH=bin..':/usr/bin',XDG_RUNTIME_DIR=runtime,FIXTURE_MARKER=marker}
 local r=U.run({'launcher-link','query','literal $(not-executed)'},{env=environment})
 equal(r.code,0); equal(U.read(marker),'query\nliteral $(not-executed)')
 for _,signal in ipairs({2,15}) do
  C.unlink(marker)
  local pid=C.fork(); assert(pid>=0)
  if pid==0 then pcall(U.exec,{'/usr/bin/luajit',bin..'/launcher-link','input'},environment); C._exit(127) end
  local deadline=U.monotime()+3
  while not U.read(marker) and U.monotime()<deadline do U.sleep(.02) end
  local data=U.read(marker); assert(data and data:sub(1,7)=='summon\n')
  local payload=U.decode(data:sub(8)); C.kill(pid,signal)
  local status=ffi.new('int[1]'); local exited=false
  while U.monotime()<deadline do if C.waitpid(pid,status,1)==pid then exited=true; break end; U.sleep(.02) end
  if not exited then C.kill(pid,9); C.waitpid(pid,status,0) end
  assert(exited,'Interrupted CLI did not stop'); equal(bit.rshift(status[0],8),128+signal)
  equal(U.read(marker),'cancelPicker\n'..payload.doneFile)
  equal(U.run({'find',runtime..'/quickshell-launcher','-mindepth','1','-print'}).stdout,'')
 end
 -- Interruption while select waits for stdin must not enter a Lua signal callback.
 local pipe=ffi.new('int[2]'); assert(C.pipe2(pipe,524288)==0)
 local pid=C.fork(); assert(pid>=0)
 if pid==0 then C.dup2(pipe[0],0); C.close(pipe[0]); C.close(pipe[1]); pcall(U.exec,{'/usr/bin/luajit',bin..'/launcher-link','select'},environment); C._exit(127) end
 C.close(pipe[0]); U.sleep(.1); C.kill(pid,2)
 local status=ffi.new('int[1]'); local deadline=U.monotime()+3; local exited=false
 while U.monotime()<deadline do if C.waitpid(pid,status,1)==pid then exited=true; break end; U.sleep(.02) end
 if not exited then C.kill(pid,9); C.waitpid(pid,status,0) end
 C.close(pipe[1]); assert(exited); equal(bit.rshift(status[0],8),130)
end)
test('timeout and cancellation terminate supervised descendants',function()
 local start=U.monotime(); local r=U.run({'/bin/sh','-c','trap "" TERM; /bin/sleep 30'},{timeout=.1})
 assert(r.code~=0 and U.monotime()-start<2.5)
 local worker=temp..'/cancel.lua'; local pids=temp..'/pids'
 U.write(worker,'package.path='..string.format('%q',helpers..'/?.lua;')..'..package.path; local U=require("runtime"); U.run({"/bin/sh","-c",\'trap "" TERM; /bin/sleep 30 & echo "$$ $!" > "$1"; wait\',"fixture",'..string.format('%q',pids)..'},{timeout=60})\n')
 local pid=C.fork(); assert(pid>=0)
 if pid==0 then pcall(U.exec,{'/usr/bin/luajit',worker}); C._exit(127) end
 local deadline=U.monotime()+3
 while not U.read(pids) and U.monotime()<deadline do U.sleep(.02) end
 local data=U.read(pids); C.kill(pid,9); C.waitpid(pid,nil,0); assert(data,'Cancellation child did not start')
 local function alive(id) local st=U.read('/proc/'..id..'/stat'); return st and st:match('%) (%a)')~='Z' end
 deadline=U.monotime()+3
 for id in data:gmatch('%d+') do while alive(id) and U.monotime()<deadline do U.sleep(.02) end; assert(not alive(id),'Child survived cancellation: '..id) end
end)
end)
for key,value in pairs(savedenv) do env(key,value) end
if not savedenv.XDG_CACHE_HOME then C.unsetenv('XDG_CACHE_HOME') end
U.run({'/bin/rm','-rf','--',temp})
if not ok then io.stderr:write(tostring(err)..'\n'); os.exit(1) end
print('NATIVE_HELPERS_PASS: '..tests..' groups, '..checks..' assertions')
