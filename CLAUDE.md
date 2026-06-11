# Apex Homes LLC — Developer Reference

## What This App Is
Single-file (`index.html`) property management web app for a house-flipping business. No build toolchain — all HTML, CSS, and JavaScript are inline. Deployed on GitHub Pages, syncs data to Supabase every 5 seconds. ~5700+ lines.

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
- `allE(p)` — returns all expenses for a property (handles BEXP migration)
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
- `saveHourlyBackup()` — saves a timestamped cloud snapshot (id=`backup-{ts}`), keeps only 2 most recent; guards against empty propData
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
- Hourly cloud snapshots: `saveHourlyBackup()` / `restoreCloudBackup()` on Company tab, max 2 kept
- Supabase Auth + RLS implemented: login screen, session tokens on all requests, `sbLogin`/`sbRefreshAuth`/`sbLogout`; Cloud Account card on Company tab
- `esc(s)` HTML escape helper added, used throughout `renderE`, `renderCr`, `renderEFiltered`, `showVendorSuggest`
- `_pushPending` flag prevents autoSyncPull from overwriting a pending save
- `fmt(n)` handles NaN — returns `$0.00` instead of crashing

---

## Backup
Company tab → Export Backup → save JSON file to iCloud/Google Drive weekly.
Restore: Company tab → Restore Backup → select the JSON file.
