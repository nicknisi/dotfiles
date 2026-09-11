#!/usr/bin/env python3
"""Check the installed Codex schema without opening credentials or starting a turn."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
codex = shutil.which('codex')
assert codex, 'Install a supported Codex CLI to run the protocol check'
with tempfile.TemporaryDirectory(prefix='launcher-protocol-') as temp:
    work = Path(temp)
    (work / '.codex').mkdir()
    env = dict(HOME=str(work), CODEX_HOME=str(work / '.codex'), PATH=os.environ['PATH'],
               XDG_CONFIG_HOME=str(work / '.config'), XDG_DATA_HOME=str(work / '.local/share'))
    def run(*args):
        return subprocess.run(args, env=env, text=True, capture_output=True, check=True).stdout

    version = run(codex, '--version').strip()
    run(codex, 'app-server', 'generate-json-schema', '--experimental', '--out', str(work / 'schema'))
    def schema(name):
        return json.loads(next((work / 'schema').rglob(name + '.json')).read_text())

    policy = json.loads(run('node', '-e', '''
const fs=require('fs'), vm=require('vm'), ctx={}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace('.pragma library',''),ctx);
console.log(JSON.stringify(ctx.start('/fixture',{}, {mcp_servers:{dangerous:{}}})));
''', str(root / 'codex/Policy.js')))
    start = schema('ThreadStartParams')
    assert set(policy) <= start['properties'].keys()
    assert 'null' in start['properties']['model']['type'] and policy['model'] is None
    assert policy['sandbox'] in start['definitions']['SandboxMode']['enum']
    assert policy['approvalPolicy'] in start['definitions']['AskForApproval']['oneOf'][0]['enum']
    assert 'user' in start['definitions']['ApprovalsReviewer']['enum']
    assert policy['historyMode'] in start['definitions']['ThreadHistoryMode']['enum']
    assert policy['environments'] == [] and 'array' in start['properties']['environments']['type']
    resume = schema('ThreadResumeParams')
    resume_policy = {k: v for k, v in policy.items() if k not in ('ephemeral', 'serviceName', 'historyMode', 'environments')}
    assert set(resume_policy) <= resume['properties'].keys()
    for name, fields in {
        'TurnStartParams': {'threadId', 'input', 'model', 'effort', 'serviceTier', 'environments'},
        'TurnSteerParams': {'threadId', 'expectedTurnId', 'input'},
        'TurnInterruptParams': {'threadId', 'turnId'},
        'CommandExecutionRequestApprovalResponse': {'decision'},
        'FileChangeRequestApprovalResponse': {'decision'},
        'PermissionsRequestApprovalResponse': {'permissions', 'scope'},
        'ToolRequestUserInputResponse': {'answers'},
        'AgentMessageDeltaNotification': {'threadId', 'turnId', 'itemId', 'delta'},
    }.items():
        assert fields <= schema(name)['properties'].keys(), name
    features = run(codex, 'features', 'list')
    known = {line.split()[0] for line in features.splitlines() if line.strip()}
    assert {k.removeprefix('features.') for k in policy['config'] if k.startswith('features.')} <= known
    assert '--stdio' in run(codex, 'app-server', '--help')
    assert '--cd' in run(codex, '--help')
    assert '--cd' in run(codex, 'resume', '--help')

    # Real helper, fake executable: gate must reject unknown versions before mkdir/app-server.
    bindir = work / 'bin'
    bindir.mkdir()
    fake = bindir / 'codex'
    fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                    'if sys.argv[1:]==["--version"]: print("codex-cli "+os.environ["FAKE_VERSION"])\n'
                    'else: print(json.dumps(sys.argv[1:]))\n')
    fake.chmod(0o700)
    for v, supported in [('0.152.0', True), ('0.153.2', True), ('0.151.9', False),
                         ('0.153.3', False), ('0.154.0', False), ('0.152.0-dev', False)]:
        testenv = dict(env, PATH=str(bindir) + ':' + env['PATH'], FAKE_VERSION=v)
        result = subprocess.run(['bash', str(root / 'helpers/codex-start.sh')], env=testenv, text=True, capture_output=True)
        assert result.returncode == (0 if supported else 65), (v, result.stderr)
        if supported:
            argv = json.loads(result.stdout)
            assert argv[:2] == ['app-server', '--stdio']
            assert argv[-6:] == ['--disable', 'hooks', '--disable', 'apps', '--disable', 'plugins']
    print('PASS', version, 'generated schema, quick safety feature names, CLI help and bounded version gate; no authenticated server or turns')
