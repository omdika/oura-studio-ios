# TC-006 — Jual Harga 1000 Diskon 1000 - Maestro UI Test

| Field | Value |
|---|---|
| **ID** | TC-006 |
| **Feature** | Penjualan (`PenjualanListView` + `TambahPenjualanSheet`) |
| **Type** | Positive (edge: total Rp0) |
| **Priority** | P1 |
| **Maestro Flow** | `test/scripts/TC006_JualHargaDiskon.yaml` |
| **Added Date** | 2026-10-15 |

## 1. Objective & Scope
*   **Goal:** Jual 1 pcs `Boneka Zeta TC004` dengan `Harga Satuan` 1000 + `Diskon` 1000 (total Rp0). Produk belum ada harga jual → harga diisi manual di kasir.
*   **Strategy:** `doc/test/TS-001-produk-nol-rupiah-ke-penjualan-strategy.md`

## 2. Pre-requisites & Setup
*   **Simulator:** Running iOS Simulator (e.g. iPhone 17 Pro).
*   **App Status:** Installed Bundle ID `handika.oura-studio-frontend`.
*   **Auth:** Logged-in precondition (Google SSO). No `clearState: true`.
*   **Seed:** Stok Free Size = 1 pcs (dari TC-005). Picker hanya menampilkan size stok > 0.
*   **Write path:** TC ini membuat order penjualan (total Rp0). Rerun butuh stok lagi — kalau stok habis, ulangi TC-005 dulu.

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Tap Tab:** Tap `"Penjualan"` → assert `"Penjualan"` visible → screenshot `TC006_01_Penjualan`.
3.  **Open Sheet:** Tap id `fab-tambah-penjualan` → assert `"Catat Penjualan"` + `"Belum ada produk ditambahkan."` visible → screenshot `TC006_02_SheetKosong`.
4.  **Picker:** Tap `"Tambah Produk"` → assert `"Pilih Produk"` → search `"Zeta"` (baris berlabel size, bukan nama produk) → tap `"Free Size"` → assert `"Harga Satuan"` → screenshot `TC006_03_Picker` + `TC006_04_ItemDitambah`.
6.  **Harga:** Tap id `input-Harga Satuan` → type `"1000"` → `scroll` → screenshot `TC006_05_Harga`.
7.  **Diskon:** Tap id `input-Diskon` → type `"1000"` → `scroll` → screenshot `TC006_06_Diskon`.
8.  **Save:** Tap `"Simpan"` → assert `"Penjualan"` visible → screenshot `TC006_07_Tersimpan`.

## Notes
- Qty default 1 = maxQty 1, jangan ubah stepper.
- `Ringkasan / Total Pendapatan` hanya muncul bila total > 0 — dengan diskon penuh total Rp0, jadi tidak di-assert.
- Validasi client: harga > 0 dan diskon ≤ harga×qty (1000 ≤ 1000 OK).
- Backend bisa menolak total Rp0 — bila `Simpan` gagal, screenshot error jadi bukti untuk revisi (mis. diskon 500).
