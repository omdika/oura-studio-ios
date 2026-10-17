# TC-004 — Tambah Produk Manual - Maestro UI Test

| Field | Value |
|---|---|
| **ID** | TC-004 |
| **Feature** | Produk (`ProdukListView` + `TambahProdukLengkapSheet`) |
| **Type** | Positive |
| **Priority** | P1 |
| **Maestro Flow** | `test/scripts/TC004_TambahProdukManual.yaml` |
| **Added Date** | 2026-10-14 |

## 1. Objective & Scope
*   **Goal:** Verifikasi tambah produk manual tanpa resep (nama + SKU auto) lalu `Simpan Tanpa Resep` kembali ke list tanpa crash. Fondasi untuk TC-005/TC-006 (harga Rp0 → jual).
*   **Strategy:** `doc/test/TS-001-produk-nol-rupiah-ke-penjualan-strategy.md`

## 2. Pre-requisites & Setup
*   **Simulator:** Running iOS Simulator (e.g. iPhone 17 Pro).
*   **App Status:** Installed Bundle ID `handika.oura-studio-frontend`.
*   **Auth:** Logged-in precondition (Google SSO). No `clearState: true` — fresh install lands on login, not dashboard.
*   **Write path:** TC ini eksplisit mencakup tap `Simpan Tanpa Resep` (menulis DB). Cleanup: hapus produk uji via detail/API setelah run agar tidak pollute list.

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Tap Tab:** Tap `"Produk"` → assert nav `"Produk"` visible.
3.  **Screenshot:** Capture `TC004_01_Produk`.
4.  **Tap FAB:** Tap FAB plus (icon-only, see Notes) → assert sheet `"BUAT PRODUK BARU"` / `"Tambah Produk"` visible.
5.  **Screenshot:** Capture `TC004_02_Sheet`.
6.  **Input Nama:** Tap field `"contoh: Scrunchie Mini"` → type `"Boneka Zeta TC004"` (SKU auto = 3 char/word → `BONZETTC0`; kata terakhir harus unik di 3 char pertama agar tidak `sku already exists`).
7.  **Size:** `scroll` (sekaligus menutup keyboard — JANGAN `hideKeyboard`, tap-nya nyasar ke `Lanjutkan ke Resep`) → assert `"Free Size"` default terpilih (JANGAN tap chip) → screenshot `TC004_03_SizeFreeSize`.
8.  **Save:** Tap `"Simpan Tanpa Resep"` → assert detail `"Boneka Zeta TC004"` visible (app navigates to detail, not list).
9.  **Screenshot:** Capture `TC004_04_Tersimpan`.
10. **Close:** Tap `"Tutup"` → assert `"Produk"` visible.
11. **Screenshot:** Capture `TC004_05_KembaliList`.

## Notes
- `OuraFAB` fixed: `.accessibilityIdentifier("fab-tambah-produk")` di `Core/OuraTheme.swift` — yaml pakai id stabil.
- SKU auto dari nama (`autoSKU`), tidak perlu input manual kecuali duplikat. Pakai nama unik per run; error `sku already exists` = data run sebelumnya belum di-cleanup, bukan flaky.
- Jika `Simpan Tanpa Resep` disabled (step1 invalid), fail = product bug, bukan flaky.
