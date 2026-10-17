# TC-005 — Tambah Stok Manual 1 pcs - Maestro UI Test

| Field | Value |
|---|---|
| **ID** | TC-005 |
| **Feature** | Produk size detail (`ProdukSizeDetailView` + `TambahStokSheet`) |
| **Type** | Positive |
| **Priority** | P1 |
| **Maestro Flow** | `test/scripts/TC005_TambahStokSatu.yaml` |
| **Added Date** | 2026-10-15 |

## 1. Objective & Scope
*   **Goal:** Stok `Boneka Zeta TC004 / Free Size` dari 0 → 1 pcs via `Tambah` agar bisa dijual di TC-006.
*   **Strategy:** `doc/test/TS-001-produk-nol-rupiah-ke-penjualan-strategy.md`

## 2. Pre-requisites & Setup
*   **Simulator:** Running iOS Simulator (e.g. iPhone 17 Pro).
*   **App Status:** Installed Bundle ID `handika.oura-studio-frontend`.
*   **Auth:** Logged-in precondition (Google SSO). No `clearState: true`.
*   **Seed:** Produk `Boneka Zeta TC004` ada (dari TC-004). Filter tanggal OFF (kalau hasil cari kosong, matikan `Filter berdasarkan Tanggal Masuk Stok`).
*   **Write path:** TC ini menambah stok DB. Idempotent untuk rerun hanya bila stok masih 0 — setelah stok 1, rerun perlu produk baru.

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Tap Tab:** Tap `"Produk"` → assert `"Produk"` visible → screenshot `TC005_01_Produk`.
3.  **Search:** Tap `"Cari produk atau bahan..."` → type `"Zeta"` → `scroll` (tutup keyboard) → assert `"Boneka Zeta TC004"` visible → screenshot `TC005_02_HasilCari`.
4.  **Open Detail:** Tap `"Boneka Zeta TC004"` → assert `"UKURAN"` visible → screenshot `TC005_03_Detail`.
5.  **Open Size:** Tap `"Free Size"` (grup) → assert `"VARIAN KAIN"` → **point-tap `70,338`** di teks baris varian → assert `"Stok"` + `"0 pcs"` → screenshot `TC005_04_GrupVarian` + `TC005_05_SizeNol`. (Tap id/text tidak memicu NavigationLink di grup ini — verified 3 run gagal; point-tap passed.)
6.  **Open Sheet:** Tap `"Tambah"` → assert `"Tambah Stok Manual"` → screenshot `TC005_06_Sheet`.
7.  **Input:** Tap id `input-Jumlah` → type `"1"` → `scroll` → screenshot `TC005_07_Terisi`.
8.  **Save:** Tap `"Simpan"` → assert `"1 pcs"` → screenshot `TC005_08_StokSatu`.
9.  **Back:** `back` ×3 → assert `"Produk"` → screenshot `TC005_09_KembaliList`.

## Notes
- JANGAN `hideKeyboard` (tap-nya nyasar) dan JANGAN tap chip size di sheet tambah produk.
- Field via accessibility id (`input-Jumlah`) — tap by text berisiko kena label statis.
