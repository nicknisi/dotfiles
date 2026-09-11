#!/usr/bin/env python3
"""Deterministic app-server fixture: early events, streaming, cancel and resume."""
import json,sys,threading,time,os
lock=threading.Lock();stop=threading.Event();turn=0

def emit(value):
 with lock:
  print(json.dumps(value),flush=True)
def event(method,params):emit({'method':method,'params':params})
def reply(id,result):emit({'id':id,'result':result})
def stream(id,p):
 global turn
 turn+=1;n=str(turn);thread=p['threadId'];text=p['input'][0]['text'];stop.clear()
 event('turn/started',{'threadId':thread,'turn':{'id':n}})
 event('item/started',{'threadId':thread,'turnId':n,'item':{'type':'userMessage','id':'u'+n,'content':[{'type':'text','text':text}]}})
 event('item/agentMessage/delta',{'threadId':thread,'turnId':n,'itemId':'a'+n,'delta':'Hello '})
 # Deliberately send deltas before the turn/start response.
 time.sleep(.05);reply(id,{'turn':{'id':n}})
 if 'slow' in text:stop.wait(3)
 time.sleep(.05)
 if not stop.is_set():
  event('item/agentMessage/delta',{'threadId':thread,'turnId':n,'itemId':'a'+n,'delta':'world'})
  event('item/completed',{'threadId':thread,'turnId':n,'item':{'type':'agentMessage','id':'a'+n,'text':'Hello world'}})
 event('turn/completed',{'threadId':thread,'turn':{'id':n,'status':'interrupted' if stop.is_set() else 'completed'}})

for line in sys.stdin:
 m=json.loads(line);method=m.get('method');p=m.get('params',{});id=m.get('id')
 if method=='initialize':reply(id,{'userAgent':'codex/0.153.2'})
 elif method=='config/read':reply(id,{'config':{'mcp_servers':{'dangerous':{'command':'must-not-start'}}}})
 elif method=='model/list':reply(id,{'data':[{'model':'gpt-5.6-luna'}]})
 elif method=='account/read':reply(id,{'account':{'type':'chatgpt'}})
 elif method=='thread/start':
  assert p['config']['mcp_servers.dangerous.enabled'] is False
  assert p['config']['features.shell_tool'] is False
  assert p['environments']==[]
  reply(id,{'thread':{'id':'thread-test','turns':[]}})
 elif method=='thread/resume':reply(id,{'thread':{'id':'thread-test','turns':[]}})
 elif method=='thread/name/set':reply(id,{})
 elif method=='turn/start':
  if p['input'][0]['text']=='crash now':os._exit(7)
  threading.Thread(target=stream,args=(id,p),daemon=True).start()
 elif method=='turn/interrupt':stop.set();reply(id,{})
 elif method=='turn/steer':reply(id,{'turnId':str(turn)})
 elif method=='thread/unsubscribe':reply(id,{'status':'unsubscribed'})
