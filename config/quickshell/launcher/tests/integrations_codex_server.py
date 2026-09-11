#!/usr/bin/env python3
"""Unauthenticated JSON-lines fixture. Never invokes Codex or any tools."""
import json
import os
import sys
import threading
import time

lock = threading.Lock()
stop = threading.Event()
approval = threading.Event()
turn = 0


def emit(value):
    with lock:
        print(json.dumps(value), flush=True)


def event(method, params):
    emit({'method': method, 'params': params})


def reply(id, result):
    emit({'id': id, 'result': result})


def stream(id, p):
    global turn
    turn += 1
    n = str(turn)
    thread = p['threadId']
    text = p['input'][0]['text']
    stop.clear()
    event('turn/started', {'threadId': thread, 'turn': {'id': n}})
    event('item/started', {'threadId': thread, 'turnId': n, 'item': {
        'type': 'userMessage', 'id': 'u' + n, 'content': [{'type': 'text', 'text': text}]}})
    event('item/agentMessage/delta', {'threadId': thread, 'turnId': n, 'itemId': 'a' + n, 'delta': 'Hello '})
    time.sleep(.1)  # Notifications arrive before the turn/start response.
    reply(id, {'turn': {'id': n}})
    if text == 'agent approval':
        approval.clear()
        emit({'id': 'approval-1', 'method': 'item/commandExecution/requestApproval', 'params': {
            'threadId': thread, 'turnId': n, 'itemId': 'command-1', 'command': 'fixture only', 'cwd': '/fixture'}})
        approval.wait(3)
    if 'slow' in text:
        stop.wait(3)
    time.sleep(.05)
    if not stop.is_set():
        event('item/agentMessage/delta', {'threadId': thread, 'turnId': n, 'itemId': 'a' + n, 'delta': 'world'})
        event('item/completed', {'threadId': thread, 'turnId': n, 'item': {
            'type': 'agentMessage', 'id': 'a' + n, 'text': 'Hello world'}})
    event('turn/completed', {'threadId': thread, 'turn': {
        'id': n, 'status': 'interrupted' if stop.is_set() else 'completed'}})


for line in sys.stdin:
    m = json.loads(line)
    with open(sys.argv[1], 'a') as log:
        log.write(json.dumps(m) + '\n')
    method, p, id = m.get('method'), m.get('params', {}), m.get('id')
    if method == 'initialize':
        reply(id, {'userAgent': 'codex/0.152.0'})
    elif method == 'config/read':
        reply(id, {'config': {'mcp_servers': {'dangerous': {'command': 'must-not-start'}}}})
    elif method == 'model/list':
        reply(id, {'data': [{'model': 'fixture-current-default', 'isDefault': True}]})
    elif method == 'account/read':
        reply(id, {'account': {'type': 'chatgpt'}})
    elif method in ('thread/start', 'thread/resume'):
        assert p['model'] is None  # Never force the upstream unavailable model.
        if p['sandbox'] == 'read-only':
            assert p['config']['mcp_servers.dangerous.enabled'] is False
            assert p['config']['features.shell_tool'] is False
            assert p['config']['features.multi_agent'] is False
            assert p['approvalPolicy'] == 'never'
            if method == 'thread/start':
                assert p['environments'] == []
        else:
            assert p['sandbox'] == 'workspace-write'
            assert p['approvalPolicy'] == 'on-request' and p['approvalsReviewer'] == 'user'
            assert 'Omarchy' not in p['baseInstructions']
        reply(id, {'thread': {'id': 'thread-test', 'turns': []}})
    elif method == 'thread/name/set':
        reply(id, {})
    elif method == 'turn/start':
        assert p['model'] is None
        if p['input'][0]['text'] == 'crash now':
            os._exit(7)
        threading.Thread(target=stream, args=(id, p), daemon=True).start()
    elif method == 'turn/interrupt':
        stop.set()
        approval.set()
        reply(id, {})
    elif method == 'turn/steer':
        reply(id, {'turnId': str(turn)})
    elif id == 'approval-1' and 'result' in m:
        assert m['result'] == {'decision': 'decline'}
        approval.set()
