# Oura Studios — Product & Engineering Handoff

Custom iOS inventory app for a self-production accessories business (scrunchies, etc.).
Core problem this app solves: **accurate HPP (COGS) calculation when raw fabric is cut into multiple product sizes with different fabric types**, plus sales, stock, and margin tracking.

### 📚 Document Map & Sub-contracts

To keep context windows lean and token-efficient for developers and AI agents, the detailed specifications have been split into domain-specific contracts:

1. 📱 **[UI Spec & Screens Flow (Design & Frontend)](ui_spec.md)**
   - Bottom navigation structure & 5 main tab specifications.
   - Screen flows (Login SSO, Bahan purchases, Resep multi-fabric, Cutting Optimizer step-by-step, Products & Sales screens).
2. 🔌 **[Database Schema & API Contract (Backend & Integration)](api_contract.md)**
   - Complete PostgreSQL/Supabase database tables, types, and constraints.
   - Exact REST API endpoints, request/response payload examples, and JWT token verification steps.
   - Completeness audit log (create, edit, delete logic per resource).
3. 📈 **[Open Decisions & Implementation Status (Product & QA)](implementation_status.md)**
   - Architecture milestones status checklist.
   - Historical regression bug fixes.
   - Seed data configurations & live backend Cloud Run connection parameters.

---

## Revision History (Latest 4)

| Version | Date | Changed by | Summary |
|---|---|---|---|
| v3.48 | 2026-09-03 | Fullstack | **IMPLEMENTED: Integrasi Login Google SSO.** Mengintegrasikan login Google Single Sign-In (SSO) secara native dengan memuat Google Client ID dari Info.plist secara dinamis, mengonfigurasi Reversed Client ID sebagai skema URL kustom, mengarahkan callback Google langsung kembali ke aplikasi tanpa static web intermediary, dan menambahkan unit pengujian verifikasi konfigurasi. Rincian spesifikasi: `doc/versions/v3.48.md`. |
| v3.47 | 2026-08-31 | SDET | **IMPLEMENTED: Otomatisasi API Integration & Network Contract Test.** Mengimplementasikan skrip pengujian integrasi live (`APIIntegrationTests.swift`) yang memvalidasi kontrak API live backend (`https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1`) untuk model data `Material` dan `ProductSize`. Rincian spesifikasi: `doc/versions/v3.47.md`. |
| v3.46 | 2026-08-30 | Frontend | **IMPLEMENTED: Expand List Item Penjualan di Daftar Penjualan.** Menambahkan opsi expand down (akordeon) di baris daftar penjualan untuk menampilkan rincian item produk yang dibeli secara kompak (nama produk, ukuran, qty, harga, diskon, subtotal) dengan indentasi estetik, sementara seluruh area baris tetap dapat diklik untuk membuka detail transaksi lengkap. Rincian spesifikasi: `doc/versions/v3.46.md`. |
| v3.45 | 2026-08-30 | Frontend | **IMPLEMENTED: Jam Transaksi Penjualan.** Menambahkan waktu jam transaksi (jam & menit) di seksi detail penjualan dan baris daftar penjualan untuk visibilitas waktu transaksi yang lebih presisi. Rincian spesifikasi: `doc/versions/v3.45.md`. |

> **Note:** Untuk melihat daftar histori revisi v1.0 s.d v3.44 secara lengkap, silakan merujuk ke folder `doc/versions/`.

---

## 0. Tech Stack (confirmed)

- **Frontend:** Native iOS — Swift + SwiftUI, standard Xcode project.
- **Sync model:** **Multi-device sync required** — this is not a single-device/local-only app.
- **Backend:** Python + **FastAPI** (with **SQLAlchemy** ORM, **Alembic** migrations, **Pydantic** validation).
- **Database: Supabase** (PostgreSQL compatible, connected via connection string `SUPABASE_DB_URL`).
- **Auth:** **Google Sign-In (OAuth 2.0)** on the iOS client, JWT bearer tokens on every backend endpoint. No self-registration or password storage on our server. Verified emails must match `AUTHORIZED_OWNER_EMAIL`.

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

Given: a fabric purchase's dimensions (width × length), and a set of candidate PatternSpecs.
Goal: compute one or more candidate **CuttingLayouts** — combinations of {size, qty, orientation} — and their resulting waste % and cost-per-piece.
Approach: **two-phase shelf-packing heuristic** — runs as a pure function server-side or on-device; no ML needed. Produces three output strategies (minWaste, maxQty, maxProfit) in a single pass.

**Phase 1 — per-candidate pre-computation:**
For each candidate PatternSpec × MaterialPurchase pair, compute both orientations:
- Normal: `cols = floor(rollWidth / cutWidth)`, `rowHeight = cutLength`
- Rotated *(if rotation allowed)*: `cols = floor(rollWidth / cutLength)`, `rowHeight = cutWidth`
- Primary orientation = whichever yields more total pieces on the full roll (`cols × rows`)
- Alternative = the other orientation (stored for Phase 2 fallback)
- `minRows = ceil(minQty / primaryCols)` — rows needed to satisfy `minQty` using the primary orientation
- **`bestMinLen` = `min(normalMinRows × cutLength, rotMinRows × cutWidth)`** — the minimum roll length needed to satisfy `minQty` using *whichever orientation is more compact*.

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
If a candidate's primary orientation has a large rowHeight (e.g. cutLength ≈ full roll length), using `primaryMinRows × primaryRowHeight` as the reservation amount would reserve nearly 100% of the roll for that candidate's future minimum — starving every candidate processed before it. `bestMinLen` uses the more compact orientation's rowHeight, which may be much smaller.

**Why the orientation fallback matters (worked example):**
Roll 200cm wide × 100cm long. M piece: cutLength=100, cutWidth=22 (rotation allowed). L piece: cutLength=120, cutWidth=25.
- M primary=normal (9 pcs on full roll, rowH=100), alt=rotated (8 pcs, rowH=22), `bestMinLen=22`
- L primary=rotated (4 pcs, rowH=25 — normal doesn't fit: 120>100), `bestMinLen=25`
- Processing M: reserve 25cm for L → `available=75cm` → primary (rowH=100): `floor(75/100)=0` → **fallback to alt (rowH=22): `floor(75/22)=3 rows` → 6 pcs, uses 66cm**
- Processing L: remaining=34cm → primary (rowH=25): `floor(34/25)=1 row` → 1 pcs
- Result: **M=6, L=1** (both min=1 constraints satisfied, waste=9cm). Without the fallback: M=0, L=4 (M's minimum silently violated).

This runs server-side (or on-device) as a pure function.
**Important:** the optimizer's output is a **suggestion**. The actual cut always gets user-confirmed/edited after physical cutting (fabric defects, human error), and that confirmed data — not the suggestion — is what the final HPP and stock entry are based on.

### 1.6 Pricing formula (for the "price advisor" feature)

```
selling_price = HPP ÷ (1 − target_margin − marketplace_fee_pct − promo_allocation_pct)
```

Margin vs markup:
- Margin = (price − HPP) / price
- Markup = (price − HPP) / HPP
