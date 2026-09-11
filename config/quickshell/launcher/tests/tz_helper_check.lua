#!/usr/bin/env luajit
-- Fixed-clock coverage of the production Lua timezone helper.
local here=arg[0]:match('^(.*)/') or '.'
package.path=here..'/../helpers/?.lua;'..package.path
local U=require('runtime')
local helper=here..'/../helpers/timezone.lua'
local now='2026-09-09T12:00:00+00:00'
local cases={
 {'10 am in london on 2026-09-06','Europe/Tallinn',{result='12:00 EEST'}},
 {'11 pm in new york to tokyo on 2026-09-06','Europe/Tallinn',{result='12:00 JST'}},
 {'1:30 am in london on 2026-03-29','Europe/Tallinn',{error='does not exist'}},
 {'1:30 am in london on 2026-10-25','Europe/Tallinn',{error='occurs twice'}},
 {'13 pm in london','Europe/Tallinn',{error='Invalid 12-hour'}},
 {'chrome','Europe/Tallinn',{error='Not a time conversion'}},
 {'10 chrome','Europe/Tallinn',{error='Not a time conversion'}},
 {'10am pt','Europe/Tallinn',{result='20:00 EEST',detail='pt = America/Los_Angeles'}},
 {'10:30pm est','Europe/Tallinn',{result='05:30 EEST',detail='Thu, 10 Sep'}},
 {'10am pst to cet','Europe/Tallinn',{result='19:00 CEST'}},
 {'10am ist','Europe/Tallinn',{result='07:30 EEST',detail='Asia/Kolkata'}},
 {'9am aest','UTC',{result='23:00 UTC',detail='Tue, 08 Sep'}},
 {'10 a.m. pt','Europe/Tallinn',{result='20:00 EEST'}},
 {'10am pt in my time','Europe/Tallinn',{result='20:00 EEST'}},
 {'10am from pt to here','Europe/Tallinn',{result='20:00 EEST'}},
 {'10.30 in london','Europe/Tallinn',{result='12:30 EEST'}},
 {'10 in london','Europe/Tallinn',{result='12:00 EEST'}},
 {'1530 utc','Europe/Tallinn',{result='18:30 EEST'}},
 {'15:00 cet','Europe/Tallinn',{result='16:00 EEST'}},
 {'noon utc','Europe/Tallinn',{result='15:00 EEST'}},
 {'midnight pt to tokyo','Europe/Tallinn',{result='16:00 JST'}},
 {'10am pt -> tokyo','Europe/Tallinn',{result='02:00 JST',detail='Thu, 10 Sep'}},
 {'10am to london','Europe/Tallinn',{result='08:00 BST'}},
 {'10am in san francisco','Europe/Tallinn',{result='20:00 EEST'}},
 {'10am amsterdam','Europe/Tallinn',{result='11:00 EEST'}},
 {'10am india','Europe/Tallinn',{result='07:30 EEST'}},
 {'10am in Europe/Tallinn to America/Los_Angeles','UTC',{result='00:00 PDT'}},
 {'10am in new_york','Europe/Tallinn',{result='17:00 EEST'}},
 {'10am utc+2','Europe/Tallinn',{result='11:00 EEST'}},
 {'10 am gmt-5','Europe/Tallinn',{result='18:00 EEST'}},
 {'10am +05:30','Europe/Tallinn',{result='07:30 EEST'}},
 {'10am australia','Europe/Tallinn',{error='sydney, adelaide or perth',hint=true}},
 {'10am in springfield','Europe/Tallinn',{error='Unknown time zone'}},
 {'10am','Europe/Tallinn',{error='Which time zone'}},
 {'now in london','Europe/Tallinn',{result='13:00 BST',live=true,detail='15:00 EEST here'}},
 {'what time is it in new york','Europe/Tallinn',{result='08:00 EDT',live=true}},
 {'time in tokyo','Europe/Tallinn',{result='21:00 JST'}},
 {'london time','Europe/Tallinn',{result='13:00 BST'}},
 {'pacific time','Europe/Tallinn',{result='05:00 PDT'}},
 {'tomorrow 10am pt','Europe/Tallinn',{detail='Thu, 10 Sep'}},
 {'monday 9am est','Europe/Tallinn',{detail='Mon, 14 Sep'}},
 {'wednesday 9am est','Europe/Tallinn',{detail='Wed, 09 Sep'}},
 {'next wednesday 9am est','Europe/Tallinn',{detail='Wed, 16 Sep'}},
 {'10am pt on friday','Europe/Tallinn',{detail='Fri, 11 Sep'}},
 {'10am pt on 6 sep','Europe/Tallinn',{detail='Sun, 06 Sep'}},
 {'10am pt sep 6 2027','Europe/Tallinn',{detail='Mon, 06 Sep'}},
 {'10am pt on 2026-09-06','Europe/Tallinn',{detail='Sun, 06 Sep'}},
 {'10pm pt on tuesday to tokyo','Europe/Tallinn',{detail='Tue, 15 Sep · 22:00 PDT → Wed, 16 Sep'}},
 -- Fractional fixed offsets, fractional DST, invalid dates, and UTC rollover.
 {'10am utc to utc+05:45','UTC',{result='15:45 UTC+05:45'}},
 {'10am utc-03:30 to utc','UTC',{result='13:30 UTC'}},
 {'10am utc+0545 to utc','UTC',{result='04:15 UTC'}},
 {'now in utc+05:30','UTC',{result='17:30 UTC+05:30',live=true}},
 {'10am utc+18:01','UTC',{error='Offset out of range'}},
 {'10am utc+05:60','UTC',{error='Unknown time zone'}},
 {'10am utc on 2026-02-30','UTC',{error='Invalid date'}},
 {'1:45am Australia/Lord_Howe on 2026-04-05','UTC',{error='occurs twice',hint=true}},
 {'2:15am Australia/Lord_Howe on 2026-10-04','UTC',{error='does not exist',hint=true}},
 {'10am Pacific/Apia on 2011-12-30','UTC',{error='does not exist',hint=true}},
 {'10am utc on sep 6th, 2027','UTC',{detail='Mon, 06 Sep'}},
 {'on 6 sep 2027 at 10am utc','UTC',{detail='Mon, 06 Sep'}},
 {'10am utc → tokyo','UTC',{result='19:00 JST'}},
 {'what is the current time right now in tokyo?','UTC',{result='21:00 JST',live=true}}
}
local failed=0
for _,case in ipairs(cases) do
 local r=U.run({'/usr/bin/luajit',helper,case[1],case[2],now},{timeout=5})
 local ok,out=pcall(U.decode,r.stdout)
 local good=ok and r.code==0
 if good then for k,v in pairs(case[3]) do if v==true then good=good and out[k]==true else good=good and type(out[k])=='string' and out[k]:find(v,1,true)~=nil end end end
 print((good and 'PASS ' or 'FAIL ')..case[1]..' -> '..(ok and U.encode(out) or r.stderr))
 if not good then failed=failed+1 end
end
print((#cases-failed)..'/'..#cases..' passed')
os.exit(failed==0 and 0 or 1)
