#!/bin/bash
# usage: tools/dryrun.sh [extra sf args]  -> prints component failures
export SF_DISABLE_TELEMETRY=true SF_AUTOUPDATE_DISABLE=true NODE_NO_WARNINGS=1
OUT=/tmp/claude-0/-home-claude/460e90f8-acea-5ff3-8ff9-0ab6678fd17c/scratchpad/deploy.json
sf project deploy start -o reel-demo --wait 40 --json "$@" > $OUT 2>/dev/null
ID=$(python3 -c "import json;d=json.load(open('$OUT'));print(d.get('data',{}).get('id','') if d.get('name')=='MetadataTransferError' else '')" 2>/dev/null)
if [ -n "$ID" ]; then sleep 5; sf project deploy report -o reel-demo --job-id $ID --json > $OUT 2>/dev/null; fi
python3 - <<'PY'
import json
d=json.load(open('/tmp/claude-0/-home-claude/460e90f8-acea-5ff3-8ff9-0ab6678fd17c/scratchpad/deploy.json'))
r=d.get('result') or d.get('data') or {}
print(r.get('status'), 'errors', r.get('numberComponentErrors'), '/', r.get('numberComponentsTotal'), '| tests run', r.get('numberTestsCompleted'), 'failed', r.get('numberTestErrors'))
det=r.get('details') or {}
fails=det.get('componentFailures') or []
if isinstance(fails,dict): fails=[fails]
for f in fails: print(f"{f.get('componentType')}:{f.get('fullName')} L{f.get('lineNumber')} -> {f.get('problem')}"[:260])
tr=(det.get('runTestResult') or {})
tf=tr.get('failures') or []
if isinstance(tf,dict): tf=[tf]
for f in tf: print(f"TEST {f.get('name')}.{f.get('methodName')}: {f.get('message')}"[:400]); print('   ', (f.get('stackTrace') or '')[:200])
if not fails and not tf and r.get('status')!='Succeeded': print(json.dumps(d)[:1500])
PY
