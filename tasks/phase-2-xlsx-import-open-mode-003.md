# Task: Verify open-mode import against the live workbook + regress prior phases

## Parent Spec
specs/phase-2-xlsx-import-open-mode.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Read-only verification + regression. Do NOT modify application source, db.js, specs,
tasks, scripts, or the journal. Boot the app, run the checks, clean up inserted rows.

### Step 1 — Boot + login
```bash
cd /Users/vasudevarao/execution-platform/app
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js & APP=$!; sleep 1.3
ADMIN=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
VASU=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"vasu","password":"vasu123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
```

### Step 2 — Live workbook now imports (the whole point of P2-4A)
```bash
cd /Users/vasudevarao/execution-platform/app
REAL_B64=$(base64 < ../source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx | tr -d '\n')
printf '{"filename":"real.xlsx","content_base64":"%s"}' "$REAL_B64" > /tmp/p24a-real.json
ROWS_BEFORE=$(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))")
curl -s -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" --data @/tmp/p24a-real.json > /tmp/p24a-prev.json
node -e "const j=require('/tmp/p24a-prev.json');console.log('real preview summary:',JSON.stringify(j.summary),'(expect importable_rows>0, ~19)');console.log('sample warnings:',JSON.stringify(j.rows.slice(0,3).map(r=>[r.row_number,r.warnings])))"
ROWS_AFTER_PREVIEW=$(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))")
echo "preview wrote nothing: before=$ROWS_BEFORE after=$ROWS_AFTER_PREVIEW (expect equal)"
```

### Step 3 — Commit the live workbook; verify defaults + stamping; then clean up
```bash
node -e "const j=require('/tmp/p24a-prev.json');require('fs').writeFileSync('/tmp/p24a-commit.json',JSON.stringify({rows:j.rows.map(r=>r.data)}))"
curl -s -X POST http://localhost:3000/api/import/commit -H 'Content-Type: application/json' --cookie "sid=$ADMIN" --data @/tmp/p24a-commit.json > /tmp/p24a-commit-out.json
node -e "const j=require('/tmp/p24a-commit-out.json');console.log('commit:',JSON.stringify({inserted_count:j.inserted_count,skipped_count:j.skipped_count}),'(expect inserted_count>0, skipped_count 0)')"
curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "
let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
  const ids=require('/tmp/p24a-commit-out.json').ids;
  const ins=JSON.parse(s).rows.filter(r=>ids.includes(r.id));
  const hasUnassignedOwner=ins.some(r=>r.owner==='Unassigned');
  const hasNonCanonTrack=ins.some(r=>r.track==='T1-Device'||r.track==='T1 Device');
  const allCanonStatus=ins.every(r=>['Not Started','In Progress','Complete','Blocked','Inconclusive'].includes(r.status));
  const stamped=ins.every(r=>r.created_by==='admin'&&r.updated_by==='admin'&&r.type==='experiment');
  console.log('inserted count:',ins.length,'| Unassigned owner present:',hasUnassignedOwner,'| non-canonical track stored as-is:',hasNonCanonTrack,'| all status canonical:',allCanonStatus,'| stamped+experiment:',stamped);
})"
# CLEANUP
node -e "require('/tmp/p24a-commit-out.json').ids.forEach(i=>console.log(i))" | while read id; do [ -n "$id" ] && curl -s -o /dev/null -X DELETE http://localhost:3000/api/rows/$id --cookie "sid=$ADMIN"; done
echo "cleanup rows now: $(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))") (expect == $ROWS_BEFORE)"
```

### Step 4 — Title-blank skip + commit revalidation + auth gating
```bash
# title-blank row is skipped at commit
echo "title-blank commit (expect inserted 0 skipped 1): $(curl -s -X POST http://localhost:3000/api/import/commit -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{"rows":[{"owner":"x","track":"T1 AstraX Device","status":"Complete"}]}' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const j=JSON.parse(s);console.log('inserted='+j.inserted_count+' skipped='+j.skipped_count)})")"
echo "vasu preview (expect 403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"filename":"f.xlsx","content_base64":"AA=="}')"
echo "vasu commit (expect 403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/commit -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"rows":[]}')"
echo "anon preview (expect 401): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' -d '{"filename":"f.xlsx","content_base64":"AA=="}')"
```

### Step 5 — Manual CRUD stays strict + P2-1/2/3 regression
```bash
echo "manual POST invalid track (expect 400/403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/rows -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{"owner":"a","title":"t","track":"T9 Bogus","type":"experiment","status":"Not Started"}')"
echo "vasu GET rows (expect 200): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/rows)"
echo "vasu POST T1 out-of-scope (expect 403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/rows -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"owner":"vasu","title":"rt1","track":"T1 AstraX Device","type":"experiment","status":"Not Started"}')"
echo "vasu users (expect 403): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/users)"
echo "admin users password_hash leak (expect 0): $(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/users | grep -c password_hash)"
grep -q "importPageBtn" public/app.js && echo "PASS importPageBtn present" || echo "FAIL importPageBtn missing"
grep -q "importable_rows" public/app.js && echo "PASS open-mode UI present" || echo "FAIL open-mode UI missing"
```

### Step 6 — Invariants + teardown
```bash
kill $APP 2>/dev/null || true
rm -f /tmp/p24a-*.json 2>/dev/null || true
cd /Users/vasudevarao/execution-platform
bash scripts/invariant-check.sh 2>&1 | tail -3
```

## Acceptance Criteria
- [ ] Live workbook preview reports importable_rows > 0 (expected ~19), skipped 0; preview writes nothing.
- [ ] Commit inserts the workbook rows; Unassigned owner present, non-canonical track stored as-is, all status canonical, stamped created_by/updated_by=admin, type=experiment; rows cleaned up after.
- [ ] Title-blank row skipped at commit; preview/commit 403 for vasu, 401 for anon.
- [ ] Manual POST /api/rows invalid track still rejected (strict CRUD unchanged).
- [ ] P2-1/2/3 regression holds; no password_hash leak; importPageBtn + open-mode UI present.
- [ ] Invariants 5/5 PASS.

## Files Likely Affected
- none (read-only verification; transient /tmp files only)

## Blocked By
- tasks/phase-2-xlsx-import-open-mode-002.md
