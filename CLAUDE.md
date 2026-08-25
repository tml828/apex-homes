# Apex Homes LLC — Developer Reference

## What This App Is
Single-file (`index.html`) property management web app for a house-flipping business. No build toolchain — all HTML, CSS, and JavaScript are inline. Deployed on GitHub Pages, syncs data to Supabase every 5 seconds. ~5900+ lines.

## Deployment
- **Live site:** tml828.github.io/apex-homes
- **Repo:** github.com/tml828/apex-homes
- **Deploy branch:** `main` — GitHub Pages auto-deploys on every push to main
- **Push directly to main** — no PRs needed unless explicitly requested
- **NOT on Netlify** — fully removed, GitHub Pages only

## Architecture

### Data Layer
All data lives in one Supabase table: `apex_data`, single row with `id='main'`.

Global variables (populated by `loadData()` on startup):
```
propData   — property details, settings, mileage, calendar, contractors, balance sheet
extra      — expenses per property key (e.g. extra['bradford'], extra['general'])
tasks      — task array
propImgs   — property photo URLs keyed by property name
window._mileage — mileage trip log array
```

Supabase credentials are hardcoded in the file — **do not remove them**. They are the fallback so receipt scanning and sync work on every device without setup.

### Properties
ALL properties are built dynamically via `buildPropPage(key)` — no hardcoded pages.
Bradford, Boston, and Warblers are stored in `propData` like any other property.
At startup, `loadData().then()` calls `getPropKeys().forEach(k => buildPropPage(k))`.
`buildPropPage(key, force=false)` — pass `force=true` to rebuild (used by `saveEditProp` so address changes reflect).
Property keys are always lowercase, no spaces.

### Sync
- `save()` — writes to localStorage immediately, then debounces a Supabase push (5s)
- `autoSyncPull()` — runs every 5 seconds, pulls from Supabase if hash changed
- **Never call `save()` before `loadData()` completes** — caused data loss once

---

## Critical Rules (DO NOT BREAK)

1. **`html { width:100vw !important }`** — must stay. Without it the page collapses to 16px wide and goes blank. Never add `html` to any `.ico` selector.

2. **API keys hardcoded** — `getApiKey()` has a hardcoded Anthropic key fallback. `SB_KEY` is hardcoded. Both are intentional.

3. **Async upload functions** — `handleExpReceipt`, `handleEditExpReceipt`, `uploadToStorage`, `processReceiptImage` must ALL be `async`. Without it, `await` silently returns `undefined` and uploads fail silently.

4. **Modal scroll** — `openModal()` uses `body{overflow:hidden}`, NOT `body{position:fixed}`. The fixed version causes scroll jump and broken modal scroll on iOS.

5. **Mileage onclick IDs need quotes** — `onclick="deleteMileage('${t.id}')"` — single quotes inside required. Without them JS treats the ID as an undefined variable.

6. **`prop-img-inp` must be in real body** — `<input type="file" id="prop-img-inp">` must be a real DOM element, not inside a template literal. It's at the bottom of the file.

7. **`propDefaults` must be empty** — `var propDefaults = {}`. Never put property data there. All data comes from Supabase.

8. **Sync interval is 5 seconds** — `setInterval(autoSyncPull, 5000)`. Do not increase.

9. **No `overflow-x:hidden` on html element** — only on `body`. On `html` it collapses the page.

10. **`renderQ` uses two ID patterns** — `getElementById("sq-"+p) || getElementById("scan-queue-"+p)`. Both exist. Do not remove either fallback.

11. **Lightbox `#m-lbox` must always center** — needs `align-items:center !important; justify-content:center !important`. The global `.mo` rule overrides to `flex-end` on mobile. The ID rule overrides it back.

12. **Supabase RLS is ENABLED — auth session required for all data access.** The `apex_data` table has Row Level Security with a policy allowing only the `authenticated` role. The anon `SB_KEY` alone can no longer read/write the table or upload to storage (public read on `apex-media` remains). All Supabase requests MUST go through `sbHeaders()` / `sbToken()` (which use the logged-in session token from localStorage `apex_auth`, falling back to `SB_KEY`). Never replace `sbToken()` with `SB_KEY` in Authorization headers — uploads and sync will silently fail. The login screen (`#login-screen`, `doLogin`, `sbLogin`, `sbRefreshAuth`) handles email/password sign-in; sessions auto-refresh every 60s and `sbFetch` retries once on 401.

---

## Auth / Security

- **Supabase Auth**: user account (apexhomes100@gmail.com) created in Supabase dashboard → Authentication → Users. Login screen appears when no session in localStorage `apex_auth`. "Continue without signing in" sets `apex_login_skipped` — with RLS on, skipping means no data loads.
- **RLS policy on `apex_data`**: `authed_full_access` — `for all to authenticated using (true) with check (true)`.
- **Storage `apex-media` bucket**: Public read (SELECT) kept so photo/receipt URLs display; anon INSERT/UPDATE policies deleted; authenticated-only write policy (`bucket_id = 'apex-media'`).
- **PIN screen** still gates the UI after login (sessionStorage `apex_unlocked`); Cloud Account card on Company tab shows sign-in status with Sign In/Out button (`updateAuthStatus`).
- **Emergency unlock**: if locked out, run `alter table apex_data disable row level security;` in Supabase SQL Editor.

---

## Key Functions Reference

### Navigation
- `showPage(btn, id)` — switches active page tab
- `showProp(p)` — navigates to a property page (builds it first if needed)
- `goBack()` — returns to dashboard

### Data Helpers
- `getPropKeys()` — returns all property keys (excludes `_` prefixed keys)
- `getProp(p)` — returns merged property object (propDefaults + propData)
- `allE(p)` — returns all expenses for a property from `extra[p]` (BEXP migration complete — hardcoded data deleted)
- `eTotal(p, yr)` — sum of expenses for property, optionally filtered by year. Credits are negative.
- `propPurchase(p, yr)` — purchase price, filtered by sale year (COGS in year of sale)
- `propSold(p, yr)` — sale price, filtered by year
- `propAllin(p)` — purchase + all expenses (no year filter)
- `propNetProfit(p)` — sold - purchase - expenses
- `propROI(p)` — (sold - cost) / cost * 100
- `incomeTotal(yr)` — sum of other income entries for year

### Expenses
- `openAddExp(p)` / `saveExp()` — add expense to property p
- `openEditExpByIndex(p, origIdx)` / `saveEditExp()` — edit expense
- `openAddCr(p)` / `saveCr()` — add credit/refund (stored with `credit:true`)
- `delExpByIndex(p, idx)` — delete expense
- `triggerCSVImport(pid)` / `importExpCSV(event, pid)` — bulk import from CSV file
  - CSV columns (header optional, auto-detected): `amount`, `date`, `description`, `category`, `vendor`
  - Rows missing a valid amount are skipped; reports added vs skipped count
  - `parseCSVLine(line)` — handles quoted fields and commas inside quotes

### Mileage
- `addMileage()` — logs a trip to `window._mileage`
- `renderMileage()` — displays trips filtered by `taxYear`
- `saveMileage()` — persists to localStorage and propData
- Rate stored in `propData._mileageRate` (default 0.725 IRS 2026)

### Tax / Financials
- `taxYear` — global, set by year buttons, triggers `refreshSite()`
- `exportTaxCSV()` — full Schedule C CSV with per-property breakdown, categories, contractors
- `exportTaxPDF()` — full printable PDF with same data
- `updateBalanceSheet()` — reads cash/loans/payable inputs, calculates equity = assets - liabilities
- Net profit formula: `revenue - acquisitions - totalExp - mileageDeduction`

### W-9 / Contractors
- W-9 checkbox shows ONLY when category = "Labor / Contractor" AND amount >= $600
- Contractors tab shows ONLY expenses where `e.w9 === true`
- Same filter applies in CSV and PDF exports

### Sync / Save
- `save()` — localStorage + debounced Supabase push
- `loadData()` — loads from localStorage first, then Supabase
- `autoSyncPull()` — every 5s, hash-checked before applying, blocked by `_pushPending` flag while a save is in flight
- `_mergeReceipts(cloudExtra)` — re-attaches local base64 receipt images stripped by cloud copy; called in `loadData` and `autoSyncPull`
- `saveHourlyBackup()` — saves a timestamped cloud snapshot (id=`backup-{ts}`), keeps only 7 most recent; guards against empty propData
- `restoreCloudBackup(id)` — synchronous POST to Supabase then reload; restores propImgs too

### Receipt Scanning
- `handleExpReceipt(file)` — processes receipt for new expense modal
- `processReceiptImage(file, crop)` — resizes/crops image, returns base64
- `_cropToReceipt(canvas)` — auto-crops to receipt paper area using brightness projection (called with `crop=true`)
- `scanExpReceipt(file, b64, mime)` — sends to Claude API (`claude-sonnet-4-6`), extracts fields
- `handleScanFiles(files, p)` — queues multiple files for batch scanning on property p
- `runScan(p)` — scans all queued files for property p, bulk-adds as expenses
- Every property expenses tab has an AI Receipt Scanner panel (tap to take/upload, select multiple, Scan All & Add)
- Category suggestion uses `claude-haiku-4-5-20251001`

---

## Data Structures

### Expense object
```js
{ a: "150.00", d: "Paint supplies", c: "Materials & Supplies", v: "Home Depot",
  dt: "2026-04-15", receipt: "https://...", w9: false, credit: false }
```

### Mileage trip
```js
{ id: 1234567890, miles: 12.5, purpose: "Site visit", date: "2026-04-10", prop: "bradford" }
```

### Property data (propData[key])
```js
{ addr: "19311 Bradford Court", city: "Strongsville", state: "Ohio", zip: "44149",
  purchase: 85000, sold: 0, pdate: "2026-01-15", sdate: "", offer: "2026-01-10",
  status: "Renovation", notes: "", budget: 50000 }
```

### Balance sheet (propData._bs)
```js
{ cash: 5000, loans: 120000, payable: 2500 }
```

---

## What Has Been Fixed (session history)

- `changePin()` — n/c/e were undefined
- `updateBudget()` — pct was undefined
- `setROIItem()` — lbl was undefined inside forEach
- Tax CSV — broken template literal for mileage rate, hardcoded filename, mileage not deducted from net profit
- Tax PDF — same math + richer layout with Schedule C lines, per-property table, contractors
- On-screen Tax Summary — mileage now deducted from net profit and SE tax
- Missing DOM elements: `ep-photo-wrap`, `ep-photo-inp`, `apikey-btn`, `co-ein-display`
- W-9 contractors filter — was showing all Labor/Contractor >= $600 regardless of checkbox
- Balance sheet — inputs were ignored, equity never subtracted liabilities
- Mileage tracker — was showing all years, now filters by taxYear
- Balance sheet header — was hardcoded "2026", now uses taxYear variable
- Button styles — Add Expense (solid red `#c0392b`), Credit/Refund and Add Income (solid green `#1a7a4a`), all with white text
- Hardcoded property pages removed — Bradford, Boston, Warblers now use `buildPropPage` like all other properties
- `buildPropPage` updated to accept `force` param; `saveEditProp` passes `true` so address header updates on edit
- Multi-receipt AI scanner added to every property's Expenses tab (was previously only on general expenses)
- CSV bulk import added: Import CSV button on every property and general expenses tab
- Closing Statement AI import tab added (between Expenses and Docs) — works for buyer and seller statements
- Credits split into own tab per property; credits excluded from Expenses tab totals; `renderCr()` added
- Dashboard stats replaced with Net Profit, All-In Cost, Avg ROI (3 cards)
- Glass morphism UI applied site-wide (backdrop-filter, rgba backgrounds)
- Background image: `Gemini_Generated_Image_d4zq21d4zq21d4zq.png` in repo root, served via raw.githubusercontent.com
- Hourly cloud snapshots: `saveHourlyBackup()` / `restoreCloudBackup()` on Company tab, max 7 kept
- Supabase Auth + RLS implemented: login screen, session tokens on all requests, `sbLogin`/`sbRefreshAuth`/`sbLogout`; Cloud Account card on Company tab
- `esc(s)` HTML escape helper added, used throughout `renderE`, `renderCr`, `renderEFiltered`, `showVendorSuggest`
- `_pushPending` flag prevents autoSyncPull from overwriting a pending save
- `fmt(n)` handles NaN — returns `$0.00` instead of crashing
- Property detail page: photo removed from info view; only info card shown. Photo edit/delete moved into Edit Property modal
- Edit Property modal scroll fixed for iPhone: `max-height:88dvh` + `touch-action:pan-y`
- Date inputs on mobile no longer overflow: `width:100%;min-width:0;box-sizing:border-box` on `.fg input`
- Docs tab Add Document button always rendered by `renderDocs()`; accepts multi-file and multi-page docs
- Doc upload rewritten: `handleDocFiles()` + `saveDocFile()` — saves to `propData._docs[p]`, then uploads to Supabase storage; no longer routes to receipt scanner queue
- `buildPropPage()` Expenses tab includes AI Receipt Scanner panel and CSV Import button for all properties
- Dashboard mini-cards grid uses `align-items:start` — prevents CSS stretch making adjacent card appear to open when one is toggled
- Expenses tab total shows **gross expenses only** (not net of credits); `expGross` computed separately from `eTotal()` in `refreshSite()`
- "Meals (50% deductible)" expense category added; IRS 50% limit applied in `exportTaxPDF()` (Line 24b), `exportTaxCSV()`, and `refreshSite()` net profit calculation
- Date inputs in `openAddExp()` and `openAddCr()` use `toLocaleDateString('en-CA')` (not `toISOString()`) to avoid next-day UTC timezone bug
- Dashboard "Tax Exempt" tab renamed to "Tx Ex/Cps"
- Estimates tab added to every property page — `propData._estimates[key]` array; functions: `getEstimates`, `openAddEst`, `openEditEst`, `saveEst`, `delEst`, `renderEstimates`
- Viewport meta: `maximum-scale=1.0` was removed (no longer needed); iOS auto-zoom prevented by `font-size:16px` on all modal inputs instead
- Recurring expenses: checkbox + frequency (Weekly/Monthly/Quarterly/Yearly) in Add Expense modal; `_recurDates(startDt,freq)` generates all instances from start date through today; each entry tagged with `recur: freq` field; shown with purple `↻ freq` badge in expense list; available on all properties and general expenses
- Multi-page receipt support: PDF receipts converted to per-page images via PDF.js; `pdfToImages()` renders all pages; receipt field supports string or array; `_receiptThumb()` shows page count badge; lightbox has prev/next nav (`lbNav`)
- Receipt delete: `deleteEditExpReceipt()` / `deleteEditCrReceipt()` in edit modals; sets `__deleted__` sentinel, cleared on save
- `_uploadBlob(blob,path,contentType)` — direct blob upload to Supabase storage
- `_stripB64Receipts(ex)` — strips base64 from expense receipts before localStorage/cloud save; keeps only http URLs
- `_receiptArr(r)` — normalizes receipt field (string|array|null) to array
- `autoSyncPull` extra merge uses `_mergeReceipts()` to preserve local receipt images
- `saveHourlyBackup` strips base64 receipts from backup payload
- `netProfitAfterMileage` uses `netProfitFull` directly (no falsy fallback to undefined `netProfit`)
- Task rendering (`renderDashTasks`, `renderTasks`, `renderPropTasks`) escapes title and property with `esc()`
- `renderPropTasks` matches tasks by key OR address (task dropdown saves address string, not key)
- Documents panel close button added (`toggleDashDocs()`)
- Trash / recycle bin system: `getTrash()`, `trashItem()`, `restoreTrashItem()`, `deleteTrashItem()`, `emptyTrash()`, `renderTrash()` — deleted items kept 30 days in `propData._trash`; all delete functions (expenses, credits, tasks, mileage, estimates, docs) route through trash; `purgeOldTrash()` runs on startup; Recently Deleted section on Company tab
- AI receipt scanner date fix: if no transaction date found returns null; app defaults to today (`toLocaleDateString('en-CA')`); prompt explicitly excludes copyright/footer years
- Lightbox `#m-lbox` z-index raised to 9000 — was appearing behind expense modals on mobile
- Contractor payments expandable dropdown: "Show all X payments" button on each contractor card using `data-cid` / `data-cnt` attributes
- XSS: `esc()` applied to all innerHTML render paths — `buildPropPage`, `renderPropCards`, `renderPots`, `renderDashPots`, `renderIncome`, `renderCalDay`, `renderContractors`, bank accounts, `ohioAutocomplete`, closing statement fields, docs tab
- `anthropicKey` removed from Supabase cloud payload in `save()` — API credentials must never be stored in application data
- `propImgs` added to `exportBackup()` — was silently missing, causing photo loss on local backup restore
- Calendar defaults: `calM` and `calS` now initialize to `new Date()` instead of hardcoded May 2026
- `openAddIncome()` date bug fixed: uses `toLocaleDateString('en-CA')` instead of `toISOString()` (UTC timezone bug)
- `var extra` in calendar rendering renamed to `var extraCount` — was shadowing global `extra` expense object
- `startAutoSync()` has `clearInterval` guard (`let _syncTimer`) — prevents interval stacking on re-call
- `autoSyncPull` catch block now logs: `catch(e){ console.warn('autoSyncPull error:',e); }` — was silently swallowed
- Global `unhandledrejection` handler added for visibility into mobile crashes
- `suggestExpCategory` XSS fix: AI-returned category text stored in `window._catSuggestions[key]` object, referenced by key in onclick — no user-controlled text interpolated into JS strings
- `runIncomeScan` fixed: income receipts uploaded to Supabase storage (URL saved), not stored as base64 blobs in cloud payload
- Duplicate expense/credit check now matches on amount + date + description (was amount only — false positives on different-date same-amount expenses)
- All 24 native `confirm()` dialogs replaced with `appConfirm(msg, okLabel)` — returns a Promise, all callers converted to `async`/`await`; custom modal matches app glass morphism style; native confirm is blocked in some mobile WebViews
- `tests.html` added — 22 financial calculation assertions covering `fmt()`, `eTotal()`, `propNetProfit()`, `propROI()`, `mileageDeduction()`, `mealsCorrection()`, `netProfitAfterMileage()`; open in browser to run
- `.github/workflows/pages.yml` added — custom GitHub Pages workflow with 3-attempt retry logic (15s, 30s delays) for flaky GitHub Pages deploy API; `concurrency: group: pages` prevents overlapping deploys
- `refreshSite(scope)` scoped: added `scope='stats'` param that skips 8 expensive DOM renders (renderPropCards, renderE general, renderIncome, renderDashPots, renderDashTasks, renderDocCards, loadNotes, loadBalanceSheetInputs); all hot-path callers (expense/credit/task/income/pot add/edit/delete, receipt scan, CSV import, closing import, trash restore) use 'stats'; full refresh kept for startup, tab switches, year changes, autoSyncPull
- BEXP hardcoded expense data fully migrated: all entries confirmed in Supabase, `BEXP` const deleted from `index.html`, `allE()` simplified to `return extra[p]||[]`, migration function and all `_migrated` guards removed; one missing warblers entry ($15,629.56) was added via console before deletion
- Paste receipt support added to credit modals (`#m-credit`, `#m-edit-credit`) via `handleCrPaste()`; registered on `openAddCr`/`openEditCrByIndex`, removed in `closeModal`
- Estimates modal AI scan: drop zone + `handleEstImage()`/`handleEstDrop()`/`handleEstPaste()`/`scanEstImage()` — AI fills all estimate fields from a pasted/dropped image
- Duplicate expense check: matches amount + date only (description comparison removed per user request — amount+date is the intended behavior)
- Return Item feature in Edit Expense modal: hidden form (`id="eeexp-return-form"`) revealed by `toggleReturnForm()`; `saveReturnCredit()` stamps `_rid` on both original expense and new credit; `renderE()` shows RETURNED (red) / PARTIAL RETURN (amber) badges based on linked `_rid` credits
- `#m-confirm` dialog: `align-items:center !important; justify-content:center !important` — stays centered on screen instead of top
- Mileage form redesigned: property first (auto-fills start date from `pdate||offer`, end date from `sdate||today`, purpose from address); `onMilePropChange()` handles auto-fill; `window._editMileageId` flag for stable edit mode; `openEditMileage(id)`, `cancelMileageEdit()`, `_resetMileageBtn()` added; no bulk-add button
- Mileage year filter: checks both `t.date` (start) and `t.dateEnd` — fixed in `refreshSite`, `exportTaxPDF`, `exportTaxCSV`, `renderMileage`
- Tax calculation audit (first pass): `refreshSite` now passes `taxYear` to `propSold`, `eTotal`, `propPurchase`; `mealsAll` filter includes `taxYear`; `soldProps` filter uses `propSold(p,taxYear)>0`; P&L rows use year-filtered values; `netProfitAfterMileage = netProfitFull - mileDeduction + mealsAll*0.5`; `tax-revenue` uses `totalRevIncome` (includes other income); PDF/CSV export both include `otherIncome` in total revenue; `propSold(p,yr)` returns 0 when `sdate` empty and `yr` specified
- Tax calculation audit (second pass — deep logic): fixed 9 bugs:
  1. `setEl("bs-prop-val")` removed — no such element exists (was silent no-op)
  2. `pl-total-rev` now uses `totalRevIncome` (was `revenue` — omitted other income, table didn't add up)
  3. `stat-net-profit` now subtracts `mileDeduction` (was overstating dashboard net profit by full mileage amount)
  4. `stat-avg-roi` filter now uses `propSold(p,taxYear)` (was unfiltered — included sold properties from all years)
  5. `delEst` trash label uses `item.job||item.contractor||'Estimate'` (was `item.desc` — field doesn't exist on estimate objects)
  6. `deleteIncome` now routes through `trashItem` before filtering (was permanently deleting without 30-day recovery)
  7. `_recurDates` month-end overflow fixed: day clamped to `Math.min(day, new Date(y,m+2,0).getDate())` for monthly/quarterly/yearly — prevents Jan-31 drifting to Mar-3
  8. Closing statement import fallback date uses `toLocaleDateString('en-CA')` (was `toISOString()` — UTC off-by-one after 8pm local)
  9. `propNetProfit` now adds back `meals*0.5` (was over-deducting meals; per-property and portfolio figures now consistent)
- Contractor delete fixed: `deleteContractor` now clears `w9=false` on all matching expenses (was only removing `propData._contractors` entry — auto-detected contractors kept reappearing); `deleteContractorByIdx` made async; `openAddContractor` replaced native `prompt()` with modal
- CSV import: preview confirm before importing ("Import 722 expenses totaling $X?"), duplicate check (amount+date), `importExpCSV` made async
- W9 checkbox: `hookW9Listeners` guarded with `_done` flag to prevent listener stacking on every modal open; `scanExpReceipt` now calls `checkW9Visibility('exp')` after AI fills fields
- Receipt upload failure: `_receiptUploadFailed` flag set on failed Supabase storage uploads; prominent red error shown; `saveExp` blocked until receipt is removed or re-attached on better connection
- Retry Failed Receipts button on Company tab: scans all expenses in memory for base64 receipts, uploads to Supabase storage, updates records so other devices sync
- Scan date `"null"` bug fixed: AI returns string `"null"` (not JSON null) when no date found; `"null"` is truthy so fallback to today never triggered; fixed on both expense and credit scan paths
- Fixed Assets tab added to Tax page: `propData._assets` array; Section 179 / Bonus Depreciation / MACRS 5-yr elections; vehicle fields (make/model/year/VIN/GVWR/miles); IRS caps enforced (passenger car $12,200, heavy SUV $28,900, truck/equipment no cap); loan interest tracked separately (Schedule C Line 16); deductions flow into `refreshSite` net profit, P&L, Tax Summary, exportTaxPDF, exportTaxCSV; functions: `getAssets`, `assetDeduction`, `totalAssetDeductions`, `totalAssetInterest`, `renderAssets`, `openAddAsset`, `openEditAsset`, `saveAsset`, `deleteAsset`, `toggleAssetTypeFields`, `toggleAssetElectionFields`, `updateAssetCalc`
- `syncAllReceiptsToCloud` forEach body was empty — filled with base64 receipt scan logic
- `exportTaxPDF` popup null check added: alerts user if pop-up is blocked and returns early
- `propPurchase` year filter: was checking `pr.sdate` (sale date) instead of `pr.pdate` (purchase date) — fixed
- `scanOne` JSON guard added: uses regex match for `{...}` block instead of direct `JSON.parse` on raw text
- `downloadDoc` now uses `doc.url||doc.data` — supports both old data-URL and new Supabase URL storage paths
- `saveDocFile` catch block now sets `doc._pending=true` and calls `save()` on upload failure
- `runIncomeScan` wrapped in try/finally — button re-enabled even on error; also validates file is an image before API call (FIX 17)
- `exportTaxPDF` XSS: added local `he()` helper; wrapped `pr.addr`, `cat`, `c.vendor`, `c.ein`, `a.description`, `a.type` in HTML escaping
- `renderContractors` manual-only section: wrapped `c.name`, `c.ein`, `c.phone`, `c.email` with `esc()`
- `ohioAutocomplete` debounced with 350ms `window._ohioTimer`; fetch wrapped in try/catch
- `pl-stat-net` stat card now updated after `plNet` is computed (fully adjusted for mileage, assets, meals)
- `taxYear` default changed from hardcoded `2026` to `new Date().getFullYear()`
- `renderTaxYearBtns` start year changed from 2026 to 2024
- Financing tab added to every property page: `propData._loans[key]` array stores loan objects (type, lender, amount, rate, startDate, endDate, interestOnly, notes); `getLoans(p)`, `totalActiveLoans()`, `autoGenLoanInterest(p)` helpers added; `openAddLoan/openEditLoan/saveLoan/deleteLoan/renderLoans` manage the shared `#m-loan` modal; auto-generated monthly interest expenses tagged with `_loanId` and `_autoGen:true` (category "Loan Interest") are created/removed alongside each loan; balance sheet Outstanding Loans display now includes `totalActiveLoans()` added to the manual input value, with an "Auto-detected from property loans" note shown below the field
- `_recurDates` 500-cap: logs `console.warn` when hit; `saveExp` shows user-visible error and blocks save if cap reached
- `restoreBackup` FileReader wrapped in Promise — async function now properly awaits file reading
- `checkPin` first-use flow: if no PIN stored in localStorage, auto-unlocks and prompts user to set a PIN; also clears `pinEntry` after successful unlock
- `startAutoSync` `visibilitychange` listener: removes old handler before adding new one via `window._visHandler` guard
- `saveHourlyBackup` skips automatic snapshots if last backup was < 55 minutes ago (uses `propData._backups` timestamps)
- `appConfirm` keyboard-accessible: Escape key cancels; `#m-confirm` element has `role="dialog" aria-modal="true"`
- `renderQ` and `handleIncomeScanFiles`: `f.name` wrapped with `esc()` in innerHTML
- Duplicate `expReceiptMime` declaration removed (kept the one in expenses section at line ~3084, removed from top-of-script var declarations)

---

## Developer Rules (Ongoing)

- **Keep CLAUDE.md current** — after every fix, feature, or structural change, update the relevant section (fix history, function reference, audit scores). Do this automatically without being asked.
- **Update audit scores** after completing items that address a listed gap — recalculate and update the table.

---

## Audit Scores (last assessed 2026-07-11)
| Area | Score | Main remaining gap |
|---|---|---|
| Security | 52/100 | Anthropic API key in public git history — rotate at console.anthropic.com |
| Performance | 74/100 | `refreshSite()` still rebuilds full DOM on tab switches and year changes |
| Reliability | 76/100 | — |
| Data Integrity | 82/100 | — |
| Maintainability | 36/100 | Single 5800-line file, no module system |
| **Overall** | **68/100** | |

---

## Backup
Company tab → Export Backup → save JSON file to iCloud/Google Drive weekly.
Restore: Company tab → Restore Backup → select the JSON file.
