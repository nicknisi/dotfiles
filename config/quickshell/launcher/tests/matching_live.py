#!/usr/bin/env python3
"""Verify an explicitly prepared native model offline. No tools are installed."""
import argparse
import json
import math
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('data_dir')
parser.add_argument('--model', choices=['small', 'large'], default='small')
args = parser.parse_args()
helper = Path(__file__).resolve().parents[1] / 'helpers/matching-start.lua'
command = ['luajit', str(helper), '--offline', '--engine', 'native', '--model', args.model, '--data-dir', args.data_dir]
rows = [
    {'id': 'browser', 'text': 'Open the web browser to visit websites and browse the internet'},
    {'id': 'screenshot', 'text': 'Capture a screenshot of a selected region of the screen'},
    {'id': 'audio', 'text': 'Change the microphone input volume and speaker output device'},
]
requests = [
    {'id': 1, 'query': 'browse the internet', 'rows': rows},
    {'id': 2, 'query': 'browse the internet', 'rows': None},
    {'id': 3, 'query': 'browse the internet'},
    {'id': 4, 'query': 'browser', 'rows': [rows[0], rows[0]]},
    {'id': 5, 'query': 'browser', 'rows': []},
    {'id': 6, 'query': '\u001c', 'rows': rows},
    # Model2Vec drops literal [UNK], yielding stable zero-score ties.
    {'id': 7, 'query': '[UNK]'},
    # Model2Vec.encode defaults to the first 512 known tokens per document.
    {'id': 8, 'query': 'browser', 'rows': [
        {'id': 'short', 'text': 'a'},
        {'id': 'long', 'text': 'a ' * 512 + 'browser'},
    ]},
    {'id': 9, 'query': 'é' * 1025},
    {'id': 10, 'query': 'browser'},
]
wire = ''.join(json.dumps(request) + '\n' for request in requests) + 'not json\n' + json.dumps({'id': 11, 'query': 'browser'}) + '\n'
result = subprocess.run(command, input=wire, text=True, capture_output=True, timeout=30, check=True)
messages = [json.loads(line) for line in result.stdout.splitlines()]
assert any(message['type'] == 'ready' for message in messages), messages
assert any(message.get('message') == f'Loading {args.model} matching model' for message in messages), messages
answers = {message['id']: message for message in messages if 'id' in message and message['id'] is not None}
assert answers[1]['matches'][0]['id'] == 'browser', answers[1]
assert answers[2]['type'] == 'error' and answers[3]['matches'] == answers[1]['matches'], answers
assert answers[4]['type'] == 'error' and answers[5]['matches'] == [], answers
assert answers[6]['matches'] == [], answers[6]
assert answers[7]['matches'] == [{'id': row['id'], 'score': 0} for row in rows], answers[7]
assert abs(answers[8]['matches'][0]['score'] - answers[8]['matches'][1]['score']) < 2e-6, answers[8]
assert answers[9]['type'] == 'error' and answers[10]['type'] == 'result' and answers[11]['type'] == 'result', answers
assert any(message['type'] == 'error' and message.get('id') is None for message in messages), messages
for answer in answers.values():
    for match in answer.get('matches', []):
        assert set(match) == {'id', 'score'} and math.isfinite(match['score']), match

oversized = subprocess.run(command, input=' ' * (4 * 1024 * 1024 + 1), text=True, capture_output=True, timeout=30)
assert oversized.returncode == 1 and 'Matching request is too large' in oversized.stdout, oversized
installed = subprocess.run(command + ['--install-only'], text=True, capture_output=True, timeout=30, check=True)
assert json.loads(installed.stdout.splitlines()[-1]) == {'type': 'installed', 'model': args.model}, installed
print(f'MATCHING_LIVE_PASS: native {args.model}, verified offline model, ranking, IDs only, protocol recovery, special tokens, truncation and bounded input')
