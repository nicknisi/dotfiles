#!/usr/bin/env luajit
-- On-demand IANA conversions using Linux tzdata and libc, including DST folds.
package.path=(debug.getinfo(1,'S').source:sub(2):match('^(.*)/') or '.')..'/?.lua;'..package.path
local U=require('runtime')
local C,ffi=U.C,U.ffi
ffi.cdef[[
struct tm { int tm_sec,tm_min,tm_hour,tm_mday,tm_mon,tm_year,tm_wday,tm_yday,tm_isdst; long tm_gmtoff; const char *tm_zone; };
void tzset(void); long time(long *); long timegm(struct tm *); long mktime(struct tm *);
struct tm *localtime_r(const long *, struct tm *);
]]
local M={}
local aliases={}
local groups={
 {'UTC','utc gmt z zulu'},
 {'America/Los_Angeles','pt pst pdt pacific san_francisco sf la seattle portland san_diego bay_area silicon_valley las_vegas'},
 {'America/Denver','mt mst mdt mountain salt_lake_city'},
 {'America/Chicago','ct cst cdt central austin dallas houston minneapolis'},
 {'America/New_York','et est edt eastern nyc ny boston miami washington dc atlanta philadelphia'},
 {'America/Halifax','ast adt atlantic'},{'America/Anchorage','akst akdt alaska'},{'Pacific/Honolulu','hst hawaii'},
 {'Europe/London','bst uk england britain'},{'Europe/Lisbon','wet west portugal'},
 {'Europe/Berlin','cet cest met mest germany munich frankfurt hamburg cologne'},
 {'Europe/Helsinki','eet eest finland'},{'Europe/Moscow','msk st_petersburg saint_petersburg'},
 {'Europe/Istanbul','trt turkey'},{'Asia/Kolkata','ist india mumbai delhi new_delhi bangalore bengaluru hyderabad chennai pune'},
 {'Asia/Karachi','pkt pakistan'},{'Asia/Bangkok','ict thailand'},{'Asia/Jakarta','wib'},
 {'Asia/Singapore','sgt'},{'Asia/Hong_Kong','hkt'},{'Asia/Tokyo','jst japan osaka'},{'Asia/Seoul','kst korea south_korea'},
 {'Asia/Dubai','gst uae'},{'Asia/Jerusalem','idt israel tel_aviv'},
 {'Australia/Sydney','aest aedt aet'},{'Australia/Adelaide','acst acdt'},{'Australia/Perth','awst'},
 {'Pacific/Auckland','nzst nzdt nzt auckland new_zealand wellington'},
 {'Africa/Johannesburg','sast south_africa cape_town'},{'Africa/Lagos','wat nigeria'},{'Africa/Nairobi','eat kenya'},
 {'America/Sao_Paulo','brt rio rio_de_janeiro'},{'America/Argentina/Buenos_Aires','art argentina'},
 {'America/Toronto','montreal ottawa'},{'America/Edmonton','calgary'},
 {'Europe/Dublin','ireland'},{'Europe/Madrid','spain barcelona'},{'Europe/Paris','france'},
 {'Europe/Rome','italy milan'},{'Europe/Amsterdam','netherlands holland'},{'Europe/Brussels','belgium'},
 {'Europe/Zurich','switzerland geneva'},{'Europe/Vienna','austria'},{'Europe/Stockholm','sweden'},
 {'Europe/Oslo','norway'},{'Europe/Copenhagen','denmark'},{'Europe/Tallinn','estonia'},
 {'Europe/Riga','latvia'},{'Europe/Vilnius','lithuania'},{'Europe/Warsaw','poland krakow'},
 {'Europe/Prague','czechia czech'},{'Europe/Budapest','hungary'},{'Europe/Bucharest','romania'},
 {'Europe/Athens','greece'},{'Europe/Kyiv','ukraine kiev'},{'Asia/Riyadh','saudi'},
 {'Asia/Ho_Chi_Minh','vietnam hanoi saigon'},{'Asia/Manila','philippines'},
 {'Asia/Shanghai','china beijing shenzhen hangzhou'},{'Asia/Taipei','taiwan'},{'Africa/Cairo','egypt'},
 {'America/Bogota','colombia'},{'America/Lima','peru'},{'America/Santiago','chile'}
}
for _,group in ipairs(groups) do for alias in group[2]:gmatch('%S+') do aliases[alias:gsub('_',' ')]=group[1] end end
M.ALIASES=aliases
local ambiguous={usa='et, ct, mt or pt',us='et, ct, mt or pt',america='et, ct, mt or pt',['united states']='et, ct, mt or pt',canada='toronto or vancouver',australia='sydney, adelaide or perth',brazil='sao paulo',russia='moscow',mexico='mexico city',indonesia='jakarta',europe='cet or eet'}
local locals={here=true,['local']=true,['local time']=true,me=true,mine=true,['my time']=true,['my zone']=true,['my timezone']=true,['my time zone']=true}
local weekdays={'monday','tuesday','wednesday','thursday','friday','saturday','sunday'}
local months={'january','february','march','april','may','june','july','august','september','october','november','december'}
local weekday_words={mon=1,monday=1,tue=2,tues=2,tuesday=2,wed=3,weds=3,wednesday=3,thu=4,thur=4,thurs=4,thursday=4,fri=5,friday=5,sat=6,saturday=6,sun=7,sunday=7}
local month_words={sept=9}; for i,m in ipairs(months) do month_words[m]=i; month_words[m:sub(1,3)]=i end
local function trim(s) return s:match('^%s*(.-)%s*$') end
local function fail(s) error(s,0) end
local function hint(s) error({error=s,hint=true},0) end
function M.normalize(text)
 text=tostring(text):lower():gsub('%s+',' ')
 for _,arrow in ipairs({'%-%>','→','=>','>'}) do text=text:gsub('%s*'..arrow..'%s*',' to ') end
 return text:gsub('^[ ?.!]+',''):gsub('[ ?.!]+$','')
end
local zones
local function zone_names()
 if zones then return zones end
 local r=U.run({'find','/usr/share/zoneinfo','-name','posix','-prune','-o','-name','right','-prune','-o','-type','f','-print','-o','-type','l','-print'},{timeout=2})
 assert(r.code==0,'Time-zone data unavailable'); zones={}
 for path in r.stdout:gmatch('[^\n]+') do
  local name=path:sub(21)
  if not name:find('%.') and name~='leapseconds' then zones[#zones+1]=name end
 end
 table.sort(zones); return zones
end
local function iana(name)
 assert(type(name)=='string' and name~='' and not name:find('[%z\\]') and not name:find('..',1,true) and name:sub(1,1)~='/', 'Unknown time zone')
 local f=io.open('/usr/share/zoneinfo/'..name,'rb'); local magic=f and f:read(4); if f then f:close() end
 assert(magic=='TZif','Unknown time zone: '..name); return ':'..'/usr/share/zoneinfo/'..name
end
local Zone={}; Zone.__index=Zone
function Zone:note()
 if self.key=='here' then return '' end
 local parts={}; for p in self.key:lower():gmatch('[^/_]+') do parts[p]=true end
 for word in self.typed:gmatch('[^/_ ]+') do if not parts[word] then return self.typed..' = '..self.key end end
 return ''
end
local function zone(typed,key,tz,offset) return setmetatable({typed=typed,key=key,tz=tz,offset=offset},Zone) end
function M.resolve(name,local_zone)
 name=trim(name); if name=='' then fail('Which time zone?') end
 if locals[name] then return zone(name,'here',iana(local_zone)) end
 if ambiguous[name] then hint(name:gsub('(%a)([%w]*)',function(a,b) return a:upper()..b end)..' spans several time zones; try '..ambiguous[name]) end
 local offset=name:gsub('^utc',''):gsub('^gmt',''):gsub('^z','')
 local sign,number=offset:match('^%s*([+-])%s*(%d+:?%d*)$')
 if sign then
  local h,m=number:match('^(%d%d?):([0-5]%d)$')
  if not h then
   if #number<=2 then h,m=number,'0'
   elseif #number==3 or #number==4 then h,m=number:sub(1,-3),number:sub(-2); if tonumber(m)>59 then h=nil end end
  end
  if h then
   h,m=tonumber(h),tonumber(m); if h*60+m>1080 then fail('Offset out of range') end
   local key=string.format('UTC%s%02d:%02d',sign,h,m)
   return zone(name,key,'UTC0',(sign=='-' and -1 or 1)*(h*3600+m*60))
  end
 end
 if aliases[name] then return zone(name,aliases[name],iana(aliases[name])) end
 local wanted=name:gsub(' ','_'); local matches={}
 for _,z in ipairs(zone_names()) do
  if z:lower()==wanted then return zone(name,z,iana(z)) end
  if z:find('/',1,true) and z:match('([^/]+)$'):lower()==wanted then matches[#matches+1]=z end
 end
 if #matches==1 then return zone(name,matches[1],iana(matches[1])) end
 if #matches>1 then hint('Which '..name..'? Try '..table.concat(matches,' or ',1,math.min(3,#matches))) end
 fail('Unknown time zone: '..name)
end
local function setzone(z) assert(C.setenv('TZ',z.tz,1)==0,U.error()); C.tzset() end
local function localtime(epoch,z)
 setzone(z); local t=ffi.new('long[1]',epoch+(z.offset or 0)); local tm=ffi.new('struct tm[1]'); assert(C.localtime_r(t,tm)~=nil,'Invalid time')
 return {year=tonumber(tm[0].tm_year)+1900,month=tonumber(tm[0].tm_mon)+1,day=tonumber(tm[0].tm_mday),hour=tonumber(tm[0].tm_hour),minute=tonumber(tm[0].tm_min),second=tonumber(tm[0].tm_sec),weekday=(tonumber(tm[0].tm_wday)+6)%7+1,offset=z.offset or tonumber(tm[0].tm_gmtoff),abbr=z.offset and z.key or ffi.string(tm[0].tm_zone)}
end
local utc=zone('utc','UTC','UTC0',0)
local function naive(d,h,m,s)
 assert(d.year>=1 and d.year<=9999 and d.month>=1 and d.month<=12 and d.day>=1 and d.day<=31,'Invalid date')
 local tm=ffi.new('struct tm[1]'); tm[0].tm_year=d.year-1900; tm[0].tm_mon=d.month-1; tm[0].tm_mday=d.day; tm[0].tm_hour=h or 0; tm[0].tm_min=m or 0; tm[0].tm_sec=s or 0
 local epoch=tonumber(C.timegm(tm)); assert(tm[0].tm_year==d.year-1900 and tm[0].tm_mon==d.month-1 and tm[0].tm_mday==d.day,'Invalid date'); return epoch
end
local function same(a,b) return a.year==b.year and a.month==b.month and a.day==b.day and a.hour==b.hour and a.minute==b.minute end
local function instant(d,h,m,z)
 local wall=naive(d,h,m); local offsets={}
 -- Collect both sides of nearby transitions, including non-DST political
 -- changes and half-hour folds, then round-trip every candidate wall time.
 for hours=-48,48,6 do local t=localtime(wall+hours*3600,z); offsets[t.offset]=true end
 local matches={}; local wanted={year=d.year,month=d.month,day=d.day,hour=h,minute=m}
 for offset in pairs(offsets) do local candidate=wall-offset; if same(localtime(candidate,z),wanted) then matches[#matches+1]=candidate end end
 if #matches==0 then hint('That time does not exist during the daylight-saving change') end
 if #matches>1 then hint('That time occurs twice during the daylight-saving change') end
 return matches[1]
end
local function date_match(text)
 local y,mo,d=text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$'); if y then return {year=tonumber(y),month=tonumber(mo),day=tonumber(d)} end
 local rel={today=0,tonight=0,tomorrow=1,tmrw=1,tmr=1,yesterday=-1}
 if rel[text] then return {rel=rel[text]} end
 local nextword,wd=text:match('^(%a+) (%a+)$')
 if weekday_words[text] then return {weekday=weekday_words[text]} end
 if (nextword=='next' or nextword=='this') and weekday_words[wd] then return {weekday=weekday_words[wd],next=nextword=='next'} end
 text=text:gsub('(%d)(st)%f[%A]','%1'):gsub('(%d)(nd)%f[%A]','%1'):gsub('(%d)(rd)%f[%A]','%1'):gsub('(%d)(th)%f[%A]','%1')
 local a,b,year=text:match('^(%S+) (%S+),? (%d%d%d%d)$')
 if not a then a,b=text:match('^(%S+) (%S+)$') end
 if not a then return nil end
 b=b:gsub(',$','')
 if a:match('^%d%d?$') and month_words[b] then return {day=tonumber(a),month=month_words[b],year=tonumber(year)} end
 if month_words[a] and b:match('^%d%d?$') then return {day=tonumber(b),month=month_words[a],year=tonumber(year)} end
end
function M.split_date(text)
 -- Suffix first, then prefix, then "on DATE to ZONE", matching the UI grammar.
 for pos in text:gmatch('() ') do
  local rest=text:sub(1,pos-1); local suffix=text:sub(pos+1):gsub('^on ',''); local d=date_match(suffix)
  if d then
   rest=rest:gsub(' on$',''); local last=rest:match('(%S+)$')
   if not ({['in']=true,from=true,at=true,to=true,['for']=true,on=true})[last] then return rest,d end
  end
 end
 local prefix=text:gsub('^on ','')
 local positions={}; for pos in prefix:gmatch('() ') do positions[#positions+1]=pos end
 for i=#positions,1,-1 do local pos=positions[i]; local d=date_match(prefix:sub(1,pos-1)); if d then return prefix:sub(pos+1):gsub('^at ',''),d end end
 local before,tail=text:match('^(.-) on (.+)$')
 if before then for pos in tail:gmatch('() ') do local d=date_match(tail:sub(1,pos-1)); local rest=tail:sub(pos+1); if d and rest:match('^(%a+) ') and ({to=true,['in']=true,['for']=true,as=true,vs=true})[rest:match('^(%a+) ')] then return before..' '..rest,d end end end
 return text,nil
end
local function time_query(text)
 local word,rest=text:match('^(%a+)(.*)$')
 local h,m,explicit
 if word=='noon' or word=='midday' or word=='midnight' then h,m,explicit=word=='midnight' and 0 or 12,0,true
 else
  local compact,tail=text:match('^(%d%d%d%d)(.*)$')
  if compact and not tail:match('^%d') and tonumber(compact:sub(1,2))<=23 and tonumber(compact:sub(3,4))<=59 then h,m,rest,explicit=tonumber(compact:sub(1,2)),tonumber(compact:sub(3,4)),tail,true
  else
   local hour,minute,tail2=text:match('^(%d%d?)[:.]([0-5]%d)(.*)$')
   if hour then h,m,rest,explicit=tonumber(hour),tonumber(minute),tail2,true
   else hour,rest=text:match('^(%d%d?)(.*)$'); if not hour then return nil end; h,m=tonumber(hour),0 end
   rest=trim(rest)
   local ap,after=rest:match('^([ap]%.?m%.?)(.*)$')
   if ap and not after:match('^[a-z]') then if h<1 or h>12 then fail('Invalid 12-hour time') end; h=h%12+(ap:sub(1,1)=='p' and 12 or 0); rest=after; explicit=true end
   if h>23 then fail('Invalid time') end
  end
 end
 rest=trim(rest)
 local sep,after=rest:match('^(%S+) (.*)$')
 if sep=='in' or sep=='from' or sep=='at' or sep=='@' then explicit=true; rest=after end
 return {hour=h,minute=m,rest=rest,explicit=explicit}
end
function M.parse(text,local_zone)
 text=M.normalize(text)
 local before,name=text:match('^(.-) in (.+)$')
 if not before then before,name=text:match('^(.-) at (.+)$') end
 if not before then before,name=text:match('^(.-) for (.+)$') end
 if not before then before,name=text:match('^(.-) of (.+)$') end
 if before then
  local now=before:gsub('^what\'s ',''):gsub('^what is ',''):gsub('^what ',''):gsub('^the ',''):gsub('^current ',''):gsub('^local ',''):gsub(' is it',''):gsub(' right now$',''):gsub(' now$','')
  if now=='time' or now=='now' or now=='date' then return {mode='now',zone=M.resolve(name,local_zone)} end
 end
 local zonename=text:match('^(.-) time$') or text:match('^(.-) now$')
 if zonename and not time_query(text) then return {mode='now',zone=M.resolve(zonename,local_zone)} end
 local date; text,date=M.split_date(text)
 local parsed=time_query(text)
 if not parsed or not parsed.explicit then fail('Not a time conversion') end
 local rest=trim(parsed.rest); local source,target
 if rest:sub(1,3)=='to ' then source,target='here',rest:sub(4)
 else
  local at,finish
  for _,sep in ipairs({'to','in','for','as','vs'}) do local a,b=rest:find(' '..sep..' ',1,true); if a and (not at or a<at) then at,finish=a,b end end
  source=at and rest:sub(1,at-1) or rest; target=at and rest:sub(finish+1) or 'here'
 end
 return {mode='at',hour=parsed.hour,minute=parsed.minute,source=M.resolve(source,local_zone),target=M.resolve(target,local_zone),date=date}
end
local function resolve_date(d,today)
 if not d then return today end
 if d.rel or d.weekday then
  local ahead=d.rel or (d.weekday-today.weekday)%7
  if ahead==0 and d.next then ahead=7 end
  return localtime(naive(today)+ahead*86400,utc)
 end
 return {year=d.year or today.year,month=d.month,day=d.day}
end
local function clock(t) return string.format('%02d:%02d %s',t.hour,t.minute,t.abbr) end
local function detail(t) return weekdays[t.weekday]:sub(1,1):upper()..weekdays[t.weekday]:sub(2,3)..string.format(', %02d ',t.day)..months[t.month]:sub(1,1):upper()..months[t.month]:sub(2,3)..' · '..clock(t) end
function M.now(text)
 if not text then return tonumber(C.time(nil)) end
 local y,mo,d,h,m,s,tail=text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)(.*)$')
 assert(y,'Invalid ISO instant'); assert(tonumber(h)<24 and tonumber(m)<60 and tonumber(s)<60,'Invalid ISO instant')
 tail=tail:gsub('^%.%d+','')
 local offset=0
 if tail~='' and tail~='Z' then local sign,oh,om=tail:match('^([+-])(%d%d):?(%d%d)$'); assert(sign and tonumber(oh)<24 and tonumber(om)<60,'Invalid ISO instant'); offset=(sign=='-' and -1 or 1)*(tonumber(oh)*3600+tonumber(om)*60) end
 return naive({year=tonumber(y),month=tonumber(mo),day=tonumber(d)},tonumber(h),tonumber(m),tonumber(s))-offset
end
function M.convert_time(text,local_zone,now)
 now=type(now)=='number' and now or M.now(now)
 local p=M.parse(text,local_zone)
 if p.mode=='now' then local t=localtime(now,p.zone); return {result=clock(t),detail=detail(t)..' in '..p.zone.key..' · '..clock(localtime(now,zone('here','here',iana(local_zone))))..' here',live=true} end
 local date=resolve_date(p.date,localtime(now,p.source))
 local epoch=instant(date,p.hour,p.minute,p.source)
 local source,target=localtime(epoch,p.source),localtime(epoch,p.target)
 local notes={}; for _,z in ipairs({p.source,p.target}) do local note=z:note(); if note~='' then notes[#notes+1]=note end end
 return {result=clock(target),detail=detail(source)..' → '..detail(target)..(#notes>0 and ' · '..table.concat(notes,', ') or '')}
end
function M.main(args)
 local ok,result=pcall(M.convert_time,args[1],args[2],args[3])
 print(U.encode(ok and result or type(result)=='table' and result or {error=tostring(result)})); return 0
end
if ...~='timezone' then os.exit(M.main(arg)) end
return M
