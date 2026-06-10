# Task: Verify XLSX import + regress Phase-1/P2-1/P2-2/P2-3 behavior

## Parent Spec
specs/phase-2-xlsx-import.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Read-only verification + regression. Do NOT modify application source, db.js,
specs, tasks, scripts, or the journal. Boot the app, run the checks below, and
clean up any test rows you insert. Report PASS/FAIL per group.

### Step 1 — Boot
```bash
cd /Users/vasudevarao/execution-platform/app
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js & APP=$!; sleep 1.3
ADMIN=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
VASU=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"vasu","password":"vasu123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
echo "admin cookie: ${ADMIN:0:8}…  vasu cookie: ${VASU:0:8}…"
```

### Step 2 — Dependency + boot checks
```bash
cd /Users/vasudevarao/execution-platform/app
grep -q '"xlsx"' package.json && echo "PASS xlsx in package.json" || echo "FAIL xlsx missing"
grep -q '"xlsx"' package-lock.json && echo "PASS xlsx in lockfile" || echo "FAIL lock missing"
```

### Step 3 — Build a canonical-track fixture and a malformed file (tmp only)
```bash
cd /Users/vasudevarao/execution-platform/app
node -e "
const XLSX=require('xlsx');
const aoa=[
 ['astraX — Team Experiment Summary'],['banner'],[],
 ['Owner','Track','Experiment Title','Function','Parent Item','Description / Hypothesis','Experiment Design','Success Criteria','Target End Date','Dependencies','Test outcome / Finding','Next Action','Status'],
 ['Asha','T3 AstraX Ops Cloud','Ops latency probe','Eng','','hyp','design','p95<200ms',new Date(Date.UTC(2026,7,15)),'','','tune','In Progress'],
 ['Ravi','T1 AstraX Device','Sensor drift test','HW','','hyp','bench','drift<1%','','','','','Not Started'],
 ['Bad','T9 Nope','Bad track','','','','','','','','','','Complete'],
 ['','T5 Business','No owner','','','','','','','','','','Blocked'],
];
const ws=XLSX.utils.aoa_to_sheet(aoa); const wb=XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb,ws,'All Experiment Summary');
require('fs').writeFileSync('/tmp/p24-fixture.xlsx', XLSX.write(wb,{type:'buffer',bookType:'xlsx'}));
console.log('fixture written');
"
FIX_B64=$(base64 < /tmp/p24-fixture.xlsx | tr -d '\n')
REAL_B64=$(base64 < ../source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx | tr -d '\n')
```

### Step 4 — Auth gating (expect 403 / 401)
```bash
printf '{"filename":"f.xlsx","content_base64":"%s"}' "$FIX_B64" > /tmp/p24-prev.json
echo "vasu preview:  $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$VASU" --data @/tmp/p24-prev.json)  (expect 403)"
echo "vasu commit:   $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/commit  -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"rows":[]}')  (expect 403)"
echo "anon preview:  $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --data @/tmp/p24-prev.json)  (expect 401)"
```

### Step 5 — Preview does not write; counts correct
```bash
ROWS_BEFORE=$(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))")
# real workbook -> expect valid 0
printf '{"filename":"real.xlsx","content_base64":"%s"}' "$REAL_B64" > /tmp/p24-real.json
curl -s -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" --data @/tmp/p24-real.json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const j=JSON.parse(s);console.log('real workbook summary:',JSON.stringify(j.summary),'(expect valid_rows 0)')})"
# fixture -> expect valid 2 / invalid 2
curl -s -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" --data @/tmp/p24-prev.json > /tmp/p24-preview-out.json
node -e "const j=require('/tmp/p24-preview-out.json');console.log('fixture summary:',JSON.stringify(j.summary),'(expect valid 2 / invalid 2)');console.log('invalid reasons:',JSON.stringify(j.invalid_rows.map(r=>[r.row_number,r.errors])))"
ROWS_AFTER_PREVIEW=$(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))")
echo "rows before=$ROWS_BEFORE after preview=$ROWS_AFTER_PREVIEW (expect EQUAL — preview must not write)"
```

### Step 6 — Commit valid rows, verify stamping + type, then clean up
```bash
node -e "const j=require('/tmp/p24-preview-out.json');require('fs').writeFileSync('/tmp/p24-commit.json',JSON.stringify({rows:j.valid_rows}))"
curl -s -X POST http://localhost:3000/api/import/commit -H 'Content-Type: application/json' --cookie "sid=$ADMIN" --data @/tmp/p24-commit.json > /tmp/p24-commit-out.json
node -e "const j=require('/tmp/p24-commit-out.json');console.log('commit:',JSON.stringify(j),'(expect inserted_count 2)')"
# verify inserted rows appear with type=experiment + created_by=admin
curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "
let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
  const ids=require('/tmp/p24-commit-out.json').ids;
  const rows=JSON.parse(s).rows.filter(r=>ids.includes(r.id));
  rows.forEach(r=>console.log('inserted id',r.id,'title=',r.title,'type=',r.type,'created_by=',r.created_by,'updated_by=',r.updated_by));
  console.log(rows.every(r=>r.type==='experiment'&&r.created_by==='admin'&&r.updated_by==='admin') ? 'PASS stamping+type' : 'FAIL stamping+type');
})"
# commit revalidation: tampered invalid-track row must be rejected
echo "tampered commit rejected_count: $(curl -s -X POST http://localhost:3000/api/import/commit -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{"rows":[{"owner":"x","track":"T9 Bogus","title":"t","status":"Complete"}]}' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rejected_count+' inserted='+JSON.parse(s).inserted_count))")  (expect rejected 1 inserted 0)"
# CLEANUP: delete the test rows we inserted
node -e "const ids=require('/tmp/p24-commit-out.json').ids;console.log(ids.join(' '))" | tr ' ' '\n' | while read id; do [ -n "$id" ] && curl -s -o /dev/null -X DELETE http://localhost:3000/api/rows/$id --cookie "sid=$ADMIN"; done
echo "cleanup done; rows now: $(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/rows | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).rows.length))") (expect == $ROWS_BEFORE)"
```

### Step 7 — Regression (P2-1/P2-2/P2-3)
```bash
echo "vasu GET rows: $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/rows) (expect 200)"
echo "vasu POST T1 (out of scope): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/rows -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"owner":"vasu","title":"reg-t1","track":"T1 AstraX Device","type":"experiment","status":"Not Started"}') (expect 403)"
echo "vasu users (expect 403): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/users)"
echo "admin users (expect 200): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$ADMIN" http://localhost:3000/api/users)"
echo "admin users password_hash leak count: $(curl -s --cookie "sid=$ADMIN" http://localhost:3000/api/users | grep -c password_hash) (expect 0)"
# frontend: Import tab admin-gated, no public upload route
grep -q "importPageBtn" public/app.js && echo "PASS importPageBtn present" || echo "FAIL importPageBtn missing"
grep -q "isAdmin() ? \`<button class=\"ws-tab\${isImportPage" public/app.js && echo "PASS import tab admin-gated" || echo "NOTE check import tab gating"
```

### Step 8 — Invariants + cleanup
```bash
kill $APP 2>/dev/null || true
rm -f /tmp/p24-*.json /tmp/p24-fixture.xlsx 2>/dev/null || true
cd /Users/vasudevarao/execution-platform
bash scripts/invariant-check.sh 2>&1 | tail -3
```

## Acceptance Criteria
- [ ] xlsx present in package.json + lockfile; app boots.
- [ ] preview/commit return 403 for vasu, 401 for anon.
- [ ] real workbook preview reports valid_rows 0 and writes nothing; fixture preview reports valid 2 / invalid 2 with row numbers + reasons.
- [ ] commit inserts 2 rows with type=experiment, created_by/updated_by=admin; tampered row rejected; test rows cleaned up.
- [ ] regression: vasu rows 200 / T1 403 / users 403; admin users 200, no password_hash leak; importPageBtn present + admin-gated.
- [ ] invariants 5/5 PASS.

## Files Likely Affected
- none (read-only verification; transient /tmp fixtures only)

## Blocked By
- tasks/phase-2-xlsx-import-003.md
