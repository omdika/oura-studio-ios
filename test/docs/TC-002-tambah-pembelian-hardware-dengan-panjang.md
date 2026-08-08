# TC-002 — Tambah Pembelian Hardware Baru dengan Panjang (Positive Case)

| Field | Value |
|---|---|
| **ID** | TC-002 |
| **Feature** | Produksi → Bahan → Tambah Pembelian (Hardware, inline create) |
| **Type** | Positive |
| **Priority** | P1 |
| **Script** | `test/scripts/TC002_TambahPembelianHardwareDenganPanjang.swift` |
| **Added** | 2026-08-07 |

---

## Preconditions

- App launched, authenticated (via `--uitest-bypass-auth`)
- "Karet Elastis 3mm" belum ada di daftar Bahan (material akan dibuat inline)
- App menggunakan MockAPIService atau live backend yang mendukung create material + purchase
- v2.5 sudah diapply: hardware di TambahPembelianSheet menampilkan field Panjang (cm)

---

## Steps

| Step | Action | Element / Identifier |
|---|---|---|
| 1 | Launch app | `app.launchArguments = ["--uitest-bypass-auth"]` |
| 2 | Tunggu tab bar | `app.tabBars.firstMatch` |
| 3 | Tap tab "Produksi" | `app.tabBars.buttons["Produksi"]` |
| 4 | Tap sub-tab "Bahan" | `app.buttons["Bahan"]` |
| 5 | Tap tombol tambah | `app.buttons["Tambah Pembelian"]` |
| 6 | Sheet TambahPembelianSheet terbuka | `app.navigationBars["Tambah Pembelian"]` |
| 7 | Tap dropdown field Bahan | `app.buttons["dropdown-Bahan"]` |
| 8 | Picker Bahan terbuka | `app.navigationBars["Bahan"]` |
| 9 | Ketik "Karet Elastis" di search field | `app.textFields.firstMatch.typeText("Karet Elastis")` |
| 10 | Tap tombol "Tambah 'Karet Elastis'" | `app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tambah'")).firstMatch` |
| 11 | Picker tutup, form tampil mode "Bahan Baru" + chip Kategori | `app.staticTexts["Karet Elastis"]`, `app.staticTexts["Bahan baru — belum tersimpan"]` |
| 12 | Tap chip "Hardware" pada Kategori | `app.buttons["Hardware"]` |
| 13 | Section Detail Pembelian muncul: Jumlah + Panjang | `app.textFields["Jumlah"]`, `app.textFields["Panjang (cm)"]` |
| 14 | Isi field "Jumlah": `3` | `app.textFields["Jumlah"]` |
| 15 | Dismiss keyboard | `tapDone(app)` |
| 16 | Isi field "Panjang (cm)": `100` | `app.textFields["Panjang (cm)"]` |
| 17 | Dismiss keyboard | `tapDone(app)` |
| 18 | Isi field "Total Biaya": `15000` | `app.textFields["Total Biaya"]` |
| 19 | Dismiss keyboard | `tapDone(app)` |
| 20 | Tap "Simpan" | `app.navigationBars.buttons["Simpan"]` |
| 21 | Sheet dismiss, kembali ke BahanListView | — |
| 22 | Tap "Karet Elastis" untuk masuk ke detail | `tapCell(in: app, text: "Karet Elastis")` |
| 23 | Lihat Riwayat Pembelian | `app.staticTexts["Riwayat Pembelian"]` |

---

## Expected Results

| # | Expected | Cara verifikasi |
|---|---|---|
| E1 | Mode "Bahan Baru" muncul setelah inline create | `app.staticTexts["Bahan baru — belum tersimpan"].waitForExistence(timeout: 4)` |
| E2 | Chip Kategori tampil: Kain, Benang, Hardware, Packaging | `app.buttons["Hardware"].waitForExistence(timeout: 3)` |
| E3 | Setelah tap chip "Hardware", muncul field "Jumlah" DAN "Panjang (cm)" | Keduanya harus ada — `Panjang (cm)` adalah perubahan v2.5 |
| E4 | Tombol "Simpan" aktif setelah Jumlah + Panjang + Total Biaya terisi | `app.navigationBars.buttons["Simpan"].isEnabled == true` |
| E5 | Sheet dismiss setelah Simpan berhasil | `app.navigationBars["Tambah Pembelian"]` tidak ada |
| E6 | "Karet Elastis" muncul di BahanListView | `app.staticTexts["Karet Elastis"].waitForExistence(timeout: 5)` |
| E7 | Di BahanDetailView, Riwayat Pembelian tampil entri baru | `app.staticTexts["Riwayat Pembelian"].waitForExistence(timeout: 5)` |
| E8 | Entri menampilkan info panjang (3 × 100 cm atau total 300 cm) | `NSPredicate(format: "label CONTAINS '100'")` |
| E9 | Entri menampilkan total biaya Rp15.000 | `NSPredicate(format: "label CONTAINS '15'")` |

---

## Notes

- **Step 9–10:** `SearchableDropdownField` tidak menetapkan `.accessibilityIdentifier` pada tombol "Tambah Baru" — script menggunakan `NSPredicate(format: "label BEGINSWITH 'Tambah'")`. Tambahkan `.accessibilityIdentifier("btn-tambah-baru")` di `SearchableDropdownField.swift` untuk identifier yang lebih stabil.
- **Step 12:** `ChipSingleSelect` chips diakses via label teks langsung (`app.buttons["Hardware"]`). Jika label berubah (misal jadi "Hardware (klip, ring)"), update selector ini.
- **Step 13:** Field "Panjang (cm)" muncul hanya jika `isHardware = true` — ini adalah behavior baru v2.5. Jika field tidak muncul, berarti `isHardware` tidak aktif atau kategori belum terpilih.
- **E3 adalah regression guard untuk v2.5** — jika field Panjang hilang di update selanjutnya, test ini akan catch-nya.
- Test ini juga implisit verify bahwa material baru dibuat dengan `usage_unit = "cm"` (karena Panjang diisi), yang akan tampak saat material ini dipakai di Tambah Resep sebagai komponen.
- Jika menggunakan live backend: pastikan tidak ada duplikat "Karet Elastis" sebelum test dijalankan, atau gunakan nama unik per test run.
