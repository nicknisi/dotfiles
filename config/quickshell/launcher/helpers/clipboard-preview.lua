#!/usr/bin/env luajit
-- Decode one numeric cliphist ID, never list/store/wipe history or log content.
package.path=(debug.getinfo(1,'S').source:sub(2):match('^(.*)/') or '.')..'/?.lua;'..package.path
local U=require('runtime')
local C,ffi,bit=U.C,U.ffi,require('bit')
local M={TEXT_LIMIT=12000,IMAGE_LIMIT=8*1024*1024}
local script=assert(U.realpath(debug.getinfo(1,'S').source:sub(2)))
local interpreter=assert(U.realpath('/proc/self/exe'))
function M.valid_id(value)
 assert(type(value)=='string' and #value>=1 and #value<=20 and value:match('^[0-9]+$'),'Invalid clipboard ID'); return value
end
function M.decode(id,limit)
 local r=U.run({'cliphist','decode',M.valid_id(id)},{timeout=5,max_output=limit+1})
 assert(r.code==0 or (r.code==125 and #r.stdout>limit),'Clipboard item unavailable')
 return r.stdout:sub(1,limit),#r.stdout>limit
end
M.text = U.text
local function basepath() return (os.getenv('XDG_CACHE_HOME') or assert(os.getenv('HOME'))..'/.cache'):gsub('/+$','')..'/quickshell' end
local function cache()
 local base=basepath(); U.mkdir_p(base,448)
 local fd=C.open(base,65536+131072+524288); assert(fd>=0,U.error())
 local ok,err=pcall(function() local st=assert(U.stat_at(fd,'',4096)); assert(st.type=='directory' and st.uid==C.getuid(),'Invalid preview owner'); assert(C.fchmod(fd,448)==0,U.error()) end)
 if not ok then C.close(fd); error(err) end
 return base,fd
end
function M.preview(id,kind)
 local data,truncated=M.decode(id,kind=='image' and M.IMAGE_LIMIT or M.TEXT_LIMIT*4)
 if kind=='text' then local text,cut=M.text(data,M.TEXT_LIMIT); return {id=id,text=text,truncated=truncated or cut} end
 if truncated then return {id=id,error='Image exceeds the 8 MiB preview limit'} end
 local raster=false
 for _,magic in ipairs({'\137PNG\r\n\26\n','\255\216\255','GIF87a','GIF89a','BM','II*\0','MM\0*'}) do if data:sub(1,#magic)==magic then raster=true end end
 assert(raster or (data:sub(1,4)=='RIFF' and data:sub(9,12)=='WEBP'),'Unsupported raster image')
 local base,basefd=cache(); local directory,path
 local ok,result=pcall(function()
  directory=U.tmpdir(base,'clipboard-preview-')
  U.atomic_write(directory..'/input',data)
  local r=U.run({'magick','-limit','memory','32MiB','-limit','map','64MiB','-limit','disk','0','-limit','width','16384','-limit','height','16384',directory..'/input[0]','-thumbnail','960x640>','-strip','png:-'},{timeout=8,max_output=M.IMAGE_LIMIT})
  assert(r.code==0 and #r.stdout<=M.IMAGE_LIMIT,'Image preview unavailable')
  local template=base..'/clipboard-preview-XXXXXX'; local buf=ffi.new('char[?]',#template+1,template)
  local fd=C.mkstemp(buf); assert(fd>=0,U.error()); path=ffi.string(buf)
  local written,err=pcall(function() assert(C.fchmod(fd,384)==0,U.error()); U.write_fd(fd,r.stdout); assert(C.rename(path,path..'.png')==0,U.error()); path=path..'.png' end)
  C.close(fd); if not written then error(err) end
  return {id=id,image=path}
 end)
 if directory then C.unlink(directory..'/input'); C.rmdir(directory) end
 if not ok and path then C.unlink(path) end
 C.close(basefd); if not ok then error(result) end
 return result
end
-- The only pipeline is literal argv, supervised by U.run's timeout group.
-- It streams arbitrary binary clips without a memory or thumbnail-size limit.
function M.pipe(id,mime)
 M.valid_id(id); assert(mime=='' or mime:match('^[a-z0-9.+%-]+/[a-z0-9.+%-]+$'),'Invalid MIME type')
 local pipe=ffi.new('int[2]'); assert(C.pipe2(pipe,524288)==0,U.error())
 local children={}
 for i=1,2 do
  local pid=C.fork()
  if pid==0 then
   if i==1 then C.dup2(pipe[1],1) else C.dup2(pipe[0],0) end
   C.close(pipe[0]); C.close(pipe[1])
   local devnull=C.open('/dev/null',1); if devnull>=0 then C.dup2(devnull,2); C.close(devnull) end
   local argv=i==1 and {'cliphist','decode',id} or {'wl-copy'}
   if i==2 and mime~='' then argv[#argv+1]='--type'; argv[#argv+1]=mime end
   pcall(U.exec,argv); C._exit(127)
  end
  if pid<0 then for _,child in ipairs(children) do C.kill(child,9); C.waitpid(child,nil,0) end; C.close(pipe[0]); C.close(pipe[1]); error(U.error()) end
  children[#children+1]=pid
 end
 C.close(pipe[0]); C.close(pipe[1])
 local failed=false; local status=ffi.new('int[1]')
 for i,child in ipairs(children) do
  local deadline=U.monotime()+20
  while true do
   local r=C.waitpid(child,status,1)
   if r==child then if status[0]~=0 then failed=true end; break end
   if r<0 and ffi.errno()~=4 then failed=true; break end
   if failed or U.monotime()>=deadline then
    failed=true; C.kill(child,9); C.waitpid(child,status,0); break
   end
   U.sleep(.01)
  end
  if failed then for j=i+1,#children do C.kill(children[j],9) end end
 end
 assert(not failed,'Could not copy clipboard item')
end
require('jit').off(M.pipe,true)
function M.copy(id,mime)
 M.valid_id(id); assert(mime=='' or mime:match('^[a-z0-9.+%-]+/[a-z0-9.+%-]+$'),'Invalid MIME type')
 local r=U.run({interpreter,script,'pipe',id,mime},{timeout=40,max_output=4096})
 assert(r.code==0,'Could not copy clipboard item')
end
function M.cleanup(path)
 local base=basepath(); local parent,name=path:match('^(.*)/([^/]+)$')
 assert(parent==base and name:match('^clipboard%-preview%-[A-Za-z0-9_-]+%.png$'),'Invalid preview path')
 local info=U.stat(base,true); if not info then return end
 local fd=C.open(base,65536+131072+524288); assert(fd>=0,U.error())
 local ok,err=pcall(function()
  local root=assert(U.stat_at(fd,'',4096)); assert(root.uid==C.getuid(),'Invalid preview owner')
  local st=U.stat_at(fd,name,256)
  if st then assert(st.type=='file' and st.uid==C.getuid(),'Invalid preview owner'); assert(C.unlinkat(fd,name,0)==0,U.error()) end
 end)
 C.close(fd); if not ok then error(err) end
end
function M.main(args)
 local mode,id,kind=args[1],args[2],args[3] or 'text'
 local ok=pcall(function()
  assert(#args>=2 and #args<=3)
  if mode=='cleanup' then M.cleanup(id)
  elseif mode=='copy' then M.copy(id,kind=='text' and '' or kind)
  elseif mode=='pipe' then M.pipe(id,kind)
  else assert(mode=='preview' and (kind=='text' or kind=='image')); M.valid_id(id); print(U.encode(M.preview(id,kind))) end
 end)
 if ok then return 0 end
 if mode=='preview' then print(U.encode({id=pcall(M.valid_id,id) and id or '',error='Preview unavailable'})) else io.stderr:write('Clipboard operation failed\n') end
 return 1
end
if ...~='clipboard-preview' then os.exit(M.main(arg)) end
return M
