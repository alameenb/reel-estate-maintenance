#!/bin/bash
export SF_DISABLE_TELEMETRY=true SF_AUTOUPDATE_DISABLE=true NODE_NO_WARNINGS=1
OUT=/tmp/claude-0/-home-claude/460e90f8-acea-5ff3-8ff9-0ab6678fd17c/scratchpad/tests.json
sf apex run test -o reel-demo ${1:---test-level RunLocalTests} --code-coverage --result-format json --wait 30 > $OUT 2>/dev/null
python3 - <<'PY'
import json
d=json.load(open('/tmp/claude-0/-home-claude/460e90f8-acea-5ff3-8ff9-0ab6678fd17c/scratchpad/tests.json'))
r=d.get('result',{}); s=r.get('summary',{})
print({k:s.get(k) for k in ['outcome','testsRan','passing','failing','orgWideCoverage','testRunCoverage']})
for t in r.get('tests',[]):
    if t.get('Outcome')!='Pass': print('FAIL', t['ApexClass']['Name']+'.'+t['MethodName'], '|', (t.get('Message') or '')[:420], '|', (t.get('StackTrace') or '')[:140])
PY
