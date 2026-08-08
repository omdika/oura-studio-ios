# TC-001 — Tambah Pembelian Kain (Positive Case)

| Field | Value |
|---|---|
| **ID** | TC-001 |
| **Feature** | Produksi → Bahan → Tambah Pembelian |
| **Type** | Positive |
| **Priority** | P1 |
| **Script** | `test/scripts/TC001_TambahPembelianKain.swift` |
| **Added** | 2026-08-07 |

---

## Preconditions

- App launched, authenticated (via `--uitest-bypass-auth` flag di UITest run)
- Material "Satin Pelangi" sudah ada di daftar Bahan (seed data mock)
- App menggunakan `MockAPIService` (`useMock = true` untuk UITest isolation, atau app menggunakan live backend yang sudah ada data seed-nya)
- Tidak ada pending sheet atau alert terbuka

---

## Steps

| Step | Action | Element / Identifier |
|---|---|---|
| 1 | Launch app | `app.launchArguments = ["--uitest-bypass-auth"]` |
| 2 | Tunggu tab bar muncul | `app.tabBars.firstMatch` |
| 3 | Tap tab "Produksi" | `app.tabBars.buttons["Produksi"]` |
| 4 | Tap sub-tab "Bahan" | `app.buttons["Bahan"]` |
| 5 | Tap tombol tambah pembelian | `app.buttons["Tambah Pembelian"]` |
| 6 | Sheet **TambahPembelianSheet** terbuka | `app.navigationBars["Tambah Pembelian"]` |
| 7 | Tap dropdown field Bahan | `app.buttons["dropdown-Bahan"]` |
| 8 | Sheet picker Bahan terbuka | `app.navigationBars["Bahan"]` |
| 9 | Tap item "Satin Pelangi" | `app.buttons["item-Satin Pelangi"]` via `tapCell(in:text:)` |
| 10 | Sheet picker tutup, material terpilih | Teks "Satin Pelangi" muncul di form |
| 11 | Isi field "Lebar (cm)": `150` | `app.textFields["Lebar (cm)"]` |
| 12 | Dismiss keyboard | `tapDone(app)` |
| 13 | Isi field "Panjang (cm)": `200` | `app.textFields["Panjang (cm)"]` |
| 14 | Dismiss keyboard | `tapDone(app)` |
| 15 | Isi field "Total Biaya": `45000` | `app.textFields["Total Biaya"]` |
| 16 | Dismiss keyboard | `tapDone(app)` |
| 17 | Tap tombol "Simpan" | `app.navigationBars.buttons["Simpan"]` |
| 18 | Sheet dismiss, kembali ke BahanListView | — |
| 19 | Masuk ke detail "Satin Pelangi" | `tapCell(in: app, text: "Satin Pelangi")` |
| 20 | Lihat Riwayat Pembelian | `app.staticTexts["Riwayat Pembelian"]` |

---

## Expected Results

| # | Expected | Cara verifikasi |
|---|---|---|
| E1 | TambahPembelianSheet terbuka setelah tap "+" | `app.navigationBars["Tambah Pembelian"].waitForExistence(timeout: 5)` |
| E2 | Setelah memilih Satin Pelangi, section "Detail Pembelian" muncul (Lebar + Panjang) | `app.textFields["Lebar (cm)"].waitForExistence(timeout: 3)` |
| E3 | Tombol "Simpan" aktif (tidak disabled) setelah semua field terisi | `app.navigationBars.buttons["Simpan"].isEnabled == true` |
| E4 | Sheet dismiss setelah Simpan | `app.navigationBars["Tambah Pembelian"]` tidak ada setelah tap Simpan |
| E5 | BahanListView masih menampilkan "Satin Pelangi" | `app.staticTexts["Satin Pelangi"].waitForExistence(timeout: 5)` |
| E6 | Di BahanDetailView, Riwayat Pembelian memiliki entri baru | Section "Riwayat Pembelian" muncul di detail view |
| E7 | Entri baru menampilkan dimensi yang benar: 150×200 cm | `app.staticTexts` berisi "150 × 200" atau teks senilai |
| E8 | Total biaya muncul sebagai "Rp 45.000" | `app.staticTexts` berisi "45.000" |

---

## Notes

- `app.buttons["Tambah Pembelian"]` — tombol ini mungkin ditampilkan sebagai ikon "+" tanpa label teks. Jika tidak ditemukan, fallback ke `app.buttons["+"]` atau cek apakah button memiliki identifier lain. Tambahkan `.accessibilityLabel("Tambah Pembelian")` di `BahanListView.swift` jika identifier belum ada. Lihat TODO di script.
- `app.textFields["Total Biaya"]` — identifier ini bergantung pada `CurrencyInputField` meng-set `.accessibilityLabel("Total Biaya")`. Verifikasi di komponen atau tambahkan jika belum ada.
- Field Supplier (opsional) sengaja dibiarkan kosong di test ini — diuji terpisah di TC-002.
- Field Tanggal Beli dibiarkan default (hari ini) — diuji terpisah di TC-003.
- Step 19–20 (verifikasi di detail) adalah P2: jika UITest untuk detail view belum stabil, skip step ini dan tandai sebagai manual verification.
