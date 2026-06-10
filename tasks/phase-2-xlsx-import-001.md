# Task: Install xlsx dependency and verify live workbook headers

## Parent Spec
specs/phase-2-xlsx-import.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
No `entries` schema change. This precondition task adds the single allowed
runtime dependency (`xlsx` / SheetJS) and verifies the live workbook structure
the parser depends on. DO NOT modify `app/db.js` or any schema. DO NOT add any
package other than `xlsx`.

### Step 1 — Install xlsx (app directory only)
```bash
cd /Users/vasudevarao/execution-platform/app
npm install xlsx
```
This must add `xlsx` to `app/package.json` dependencies and update
`app/package-lock.json`. No global install. No other package.

### Step 2 — Verify the dependency resolves
```bash
cd /Users/vasudevarao/execution-platform/app
node -e "const X=require('xlsx'); if(!X.read||!X.utils||!X.SSF) { console.error('FAIL: xlsx API missing'); process.exit(1);} console.log('PASS: xlsx', require('xlsx/package.json').version);"
```

### Step 3 — Verify live workbook structure (read-only)
The parser (next task) targets sheet `All Experiment Summary`, header row 4,
data columns 1–13. Confirm these still hold:
```bash
cd /Users/vasudevarao/execution-platform/app
node -e "
const XLSX=require('xlsx');
const wb=XLSX.read(require('fs').readFileSync('../source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx'),{type:'buffer'});
if(!wb.SheetNames.includes('All Experiment Summary')){console.error('FAIL: summary sheet missing');process.exit(1);}
const m=XLSX.utils.sheet_to_json(wb.Sheets['All Experiment Summary'],{header:1,defval:null,blankrows:true});
let hdr=-1; for(let i=0;i<m.length;i++){const c=(m[i]||[]).map(x=>x==null?'':String(x).trim()); if(c.includes('Owner')&&c.includes('Track')&&c.includes('Experiment Title')){hdr=i;break;}}
if(hdr<0){console.error('FAIL: header row not found');process.exit(1);}
const want=['Owner','Track','Experiment Title','Function','Parent Item','Description / Hypothesis','Experiment Design','Success Criteria','Target End Date','Dependencies','Test outcome / Finding','Next Action','Status'];
const have=(m[hdr]||[]).map(x=>x==null?'':String(x).trim());
for(const w of want){ if(!have.includes(w)){console.error('FAIL: missing header '+w);process.exit(1);} }
console.log('PASS: sheet + all 13 headers present at row', hdr+1);
"
```

## Acceptance Criteria
- [ ] `xlsx` appears in `app/package.json` dependencies; `app/package-lock.json` updated.
- [ ] `require('xlsx')` exposes `read`, `utils`, and `SSF`.
- [ ] Sheet `All Experiment Summary` exists; the 13 expected headers are present at the header row.
- [ ] `app/db.js` and the database schema are NOT modified.
- [ ] No package other than `xlsx` was added.

## Files Likely Affected
- app/package.json
- app/package-lock.json

## Blocked By
- none
