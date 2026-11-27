# TC-009 — Filter Kategori Produk List (Chip "All" + Tampilan Kompak)

| Field | Value |
|---|---|
| **ID** | TC-009 |
| **Feature** | Produk → Produk List → Filter Kategori |
| **Type** | Sanity / UI |
| **Priority** | P1 |
| **Script** | (UITest via `app.buttons` / `app.staticTexts` di `ProdukListView`) |
| **Added** | 2026-11-26 |
| **Spesifikasi** | `doc/versions/v3.88.md` |

---

## Preconditions
- App launched, authenticated.
- Tab "Produk" aktif (`ProdukListView`).
- Ada seed data produk dengan kategori `pouch` dan `scrunchie` (minimal 1 produk per kategori).
- Tidak ada pending sheet atau alert terbuka.

---

## Step-by-Step Execution Flow

| Step | Action | Element / Identifier |
|---|---|---|
| 1 | Buka tab "Produk" | `app.tabBars.buttons["Produk"]` |
| 2 | Pastikan area filter kategori muncul di bawah search header | `app.staticTexts["Kategori"]` |
| 3 | Pastikan chip "All", "Pouch", "Scrunchie" tampil sejajar dalam satu baris horizontal | `app.buttons["All"]`, `app.buttons["Pouch"]`, `app.buttons["Scrunchie"]` |
| 4 | Verifikasi "All" aktif default saat masuk (semua produk non-archived muncul) | List menampilkan semua produk; chip "All" ditandai aktif (accent) |
| 5 | Tap chip "Pouch" | `app.buttons["Pouch"]` |
| 6 | Verifikasi hanya produk kategori pouch yang muncul; chip "Pouch" accent, "All" tidak aktif | List hanya produk pouch; `app.buttons["Pouch"]` terpilih |
| 7 | Tap chip "All" kembali | `app.buttons["All"]` |
| 8 | Verifikasi kembali ke semua produk; chip "All" accent terpilih | List semua produk non-archived |
| 9 | Tap chip "Scrunchie" | `app.buttons["Scrunchie"]` |
| 10 | Verifikasi hanya produk kategori scrunchie yang muncul | List hanya produk scrunchie |
| 11 | (P2) Kombinasi kategori + search: aktifkan "Pouch", ketik search produk pouch | List intersect antara kategori pouch + search |
| 12 | (P2) Verifikasi tampilan lebih kompak dari sebelumnya (tinggi area filter lebih sempit, tidak ada ouraCard tebal) | Visual check: area filter kategori lebih sempit vertikal |

---

## Assertion & Verification Criteria

| # | Expected | Cara verifikasi |
|---|---|---|
| E1 | Chip "All", "Pouch", "Scrunchie" semua tampil dalam satu baris horizontal | `app.buttons["All"].exists`, `app.buttons["Pouch"].exists`, `app.buttons["Scrunchie"].exists` |
| E2 | "All" aktif default saat masuk | Semua produk non-archived tampil di list; chip "All" accent/terpilih |
| E3 | Setelah pilih "Pouch", hanya produk pouch muncul | Setiap produk di list memiliki kategori pouch |
| E4 | Setelah pilih "All" kembali, semua produk muncul kembali | List kembali ke semua produk non-archived |
| E5 | Setelah pilih "Scrunchie", hanya produk scrunchie muncul | Setiap produk di list memiliki kategori scrunchie |
| E6 | Chip "All" bisa diklik untuk kembali ke semua setelah memilih kategori lain | Tap `app.buttons["All"]` mengembalikan daftar penuh |
| E7 | Area filter kategori lebih kompak (tanpa ouraCard tebal + padding besar) | Tinggi area filter lebih sempit dari implementasi v3.87 |
| E8 | `ChipSingleSelect` di layar lain (non-compact) tidak rusak (regression) | Buka layar lain yang pakai ChipSingleSelect, tampil normal |

---

## Notes
- Identifier aksesibilitas `app.buttons["All"]` / `["Pouch"]` / `["Scrunchie"]` bergantung pada chip `ChipSingleSelect` meng-set `.accessibilityLabel` sesuai title opsi. Tambahkan jika belum ada.
- Jika UITest belum stabil untuk verifikasi visual proporsi (E7), tandai sebagai manual verification.
