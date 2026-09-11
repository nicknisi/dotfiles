#!/usr/bin/env luajit
-- Join live binds to explicitly registered callbacks, without invoking them.
package.path=(debug.getinfo(1,'S').source:sub(2):match('^(.*)/') or '.')..'/?.lua;'..package.path
local U=require('runtime')
local bit=require('bit')
local M={MAX_REGISTRY_OUTPUT=262144,MAX_BINDINGS=1024}
M.REGISTRY_ARGV={'hyprctl','repl','return _G.launcher_bindings and _G.launcher_bindings.snapshot() or "{}"'}
M.IDENTITY_FIELDS={'arg','key','keycode','modmask','submap','release','longPress','mouse','repeat'}
local defaults={'','',0,0,'',false,false,false,false}
local modifiers={{64,'SUPER'},{1,'SHIFT'},{4,'CTRL'},{8,'ALT'},{2,'CAPS'},{16,'MOD2'},{32,'MOD3'},{128,'MOD5'}}
local labels={
 ['SUPER + SPACE']='Launcher',['SUPER + V']='Clipboard History',
 PRINT='Screenshot Region',['SHIFT + PRINT']='Screenshot Screen',['ALT + PRINT']='Annotate Screenshot',
 ['SUPER + PRINT']='Record Region',['SUPER SHIFT + PRINT']='Stop Recording',['SUPER + RETURN']='Terminal',
 ['SUPER SHIFT + RETURN']='Browser',['SUPER + Q']='Close window',['SUPER + ESCAPE']='Lock',
 ['SUPER SHIFT + ESCAPE']='Log out',['SUPER SHIFT + F']='Full screen',['SUPER + F']='Maximize window',
 ['SUPER SHIFT + SPACE']='Toggle floating',['SUPER + SLASH']='Toggle split',['SUPER + COMMA']='Toggle window group',
 ['SUPER ALT + L']='Toggle workspace layout',['SUPER CTRL + SPACE']='Center window',
 ['SUPER + mouse:272']='Drag window',['SUPER + mouse:273']='Resize window',['SUPER + code:19']='Next theme',
 ['SUPER CTRL + code:19']='Next wallpaper',['SUPER + TAB']='Previous workspace',
 ['SUPER SHIFT + TAB']='Move workspace to next monitor',['SUPER SHIFT + EQUAL']='Grow window',['SUPER SHIFT + MINUS']='Shrink window'
}
for i,key in ipairs({'H','J','K','L'}) do
 for mods,action in pairs({SUPER='Focus',['SUPER SHIFT']='Move window',['SUPER CTRL']='Nudge floating window'}) do
  labels[mods..' + '..key]=action..' '..({'left','down','up','right'})[i]
 end
end
local workspaces={B='W',P='S',S='S'}
for key in ('ACDNTWXZ'):gmatch('.') do workspaces[key]=key end
for n=1,9 do workspaces['code:'..(n+9)]=tostring(n) end
for key,workspace in pairs(workspaces) do labels['SUPER + '..key]='Workspace '..workspace; labels['SUPER SHIFT + '..key]='Move window to workspace '..workspace end
function M.lua_string(value)
 return '"'..value:gsub('[%z\1-\31\127\\"]',function(c) return (c=='\\' or c=='"') and '\\'..c or string.format('\\%03d',c:byte()) end)..'"'
end
-- POSIX shlex splitting for the permitted non-shell exec subset.
local function split(command)
 local out,word,quote,started={},'',nil,false
 local i=1
 while i<=#command do
  local c=command:sub(i,i)
  if quote=="'" then if c=="'" then quote=nil else word=word..c end
  elseif c=='\\' then
   i=i+1; local nextc=command:sub(i,i); if nextc=='' then return nil end
   word=word..((quote=='"' and nextc~='"' and nextc~='\\') and '\\'..nextc or nextc); started=true
  elseif quote=='"' then if c=='"' then quote=nil else word=word..c end
  elseif c=='"' or c=="'" then quote=c; started=true
  elseif c:match('%s') then if started then out[#out+1]=word; word=''; started=false end
  else word=word..c; started=true end
  i=i+1
 end
 if quote then return nil end
 if started then out[#out+1]=word end
 return out
end
function M.dispatch_argv(dispatcher,arg)
 local empty=U.array()
 if arg:find('\0',1,true) then return empty end
 if dispatcher=='exec' then
  if arg:find('[$`;|&<>\n\r]') or arg:match('^%s*%[') then return empty end
  local argv=split(arg)
  if not argv or not argv[1] or argv[1]:find('=',1,true) or argv[1]:sub(1,1)=='~' then return empty end
  local out=U.array({'uwsm-app','--'}); for _,v in ipairs(argv) do out[#out+1]=v end; return out
 end
 local expression
 if dispatcher=='killactive' and arg=='' then expression='hl.dsp.window.close()'
 elseif dispatcher=='togglefloating' and arg=='' then expression='hl.dsp.window.float({ action = "toggle" })'
 elseif dispatcher=='fullscreen' and (arg=='' or arg=='0' or arg=='1') then expression='hl.dsp.window.fullscreen({ mode = '..M.lua_string(arg=='1' and 'maximized' or 'fullscreen')..' })'
 elseif (dispatcher=='movefocus' or dispatcher=='movewindow') and arg:match('^[lrud]$') then
  expression=(dispatcher=='movefocus' and 'hl.dsp.focus' or 'hl.dsp.window.move')..'({ direction = '..M.lua_string(arg)..' })'
 elseif (dispatcher=='workspace' or dispatcher=='movetoworkspace' or dispatcher=='movetoworkspacesilent') and (arg:match('^[+-]?%d+$') or arg:match('^name:[^,\n\r]+$') or arg=='previous' or arg=='empty') then
  expression=(dispatcher=='workspace' and 'hl.dsp.focus' or 'hl.dsp.window.move')..'({ workspace = '..M.lua_string(arg)
  if dispatcher~='workspace' then expression=expression..', follow = '..tostring(dispatcher~='movetoworkspacesilent') end
  expression=expression..' })'
 elseif dispatcher=='dpms' and (arg=='on' or arg=='off') then expression='hl.dsp.dpms({ action = '..M.lua_string(arg)..' })'
 elseif dispatcher=='togglesplit' and arg=='' then expression='hl.dsp.layout("togglesplit")' end
 return expression and U.array({'hyprctl','dispatch',expression}) or empty
end
local function truth(v) return v~=nil and v~=false and v~=U.null and v~='' and v~=0 end
local function str(v) return truth(v) and tostring(v) or '' end
local function object(v) return type(v)=='table' and v~=U.null and (not getmetatable(v) or getmetatable(v).__jsontype~='array') end
local function array(v) return type(v)=='table' and v~=U.null and (not getmetatable(v) or getmetatable(v).__jsontype~='object') end
function M.keyboard_only(b)
 return truth(b.release) or truth(b.longPress) or truth(b.mouse) or truth(b.submap) or truth(b.catch_all) or b.enabled==false or str(b.key):lower():find('mouse',1,true)~=nil
end
function M.identity(b)
 local values=U.array()
 for i,field in ipairs(M.IDENTITY_FIELDS) do
  local v=b[field]; if v==nil then v=defaults[i] end
  assert(type(v)==type(defaults[i]) and (type(v)~='number' or v%1==0),'Invalid binding identity'); values[i]=v
 end
 return U.encode(values)
end
function M.registry_index(snapshot)
 if not object(snapshot) then return {} end
 local generation,bindings=snapshot.generation,snapshot.bindings
 if type(generation)~='string' or #generation~=32 or not generation:match('^[0-9a-f]+$') or not array(bindings) or #bindings>M.MAX_BINDINGS then return {} end
 local index,ids={},{}
 local ok=pcall(function()
  for _,bind in ipairs(bindings) do
   assert(object(bind))
   for _,field in ipairs(M.IDENTITY_FIELDS) do assert(bind[field]~=nil) end
   local id=bind.id; assert(type(id)=='number' and id%1==0 and id>=1 and id<=M.MAX_BINDINGS and not ids[id]); ids[id]=true
   local key=M.identity(bind); assert(not index[key] and not M.keyboard_only(bind)); index[key]={generation=generation,id=id}
  end
 end)
 return ok and index or {}
end
function M.registered_argv(r) return U.array({'hyprctl','dispatch','_G.launcher_bindings.resolve('..M.lua_string(r.generation)..', '..r.id..')'}) end
function M.normalize(records,snapshot)
 local registered,out=M.registry_index(snapshot),U.array()
 for _,b in ipairs(array(records) and records or {}) do if object(b) then
  local key=str(b.key); if key=='' and truth(b.keycode) then key='code:'..tostring(b.keycode) end
  local mask=tonumber(b.modmask or 0)
  if key~='' and mask and mask==mask and math.abs(mask)<math.huge then
   local mods={}; for _,m in ipairs(modifiers) do if bit.band(mask,m[1])~=0 then mods[#mods+1]=m[2] end end
   local combo=(#mods>0 and table.concat(mods,' ')..' + ' or '')..key
   local dispatcher,arg,description=str(b.dispatcher),str(b.arg),str(b.description)
   local hint=(not truth(b.submap) and labels[combo]) or ''
   local label=description~='' and description or hint~='' and hint or (key:sub(1,4)=='XF86' and key:sub(5) or dispatcher..(dispatcher=='__lua' and ' callback' or ' '..arg))
   local registration,argv=U.null,U.array()
   if not M.keyboard_only(b) then
    if dispatcher=='__lua' then local ok,id=pcall(M.identity,b); registration=ok and registered[id] or U.null; if registration~=U.null then argv=M.registered_argv(registration) end
    else argv=M.dispatch_argv(dispatcher,arg) end
   end
   out[#out+1]={combo=combo,label=label,description=description,labelHint=hint~='' and description=='',dispatcher=dispatcher,arg=arg,argv=argv,registration=registration,submap=str(b.submap),release=truth(b.release),['repeat']=truth(b['repeat']),longPress=truth(b.longPress),mouse=truth(b.mouse) or key:lower():find('mouse',1,true)~=nil,catch_all=truth(b.catch_all),enabled=b.enabled~=false}
  end
 end end
 return out
end
function M.main()
 local snapshot
 pcall(function() local r=U.run(M.REGISTRY_ARGV,{timeout=5,max_output=M.MAX_REGISTRY_OUTPUT}); if r.code==0 and #r.stdout<=M.MAX_REGISTRY_OUTPUT then snapshot=U.decode(r.stdout) end end)
 local ok,rows=pcall(function() local r=U.run({'hyprctl','binds','-j'},{timeout=5}); assert(r.code==0); return M.normalize(U.decode(r.stdout),snapshot) end)
 if not ok then return 1 end
 print(U.encode(rows)); return 0
end
if ...~='hotkeys' then os.exit(M.main()) end
return M
