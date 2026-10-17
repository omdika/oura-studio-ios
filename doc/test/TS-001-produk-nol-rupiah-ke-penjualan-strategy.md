# TS-001 — Produk Rp0 ke Penjualan - Maestro Strategy

| Field | Value |
|---|---|
| **ID** | TS-001 |
| **Feature** | Produk manual → Penjualan (`ProdukListView` + `TambahProdukLengkapSheet` → `PenjualanListView` + `TambahPenjualanSheet`) |
| **Type** | Maestro UI (black-box journey) |
| **App ID** | `handika.oura-studio-frontend` |
| **Added Date** | 2026-10-14 |

## 1. Objective & Scope
*   **Goal:** Verifikasi alur tambah produk manual tanpa resep, harga Rp0 / belum ada harga, lalu jual produk tersebut via Catat Penjualan. Memastikan navigasi, sheet, dan list sync tidak crash.
*   **Out-of-scope (delegated):** Validasi HPP/margin Rp0 dan `POST /api/v1` contract → API tests (`sdet-test-strategy`). Assert tombol `Simpan` disabled-state presisi → XCUITest (`test-write`). Perhitungan `Total Pendapatan` → API.

## 2. Pre-requisites & Setup
*   **Simulator:** Booted (e.g. iPhone 17 Pro), app installed.
*   **Auth:** Logged-in precondition (Google SSO). No `clearState: true`.
*   **Seed labels (grep-verified):** `"Produk"`, `"BUAT PRODUK BARU"`, `"Simpan Tanpa Resep"`, `"Simpan Produk & Resep"`, `"Belum ada harga"`, `"Penjualan"`, `"Catat Penjualan"`, `"Pilih Produk"`, `"Produk Dijual"`, `"Belum ada produk ditambahkan."`, `"Total Pendapatan"`, `"Batal"`

## 3. TC Matrix (planned — YAML by test-maestro-write)

| TC-ID | Title | Type | Priority | Feasibility | Planned Maestro Flow |
|---|---|---|---|---|---|
| TC-004 | Tambah produk manual Simpan Tanpa Resep | Positive | P1 | Feasible | `test/scripts/TC004_TambahProdukManual.yaml` (planned) |
| TC-005 | Produk baru tampil Belum ada harga / harga 0 | Edge | P1 | Feasible (assert text), Delegate (nilai numerik) | `test/scripts/TC005_ProdukHargaNol.yaml` (planned) |
| TC-006 | Jual produk Rp0 via Catat Penjualan | Positive | P1 | Feasible read-only-open, Write with cleanup | `test/scripts/TC006_JualProdukNol.yaml` (planned) |
| TC-007 | Batalkan / dismiss tanpa simpan tetap aman | Negative | P2 | Feasible | `test/scripts/TC007_BatalTanpaSimpan.yaml` (planned) |

## 4. Per-TC Step Outline (assert-level, no YAML syntax)
### TC-004 — Tambah produk manual Simpan Tanpa Resep
1. Launch → tap tab `"Produk"` → assert `"Produk"` visible → screenshot `TC004_01_Produk`
2. Tap `"BUAT PRODUK BARU"` → assert `"BUAT PRODUK BARU"` visible → screenshot `TC004_02_Sheet`
3. Isi nama manual → tap `"Simpan Tanpa Resep"` → assert kembali ke `"Produk"` → screenshot `TC004_03_Tersimpan`

### TC-005 — Produk baru tampil Belum ada harga / harga 0
1. Launch → tap `"Produk"` → assert produk baru muncul, assert `"Belum ada harga"` atau `"Rp0"` visible → screenshot `TC005_01_HargaNol`
2. Tap produk → assert detail `"Belum ada harga"` visible → screenshot `TC005_02_Detail`
3. Back → assert `"Produk"` visible → screenshot `TC005_03_Kembali`

### TC-006 — Jual produk Rp0 via Catat Penjualan
1. Launch → tap `"Penjualan"` → assert `"Penjualan"` visible → screenshot `TC006_01_Penjualan`
2. Tap `"Catat Penjualan"` → assert `"Produk Dijual"` + `"Belum ada produk ditambahkan."` visible → screenshot `TC006_02_Sheet`
3. Tap `"Pilih Produk"` → pilih produk TC-004 → assert `"Total Pendapatan"` visible → screenshot `TC006_03_Terjual`
4. Dismiss via `back`/`"Batal"` (default read-only). Jika tap Simpan, wajib catat cleanup: batalkan order via API / hapus data uji.

### TC-007 — Batalkan / dismiss tanpa simpan tetap aman
1. Launch → `"Produk"` → `"BUAT PRODUK BARU"` → tap `"Batal"`/`back` → assert `"Produk"` visible → screenshot `TC007_01_BatalProduk`
2. Launch → `"Penjualan"` → `"Catat Penjualan"` → `back` → assert `"Penjualan"` visible → screenshot `TC007_02_BatalJual`

## 5. Screenshot Policy
*   `takeScreenshot: TC{NNN}_NN_Name` at start, each transition/assert, end. No `..`, no empty, no dir path.
*   Contoh: `TC004_01_Produk`, `TC006_03_Terjual`.
