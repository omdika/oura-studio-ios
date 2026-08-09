# Oura Studios — Product & Engineering Handoff

Custom iOS inventory app for a self-production accessories business (scrunchies, dst).
Core problem this app solves: **accurate HPP (COGS) calculation when raw fabric is cut into multiple product sizes with different fabric types**, plus sales, stock, and margin tracking.

This doc is structured for three audiences reading in parallel:
- **Design** → Section 2 (screens/flows) for mockups in Claude Design
- **Backend** → Section 3 (DB schema) + Section 4 (API contract)
- **Product/QA** → Section 1 (concepts) to sanity-check logic

---

## Revision History

| Version | Date | Changed by | Summary |
|---|---|---|---|
| v1.0 | 2026-07-29 | Initial | Full initial spec — all screens, schema, API contract |
| v1.1 | 2026-07-30 | Frontend | **Auth method changed: email+password → Google SSO (OAuth 2.0).** Login screen replaced with "Sign in with Google" button. Backend impact: `POST /auth/login` replaced with `POST /auth/google`, `owner_account` table drops `password_hash`, adds `google_sub`. Setup step changes from credential seed to authorized-email env config. See Section 0 Auth, Section 2 Screen 0, Section 3 `owner_account`, Section 4 Auth endpoints. |
| v1.2 | 2026-07-31 | Frontend | **Frontend implementation complete (all 11 screens built).** Material name corrected: "Waffle Merah" → "Waffle Merah" throughout spec examples and mock data. Added `GET /reports/dashboard` endpoint (used by Beranda screen — returns today's sales summary + low-stock alerts in one call). Mock seed data simplified to 2 fabric purchases only: Satin Putih (150×100 cm) and Waffle Merah (150×100 cm). Open decision #1 (weighted-average cost) confirmed as implemented approach. See Section 4 Reports, Section 6. |
| v1.3 | 2026-07-31 | Frontend | **Three bug fixes + Optimasi → Produksi flow completed.** (1) Optimasi Step 2 candidate filter fixed: now only shows PatternSpecs whose `fabrics[].materialId` matches the selected purchase's material — previously showed all active specs regardless of fabric. (2) MockAPIService `_productionBatches` now persists across calls — `getProductionBatches`, `confirmBatch`, `updateBatchItem`, `deleteProductionBatch` all operate on the same in-memory store; previously `getProductionBatches` always returned `[]`. (3) `deleteProductionBatch` now correctly blocks confirmed batches with 409. Optimasi → Produksi navigation wired: after "Gunakan Layout Ini", a success screen appears showing batch details with "Lanjut ke Produksi" (switches to Produksi tab) and "Mulai Optimasi Baru" (resets to Step 1). See Section 2 Tab: Optimasi (filter spec clarification added), Section 7 (updated). |
| v1.4 | 2026-07-31 | Frontend | **Three more bug fixes + `CuttingLayout` model change + mock data simplified for end-to-end testing.** (1) Optimizer orientation bug fixed: mock now tries both normal and rotated orientations and picks whichever yields more pieces — previously only tried normal orientation, causing e.g. 7 pcs instead of correct 10 for a 150×200 roll. (2) `createLayout` mock now persists layouts to `_cuttingLayouts` and uses real request data (materialName from purchase, items from request, wastePct and totalFabricCost computed) — previously returned a hardcoded stub with empty items. (3) `createProductionBatch` mock now looks up the saved layout and builds batch items from it with live HPP calculation (fabric from layout's costPerPiece, labor/overhead/pooled from settings, hardware from PatternSpec components) — previously always returned 2 hardcoded Scrunchie M+S items regardless of optimizer output. **Model change:** `CuttingLayout` gains `strategy: String?` field (raw value e.g. `"min_waste"`) — backend must include this in `POST /cutting-optimizer/layouts` response so `createProductionBatch` can label the batch correctly. **Mock data:** stripped to minimal test set — Satin Putih (2 purchases: 150×100 + 150×200), Waffle Merah (1 purchase: 150×100), Scrunchie product with M+L sizes only, 2 PatternSpecs (M: 150×18 Satin, L: 150×22 Satin), no sales orders. See Section 3 (cutting_layout schema), Section 4 (POST /cutting-optimizer/layouts response), Section 7 (updated). |
| v1.5 | 2026-08-01 | Frontend | **Optimizer `minQty` constraint now respected.** Previously the optimizer's sequential greedy loop never read `candidate.minQty`, causing the first-processed candidate to exhaust the roll and subsequent candidates to receive zero pieces (e.g. L=9 M=0 when both had min=2). Rewrote `suggestLayouts` with a two-phase algorithm: (1) pre-compute orientation, cols, rowHeight, and `minRows = ceil(minQty / cols)` for every candidate; (2) for each candidate, subtract the sum of all future candidates' `minRows × rowHeight` from remaining length before allocating, guaranteeing each candidate gets at least its minimum rows. Strategy differentiation: minWaste/maxQty use all available extra rows; maxProfit holds back 10% of extra rows. Expected results for roll 150×200 with M (18cm) min=2 and L (22cm) min=2: minWaste/maxQty → M=8 L=2 total=10 waste≈0%; maxProfit → M=7 L=2 total=9. **Backend must implement the same two-phase reservation logic** when `candidates[].min_qty` is provided in `POST /cutting-optimizer/suggest`. See Section 4 (Optimasi endpoint). |
| v1.6 | 2026-08-01 | Frontend | **Three UX fixes + mandatory-field validation rule codified.** (1) Back button relocated: BahanDetailView and ResepEditorView now use a custom sticky top bar (`[<] Title [Action]`) above the ScrollView instead of the system navigation bar floating between the ProduksiTabView header and content. (2) Silent data-drop bug fixed in TambahResepSheet and ResepEditorView: `compactMap { guard condition else { return nil } }` was silently dropping incomplete fabric/component entries on save; replaced with explicit pre-save validation that shows a named error and blocks save if any selected item's mandatory sub-fields are unfilled. (3) Material name now shown in ProdukDetailView header and ProdukSizeDetailView info card, derived from confirmed production batches. **Mandatory-when-selected rule added to spec** (see Section 2, Tab Resep, Detail Resep card rule): any field that appears because the user made a selection inherits a mandatory obligation on its required sub-fields — the save button must be disabled (not just runtime-checked) until these are filled, and errors must name the specific incomplete item. See dev-frontend skill rule #6. |
| v1.8 | 2026-08-02 | Frontend | **3-level product navigation replacing flat size list.** `ProdukListView` card now has two independent tap targets: the header navigates to `ProdukDetailView` (product management), while each size-label row (M, L) navigates to the new `ProdukSizeGroupView`. `ProdukSizeGroupView` shows all fabric variants for that (product, size) — e.g. M · Satin Pelangi and M · Waffle Merah — with per-variant stock, HPP, margin, and a "Tambah Varian" button that opens `AddSizeSheet` with the size label pre-filled and locked. `ProdukDetailView` also now shows size-label groups instead of a flat variant list. The flat layout did not scale beyond ~3 variants per product. See Section 2, Screen 3 (Products). |
| v1.9 | 2026-08-02 | Frontend | **Optimizer orientation-fallback fix + `bestMinLen` reservation.** Two related bugs in the v1.5 two-phase algorithm caused one candidate to always receive 0 pieces when multiple sizes shared a fabric roll: **(1) Over-reservation:** `futureMinLength` used `primaryMinRows × primaryRowHeight` for each future candidate. When the primary orientation's rowHeight equals the full roll length (e.g. M piece with cutLength=100cm on a 100cm roll), this reserved 100% of the fabric for that one candidate's future minimum — leaving 0 available for the current candidate. **(2) No orientation fallback:** if the primary orientation didn't fit in the available space after reservation, the candidate was unconditionally skipped even when the alternative orientation (smaller rowHeight) would have fit. **Fix:** (1) reservation now uses `bestMinLen = min(normalMinRows × cutLength, rotMinRows × cutWidth)` — the smallest fabric length sufficient to satisfy `minQty` using either orientation; (2) if the primary orientation yields `maxRows=0`, the allocation phase tries the alternative orientation before skipping. Both orientations are pre-computed in Phase 1 and stored alongside the primary. **Expected result for M (100×22, rotation allowed) + L (120×25) on 200×100cm roll:** minWaste → M=6 pcs (rotated, 3 rows × 22cm), L=1 pcs (rotated, 1 row × 25cm), waste=9cm (9%). Without fix: M=0, L=4 (min constraint violated). See Section 1.5 (algorithm updated). |
| v2.0 | 2026-08-02 | Frontend | **Seed data locked to real product specs + three UX additions.** (1) Mock seed data updated: 4 ProductSize variants (M·Satin, M·Waffle, L·Satin, L·Waffle) and 4 PatternSpecs with real cut dimensions confirmed by owner — see Section 7 Mock Data State. (2) Dashboard quick actions "Catat Produksi" and "Optimasi Pola" now navigate to the correct Produksi sub-tab via `AppState.selectedTab` / `AppState.produksiSubTabIndex` (previously both had empty `{ }` action closures). (3) "Tambah Varian Kain" sheet now loads fabric options from active PatternSpecs for that product+size (replaces free-text field); includes optional "Stok Awal" field that — when filled — deducts the corresponding fabric length from bahan purchases (FIFO) and records the qty as `manualStockQty`. New API calls: `getPatternSpecsForSize`, `addStockFromBahan`. |
| v1.7 | 2026-08-02 | Frontend | **Fabric variant as first-class ProductSize dimension + one-spec-per-fabric rule + stock correctness fix.** **(DB)** `product_size` gains `fabric_variant_name TEXT` (nullable); uniqueness constraint changes from `(product_id, size_label)` to `(product_id, size_label, fabric_variant_name)`; each (size + fabric) combination is now a separate row — e.g. "M · Satin Pelangi" and "M · Waffle Merah" are distinct `ProductSize` rows, each tracking their own stock independently. **(API)** `POST /products/{sku}/sizes` body adds optional `fabric_variant_name`; `PATCH /products/{sku}/sizes/{sizeId}`, `DELETE /products/{sku}/sizes/{sizeId}`, and `POST /products/{sku}/sizes/{sizeId}/price-advisor` path parameter changes from `sizeLabel: String` to `sizeId: UUID` (required because multiple sizes now share the same label). **(UX)** TambahResepSheet size picker deduplicates by `sizeLabel` (shows "M" once even if M·Satin and M·Waffle exist); saving creates one `PatternSpec` per selected fabric, each auto-linked to the correct `(sizeLabel + fabricVariantName)` ProductSize (auto-created on-the-fly if absent); OptimasiView candidate rows show the fabric name + that fabric's specific cut dimensions (previously showed first-fabric's dimensions regardless); ProdukListView and ProdukDetailView display `displayLabel` ("M · Satin Pelangi"); AddSizeSheet adds optional "Jenis Kain" field; material-name derivation in ProdukDetailView now reads `sizes.compactMap { $0.fabricVariantName }` instead of scanning confirmed batches. **Root-cause fix:** previously all fabrics in a multi-fabric recipe shared one `PatternSpec` and one `productSizeId`, causing production confirmation to increment the wrong variant's stock. The one-spec-per-fabric rule eliminates this class of stock-tracking bug. See Section 3 (`product_size`), Section 4 (Products/Stock), Section 7. |
| v2.2 | 2026-08-03 | Frontend | **Tambah Penjualan: product picker modal + stock-only filter.** `TambahPenjualanSheet` rewritten. Items are no longer added via inline `SearchableDropdownField` — instead, "Tambah Produk" button opens `ProductPickerSheet`, a searchable bottom sheet that loads only `ProductSize` variants with `currentStockQty > 0` (archived sizes also excluded). Variants are grouped by product name, each row shows `displayLabel` (e.g. "M · Satin Pelangi"), selling price, and a stock badge (green = normal, amber = menipis). Already-selected variants are hidden from the picker to prevent duplicates. After selection, the item appears as a card with: displayName, "Tersedia: N pcs" subtitle, qty field (with inline over-limit warning if qty > maxQty), harga satuan (pre-filled from sellingPrice), and diskon. `canSave` blocks if any item's qty exceeds its `maxQty`. Empty state shown when no items added yet. See Section 2, Screen 4 (Sales). |
| v2.1 | 2026-08-02 | Frontend | **Fabric picker in AddSizeSheet replaced with searchable inventory modal.** The native `Picker` dropdown in "Tambah Varian Kain" was not scalable for dozens of fabrics. Replaced with `FabricPickerSheet` — a full bottom sheet modal with search bar and scrollable list. Key behavior changes: **(1) All inventory fabrics shown**, not just those in the active resep for this size. Each row shows the fabric name with a green "Ada di resep · bisa kurangi stok bahan" badge when a matching PatternSpec exists for this (product, size, fabric) — fabrics without a spec are shown plainly. **(2) Inline "add new" option** — if search text doesn't match any existing fabric, a "Tambah '[X]'" row appears at the bottom, allowing the user to name a brand-new fabric variant not yet in inventory (selectedSpecId = nil, so no bahan deduction is attempted). **(3) Stok Awal field only appears when fabric has a matching resep spec** (same rule as before, now derived from modal selection). **(4) Footer feedback** under the selected fabric row states either "ada di resep — stok bahan dapat dikurangi otomatis" or "tidak ada di resep — stok bahan tidak akan dikurangi." No API changes. See Section 2 (Screen 3, Level 2 ProdukSizeGroupView). |
| v2.7 | 2026-08-08 | Frontend+Backend | **RINCIAN HPP in batch confirmation + list endpoint field spec.** (1) `GET /products/{sku}/sizes` (list) response spec updated: must include `latest_hpp_breakdown`, `selling_price`, `margin_pct`, `production_stock_qty`, `manual_stock_qty` — these are required by the iOS client's `fetchSizeToProductMap()` enrichment pass which populates the RINCIAN HPP card in draft batch confirmation. (2) Tab Produksi → Produksi screen spec: RINCIAN HPP data source clarified as `latest_hpp_breakdown` from the size list; section is hidden for first-time production (no prior confirmation). See Section 2 Tab Produksi, Section 4 Products/Stock. |
| v3.0 | 2026-08-09 | Frontend | **BahanDetailView: tampilan sisa kain per purchase + total sisa di header.** Tag "Sudah dipakai" diganti dengan status granular: `[Habis]` (merah, remaining=0), `[Sisa X cm]` (kuning, partially consumed), atau tidak ada tag (belum terpakai). Header material menampilkan capsule "Sisa X cm" di sebelah kanan tag kategori — dihitung dari `SUM(remaining_length_cm)` semua purchases. Tidak ada perubahan API — `remaining_length_cm` sudah dikembalikan backend sejak v2.5. `MaterialPurchase` ditambah `isFullyConsumed` dan `isPartiallyConsumed`. See Section 2 (Tab Produksi → Bahan). |
| v2.9 | 2026-08-09 | Frontend+Backend | **DashboardSummary: 5 month-level fields dijadikan optional (backend belum implement).** Backend `GET /reports/dashboard` saat ini hanya mengembalikan `today_*` + `low_stock_alerts`. Field `month_revenue`, `month_orders`, `month_units_sold`, `month_batches_confirmed`, `avg_margin_pct` absen dan menyebabkan `keyNotFound 'month_revenue'` decode error — dashboard dan laporan tidak tampil. Frontend fix: kelima field dijadikan `Double?`/`Int?` di `DashboardSummary`; BerandaView tidak berubah karena sudah `?? 0`. Backend task: tambahkan kelima field ke response schema — lihat v2.9.md untuk definisi per field. See Section 4 (Reports). |
| v2.8 | 2026-08-09 | Frontend | **TambahPenjualanSheet: stepper fix + inline over-stock warning + quick stok adjustment.** (1) Tombol up/down qty sekarang menggunakan `.buttonStyle(.borderless)` — sebelumnya `.plain` di dalam List row dapat diintercept gesture selection sehingga tidak merespons. (2) Up stepper tidak lagi diam-diam berhenti di maxQty — jika qty melebihi stok tersedia, muncul warning inline "Stok tidak cukup (tersedia N pcs)" dengan tombol "Tambah Stok". (3) Tombol "Tambah Stok" membuka `QuickAdjustStokSheet` — sheet medium dengan numeric input untuk jumlah yang ditambah; memanggil `POST /products/{sku}/sizes/{sizeId}/stock-adjustments` (endpoint sudah ada sejak v2.0, reason: "sales_adjustment"); setelah berhasil `maxQty` di item di-update in-place dan warning hilang. Tombol "Simpan" tetap disabled selama ada item dengan qty > maxQty. Tidak ada backend changes. See Section 2, Screen 4 (Penjualan). |
| v2.6 | 2026-08-08 | Frontend+Backend | **API contract fixes: 2 production endpoints + dashboard field.** (1) `GET /reports/dashboard` response contract updated: added `today_units_sold` (Int) — total units sold today across all sales_order_items. Previously missing from spec and backend response, causing decode error on Beranda screen. (2) `PATCH /production-batches/{id}/items/{item_id}` response shape now explicitly specified: must return the updated item object (not the whole batch). Backend was returning the parent batch; iOS client expects only the item. (3) `GET /production-batches` (and by ID): confirmed that `product_size_id` must always be present in item responses — it is `NOT NULL` in the schema; backend was omitting it for confirmed items, causing decode error. Frontend workaround: `productSizeId: UUID?` in `BackendProductionBatchItem` (tolerant decode). See Section 4 Reports + Production. |
| v2.5 | 2026-08-07 | Frontend | **Hardware purchase: tambah field Panjang (cm) opsional + downstream unit propagation.** Hardware kini bisa punya `qty` + `length_cm`. Jika `length_cm` diisi: purchase length-tracked (`remaining_length_cm = qty × length_cm`); material baru inline dibuat dengan `usage_unit = "cm"` bukan `"pcs"`. Jika tidak: count-only. Downstream effect: `usage_unit` dari material mengalir ke screen Resep — field qty komponen menampilkan "Karet Elastis per unit (cm)" untuk hardware panjang, "Ring D per unit (pcs)" untuk hardware unit. Read-only ResepEditorView kini menampilkan unit setelah qty (sebelumnya hanya angka). Section 2 (Tambah Pembelian + Resep/Komponen Hardware field), Section 3 (schema), Section 4 (API). Tidak ada migrasi — kolom sudah ada. |
| v2.4 | 2026-08-07 | Frontend | **Live backend integration + 8 model format fixes.** iOS app connected to live FastAPI backend at Cloud Run URL. All major screens were broken due to backend response format mismatches — fixed via `Backend*` intermediate structs + client-side enrichment pattern (`fetchSizeToProductMap`, `enrichPatternSpecs`, `enrichProductionBatches`). Key fixes: (1) `ProductSizeBasic` for flat size list response. (2) `BackendPatternSpec` for flat pattern spec response. (3) `BackendCreatePatternSpecRequest` — POST /pattern-specs requires flat fields (`fabric_material_id`, `cut_height_cm`), not `fabrics[]` array. (4) Draft HPP: `hpp_*: 0.0` in draft; `fabric_cost_per_piece` used as estimate, shown as `~kain Rp.../pcs`. (5) Archive product/size now uses `PATCH` (soft) not `DELETE` (hard cascade). (6) `est_labor_minutes > 0` validation in TambahResepSheet. (7) SKU auto-generator: per-word 3-char prefix. (8) Optimizer + production batch backend decoders. See `doc/versions/v2.4.md` for full details. |
| v2.3 | 2026-08-05 | Frontend | **4 UI/UX fixes + DateRangeField component + sales report mock data + Supabase stack.** (1) `SearchableDropdownField` and `TokenizedMultiSelectField` sheet layout fixed for iOS 26 Liquid Glass: `fullScreenCover` content was anchoring at screen center/bottom; fixed by wrapping body in `NavigationStack` (nav bar pins content to top). (2) "Done" keyboard toolbar button removed from `NumericInputField` and `InlineSearchDropdownField` — unnecessary extra tap. (3) `InlineSearchDropdownField` now shows list immediately on focus (was gated behind first keypress); "Tambah Baru" button always visible when `onCreateNew != nil`, not just after typing. (4) `ReportsView` redesigned: two `OuraDatePickerField` pickers + "Muat Laporan" button replaced with single `DateRangeField` private component — one tappable button shows "5 Agu – 5 Agu 2026" style label; picker sheet has 5 preset chips (7 Hari, 30 Hari, Bulan Ini, Bulan Lalu, 3 Bulan) + two compact `DatePicker` rows + "Terapkan" callback. `getSalesReport` in `MockAPIService` now filters `_salesOrders` by actual `from`/`to` dates (previously ignored params); 17 seeded `SalesOrder` objects added spanning 30 days. **Database stack changed: PostgreSQL → Supabase** — see Section 0. |

---

## 0. Tech Stack (confirmed)

This section didn't exist in earlier drafts — the schema and API contract were written stack-agnostic, which left real decisions unstated. Confirmed as of this revision:

- **Frontend:** Native iOS — Swift + SwiftUI, standard Xcode project. (Follows from the original "iOS app" requirement; no cross-platform framework was requested or is in scope.)
- **Sync model:** **Multi-device sync required** — this is not a single-device/local-only app. This resolves what was previously an open question and means a real backend is in scope from the start, not a later add-on.
- **Backend:** Python + **FastAPI**. Recommended companions (standard pairing with this stack, not separately negotiated): **SQLAlchemy** as the ORM, **Alembic** for migrations, **Pydantic** for request/response schemas (FastAPI uses this natively, so the API contract in Section 4 maps directly to Pydantic models).
- **Database: Supabase** (updated v2.3 — was PostgreSQL). Supabase is a PostgreSQL-compatible managed backend-as-a-service that replaces the need to self-host and manage a PostgreSQL instance. The SQL schema in Section 3 is valid as-is — Supabase runs PostgreSQL under the hood, so `UUID`, `TIMESTAMPTZ`, `REFERENCES`, and all constraint syntax are supported unchanged. For FastAPI server-side access: use `asyncpg` or `psycopg2` with the Supabase connection string (`SUPABASE_DB_URL`), or use the `supabase-py` client library for convenience. Key environment variables for the backend: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (replaces a raw `DATABASE_URL`). Supabase also provides auth, storage, and real-time subscriptions — these are not used (the app uses its own JWT auth per Section 4), but storage could be added later for invoice PDF attachments.
- **Auth (updated in v1.1 — was email+password, now Google SSO):** since data needs to sync across the owner's devices, the API needs real authentication. This app has exactly one owner (not multi-tenant SaaS), so auth is minimal: **Google Sign-In (OAuth 2.0)** on the iOS client, JWT bearer tokens on every backend endpoint. The iOS app never handles a password — it gets a Google ID token via `ASWebAuthenticationSession` and exchanges it at `POST /auth/google` for an app-level JWT. There is no self-registration endpoint. The "authorized account" is configured by the backend operator via an environment variable (`AUTHORIZED_OWNER_EMAIL`) — only a Google Sign-In whose verified email matches that env var is accepted; all others get 403. The `owner_account` table (Section 3) stores the owner's Google `sub` + `email` on their first successful sign-in, and all subsequent sign-ins must match that same `google_sub`. **See Section 4 Auth endpoints for the exact exchange protocol and token verification steps.**
- **Still open:** hosting/deployment platform for the FastAPI backend (e.g. Railway, Render, Fly.io, self-hosted) — see Section 6.

---

## 1. Core Concepts (read this before designing/building anything)

### 1.1 Entities and their relationship

```
Material (kain, benang, hardware)
   └─ bought as MaterialPurchase (batch, has cost, width, length)
        └─ consumed via PatternSpec (recipe: how much material a SKU+size+material-type needs)
             └─ realized in CuttingLayout (optimizer output: how a specific purchase gets cut)
                  └─ becomes ProductionBatch (actual units produced, actual HPP)
                       └─ added to StockLedger (finished goods stock)
                            └─ sold via SalesOrder (deducts stock, records margin)
```

### 1.2 Why HPP isn't a fixed number per SKU

Fabric consumption depends on **(SKU, size, fabric type)** — satin and waffle need different cut dimensions for the same finished size because of stretch behavior. So `PatternSpec` is keyed by all three, not just SKU+size.

Fabric cost per piece depends on **how the cutting layout nests on the specific fabric roll/piece width** — not on cm² alone. Two patterns with the same area can have very different cost-per-piece depending on how well they tile against the fabric's width. So HPP for fabric is computed **per purchase batch + per layout**, not as a flat rate.

### 1.3 Cost classification (drives how precisely each is tracked)

| Class | Examples | Tracking method |
|---|---|---|
| `direct_precise` | Fabric, hardware (clips, rings) | Tracked per unit via PatternSpec + CuttingLayout |
| `direct_pooled` | Thread, needles, glue | NOT tracked per color/unit. Pooled cost ÷ estimated yield = flat rate per finished unit |
| `labor` | Maker's time | Rate/minute × estimated minutes per size (from PatternSpec) |
| `overhead` | Packaging, electricity, platform fees | Flat rate per unit or % of price |

### 1.4 HPP formula per unit

```
HPP(sku, size) =
    fabric_cost_per_piece(from CuttingLayout of the batch used)
  + pooled_material_rate (thread etc., flat rate, updated periodically)
  + hardware_cost (direct, from PatternSpec qty × Material unit cost)
  + labor_minutes(sku,size) × labor_rate_per_minute
  + overhead_per_unit
```

### 1.5 Cutting optimizer (nesting problem)

Given: a fabric purchase's dimensions (width × length — every purchase, whether a large bolt or a small remnant, is entered as one bounded rectangle; there's no separate "roll" purchase mode, see Section 2 Tab Bahan), and a set of candidate PatternSpecs (each with cut W×H, and whether rotation is allowed — some prints are directional and can't rotate).

Goal: for a given MaterialPurchase, compute one or more candidate **CuttingLayouts** — combinations of {size, qty, orientation} — and their resulting waste % and cost-per-piece.

Approach: **two-phase shelf-packing heuristic** — runs as a pure function server-side or on-device; no ML needed. Produces three output strategies (minWaste, maxQty, maxProfit) in a single pass.

**Phase 1 — per-candidate pre-computation (done once, shared across all three output strategies):**

For each candidate PatternSpec × MaterialPurchase pair, compute both orientations:
- Normal: `cols = floor(rollWidth / cutWidth)`, `rowHeight = cutLength`
- Rotated *(if rotation allowed)*: `cols = floor(rollWidth / cutLength)`, `rowHeight = cutWidth`
- Primary orientation = whichever yields more total pieces on the full roll (`cols × rows`)
- Alternative = the other orientation (stored for Phase 2 fallback — see critical note below)
- `minRows = ceil(minQty / primaryCols)` — rows needed to satisfy `minQty` using the primary orientation
- **`bestMinLen` = `min(normalMinRows × cutLength, rotMinRows × cutWidth)`** — the minimum roll length needed to satisfy `minQty` using *whichever orientation is more compact*. This is NOT the same as `primaryMinRows × primaryRowHeight` and must NOT be simplified to that — see critical note.

**Phase 2 — sequential greedy allocation (run separately for each output strategy):**

For each candidate in submission order:
1. `futureMinLength = sum(bestMinLen for all not-yet-processed candidates)`
2. `available = max(0, remainingLength − futureMinLength)`
3. Try primary orientation: `maxRows = floor(available / primaryRowHeight)`
4. **If `maxRows = 0` and alt orientation exists** → try alt: `maxRows = floor(available / altRowHeight)`. If it fits, switch to alt for this candidate (use altCols, altRowHeight for the rest of the calculation).
5. If `maxRows = 0` in both orientations → skip (can't fit even 1 row).
6. `finalRows = minRows + extraRows`
   - minWaste / maxQty: `extraRows = maxRows − minRows` (use all available space)
   - maxProfit: `extraRows = floor((maxRows − minRows) × 0.9)` (hold back ~10% to preserve fabric value)
7. Emit item: `qty = usedCols × finalRows`, `fabricLengthUsedCm = finalRows × usedRowHeight`, `costPerPiece = (totalPurchaseCost / rollLength) × usedRowHeight / usedCols`
8. `remainingLength -= fabricLengthUsedCm`

**Critical: why `bestMinLen` ≠ `primaryMinRows × primaryRowHeight`**

If a candidate's primary orientation has a large rowHeight (e.g. cutLength ≈ full roll length), using `primaryMinRows × primaryRowHeight` as the reservation amount would reserve nearly 100% of the roll for that candidate's future minimum — starving every candidate processed before it. `bestMinLen` uses the more compact orientation's rowHeight, which may be much smaller. Concretely: M piece with cutLength=100cm on a 100cm roll has `primaryRowHeight=100cm` but `bestMinLen=22cm` (from the rotated alt, rowHeight=22cm). Using 100cm as the reservation would leave 0cm for any candidate processed before M; using 22cm leaves 78cm.

**Why the orientation fallback matters (worked example):**

Roll 200cm wide × 100cm long. M piece: cutLength=100, cutWidth=22 (rotation allowed). L piece: cutLength=120, cutWidth=25.
- M primary=normal (9 pcs on full roll, rowH=100), alt=rotated (8 pcs, rowH=22), `bestMinLen=22`
- L primary=rotated (4 pcs, rowH=25 — normal doesn't fit: 120>100), `bestMinLen=25`
- Processing M: reserve 25cm for L → `available=75cm` → primary (rowH=100): `floor(75/100)=0` → **fallback to alt (rowH=22): `floor(75/22)=3 rows` → 6 pcs, uses 66cm**
- Processing L: remaining=34cm → primary (rowH=25): `floor(34/25)=1 row` → 1 pcs
- Result: **M=6, L=1** (both min=1 constraints satisfied, waste=9cm). Without the fallback: M=0, L=4 (M's minimum silently violated).

This runs server-side (or on-device) as a pure function — no ML needed, just geometry + combinatorics over a small size set (typically 4-6 sizes).

**Important:** the optimizer's output is a **suggestion**. The actual cut always gets user-confirmed/edited after physical cutting (fabric defects, human error), and that confirmed data — not the suggestion — is what the final HPP and stock entry are based on.

### 1.6 Pricing formula (for the "price advisor" feature)

```
selling_price = HPP ÷ (1 − target_margin − marketplace_fee_pct − promo_allocation_pct)
```

Margin vs markup — must be labeled unambiguously in UI:
- Margin = (price − HPP) / price
- Markup = (price − HPP) / HPP

> **Note:** profit-per-labor-minute ranking was considered as a decision metric but is deprioritized for now (not in current scope). `est_labor_minutes` stays in the schema since it's needed for HPP labor cost, but no ranking feature is built on top of it yet.

---

## 2. Screens & Flows (for Claude Design mockups)

### Bottom navigation (confirmed by mockup)
5 tabs: `Beranda` (Dashboard) · `Produksi` (the 4-tab screen below) · `Produk` (Products/Finished Goods, screen #3) · `Penjualan` (Sales, screen #4) · `Lainnya` (likely houses Reports + Settings, screens #5-6). Note that **Produk is its own bottom-nav destination, separate from the Produksi tabs** — don't nest Products inside the Produksi screen.

### Screen list

0. **Login (updated in v1.1 — was email+password, now Google SSO)** — gates every other screen; the app opens here if no valid stored JWT exists in the iOS Keychain. The screen shows: the Oura Studios brand mark (scissors icon, app name, tagline), and a single **"Sign in with Google"** button styled per Google's button design guidelines (white background, Google G icon, "Sign in with Google" label, rounded rectangle border). No email or password fields.

   **Button tap flow:**
   1. iOS presents a Google OAuth consent screen via `ASWebAuthenticationSession` (the standard system browser sheet — no external SDK required).
   2. Owner authenticates with their Google account.
   3. iOS receives a Google `id_token` in the OAuth callback URL fragment.
   4. App calls `POST /auth/google` with `{ "id_token": "<google_id_token>" }`.
   5. Backend verifies the token with Google, checks the email against `AUTHORIZED_OWNER_EMAIL`, and returns `{ access_token, expires_at }`.
   6. App stores the JWT in the **iOS Keychain** (never UserDefaults or plaintext) and navigates to Beranda.

   **Error handling:** if the backend returns 403 (unauthorized Google account), show an inline error "Akun Google ini tidak diizinkan". If the user cancels the consent screen, silently return to the login screen (no error shown). Any network error shows an inline message.

   **No password, no "Buat akun", no "Lupa password"** — these concepts don't exist in this auth model. Recovery (e.g. owner changes Google account) is handled by updating `AUTHORIZED_OWNER_EMAIL` on the backend and clearing the `owner_account` row.

   A **"Keluar" (log out)** action exists in the Lainnya tab — clears the stored Keychain token and returns to this screen.
1. **Dashboard** — today's sales, low-stock alerts for finished products (product+size below minimum stock), quick actions
2. **Produksi** (core differentiator area) — one screen, **4 tabs**: `Bahan` · `Resep` · `Optimasi` · `Produksi`. These were originally spec'd as 4 separate screens; the mockup consolidates them into one tabbed flow, which is the correct IA — keep this structure. The 4 tabs form a left-to-right working sequence (bahan masuk → resep dipakai → dioptimasi → jadi batch), but each tab is also independently accessible (e.g. to just check material stock without starting a production run).

   **Tab: Bahan** (Materials)
   - **Correction from earlier draft:** this is NOT three equal sub-tabs. `Daftar` → `Detail` is a hierarchical drill-down (list → item), and `Tambah Pembelian` is a contextual action, not a peer destination. Modeling all three as same-level tabs forces the tab order (left–middle–right) to fight the actual usage order (list → detail → add, which visually means left → right → middle) — that mismatch is what made the earlier version feel like backtracking. Fix: use push navigation for the drill-down, and a modal/sheet for the action.

   - **`Daftar`** (the only persistent view under the Bahan tab):
     - Search box at top: textbox with live autocomplete dropdown as the user types (inline, not a separate screen).
     - Picking a suggestion, or tapping any row → **pushes** a Detail screen on top (standard list-detail navigation, with a **back** button/gesture returning to Daftar — not a tab switch).
     - Typing without picking a suggestion filters the list in place.
     - A **"+" button in the header** (top-right) opens the **Tambah Pembelian modal** with the Bahan field empty/searchable — this is the entry point for logging a purchase without already having a specific material open.
     - List: name, category, unit cost, stock qty, Menipis/Rendah color coding — unchanged from before.

   - **`Detail`** (pushed screen, not a tab):
     - Scoped to one material. Shows `avg Rp X/m` badge (live `material.current_avg_cost`), **Riwayat Pembelian** and **Pergerakan Stok** sections (both reverse-chronological; tapping a consumption row jumps to that Production Batch, tapping a purchase row opens it for edit — full edit/delete behavior spec'd below, since this was previously just a one-line mention with no real spec).
     - A **"+ Tambah Pembelian" button** here opens the same modal as above, but with the Bahan field **pre-filled and locked** (small "Ubah" link to override if needed) — this is the expected default path when logging a restock for a material you're already looking at.
     - Back navigation returns to `Daftar` at its prior scroll position (don't reset the list/search).

   - **`Tambah Pembelian`** (modal/bottom sheet, presented over Daftar or Detail — not a tab):
     - Triggered only from the two "+" entry points above, never a standalone tab destination.
     - Bahan field: same searchable dropdown pattern; pre-filled+locked when opened from Detail, empty+searchable when opened from Daftar's header "+".

     - **"Buat bahan baru" flow — exact states (this is where the mockup currently overlaps two elements that should never be visible at the same time):**
       1. **Typing state:** user types in Bahan field → dropdown appears below it showing matching existing materials (if any) + a **"+ Buat bahan baru: '[nama yang diketik]'"** row at the bottom of that same dropdown list, live-updating as they type.
       2. **Tap "+ Buat bahan baru...":** the dropdown **closes completely** (it does not stay open or float above what comes next — this is the bug in the current mockup, where the dropdown suggestion and the new-material panel are stacked on top of each other). The Bahan field itself now shows the typed name in a **locked/confirmed state** (same visual treatment as an existing material being selected), with a small **"Baru"** badge next to it so it's clear this isn't an existing record.
       3. **New-material panel expands inline**, pushing the rest of the form down (not overlapping it): a **Kategori** selector (Kain / Benang / Hardware, single-select, no default — user must choose) appears directly below the confirmed Bahan field.
       4. **Conditional field by category:** if `Kategori = Kain`, a **"Lebar Kain (cm)"** field appears — this sets `material.fabric_width_cm`, a **default/typical width for this fabric**, not a hard lock (see the field-linkage note below for why it's a suggestion, not a constraint). If `Benang` or `Hardware`, no extra field appears here — Kategori alone is enough to create the material record.
       5. Once Kategori (and Lebar Kain, if Kain) is filled, the rest of the form below (dimensions, Total Biaya, Tanggal, Supplier) becomes active/scrollable into view — it was always present, just visually de-emphasized while the new-material panel is incomplete.
       - **Field linkage:** if the user just set "Lebar Kain (cm)" in step 4, the **"Lebar (cm)"** field further down in the same form **auto-fills from it as a starting suggestion** (they usually describe the same fabric) — but stays **fully editable**, since an individual purchase (e.g. a remnant or an odd cut) can legitimately be narrower than the fabric's typical width. Don't lock it.
       - This "+ Buat bahan baru" path is the **only** way new materials get created — there is no separate "add material" screen anywhere else in the app.

     - **No Potong/Roll purchase-type toggle** — this was in an earlier draft and is now removed per explicit direction: every fabric purchase is entered the same way, as one bounded **Lebar (cm) × Panjang (cm)** rectangle, whether it's a small remnant or a large bolt. This also simplifies the cutting optimizer (Section 1.5) — it no longer needs to special-case "fixed-width roll" vs "bounded piece," every purchase is just a bounded rectangle.

     - **Category-conditional fields (full spec):**

       **If Kategori = Kain:**
       - `Lebar (cm)` and `Panjang (cm)` — both plain numeric fields, no toggle, no mode switching. Pre-filled from the material's typical `fabric_width_cm` if set (see field linkage above), fully editable.
       - Common fields below: Total Biaya, Tanggal, Supplier.

       **If Kategori = Benang:**
       - `Ukuran Kemasan` toggle: **Kecil** | **Besar** — purely descriptive metadata to help the owner recognize which purchase record is which later in Riwayat Pembelian; it does not feed into HPP math, since thread stays a pooled/flat-rate cost regardless of spool size (see Section 1.3).
       - `Jumlah (gulung)` — a single numeric quantity field.
       - Common fields: Total Biaya, Tanggal, Supplier.

       **If Kategori = Hardware:**
       - `Jumlah (pcs)` — numeric quantity field, how many pieces/units were purchased.
       - `Panjang (cm)` *(opsional)* — length per unit, for length-based hardware like elastic bands (karet elastis), ribbon/pita, or zipper tape that is bought and consumed by length, not just by piece count. Leave blank for ring/clip/snap-type hardware that has no meaningful length dimension.
       - Common fields: Total Biaya, Tanggal, Supplier.
       - **Behavior when `Panjang` is filled:** the purchase is length-tracked — `remaining_length_cm` (= `qty × length_cm`) is decremented as the hardware is consumed in production, identical to how fabric rolls are tracked. Cost per cm is `total_cost / (qty × length_cm)`. `canSave` requires `qty > 0`; `length_cm` is truly optional (a hardware purchase with only `qty` and no `length_cm` remains valid).
       - **Behavior when `Panjang` is blank:** count-based only — `qty` tracks total stock, cost per unit is `total_cost / qty`. No `remaining_length_cm` tracking. This is the existing behavior for ring/clip/hook-type hardware and remains the default.
       - **Why both?** A single accessory product may use both types: "Ring Elastis 3mm" (by length) and "D-ring 2cm" (by piece). The form must support either in the same session, not force a category sub-type choice.
       - (No package-size toggle for hardware — that's only for thread/yarn.)
       - **`material.usage_unit` for length-based hardware:** when a new hardware material is created inline in Tambah Pembelian with `Panjang (cm)` filled, its `usage_unit` is set to `"cm"` instead of the default `"pcs"`. This is important because `usage_unit` flows downstream into the Resep screens — the component qty field label and unit suffix both derive from `material.usage_unit`. A karet elastis with `usage_unit = "cm"` will show "Karet Elastis per unit (cm)" in the resep form, prompting the user to enter centimetres consumed per product rather than piece count. Count-only hardware keeps `usage_unit = "pcs"`.

     - **Component-level behavior — spec'd precisely so Claude Design can build these as functioning, not just visual, elements:**
       - **Numeric fields (Lebar, Panjang, Jumlah):** numeric keypad only (no letters), decimal allowed with comma as the separator per Indonesian convention (e.g. "5,2"), must be > 0 to allow saving — show inline validation (field border/text turns to an error color, small message below) rather than blocking keystrokes.
       - **Total Biaya:** numeric keypad, auto-formats live as the user types into Rupiah grouping (typing "712500" displays as "Rp 712.500" progressively, not just on blur) — this is a currency-input component, not a plain number field.
       - **Tanggal (date picker):** tapping the field opens the platform-native iOS date picker (wheel or calendar sheet, whichever matches the rest of the app's date pickers — keep consistent across the whole app, don't mix styles). Defaults to **today's date**. **Cannot select a future date** (a purchase can't happen after today) — future dates should be disabled/greyed in the picker, not just rejected after selection. Displayed format matches the rest of the app: "27 Jul 2026" (day, abbreviated month, year).
       - **Bahan and Supplier fields:** both use the identical searchable-dropdown-with-inline-create pattern (see Supplier spec directly below) — same component, reused, not two different implementations.
       - **Close ("×") button:** if any field in the sheet has been changed from its opening state, tapping "×" shows a confirm-discard prompt ("Buang perubahan?" / batal / buang) before closing — don't silently discard a half-filled purchase entry. If nothing was changed, close immediately with no prompt.
       - **"Simpan Pembelian" button:** disabled (visually muted, not tappable) until all required fields for the current category are valid. On tap: brief loading state on the button itself, then either success (sheet dismisses per the flow already described) or an inline error if the save fails (don't lose the user's entered data on failure — keep the sheet open with the error shown).

     - **Supplier field — same pattern as Bahan, now fully specified:**
       - This requires treating Supplier as its own record, not a free-text string — otherwise "Toko Kain Abadi" and "toko kain abadi" fragment into separate suppliers with no way to see combined purchase history per supplier later.
       - Same interaction as Bahan: tap/type in the Supplier field → dropdown shows matching existing suppliers as the user types, live-filtered → tap one to select. If no match, an inline **"+ Tambah supplier baru: '[nama]'"** row at the bottom of the dropdown creates a new Supplier record on tap — no separate screen, no extra fields required (just the name; unlike materials, suppliers don't need a category or dimensions to be usable).
       - Supplier is **optional** — unlike Bahan, a purchase can be saved without one (some purchases might not have a clear supplier on record).

     - **"Simpan Pembelian"** → sheet dismisses, returning to Detail (creating it via push if the sheet was opened from Daftar) with the new purchase at the top of Riwayat Pembelian and avg cost already updated. No tab-hopping at any point in this flow.

   - **Edit & Delete Pembelian (previously undocumented — full spec):**
     - **This is not simple CRUD.** A purchase's `total_cost`/`qty`/dimensions feed into `material.current_avg_cost` (a running weighted average), and once any of that purchase's fabric length has been consumed by a `CuttingLayout`, changing its dimensions retroactively would make the consumption math inconsistent. So editability depends on **whether the purchase has already been used**.
     - **Tapping a row in Riwayat Pembelian** opens the same `Tambah Pembelian` sheet UI, pre-filled with that purchase's data, titled "Edit Pembelian" instead of "Tambah Pembelian" and with a "Simpan Perubahan" button instead of "Simpan Pembelian".
     - **If the purchase is untouched** (fabric: `remaining_length_cm` still equals the original purchased length, i.e. nothing has been cut from it yet; thread/hardware: no stock_ledger consumption rows reference it) — **all fields are freely editable**, including Lebar/Panjang/Jumlah. Saving triggers a full recalculation of `material.current_avg_cost` from all that material's purchases.
     - **If the purchase has already been partially or fully consumed** — `Lebar (cm)` / `Panjang (cm)` / `Jumlah` become **locked** (greyed, not editable) with a short explanatory note ("Sudah dipakai di produksi — dimensi tidak bisa diubah"). **Total Biaya, Tanggal, and Supplier remain editable** regardless of consumption state, since correcting a mistyped price or wrong supplier doesn't affect physical stock tracking. Editing Total Biaya still triggers the avg-cost recalculation.
     - **Delete:** a trash/delete icon on the Edit Pembelian sheet (or a swipe-to-delete gesture on the Riwayat Pembelian row — pick one, be consistent with other list-delete patterns in the app).
       - **If untouched** (same condition as above): delete is allowed, behind a confirm dialog ("Hapus pembelian ini? Tindakan ini tidak bisa dibatalkan."). On confirm: removes the `MaterialPurchase` row and recalculates `material.current_avg_cost` from the remaining purchases.
       - **If already consumed at all:** delete is **disabled**, not just discouraged — removing it would orphan the `CuttingLayout`/`ProductionBatch` records that reference it and corrupt their locked HPP history. Show the same explanatory note as the dimension-lock case above, and don't offer a "force delete" escape hatch; a wrong purchase entry that's already been used should be corrected via the editable fields (cost/supplier/date) rather than removed.

   - **Pagination:** this list grows continuously (every purchase can introduce cost changes; long-running shops will have 30+ materials). Design with pagination/infinite-scroll in mind, not a single static screen — show at least 15-20 sample rows across a couple of fabric types, thread colors, and hardware types when mocking this up, so the scroll/pagination behavior is visible, not just the 6 items in the current mockup.


   **Tab: Resep** (Pattern Specs)
   - **Same structural fix as Tab Bahan:** `Daftar Resep` and `Editor` are not equal peer tabs. `Daftar Resep` is the persistent view; `Editor` is always entered *with context* (either "add new" or "edit this specific row"), never opened blank without knowing why. Use push navigation, not tab-switching, for the same reason explained in Tab: Bahan above.

   - **`Daftar Resep`** (persistent view):
     - Grouped by product name (e.g. "SCRUNCHIE", "IKAT RAMBUT" headers). Each row under a group = one **(size, fabric type)** combination — e.g. "M · Satin" and "M · Waffle" are separate rows since consumption differs by fabric (see Section 1.1–1.2). Row shows cut dimensions (W×H cm), estimated labor minutes, and **"Aktif sejak [date]"**.
     - **"Riwayat Versi" link per row** → pushes to a read-only version-history screen for that specific (size, fabric) pattern spec: a reverse-chronological list of every past version (`effective_from` → `effective_to`, dimensions, labor minutes at that time). Old versions are view-only — you can't edit history, only see what a batch from that period was costed against. No action buttons here except back.
     - Tapping the row itself (not the Riwayat Versi link) → **pushes** to `Editor`, pre-filled with that pattern spec's current active values — this is the "edit" entry point, and saving here creates a new version (see Editor behavior below).
     - **"+" button in the header** → starts the **Tambah Resep** flow (see below) — this is the only "create new" entry point, consistent with how Tambah Pembelian works in Tab Bahan.

   - **"Tambah Resep" flow — full spec, including multi-fabric selection** (the earlier draft only allowed picking one fabric at a time and left component behavior too vague for a real implementation; both are fixed below, and a full worked example is included so the flow is unambiguous end-to-end).

     - **Presentation:** one scrollable bottom sheet with numbered sections, not a multi-screen wizard. All sections are visible at once (progressive disclosure — later sections are visually de-emphasized/inactive until earlier ones are filled, but the user can scroll and see the whole shape of the form). **"Simpan Resep"** stays pinned at the bottom, disabled until every required field is valid.

     - **1. Pilih Produk — full spec & layout:**
       - **Rule:** exactly one product must be selected — this is a hard single-select, never multiple. A `PatternSpec` always belongs to one `Product` via one `ProductSize`; there's no such thing as a recipe shared across two different products.
       - **Layout:** section header "1. PILIH PRODUK" (label style matches the mockup's numbered-section convention), followed by a **horizontally-wrapping row of chips** — existing products first, in the order returned by `GET /products` (suggest: alphabetical or most-recently-used), then the **"+ Tambah Produk Baru"** chip always last in the row so it doesn't shift position as products are added over time.
       - **Chip states:**
         - *Unselected:* light/outline fill, dark text (matches "Ikat Rambut" styling in the reference screenshot).
         - *Selected:* solid filled background (matches "Scrunchie" styling in the reference screenshot) — only one chip in this row can be in this state at a time.
         - *"+ Tambah Produk Baru":* dashed border, muted text — visually distinct from real data chips so it always reads as an action, not a 3rd product choice.
       - **Tap behavior:** tapping an unselected existing chip selects it and deselects whatever was previously selected (radio-button semantics — not a toggle, you can't "deselect" down to zero once one is chosen, since Ukuran and Bahan below depend on a product being set). Tapping the already-selected chip does nothing (no-op, not a deselect).
       - **"+ Tambah Produk Baru" expansion:** tapping it does **not** navigate to a new screen or open a separate modal — it expands **inline, directly below the chip row**, pushing section 2 further down. The expansion shows: a **Nama Produk** text field (autofocaused, keyboard opens immediately), and directly below it a smaller **SKU** field that live-auto-fills as an uppercase slug of whatever's typed in Nama Produk (e.g. typing "Pouch Serut" → SKU field shows "POUCH-SERUT" automatically), with the SKU field remaining manually editable if the user wants to override it. Two small buttons close this expansion: **"Batal"** (collapses the expansion, discards the typed name, no chip is added) and **"Tambah"** (only enabled once Nama Produk is non-empty and SKU is non-empty/unique — validate SKU uniqueness against `GET /products` before enabling; show inline error under the SKU field if a duplicate is typed, e.g. "SKU sudah dipakai"). Confirming with "Tambah" collapses the expansion, inserts a new selected chip with that name into the chip row (positioned just before the "+" chip), and this new product becomes the current selection for the rest of the sheet.
       - Nothing below section 1 is enabled/visible in an interactive state until a product is selected (existing or newly created) — sections 2-4 stay visually muted/disabled, consistent with the earlier progressive-disclosure note.

     - **2. Pilih Ukuran — full spec & layout:**
       - **Rule:** exactly one size must be selected — also a hard single-select, same reasoning as Produk (one `PatternSpec` = one `ProductSize`).
       - **Layout:** identical structural pattern to section 1 — header "2. PILIH UKURAN", horizontally-wrapping chip row scoped to **only the currently-selected product's existing sizes** (re-fetch/filter this list every time the Produk selection in section 1 changes — if the user switches products after having picked a size, the size selection resets, since sizes don't carry across products).
       - **Chip contents, in order:** existing sizes for that product (in whatever order they were created, or a recognized-progression order XS→S→M→L→XL→XXL if all labels match that convention), then a **suggested next-size chip** if the existing sizes form a recognizable progression with a gap at the top (e.g. XS/S/M/L present → show "+ Buat ukuran 'XL'"; if sizes are already XS-XXL, no suggestion chip appears since there's no obvious next size), then a plain **"+ Ukuran lain..."** chip last.
       - **Selected/unselected chip states:** identical visual treatment to section 1's chips (filled = selected, outline = unselected).
       - **"+ Buat ukuran '[X]'" (the auto-suggested one):** single tap immediately creates and selects that size — no further text entry needed, since the label is already fully determined by the suggestion.
       - **"+ Ukuran lain..." expansion:** tapping it expands inline below the chip row (same pattern as Produk's "+ Tambah Produk Baru") with a single **Label Ukuran** text field (e.g. for entering "Kecil", "Sedang", "XXXL", or any custom label) and **"Batal"**/**"Tambah"** buttons, same validation pattern (non-empty, and unique within this product's existing sizes — reject "M" if "M" already exists for this product, with inline error "Ukuran ini sudah ada").
       - Sections 3-4 stay disabled/muted until a size is selected, same progressive-disclosure rule as before.


     - **3. Pilih Bahan (Kain) — full spec & layout, multi-select search+dropdown (this is the part that most needs precise spec):**
       - **Rule:** one *or more* fabrics may be selected — this is the one field in the whole sheet that's intentionally multi-select, because a single Tambah Resep session commonly needs to define the recipe for more than one fabric at once (e.g. Satin *and* Waffle for the same new size). Do not build this as a single-select chip row like sections 1-2 above.
       - **Layout:** section header "3. PILIH BAHAN (KAIN)", followed by **one field** (not a chip row) that looks like a text input but behaves as a tokenized multi-select — visually: a rounded-rectangle container matching the other text-input fields in this app (same border/fill as e.g. the Lebar/Panjang fields elsewhere), tall enough to wrap to 2+ lines once several tokens are added. A small search icon at the field's left edge signals it's searchable, not just typed free text.
       - This field is a **tokenized multi-select search input** (the same interaction family as an email "To:" field with recipient chips), not single-select chips.
       - **Exact interaction sequence:**
         1. User taps the Bahan field → keyboard opens, an empty text input is focused (any already-selected fabrics show as small removable chips/tokens to the left inside the same field, e.g. "Satin Putih ×").
         2. User types (e.g. "sat") → a dropdown list appears directly below the field, live-filtered to matching **Kain** materials that already have at least one purchase on record (same eligibility rule as before — a recipe can't be defined against a fabric with no cost history). Materials already selected as tokens are excluded from this list (or shown greyed/disabled) so they can't be picked twice.
         3. Tapping a result in the dropdown **adds it as a token/chip inside the field** (does not close the field or navigate away) and **clears the text input**, which stays focused so the user can immediately type the next fabric name. This repeats for as many fabrics as needed.
         4. Tapping the "×" on any existing token removes just that fabric.
         5. If the typed text matches no existing (purchased) material, show a short inline note ("Bahan belum ditemukan — tambahkan dulu di Tab Bahan") instead of a "+ Buat baru" option — fabric creation is intentionally not available inline here, same rule as the single-select version had, now just restated for the multi-select case.
       - **Minimum 1 fabric required** to proceed to section 4; no maximum.

     - **4. Detail Resep — one card per selected fabric (this is the section that changes shape based on step 3, and needs the most explicit spec for Claude Code to get right):**
       - If 2 fabrics were selected in step 3 (e.g. "Satin Putih" and "Waffle Merah"), this section renders **2 separate cards**, each headed by that fabric's name, each fully independent with its own: Lebar Potong (cm), Tinggi Potong (cm), Rotasi Diizinkan toggle, Komponen Hardware list (add/remove rows), Estimasi Waktu Kerja (menit). This mirrors why fabric-specific recipes exist in the first place (Section 1.2) — satin and waffle behave differently when cut, so their dimensions are never shared, even though they're being defined in the same sitting.
       - **Convenience action, not a default:** below the first card, offer a small **"Salin Komponen Hardware ke bahan lain"** button — hardware (e.g. "Ring Elastis 3mm × 1 pcs") is the one part that's usually identical across fabrics for the same size, so this copies just the Komponen Hardware rows from card 1 into any other cards that are still empty. It never touches Lebar/Tinggi/Rotasi/Waktu Kerja, since those are exactly the values expected to differ per fabric — auto-copying them would undermine the reason multi-fabric cards exist.
       - Each card validates independently; **"Simpan Resep" stays disabled until every card's required fields are filled**, not just the first one. **Required fields for each fabric card:** Lebar Potong > 0 AND Tinggi Potong > 0 (mandatory — a fabric entry with zero dimensions cannot produce a valid HPP). Optional fields per card: Rotasi toggle (defaults to on), Komponen Hardware (can be empty), Estimasi Waktu Kerja (menit, optional — defaults to 0 if blank). **Required fields for each component row:** qty > 0 (mandatory — adding a component with qty=0 is meaningless and must be treated as an incomplete entry, not a valid save). The "mandatory when selected" rule: any field that becomes visible only because the user made a selection (fabric card because a fabric token was added; component row because a component was added) is mandatory — the act of selecting it creates an obligation to fill its required sub-fields before saving. If a sub-field is unfilled, block save AND show a clear inline error naming which specific item is incomplete, rather than silently dropping the incomplete entry from the saved data.

     - **Save behavior (client-side batching — spec'd explicitly since the backend has one `PatternSpec` per fabric, not a bulk endpoint):** tapping **"Simpan Resep"** issues one `POST /pattern-specs` call per card (see Section 4 API contract) — e.g. 2 fabrics selected → 2 calls, one for Satin's card and one for Waffle's card, each carrying that card's own dimensions/rotation/hardware/labor-minutes plus the shared `product_size_id`. Show one combined loading state while all calls are in flight. **If all succeed:** dismiss the sheet, return to `Daftar Resep` with both new rows visible under the product group. **If some fail and some succeed:** don't discard the whole sheet — keep it open, mark which card(s) failed with an inline error, keep the successful card(s) visually confirmed, and let the user retry just the failed one(s) rather than re-entering everything.

     - **Contextual pre-fill:** if "+ Tambah Resep" is opened while already viewing a specific pattern spec (e.g. from the "Scrunchie · M · Satin" Editor, or from a row in Daftar Resep), **Produk and Ukuran pre-select to that context** and show as already-chosen (e.g. "M (sudah ada)" highlighted) — the common real case is "same product and size, just need recipes for one or more different fabrics," so only Bahan (step 3) and Detail Resep (step 4) need fresh input. Opening "+ Tambah Resep" from the bare `Daftar Resep` list (not from within a specific spec) starts with nothing pre-selected.

     - **Worked example, to make the whole flow concrete:** adding a brand-new size to an existing product, for two fabrics at once —
       1. Pilih Produk: tap the existing **"Scrunchie"** chip.
       2. Pilih Ukuran: existing sizes show as chips (XS, S, M, L, XL); tap **"+ Buat ukuran 'XXL'"** (auto-suggested since XL is the current largest) → confirms **"XXL"** as a new ProductSize.
       3. Pilih Bahan: type "sat" → tap **"Satin Putih"** from the dropdown (becomes a token) → type "waf" → tap **"Waffle Merah"** (becomes a second token). Field now shows two chips: "Satin Putih ×" "Waffle Merah ×".
       4. Detail Resep shows two cards:
          - **Satin Putih card:** Lebar Potong `22`, Tinggi Potong `18`, Rotasi Diizinkan on, Komponen Hardware: "Ring Elastis 3mm × 1 pcs", Estimasi Waktu Kerja `12` menit.
          - **Waffle Merah card:** Lebar Potong `19`, Tinggi Potong `17`, Rotasi Diizinkan on, Komponen Hardware: (tap "Salin Komponen Hardware ke bahan lain" → "Ring Elastis 3mm × 1 pcs" appears here too), Estimasi Waktu Kerja `12` menit.
       5. Tap **"Simpan Resep"** → two `POST /pattern-specs` calls fire (XXL·Satin, XXL·Waffle) → both succeed → sheet dismisses → `Daftar Resep` now shows two new rows under "SCRUNCHIE": "XXL · Satin" and "XXL · Waffle".

     - **Component-level behavior — spec'd so both Claude Design (visual states) and Claude Code (functional implementation) build the same thing:**
       - **Chip/pill single-select (Produk, Ukuran):** tap toggles selection; selecting a new chip in the same group visually deselects the previous one (radio-button semantics, not checkbox). The "+" chip is visually distinct (dashed border or lighter fill, matching the existing mockup convention) from real data chips.
       - **Tokenized multi-select search field (Bahan):** functionally a combobox + token list, not a plain `<select>`. Needs: a text input that stays mounted and focused after each token is added (don't dismiss keyboard or blur), a dropdown/listbox positioned directly below the input that updates on every keystroke (debounce ~200-300ms if hitting a live search endpoint), token chips rendered inline within the same input's bounding box (wrapping to a second line if needed, input continues after the last token), and a per-token "×" tap target large enough for touch (not a tiny inline glyph).
       - **Numeric fields (Lebar Potong, Tinggi Potong, Estimasi Waktu Kerja):** reuse the exact same numeric-input component already spec'd under Tab Bahan → Tambah Pembelian's "Component-level behavior" (numeric keypad, comma decimal, must be > 0) — do not build a second implementation with different behavior.
       - **Rotasi Diizinkan:** standard on/off switch/toggle component, default **on** (matches `pattern_spec.rotation_allowed DEFAULT true`).
       - **Komponen Hardware — see the dedicated "Tambah Hardware — full spec & layout" block right after this list for complete detail (row layout, picker behavior, validation).** Summary: each fabric card's Komponen Hardware section is an add/remove list of {material, qty} rows, reusing the same search+dropdown picker pattern as Bahan but single-select per row.
       - **"Salin Komponen Hardware ke bahan lain" button:** only appears once at least 2 fabric cards exist and the first card has at least 1 hardware component filled; disabled/hidden otherwise. A single tap, not a toggle — running it twice after further edits just re-copies the current state of card 1 into the others (overwriting, with a brief confirm if the target cards already have their own entries, so a copy doesn't silently clobber manually-entered data).

     - **Tambah Hardware — full spec & layout (this was previously a single vague bullet; here's the complete technical doc for Claude Code and Claude Design):**
       - **Where this lives:** inside **each fabric card** in section 4 (Detail Resep) — not a separate top-level section of the sheet. If 2 fabrics are selected, there are 2 independent Komponen Hardware lists, one per card, since hardware needs can differ by fabric too (rare, but e.g. a lined satin variant might need an extra snap that an unlined waffle variant doesn't).
       - **Section layout within a card, top to bottom:**
         1. A small label **"KOMPONEN HARDWARE"** (matches the muted all-caps label style used for "LEBAR POTONG (CM)" etc. elsewhere in the same card).
         2. **Zero or more hardware rows** (see row layout below), stacked vertically, each separated by a thin divider line (same divider style as the rest of the card's fields).
         3. An **"+ Tambah Komponen"** row at the bottom of the list — full-width, dashed border, centered text, matching the visual style already used for "+ Tambah Komponen" in the reference Editor screenshot. This stays pinned as the last item in the list — new rows insert above it, never below.
       - **Empty state:** if zero hardware rows exist yet, the section shows just the label and the "+ Tambah Komponen" row (no "no components" placeholder text needed — the add row itself communicates the empty state clearly enough). This is a valid, save-able state — hardware is optional (see validation below).
       - **Row layout (each existing hardware row), left to right:**
         - **Material picker** (left, flexible width — takes up most of the row): shows the selected hardware material's name once picked (e.g. "Ring Elastis 3mm"), or a muted placeholder "Pilih hardware..." before anything is picked. Tapping it opens the **same search+dropdown pattern as the Bahan field** (search box appears, typing filters a dropdown of Hardware-category materials with at least one purchase on record — same eligibility rule as fabric), but this picker is **single-select per row** (not tokenized/multi-select like Bahan) — picking one result fills this row's material and closes the dropdown, it does not add a token, since a hardware row is exactly one material.
         - **Qty field** (right, fixed narrow width, e.g. "× 1 pcs" or "× 5 cm"): reuses the same numeric-input component spec'd elsewhere (numeric keypad, must be > 0). The unit suffix shown is `material.usage_unit` — "pcs" for count-based hardware (rings, clips), "cm" for length-based hardware (karet elastis, ribbon). This unit is set when the material is first created in Tambah Pembelian and flows through to the Resep screen automatically — no separate toggle needed.
         - **Remove affordance** (far right, small "×" or trash icon, minimum comfortable touch target ~44×44pt): tapping it removes this row immediately — no confirmation needed, since re-adding a row is trivial and this isn't a destructive action against saved data (the whole sheet hasn't been submitted yet).
       - **"+ Tambah Komponen" tap behavior:** appends a new empty row (picker shows placeholder, qty field empty) directly above the "+ Tambah Komponen" row itself, and immediately opens that new row's material picker (auto-focus) so the user can start typing right away without an extra tap.
       - **Duplicate prevention:** once a material is picked in one row, it's excluded from the dropdown in every other row within the *same card* (a recipe shouldn't list "Ring Elastis 3mm" twice with two different quantities — if more is needed, that's one row with a higher qty). This exclusion is per-card only — the same hardware material can appear in both the Satin card and the Waffle card independently, since those are entirely separate recipes.
       - **Validation:** a row with a picked material but empty/zero qty is invalid (blocks "Simpan Resep", inline error under that row's qty field). A row that's still at the placeholder/unpicked state is only invalid if the user tries to leave it half-filled (e.g. qty typed but no material picked) — an untouched empty row from "+ Tambah Komponen" that's simply removed again causes no error. Zero hardware rows total is valid (optional, as stated above).



   - **`Editor`** (pushed screen, entered only via a tapped row in `Daftar Resep` — never a freestanding tab, and distinct from the "Tambah Resep" sheet above):
     - Header shows context: "Scrunchie · M · Satin" (as in the mockup).
     - Same fields as "Detail Resep" above: Lebar Potong (cm), Tinggi Potong (cm), Rotasi Diizinkan toggle, Komponen Hardware list (add/remove), Estimasi Waktu Kerja (minutes) — plus Produk/Ukuran/Bahan shown as fixed context (not editable — changing any of those means a different pattern spec, i.e. use Tambah Resep instead).
     - **Behavior now depends on whether this version has been used yet** (refined during the CRUD audit in Section 5 — see `POST /pattern-specs`):
       - **If zero production batches have used this version:** it's a plain correction — no dotted-box warning, button reads **"Simpan Perubahan"**, and saving updates the same row (no new version number, no change to "Aktif sejak" date).
       - **If at least one production batch has used this version:** show the dotted-box notice exactly as in the mockup: *"Resep aktif sejak [date] — batch produksi sebelumnya tetap memakai biaya versi lama."* Button reads **"Simpan Versi Baru"**, and saving creates a new version as originally designed.
     - A **delete option** is available only in the first case (zero batches used) — see Section 5's `DELETE /pattern-specs/{id}`; once any batch has used a version, it can only be superseded by a new version, never deleted.

   - **Pagination:** grows with every SKU × size × fabric-type combination (e.g. 2 products × 5 sizes × 2 fabrics = 20 rows already). Mock with enough rows to require scrolling within the grouped list, and to exercise the "Muat Lebih Banyak" pattern already shown in the mockup.

   **Tab: Optimasi** (Cutting Optimizer)

   The optimizer is per-physical-roll: one optimization session selects **one specific MaterialPurchase** (one roll/bolt), not a fabric type. Multiple purchases of the same fabric (e.g. Satin Putih beli dua kali) appear as separate selectable rows — each with their own remaining length and cost basis. The optimizer adapts its canvas dimensions to whichever roll the user selects.

   The **PatternSpec (Resep)** is linked to a fabric **material type** (not to a specific purchase), so the same spec applies to any roll of that fabric. The specific roll's dimensions are what the optimizer uses as the cutting canvas.

   **3-step flow:**

   - **Step 1 — Pilih Kain:** list all MaterialPurchases of category=fabric with `remaining_length_cm > 0`. Each row shows material name, roll dimensions (width × remaining length), and cost. User selects exactly one.

   - **Step 2 — Pilih Pola Kandidat:** **candidate filter rule (v1.3 — previously missing from spec):** only PatternSpecs where `fabrics[].materialId == selectedPurchase.materialId` are shown. A spec that uses Waffle Merah will not appear when Satin Putih is selected, even if both products have specs for the same size. This is correct — the optimizer packs pieces from ONE fabric roll at a time, so only specs whose cut dimensions reference that fabric type are relevant. The backend's `POST /cutting-optimizer/suggest` must also validate this: reject any candidate whose PatternSpec does not reference the submitted `material_purchase_id`'s material (400 Bad Request).
     - Each candidate row is checkable; once checked, a small "Min qty" field appears (optional floor constraint for the optimizer).

   - **Step 3 — Hasil:** calls `POST /cutting-optimizer/suggest`, returns up to 3 candidate layouts (Waste Minimum, Max Qty, Max Profit). User picks one → "Gunakan Layout Ini" → calls `POST /cutting-optimizer/layouts` + `POST /production-batches` → shows a **success screen** with batch summary (strategy name, total pcs, product breakdown) and two actions:
     - **"Lanjut ke Produksi"** — switches to the Produksi tab (the batch is now visible there as a draft)
     - **"Mulai Optimasi Baru"** — resets to Step 1 for the next roll

   This tab's output feeds directly into the Produksi tab — the "Lanjut ke Produksi" affordance is implemented (not a dead-end).

   **Tab: Produksi** (Production Batch Confirm)
   - Header shows draft provenance: **"Draft · dari Layout '[strategy name]'"** — e.g. "dari Layout 'Waste Minimum'" — so the user always knows which optimizer suggestion this batch came from (or "Manual" if no optimizer was used).
   - **Qty Aktual per Ukuran**: one row per (product, size) in this batch, showing the optimizer's suggested qty struck through, with an editable actual-qty field next to it — this is where defects/miscounts get corrected before locking.
   - **Rincian HPP** (per size, shown for the size currently selected — tap a row to switch): legend rows for Kain (fabric), Bahan Pooled (thread), Hardware, Tenaga Kerja, Overhead, dan HPP Total. This is the "trust-building" breakdown from Section 1.4 — always show all 5 components, never just the total. **Data source:** `latest_hpp_breakdown` from `GET /products/{sku}/sizes` — populated by the iOS `fetchSizeToProductMap()` enrichment pass. **Hidden if null** (first-ever production of a size has no prior confirmed HPP to reference — section is simply not shown; does not block confirmation). This is not the HPP computed by the current batch; it is the last confirmed HPP for reference only.
   - `Konfirmasi & Tambah ke Stok` button → calls `POST /production-batches/{id}/confirm`. Warning text "Setelah dikonfirmasi, biaya batch ini terkunci dan tidak dapat diubah" shown below the button — irreversible cost-lock, not just a stock update.

3. **Products (Finished Goods) — 3-level navigation (updated v1.8)**

   The product tab uses a 3-level drill-down. The flat "all variants in one list" layout from earlier drafts does not scale once a product has many fabric types (e.g. 10 fabrics × 3 sizes = 30 rows in a single card).

   **Level 1 — ProdukListView (product list):**
   - One card per product. Each card has two clickable areas:
     - **Card header (product name + SKU + "›")** → navigates to `ProdukDetailView` (product management: rename, archive, add size).
     - **Size label rows inside the card** (M, L, XL, …) → navigates to `ProdukSizeGroupView`. Each row shows: size label, aggregate stock (sum of all fabric variants), worst-case stock badge (Habis/Menipis), variant count if > 1, and lowest selling price.
   - These are independent NavigationLinks — tapping "M" does NOT go through the product detail screen.

   **Level 2 — ProdukSizeGroupView (fabric variants for one size):**
   - Title: "Scrunchie · M"
   - Aggregate card: product name, size label large, variant count, total stock.
   - "Varian Kain" section: lists all non-archived `ProductSize` rows where `sizeLabel == selectedLabel` — e.g. "M · Satin Pelangi", "M · Waffle Merah". Each row shows fabric name (not the full displayLabel), stock, HPP, margin.
   - **"Tambah Varian"** button: opens `AddSizeSheet` with `sizeLabel` pre-filled and locked. User selects a fabric from `FabricPickerSheet` — a searchable bottom sheet that lists **all fabrics in bahan inventory**. Fabrics that already have an active PatternSpec for this (product + size) are marked "Ada di resep" (green badge) and enable the optional "Stok Awal" field after selection. Fabrics without a matching spec are shown without the badge — selecting one still creates the variant but does not deduct bahan stock (no spec = no cut dimensions available). If the user types a fabric name that doesn't match any inventory item, a "Tambah '[X]'" row appears at the bottom so they can name a brand-new fabric variant not yet in inventory (no spec, no bahan deduction). A footer note under the selected fabric tells the user which path applies before they save.
   - Swipe-to-archive: archives a single fabric variant (not the whole size group).
   - Tapping a row → Level 3.

   **Level 3 — ProdukSizeDetailView (one specific size + fabric):**
   - Title: displayLabel ("M · Satin Pelangi").
   - Info card: stock, fabric name, selling price, margin, reorder min. Edit button to change selling price and reorder min.
   - HPP breakdown card (fabric / pooled / hardware / labor / overhead / total) — only shown after at least one confirmed production batch exists for this variant.
   - Price Advisor: collapsible section. Inputs: target margin %, marketplace fee %. Output: suggested price, actual margin, markup. "Gunakan Harga Ini" applies the suggested price via PATCH.

   **ProdukDetailView (product management — reached from card header, not from size rows):**
   - Shows same size-label groups (M, L) as `ProdukListView`, each linking to `ProdukSizeGroupView`. "Jumlah Ukuran" shows unique size label count (not total variant count).
   - Actions: rename product (inline alert), archive product (with confirmation). "Tambah Ukuran" button opens `AddSizeSheet` with no prefill — user enters both size label and optional fabric variant.

   **Rationale:** separating "sizes" from "fabric variants of a size" is the critical UX decision here. A product with 3 sizes and 5 fabric types would otherwise produce 15 undifferentiated rows in a flat list. The 3-level hierarchy makes it clear that M/L/XL are structural size differences, while Satin/Waffle/Linen are production variants of the same structural size.

   - **Pagination:** same pattern as Bahan/Resep — mock with enough SKU × size × fabric rows to exercise scroll/pagination.
4. **Sales**
   - New sale: pick product(s)+qty, discount, payment method → auto-deducts stock, computes profit using HPP at time of sale
   - Sales history / invoice list — this one especially needs realistic pagination in mockups, since sales entries accumulate daily; show at least 20-30 sample invoices spanning several days/weeks so date-grouping and pagination/infinite-scroll are both visible.
5. **Reports**
   - Sales by period, best/worst margin products, stock card (kartu stok) per product, waste rate by material, low-stock alerts (finished products)
6. **Settings**
   - Labor rate/minute, overhead rate, pooled material rates (thread etc.), marketplace fee defaults

### Sample data & pagination — general note for Claude Design
Several screens above (Bahan, Resep, Products, Sales) are lists that will realistically grow well past what fits on one screen. When generating mockups, use enough sample rows (15-30, varied dates/values/categories) to actually exercise scrolling and pagination UI (e.g. "load more", numbered pages, or infinite scroll — pick one pattern and use it consistently across all list screens), rather than the 2-6 item examples used earlier in this doc for illustration. The 2-6 item examples in Section 1 and the screenshots referenced during design review are illustrative only, not the target data volume for final mockups.

### Key UX principles to carry into mockups
- The **Optimasi tab** (within Produksi) is the hero feature — give it the most visual/design attention (a simple 2D layout preview, even schematic, helps trust the numbers).
- Always show HPP breakdown (fabric / hardware / labor / overhead) stacked, not just a total — builds user trust in the number.
- Distinguish clearly in UI copy between "suggested/estimated" values (pre-confirm) and "actual/locked" values (post-confirm) — different visual treatment (e.g. dashed vs solid, "draft" badge). The mockup's strikethrough-suggested / editable-actual pattern in the Produksi tab is a good implementation of this — keep it.
- Margin vs markup must never be ambiguous — always label explicitly.

---

## 3. Database Schema

```sql
-- ===== AUTH (updated v1.1 — Google SSO replaces email+password) =====

CREATE TABLE owner_account (
    id          UUID PRIMARY KEY,
    google_sub  TEXT NOT NULL UNIQUE,   -- Google's stable user ID ('sub' claim from the verified ID token)
    email       TEXT NOT NULL UNIQUE,   -- from Google, for display/logging only — not the auth lookup key
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Still a single-row-in-practice table. No password_hash column — auth is fully delegated to Google.
-- Row is auto-provisioned on the owner's FIRST successful Google Sign-In (when the verified email matches
-- the AUTHORIZED_OWNER_EMAIL env var). On subsequent sign-ins, the backend verifies google_sub matches
-- the existing row (google_sub is stable; email can change in Google, so don't use email as lookup key).
-- No roles/permissions table: every authenticated request has full access to everything.
-- Recovery (owner changes Google account): update AUTHORIZED_OWNER_EMAIL in env + DELETE the owner_account
-- row — the next sign-in will re-provision with the new google_sub.

-- ===== MATERIALS =====

CREATE TABLE material (
    id              UUID PRIMARY KEY,
    name            TEXT NOT NULL,              -- "Satin Putih", "Benang Merah"
    category        TEXT NOT NULL,               -- 'fabric' | 'thread' | 'hardware' | 'packaging'
    cost_class      TEXT NOT NULL,               -- 'direct_precise' | 'direct_pooled'
    purchase_unit   TEXT NOT NULL,               -- 'meter' | 'roll' | 'pack' | 'pcs'
    usage_unit      TEXT NOT NULL,               -- 'cm' | 'cm2' | 'pcs'
    fabric_width_cm NUMERIC,                     -- nullable, only for category='fabric': typical/default width, used to pre-fill (not lock) new purchase entries
    current_avg_cost NUMERIC NOT NULL DEFAULT 0, -- weighted average cost per usage_unit
    reorder_min_qty NUMERIC,
    is_archived     BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE supplier (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE material_purchase (
    id              UUID PRIMARY KEY,
    material_id     UUID NOT NULL REFERENCES material(id),
    width_cm        NUMERIC,          -- fabric only ("Lebar (cm)") — every fabric purchase is a bounded rectangle, no piece/roll distinction
    length_cm       NUMERIC,          -- fabric: "Panjang (cm)" of the roll. hardware (optional): length per unit, e.g. 100cm for elastic bands — when set, enables remaining_length_cm tracking for that purchase
    qty             NUMERIC,          -- thread/hardware: jumlah gulung / jumlah pcs. hardware with length_cm: qty × length_cm = total length purchased
    package_label   TEXT,             -- thread only, optional: 'Kecil' | 'Besar' or similar — descriptive only, not used in cost calc
    total_cost      NUMERIC NOT NULL,
    supplier_id     UUID REFERENCES supplier(id),   -- nullable, optional field
    purchased_at    DATE NOT NULL,
    remaining_length_cm NUMERIC,     -- fabric: decremented as CuttingLayouts consume it. hardware with length_cm: initialized to qty × length_cm, decremented as PatternSpec components consume it. null for count-only hardware (no length_cm) and thread/packaging
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== PRODUCTS & RECIPES =====

CREATE TABLE product (
    id          UUID PRIMARY KEY,
    sku         TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,           -- "Scrunchie"
    is_archived BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE product_size (
    id                  UUID PRIMARY KEY,
    product_id          UUID NOT NULL REFERENCES product(id),
    size_label          TEXT NOT NULL,           -- 'XS','S','M','L','XL','XXL'
    fabric_variant_name TEXT,                    -- nullable; e.g. 'Satin Pelangi', 'Waffle Merah'. NULL means no
                                                 -- fabric-specific variant. Each (size_label, fabric_variant_name)
                                                 -- combination is a distinct row with its own stock counter.
    reorder_min_qty     NUMERIC,                 -- minimum finished-goods stock before low-stock alert triggers
    is_archived         BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    UNIQUE(product_id, size_label, fabric_variant_name)
    -- NOTE v1.7: constraint changed from UNIQUE(product_id, size_label) — size_label alone is no longer unique
    -- when fabric variants exist. Backend must enforce this composite key on create and reject duplicates with 409.
);

-- Recipe: keyed by (product_size, fabric material) since consumption differs per fabric type.
-- Versioned: don't hard-delete, deactivate + insert new row, so historical batches keep original costing basis.
CREATE TABLE pattern_spec (
    id                  UUID PRIMARY KEY,
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    fabric_material_id  UUID NOT NULL REFERENCES material(id),
    cut_width_cm        NUMERIC NOT NULL,
    cut_height_cm       NUMERIC NOT NULL,
    rotation_allowed    BOOLEAN NOT NULL DEFAULT true,
    est_labor_minutes   NUMERIC NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    effective_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    effective_to        TIMESTAMPTZ
);

-- Non-fabric components needed per product_size (hardware: clips, rings; direct_precise class)
CREATE TABLE pattern_component (
    id                  UUID PRIMARY KEY,
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    material_id         UUID NOT NULL REFERENCES material(id),
    qty_per_unit        NUMERIC NOT NULL
);

-- ===== CUTTING OPTIMIZER =====

CREATE TABLE cutting_layout (
    id                  UUID PRIMARY KEY,
    material_purchase_id UUID NOT NULL REFERENCES material_purchase(id),
    status              TEXT NOT NULL DEFAULT 'suggested', -- 'suggested' | 'used' | 'discarded'
    waste_pct           NUMERIC,
    total_fabric_cost   NUMERIC NOT NULL,   -- cost allocated across this layout (usually = purchase total_cost)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cutting_layout_item (
    id                  UUID PRIMARY KEY,
    cutting_layout_id   UUID NOT NULL REFERENCES cutting_layout(id),
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    orientation         TEXT NOT NULL,      -- 'normal' | 'rotated'
    qty_suggested       INTEGER NOT NULL,
    fabric_length_used_cm NUMERIC NOT NULL, -- length of roll consumed for this row/group
    cost_per_piece      NUMERIC NOT NULL    -- derived: (share of total_fabric_cost) / qty_suggested
);

-- ===== PRODUCTION =====

CREATE TABLE production_batch (
    id                  UUID PRIMARY KEY,
    cutting_layout_id   UUID REFERENCES cutting_layout(id), -- nullable: batch can exist without optimizer (manual entry)
    produced_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    status              TEXT NOT NULL DEFAULT 'draft',      -- 'draft' | 'confirmed'
    notes               TEXT
);

CREATE TABLE production_batch_item (
    id                  UUID PRIMARY KEY,
    production_batch_id UUID NOT NULL REFERENCES production_batch(id),
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    qty_actual          INTEGER NOT NULL,        -- user-confirmed, may differ from cutting_layout_item.qty_suggested
    hpp_fabric          NUMERIC NOT NULL,
    hpp_pooled_material NUMERIC NOT NULL,        -- thread etc.
    hpp_hardware        NUMERIC NOT NULL,
    hpp_labor           NUMERIC NOT NULL,
    hpp_overhead        NUMERIC NOT NULL,
    hpp_total           NUMERIC NOT NULL         -- sum of above; locked once batch confirmed
);

-- ===== STOCK =====

CREATE TABLE stock_ledger (
    id                  UUID PRIMARY KEY,
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    change_qty          INTEGER NOT NULL,        -- + for production/return, - for sale/damage
    reason              TEXT NOT NULL,           -- 'production' | 'sale' | 'adjustment' | 'damage' | 'return'
    ref_type            TEXT,                    -- 'production_batch' | 'sales_order'
    ref_id              UUID,
    unit_hpp_snapshot   NUMERIC,                 -- HPP at time of this movement (for COGS on sale)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== SALES =====

CREATE TABLE sales_order (
    id              UUID PRIMARY KEY,
    invoice_no      TEXT NOT NULL UNIQUE,
    customer_name   TEXT,
    payment_method  TEXT,                        -- 'cash' | 'transfer' | 'qris' | 'marketplace'
    marketplace_fee_pct NUMERIC DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'unpaid', -- 'unpaid' | 'paid'
    sold_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sales_order_item (
    id                  UUID PRIMARY KEY,
    sales_order_id      UUID NOT NULL REFERENCES sales_order(id),
    product_size_id      UUID NOT NULL REFERENCES product_size(id),
    qty                  INTEGER NOT NULL,
    unit_price           NUMERIC NOT NULL,
    discount             NUMERIC NOT NULL DEFAULT 0,
    unit_hpp_snapshot    NUMERIC NOT NULL,        -- pulled from stock_ledger at sale time
    line_profit          NUMERIC NOT NULL         -- (unit_price - discount - unit_hpp_snapshot) * qty
);

-- ===== SETTINGS =====

CREATE TABLE settings (
    key         TEXT PRIMARY KEY,   -- 'labor_rate_per_minute' | 'default_overhead_per_unit' | 'pooled_material_rate:thread' etc.
    value       NUMERIC NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 4. API Contract

Base path: `/api/v1`. All bodies JSON. **Auth is required on every endpoint below except `/auth/google`** — see Section 0 for why. Every request other than the Google sign-in exchange must carry `Authorization: Bearer <token>`; a missing/invalid/expired token returns 401.

### Auth (updated v1.1)

```
POST   /auth/google
  body: { "id_token": "<google_id_token>" }
  → returns { access_token, expires_at } (app-issued JWT bearer token)

  Backend verification steps (must happen in this order):
  1. Call Google's tokeninfo endpoint to verify the id_token is authentic and not expired:
       GET https://oauth2.googleapis.com/tokeninfo?id_token=<id_token>
     OR use google-auth-library (Python: `google.oauth2.id_token.verify_oauth2_token`)
     for offline verification using Google's public keys (preferred for production — no extra HTTP call).
  2. Verify `aud` claim in the decoded token matches your iOS OAuth client ID
     (prevents tokens from other apps being replayed here).
  3. Extract `sub` (stable Google user ID) and `email` from the verified token payload.
  4. Check `email` against AUTHORIZED_OWNER_EMAIL env var → 403 Forbidden if it doesn't match.
  5. Upsert owner_account:
       - If no row exists yet: INSERT (google_sub, email) — first-time provisioning.
       - If a row exists: verify google_sub matches the stored row → 403 if it doesn't
         (prevents a different Google account with a matching email from taking over).
  6. Issue an app-level JWT (signed with your own secret key, not Google's) containing owner_account.id.
     Return { access_token, expires_at }.

  Error responses:
  → 400 if id_token is missing or malformed
  → 401 if Google reports the token is invalid or expired
  → 403 if the verified email doesn't match AUTHORIZED_OWNER_EMAIL, or google_sub conflicts

  -- Required environment variables for the backend:
       AUTHORIZED_OWNER_EMAIL   the owner's Google email address (e.g. owner@gmail.com)
       GOOGLE_CLIENT_ID         the iOS OAuth 2.0 client ID from Google Cloud Console
                                (used to verify the `aud` claim in step 2 above)
       JWT_SECRET               secret key for signing app-level JWTs
  -- Token lifetime: recommend 30-day expiry for a single-owner app (no public attack surface).
     No refresh-token flow needed — owner simply re-authenticates via Google on expiry.
     See Section 6 for remaining open decisions.
```

### Materials

```
POST   /materials
GET    /materials
GET    /materials/{id}
PATCH  /materials/{id}

POST   /materials/{id}/purchases
  body: { width_cm?, length_cm?, qty?, package_label?, total_cost, supplier_id?, supplier_name?, purchased_at }
  -- fabric materials: width_cm + length_cm required (plain bounded rectangle, no purchase-type distinction), qty/package_label omitted
  -- thread materials: qty required, package_label optional, width_cm/length_cm omitted
  -- hardware materials: qty required; length_cm optional (only for length-tracked hardware like elastic bands); package_label/width_cm omitted
  --   if length_cm present: server initializes remaining_length_cm = qty × length_cm; cost_per_cm = total_cost / remaining_length_cm
  --   if length_cm absent: count-only tracking; remaining_length_cm stays null
  -- supplier: pass supplier_id if an existing supplier was picked from the dropdown; pass supplier_name instead to create
     a new Supplier inline (same "+ Tambah supplier baru" pattern as material creation); omit both if left blank (optional)
  → creates MaterialPurchase, updates material.current_avg_cost (weighted average)

GET    /materials/{id}/purchases

PATCH  /materials/{id}/purchases/{purchase_id}
  body: { width_cm?, length_cm?, qty?, total_cost?, supplier_id?, supplier_name?, purchased_at? }
  -- if the purchase is untouched (fabric/length-hardware: remaining_length_cm == qty × length_cm; count-only hardware: no stock_ledger rows reference it):
     all fields may be updated.
  -- if the purchase has any recorded consumption: width_cm/length_cm/qty are rejected (400) if present in the
     body — only total_cost, supplier_id/supplier_name, purchased_at may be changed.
  → recalculates material.current_avg_cost from all purchases after saving

DELETE /materials/{id}/purchases/{purchase_id}
  -- allowed only if untouched (same condition as above); returns 409 Conflict if the purchase has any
     recorded consumption (referenced by a CuttingLayout or stock_ledger entry), since deleting it would
     orphan locked production-batch cost history.
  → on success, recalculates material.current_avg_cost from remaining purchases
```

### Suppliers

```
POST   /suppliers
  body: { name }
  → creates Supplier. Also creatable inline via material_purchase's supplier_name shortcut above — this
    standalone endpoint exists for cases where Claude Design wants a direct create action outside that flow.

GET    /suppliers?search=
  → for the Supplier field's autocomplete dropdown, same pattern as material search
```

### Pattern Specs (Recipes)

```
POST   /pattern-specs
  body: { product_size_id, fabric_material_id, cut_width_cm, cut_height_cm,
          rotation_allowed, est_labor_minutes, components: [{material_id, qty_per_unit}] }
  → if no active spec exists yet for this (product_size_id, fabric_material_id): creates it directly
  → if an active spec exists and has zero ProductionBatchItem rows against it: updates that same row in place
  → if an active spec exists and has at least one ProductionBatchItem row against it: deactivates it and
    inserts a new versioned row (the original "always version forward" behavior)
  -- see Section 5's CRUD audit for why the middle case (in-place update) was added
  -- validation: fabric_material_id and every components[].material_id must reference a Material with at least
     one MaterialPurchase on record (no cost basis = can't compute HPP). The Bahan/Hardware picker in the
     Tambah Resep UI should only list materials satisfying this, per Section 2's "must already have a purchase
     on record" rule.

GET    /pattern-specs?product_id=&size=&fabric_material_id=
GET    /pattern-specs/{id}
```

### Cutting Optimizer

```
POST   /cutting-optimizer/suggest
  body: {
    material_purchase_id,
    candidates: [ { product_size_id, pattern_spec_id, min_qty? } ]
  }
  → runs two-phase shelf-packing heuristic (see Section 1.5 for full algorithm spec), returns candidate layouts (not persisted yet)
  -- min_qty: the algorithm guarantees this candidate receives at least min_qty pieces IF geometrically possible.
  --   Uses bestMinLen reservation (not primaryRowHeight-based) to avoid over-reserving the roll for one candidate's
  --   future minimum. Falls back to the alternative orientation if the primary orientation doesn't fit in available space.
  --   If min_qty cannot be satisfied for any candidate (geometry truly doesn't allow it), that candidate receives 0
  --   and is omitted from the layout — it is NOT an error condition. Backend must implement the same two-phase logic.
  response: {
    layouts: [
      {
        strategy: "max_qty" | "min_waste" | "max_profit",
        waste_pct: number,
        items: [
          { product_size_id, pattern_spec_id, orientation, qty_suggested,
            fabric_length_used_cm, cost_per_piece }
        ]
      }
    ]
  }

POST   /cutting-optimizer/layouts
  body: { material_purchase_id, chosen from one of the suggested layouts (items array) }
  → persists as CuttingLayout + CuttingLayout_items, status='suggested'
  → returns cutting_layout_id

POST   /cutting-optimizer/layouts/{id}/discard
```

### Production

```
POST   /production-batches
  body: { cutting_layout_id? }
  → creates draft ProductionBatch, pre-filled items from layout if provided (qty_actual = qty_suggested initially)

PATCH  /production-batches/{id}/items/{item_id}
  body: { qty_actual }
  → user edits actual qty after physical cutting
  -- updated v2.6: response must be the updated item only (NOT the parent batch object)
  response: {
    id, production_batch_id, product_size_id, pattern_spec_id,
    qty_actual, qty_suggested?,
    fabric_cost_per_piece?,
    hpp_fabric, hpp_pooled_material, hpp_hardware, hpp_labor, hpp_overhead, hpp_total
  }
  -- hpp_* will be 0.0 for draft batches; populated after confirm

POST   /production-batches/{id}/confirm
  → computes hpp_fabric / hpp_pooled_material / hpp_hardware / hpp_labor / hpp_overhead / hpp_total per item
    using: cutting_layout_item.cost_per_piece (fabric), settings pooled rates, pattern_component costs,
           est_labor_minutes × labor_rate_per_minute, overhead settings
  → writes stock_ledger rows (reason='production', unit_hpp_snapshot = hpp_total)
  → decrements material_purchase.remaining_length_cm and hardware material stock
  → sets production_batch.status = 'confirmed' (immutable after this)

GET    /production-batches/{id}
GET    /production-batches?status=
```

### Products / Stock

```
POST   /products
  body: { name, sku? }   -- sku auto-suggested from name (slug) if omitted, but must end up unique
  → creates Product. This is the only path new product types (e.g. "Pouch") get created — triggered from the "Tambah Resep" flow's "+ Buat produk baru" step, not a standalone product-creation screen.

POST   /products/{sku}/sizes
  body: { size_label, fabric_variant_name?, reorder_min_qty? }
  -- fabric_variant_name (v1.7): optional; if provided, this ProductSize represents one specific fabric
  --   variant (e.g. "Satin Pelangi"). Multiple sizes can share the same size_label as long as their
  --   fabric_variant_name differs. NULL fabric_variant_name is treated as a distinct value for uniqueness
  --   (i.e. "M" with no variant and "M · Satin Pelangi" are two different rows).
  -- Uniqueness: (product_id, size_label, fabric_variant_name) — return 409 if a duplicate is attempted.
  → creates ProductSize under an existing product. Triggered from "Tambah Resep" flow's "+ Buat ukuran baru"
    step, or auto-created by TambahResepSheet when a (sizeLabel + fabric) combination does not yet exist.

GET    /products
GET    /products/{sku}/sizes
  -- response: array of ProductSize objects. Each object MUST include all fields below.
  -- (updated v2.7: list endpoint must return the same HPP/stock/price fields as the detail endpoint —
  --  the iOS client uses this list in fetchSizeToProductMap() to populate RINCIAN HPP in batch confirmation)
  response per item: {
    id, product_id, size_label,
    fabric_variant_name,          -- nullable; display label = "{size_label} · {fabric_variant_name}" if set
    reorder_min_qty,              -- nullable Double
    selling_price,                -- nullable Double
    is_archived,
    current_stock_qty,            -- Int, total stock
    production_stock_qty,         -- Int, from confirmed batches (0 if none)
    manual_stock_qty,             -- Int, from manual stock adjustments (0 if none)
    latest_hpp_breakdown: {       -- null if this size has never been through a confirmed batch
      fabric, pooled_material, hardware, labor, overhead, total   -- all Double
    },
    margin_pct                    -- nullable Double (selling_price → HPP margin)
  }

GET    /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID, NOT sizeLabel: String — required because multiple sizes
  --   can share the same size_label when fabric variants exist
  response includes: current_stock_qty, reorder_min_qty, latest_hpp_breakdown, selling_price, margin_pct,
                     fabric_variant_name

PATCH  /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID
  body: { selling_price?, reorder_min_qty? }

POST   /products/{sku}/sizes/{sizeId}/price-advisor
  -- (v1.7) path parameter is now sizeId: UUID
  body: { target_margin_pct, marketplace_fee_pct?, promo_allocation_pct? }
  response: { suggested_price, resulting_margin_pct, resulting_markup_pct }

DELETE /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID (was size_label string in earlier versions)
  -- same archive-vs-hard-delete logic as before: archive if history exists, hard-delete if unused

POST   /stock/adjustments
  body: { product_size_id, change_qty, reason, note? }
  → manual stock opname / damage adjustment
```

### Sales

```
POST   /sales-orders
  body: {
    customer_name?, payment_method, marketplace_fee_pct?,
    items: [ { product_size_id, qty, unit_price, discount? } ]
  }
  → validates stock availability, pulls unit_hpp_snapshot from current stock cost,
    writes stock_ledger (reason='sale', negative qty), computes line_profit per item

GET    /sales-orders
GET    /sales-orders/{id}
PATCH  /sales-orders/{id}   body: { status }   -- mark paid
```

### Reports

```
GET /reports/dashboard
  -- added v1.2: single-call summary for the Beranda (Dashboard) screen
  -- updated v2.6: today_units_sold added
  response: {
    today_revenue, today_order_count, today_units_sold, today_profit,
    low_stock_alerts: [ { product_size_id, product_name, size_label, current_stock_qty, reorder_min_qty } ]
  }
  -- today_units_sold: SUM(qty) from sales_order_items where sold_at is today (server timezone)
  -- today is determined by server timezone; no parameters needed

GET /reports/sales?from=&to=&group_by=day|week|month
GET /reports/margin-ranking?sort=margin_pct
GET /reports/stock-card/{product_size_id}
GET /reports/waste-by-material?from=&to=
GET /reports/low-stock          -- finished products (product_size) below reorder_min_qty
```

### Settings

```
GET    /settings
PATCH  /settings   body: { key, value }
```

---

## 5. CRUD Audit — completeness check across all entities

Prompted by finding that `MaterialPurchase` had create fully spec'd but edit/delete completely missing. This section audits every entity in the schema the same way, so the same gap doesn't exist elsewhere. General principle applied throughout: **an entity that has already had real-world consequences (stock consumed, cost locked, money moved) should never be silently editable or hard-deletable** — it's either restricted to safe fields, archived instead of deleted, or requires an explicit reversing action instead of an edit.

| Entity | Create | Edit | Delete |
|---|---|---|---|
| Material | ✅ inline via first purchase | ✅ `PATCH /materials/{id}` (name, reorder_min_qty, etc.) | **No hard delete.** Added `is_archived` flag — see below. |
| MaterialPurchase | ✅ spec'd earlier | ✅ full if unused, cost/date/supplier-only if consumed — spec'd earlier | ✅ if unused / 🚫 blocked (409) if consumed — spec'd earlier |
| Supplier | ✅ inline via purchase, or `POST /suppliers` | ⚠️ was missing — added `PATCH /suppliers/{id}` below | ⚠️ was missing — added below, allowed only if unused |
| Product | ✅ inline via Tambah Resep | ⚠️ was missing — added `PATCH /products/{sku}` below (rename only; sku immutable) | **No hard delete once any size has history.** Added `is_archived` — see below. |
| ProductSize | ✅ inline via Tambah Resep (auto-created per fabric variant in v1.7) | ✅ `PATCH .../sizes/{sizeId}` — path param is UUID since v1.7 (was sizeLabel string) | ✅ `DELETE .../sizes/{sizeId}` — archive if used, hard-delete if never used; path param is UUID since v1.7 |
| PatternSpec (Resep) | ✅ spec'd earlier | ✅ always creates a new version — **refined below**: if the current version has zero production batches against it, editing updates it in place instead of spawning a version, to avoid version-number noise from typo fixes | ⚠️ was missing — added below, allowed only if the version has zero production batches against it |
| PatternComponent (hardware in a recipe) | ✅ part of the `components` array in `POST /pattern-specs` | ✅ same — the whole array is replaced on each save, no per-row endpoint needed | ✅ same — omitting a row from the array on save removes it |
| CuttingLayout | ✅ spec'd earlier | N/A (layouts aren't edited, just re-run via suggest) | ✅ `POST /cutting-optimizer/layouts/{id}/discard` already existed — **clarified below**: only valid while `status='suggested'` |
| ProductionBatch | ✅ spec'd earlier | ✅ `qty_actual` editable pre-confirm; fully locked post-confirm | ⚠️ was missing for the draft (pre-confirm) case — added below |
| StockLedger | ✅ system-written on every production/sale/adjustment | 🚫 **by design, never** | 🚫 **by design, never** — append-only audit log; corrections happen via a new offsetting adjustment, not by touching history. Worth stating explicitly rather than leaving as an apparent oversight. |
| SalesOrder | ✅ spec'd earlier | 🚫 **by design, not supported** — line items aren't edited after creation (money/stock have already moved); correct via cancel below, then re-enter | ⚠️ was missing entirely — added `POST /sales-orders/{id}/cancel` below (reverses stock, doesn't hard-delete the record so history isn't lost) |
| Settings | ✅ fixed key set, no creation needed | ✅ `PATCH /settings` already existed | 🚫 not applicable — fixed set of known keys, nothing to delete |

### New/updated endpoints from this audit

```
PATCH  /suppliers/{id}
  body: { name }

DELETE /suppliers/{id}
  -- allowed only if zero MaterialPurchase rows reference this supplier_id; 409 Conflict otherwise

PATCH  /products/{sku}
  body: { name }
  -- sku itself is immutable after creation (it's the stable identifier used throughout the API)

DELETE /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID (was size_label string before v1.7)
  -- if this ProductSize has zero PatternSpec, zero stock_ledger, and zero sales_order_item history:
     hard-deletes it
  -- otherwise: sets is_archived = true instead (hides it from Tambah Resep pickers and Products list going
     forward, but keeps historical reports/HPP intact); returns which of the two happened so the UI can
     message it correctly ("Ukuran dihapus" vs "Ukuran diarsipkan karena sudah punya riwayat")

DELETE /products/{sku}
  -- same archive-vs-delete logic as above, applied across all of that product's sizes

PATCH  /materials/{id}
  -- (already existed) now also accepts { is_archived }
  -- archiving hides the material from Tambah Pembelian / Tambah Resep pickers, but existing purchases,
     pattern specs, and reports referencing it are unaffected

DELETE /pattern-specs/{id}
  -- allowed only if zero ProductionBatchItem rows reference this exact pattern_spec version; 409 otherwise
  -- note the refined edit behavior: POST /pattern-specs, when updating a spec that currently has zero
     ProductionBatchItem rows against it, updates that same row in place (no new version row inserted).
     Once at least one batch has been produced against a version, further edits always insert a new
     versioned row as originally spec'd — this avoids meaningless version numbers from same-day typo fixes.

POST   /cutting-optimizer/layouts/{id}/discard
  -- (already existed) clarified: only valid while status='suggested'; returns 409 if status='used'
     (a ProductionBatch already exists from this layout)

DELETE /production-batches/{id}
  -- allowed only while status='draft' (nothing has been written to stock_ledger or remaining_length_cm yet,
     since that only happens at confirm) — lets the user abandon a batch they started by mistake
  -- once status='confirmed', this always 409s — already-established immutability rule

POST   /sales-orders/{id}/cancel
  body: { reason? }
  → writes offsetting stock_ledger rows (reason='return', positive qty) for every item in the order,
    restoring finished-goods stock; sets sales_order.status = 'cancelled' (record is kept, not deleted,
    so sales history/reports stay accurate)
```

---

## 6. Open Decisions for Design/Dev to Confirm

1. ~~**Weighted-average vs FIFO** for material cost~~ — **resolved in v1.2**: weighted average confirmed and implemented throughout MockAPIService and all cost-recalc logic.
2. **Pooled material rate recompute cadence** — manual (settings screen) vs. auto-recalculated from monthly thread purchases ÷ monthly output.
3. **Rounding rule for prices** — round to nearest 500/1000 IDR in the price advisor output.
4. **Backend hosting/deployment platform** — e.g. Railway, Render, Fly.io, or self-hosted (see Section 0; stack itself is now confirmed, hosting is not).
5. ~~**JWT token lifetime and refresh strategy**~~ — **resolved in v1.1**: 30-day expiry, no refresh token. Owner re-authenticates via Google on expiry (acceptable for a single-owner app).
6. **(New — v1.1) Google Cloud Console setup:** before the backend can be deployed, the following must be configured in Google Cloud Console:
   - Create an OAuth 2.0 client ID for **iOS** (type: "iOS application"), providing the app's bundle ID (`handika.oura-studio-frontend`).
   - Note the resulting iOS client ID — this goes into the iOS app's `LoginView.swift` (replacing the `YOUR_GOOGLE_CLIENT_ID` placeholder at line ~104) and into the backend's `GOOGLE_CLIENT_ID` env var.
   - No server-side client ID is needed separately — the iOS client ID is sufficient since the backend only verifies the token Google already issued, not initiates its own OAuth flow.
7. **(New — v1.1) Authorized owner email:** must be set as `AUTHORIZED_OWNER_EMAIL` in the backend's environment before deploying. This is the one Google account permitted to authenticate. Changing it requires a backend redeploy + clearing the `owner_account` table row.

---

## 7. Frontend Implementation Status (as of v2.4 — 2026-08-07)

All 11 frontend milestones are **complete**. The iOS app is now connected to the **live backend** (`APIService.shared.useMock = false` by default as of v2.4). JWT is stored in Keychain under service `"id.ourastudio.app"`. Google Sign-In is implemented but blocked pending GCP OAuth Client ID configuration — auth currently works via manually stored JWT.

| # | Screen / Module | Status | Files |
|---|---|---|---|
| 1 | Networking layer + all models | ✅ Done | `APIService.swift`, `MockAPIService.swift`, `Models/` |
| 2 | Auth (Google SSO, Keychain) | ✅ Done | `LoginView.swift`, `AppState.swift`, `KeychainManager.swift` |
| 3 | Shared components | ✅ Done | `NumericInputField`, `CurrencyInputField`, `OuraDatePickerField`, `ChipSingleSelect`, `TokenizedMultiSelectField`, `SearchableDropdownField`, `InlineSearchDropdownField` |
| 4 | Bottom nav + Produksi inner tabs | ✅ Done | `MainTabView.swift`, `ProduksiTabView.swift` |
| 5 | Produksi → Bahan | ✅ Done | `BahanListView`, `BahanDetailView`, `TambahPembelianSheet`, `EditPembelianSheet` |
| 6 | Produksi → Resep | ✅ Done | `ResepListView`, `TambahResepSheet`, `ResepEditorView`, `ResepVersionHistoryView` |
| 7 | Produksi → Optimasi + Batch confirm | ✅ Done | `OptimasiView`, `ProduksiBatchView` |
| 8 | Produk (list + price advisor) | ✅ Done | `ProdukListView`, `ProdukDetailView` |
| 9 | Penjualan | ✅ Done | `PenjualanListView`, `TambahPenjualanSheet` |
| 10 | Lainnya (Reports + Settings + Keluar) | ✅ Done | `LainnyaView`, `ReportsView`, `SettingsView` |
| 11 | Beranda / Dashboard | ✅ Done | `BerandaView` |

### Bug fixes applied (v1.3)

Three bugs identified during regression testing and fixed:

| # | Bug | Fix location | Impact |
|---|---|---|---|
| 1 | `createOrUpdatePatternSpec` matched by `productSizeId` only — 2nd fabric's spec overwrote the 1st | `MockAPIService.swift` | Resep multi-fabric: saving Satin then Waffle for same size now creates two separate active specs correctly |
| 2 | `cancelSalesOrder` changed status but did not restore `currentStockQty` | `MockAPIService.swift` | Cancelling a sale now correctly increments stock back for each item |
| 3 | `getProductionBatches` always returned `[]` — `_productionBatches` was not a persistent state var | `MockAPIService.swift` | Tab Produksi now shows batches created from Optimasi; `confirmBatch`, `updateBatchItem`, `deleteProductionBatch` all now operate on the shared in-memory store |

### Optimasi → Produksi flow (v1.3)

After "Gunakan Layout Ini":
1. `createLayout` → `createProductionBatch(cuttingLayoutId:)` are called
2. Success screen appears showing: batch strategy name, total pcs, per-product breakdown
3. Two actions: **"Lanjut ke Produksi"** (switches inner tab to Produksi, resets Optimasi state) · **"Mulai Optimasi Baru"** (resets Optimasi state, stays on tab)
4. The new batch appears immediately in Tab Produksi as a draft

Candidate filter: Step 2 now filters PatternSpecs to only those whose `fabrics[].materialId == selectedPurchase.materialId`. Specs using a different fabric are excluded.

### Bug fixes applied (v1.7)

Four bugs fixed as part of the fabric-variant refactor:

| # | Bug | Root cause | Fix |
|---|---|---|---|
| 1 | Confirming a Waffle Merah production batch updated the wrong size's stock | `TambahResepSheet.save()` bundled all fabrics into one `PatternSpec` linked to one `productSizeId` — a Waffle Merah batch item still pointed to the Satin ProductSize | `save()` now creates one spec per fabric, each linked to the correct `(sizeLabel + fabricVariantName)` ProductSize |
| 2 | Optimizer showed wrong cut dimensions when non-first fabric was selected | `candidateRow` always read `spec.fabrics.first?.cutLengthCm` regardless of which purchase was selected | Now looks up `spec.fabrics.first(where: { $0.materialId == selectedPurchase?.materialId })` for fabric-specific dimensions |
| 3 | TambahResepSheet size picker showed duplicate "M" chips when M·Satin and M·Waffle both existed | `ForEach` iterated all `ProductSizeDetail` objects, showing `size.sizeLabel` for each — two "M" chips appeared | Added `uniqueSizeLabels` computed property (Set deduplication by `sizeLabel`); size picker now shows one chip per label |
| 4 | `patchProductSize`, `archiveProductSize`, `getPriceAdvisor` matched by `sizeLabel: String` — ambiguous once two sizes share the same label | String-based lookup in mock and real API paths | All three functions changed to `sizeId: UUID` parameter; mock lookups changed to `$0.id == sizeId` |

### Mock data state (v2.0)

Seed data matches confirmed owner specs. **Cut dimensions are authoritative** — use these when building the real backend's initial seed SQL.

**Bahan (fabric only):**

| Nama | Lebar | 1 Pembelian | Total Biaya |
|---|---|---|---|
| Satin Pelangi | 200 cm | 200×100 cm | Rp 45.000 |
| Waffle Merah | 150 cm | 150×100 cm | Rp 32.000 |

**Product: Scrunchie** (SKU: SCRUNCHIE) — 4 ProductSize variants, 4 PatternSpecs:

| Size | Kain | Cut (panjang × lebar) | Labor |
|---|---|---|---|
| M | Satin Pelangi | 90 × 20 cm | 10 menit |
| M | Waffle Merah | 80 × 18 cm | 10 menit |
| L | Satin Pelangi | 100 × 22 cm | 12 menit |
| L | Waffle Merah | 90 × 21 cm | 12 menit |

- No sales orders, no hardware components, no benang materials in seed (intentional for focused flow testing)
- Settings: labor Rp 50/menit, overhead Rp 300/unit, thread pool Rp 500/unit, packaging pool Rp 200/unit

### UI/UX fixes and improvements (v2.3)

| # | Change | Files | Details |
|---|---|---|---|
| 1 | Picker sheet layout — iOS 26 Liquid Glass fix | `SearchableDropdownField.swift`, `TokenizedMultiSelectField.swift` | `fullScreenCover` content anchored at screen center/bottom, not top — caused by iOS 26 Liquid Glass layout changes. Fixed by wrapping the entire sheet body in `NavigationStack`; the navigation bar naturally pins content to top. Both pickers now use `NavigationStack { VStack { searchBar + Divider + ScrollView + Spacer } }` with `.navigationTitle(label).navigationBarTitleDisplayMode(.inline)` and a `.cancellationAction` / `.confirmationAction` toolbar button. |
| 2 | Keyboard "Done" toolbar removed | `NumericInputField.swift`, `InlineSearchDropdownField.swift` | `ToolbarItemGroup(placement: .keyboard)` with "Done" button removed from both components. The extra tap was unnecessary — users can dismiss the keyboard by tapping outside the field. `@FocusState` retained in both for border highlight on focus. |
| 3 | InlineSearchDropdownField immediate display + "Tambah Baru" | `InlineSearchDropdownField.swift` | Dropdown list was gated behind `isEditing` state, requiring user to tap before list appeared. Changed to `if !filtered.isEmpty || onCreateNew != nil` — list shows immediately on focus. "Tambah Baru" (create button) is now always visible when `onCreateNew != nil`; shows "Tambah Baru" with empty query, "Tambah '\<query\>'" with non-empty query and no exact match, hidden when exact match exists. |
| 4 | ReportsView — DateRangeField component | `ReportsView.swift` | Two `OuraDatePickerField` + "Muat Laporan" button replaced with `DateRangeField` private struct. Single tappable button shows localized range label (e.g. "5 Agu – 5 Agu 2026"). Presents `DateRangePickerSheet` (private struct) as `.medium` detent sheet with: 5 preset chips (7 Hari, 30 Hari, Bulan Ini, Bulan Lalu, 3 Bulan) + two compact `DatePicker` rows (Dari / Sampai) + "Terapkan" button that triggers `onApply` callback. Applied to both `SalesReportDetailView` and `WasteReportView`. |
| 5 | Sales report date filtering + seed data | `MockAPIService.swift` | `getSalesReport(from:to:groupBy:)` was ignoring date params and returning random generated data. Rewrote to filter `_salesOrders` by `soldAt` date using `Calendar.startOfDay` comparison. Added `seedSalesOrders()` creating 17 `SalesOrder` objects spread over 0–30 days ago, using known product size UUIDs (M·Satin, M·Waffle, L·Satin, L·Waffle, L·Silk). `_salesOrders` now initialized from seed instead of `[]`. |

### Mock data state (v2.3)

All data from v2.0 preserved, with sales orders added:

**Sales orders (new in v2.3):** 17 seeded orders spanning the last 30 days. Orders reference 5 product size variants with realistic quantities and prices. Use date range presets in `ReportsView → Laporan Penjualan` to view different subsets.

### Live backend status (v2.4)

The app now runs against the live backend by default (`useMock = false`). JWT is stored in Keychain under service `"id.ourastudio.app"`. The remaining setup steps are:

1. ~~Set `APIService.shared.useMock = false`~~ — **Done.**
2. ~~Set `APIService.shared.baseURL`~~ — **Done.** Pointing to Cloud Run URL.
3. **Pending:** Replace the `YOUR_GOOGLE_CLIENT_ID` placeholder in `LoginView.swift` with the actual iOS OAuth client ID from GCP console.
4. **Pending:** Configure `AUTHORIZED_OWNER_EMAIL` on the backend.
5. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` — set on backend server (not iOS client).
