# Task: Verify the Basic Dashboard + regress prior phases

## Parent Spec
specs/phase-2-basic-dashboard.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Read-only verification + regression. Do NOT modify application source, db.js, specs,
tasks, scripts, or the journal. Boot the app, run the checks, clean up any test rows.

### Step 1 — Boot + login
```bash
cd /Users/vasudevarao/execution-platform/app
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js & APP=$!; sleep 1.3
ADMIN=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
VASU=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"vasu","password":"vasu123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
echo "admin=${ADMIN:0:6} vasu=${VASU:0:6}"
```

### Step 2 — Dashboard markers + syntax (frontend)
```bash
cd /Users/vasudevarao/execution-platform/app
node --check public/app.js && echo "PASS app.js syntax"
for m in "id=\"rowsPageBtn\"" "id=\"dashPageBtn\"" "function renderDashboard" "state.page === 'dashboard'" "Execution health" "Items by status" "Items by track" "Owner load" "Blocked items" "Overdue / target-risk" "Recently updated" "Open next actions"; do
  grep -qF "$m" public/app.js && echo "PASS marker: $m" || echo "FAIL marker missing: $m"
done
# Dashboard tab universal (not admin-gated); Users/Import still admin-gated
grep -q 'id="dashPageBtn"' public/app.js && ! grep -q 'isAdmin() ? .*dashPageBtn' public/app.js && echo "PASS dashboard tab universal" || echo "NOTE check dashboard gating"
```

### Step 3 — Dashboard helper logic (extract + unit test in node; messy data + blanks)
```bash
cd /Users/vasudevarao/execution-platform/app
node -e '
const fs=require("fs"); const src=fs.readFileSync("public/app.js","utf8");
const block=src.slice(src.indexOf("// ---------- dashboard ----------"), src.indexOf("// ---------- users panel ----------"));
const esc=s=>s==null?"":String(s).replace(/[&<>\"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c]));
let state={rows:[]}; eval(block);
// empty set must not crash
let ok=true;
try{ const h=renderDashboard(); if(!h.includes("Execution health")||!h.includes("None.")) ok=false; }catch(e){ ok=false; console.log("empty crash",e.message); }
console.log(ok?"PASS empty renders":"FAIL empty");
state.rows=[
 {id:1,title:"A",owner:"Unassigned",track:"T1-Device",status:"Not Started",next_action:"x",target_end_date:"2020-01-01",updated_at:"2026-06-01 10:00:00"},
 {id:2,title:"B",owner:"V",track:"T1 Device",status:"In Progress",next_action:"",target_end_date:"?",updated_at:"2026-06-10 09:00:00"},
 {id:3,title:"C",owner:"A",track:"T3 AstraX Ops Cloud",status:"Blocked",next_action:"unblock",target_end_date:"2020-02-02",updated_at:"2026-06-11 08:00:00"},
 {id:4,title:"D",owner:"Unassigned",track:"Unassigned Track",status:"Complete",next_action:"ship",target_end_date:"2020-01-01",updated_at:"2026-06-09 07:00:00"},
];
let h2; try{ h2=renderDashboard(); }catch(e){ console.log("FAIL messy crash",e.message); }
const st=dashStats();
console.log("stats:",JSON.stringify(st),"(expect total4 open3 complete1 blocked1)");
console.log(JSON.stringify(byCount(state.rows,"track")).includes("T1-Device")?"PASS track not canonicalized":"FAIL track canonicalized");
console.log(blockedRows().length===1?"PASS blocked=1":"FAIL blocked");
console.log(overdueRows().map(r=>r.title).join(",")==="A,C"?"PASS overdue=A,C":"FAIL overdue "+overdueRows().map(r=>r.title));
console.log(parseDateSafe("?")===null&&parseDateSafe("")===null?"PASS junk dates -> null":"FAIL date parse");
console.log(openNextActions().map(r=>r.title).join(",")==="A,C"?"PASS nextactions=A,C":"FAIL nextactions "+openNextActions().map(r=>r.title));
'
```

### Step 4 — Regression: rows CRUD perms, users, import all still work
```bash
echo "vasu GET rows (200): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/rows)"
echo "vasu POST T1 out-of-scope (403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/rows -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"owner":"v","title":"t","track":"T1 AstraX Device","type":"experiment","status":"Not Started"}')"
echo "vasu GET users (403): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$VASU" http://localhost:3000/api/users)"
echo "admin GET users (200): $(curl -s -o /dev/null -w '%{http_code}' --cookie "sid=$ADMIN" http://localhost:3000/api/users)"
echo "admin import preview empty-body reachable (400 not 404): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{}')"
echo "vasu import preview (403): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$VASU" -d '{"filename":"f.xlsx","content_base64":"AA=="}')"
```

### Step 5 — Protected files untouched + invariants + teardown
```bash
kill $APP 2>/dev/null || true
cd /Users/vasudevarao/execution-platform
git diff --quiet -- app/server.js app/db.js app/package.json app/package-lock.json app/public/index.html && echo "PASS protected files untouched" || echo "FAIL protected files changed"
bash scripts/invariant-check.sh 2>&1 | tail -3
```

## Acceptance Criteria
- [ ] app.js syntax OK; all dashboard markers + 8 widget titles present; Dashboard tab universal, Users/Import still admin-gated.
- [ ] Dashboard helpers: empty set renders (no crash); messy data → correct stats, track labels not canonicalized, blocked/overdue/next-action correct, junk dates → null.
- [ ] Regression: vasu rows 200 / T1 403 / users 403; admin users 200; import routes reachable + admin-gated.
- [ ] server.js/db.js/package*.json/index.html untouched; invariants 5/5.

## Files Likely Affected
- none (read-only verification)

## Blocked By
- tasks/phase-2-basic-dashboard-002.md
