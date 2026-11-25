# TC-006 — Download/Simpan Struk PDF di Detil Penjualan

| Field | Value |
|---|---|
| **ID** | TC-006 |
| **Feature** | Penjualan → Detil Penjualan → Simpan Struk PDF |
| **Type** | Sanity / Positive + Negative |
| **Priority** | P1 |
| **Spesifikasi** | `doc/versions/v3.86.md` |
| **Added** | 2026-11-25 |

---

## 1. Objective & Scope

Verifikasi bahwa tombol "Simpan sebagai PDF" di halaman detil penjualan (`EditPenjualanSheet`, section "Struk Penjualan") tidak lagi silent failure (tidak ada apa-apa saat ditekan). Share sheet `UIActivityViewController` harus muncul, dan PDF harus dapat disimpan ke Files. Juga verifikasi error handling jika environment tidak mendukung presentasi share sheet.

## 2. Pre-requisites & Setup

- App launched, authenticated.
- Minimal ada 1 sales order (`SalesOrder`) dengan status `paid` atau `pending`, memiliki ≥1 item, dan `invoiceNo` valid (format `INV-YYYY-NNN`).
- Tidak ada pending sheet, alert, atau keyboard terbuka.
- Printer Bluetooth tidak perlu terhubung (fitur PDF tidak bergantung printer).
- Untuk UITest: gunakan `MockAPIService` (`useMock = true`) atau live backend dengan seed data.

## 3. Step-by-Step Execution Flow

| Step | Action | Element / Identifier |
|---|---|---|
| 1 | Launch app | `app.launch()` |
| 2 | Tunggu hingga halaman Penjualan muncul | `app.navigationBars["Penjualan"].waitForExistence(timeout: 5)` |
| 3 | Tap order apa pun di daftar penjualan | `app.buttons` berisi `invoiceNo` order → buka `EditPenjualanSheet` |
| 4 | Verifikasi sheet detil penjualan terbuka | `app.navigationBars[invoiceNo]` ada |
| 5 | Scroll ke section "Struk Penjualan" | Section header "Struk Penjualan" muncul |
| 6 | Tap tombol "Simpan sebagai PDF" | `app.buttons["Simpan sebagai PDF"]` atau ikon `doc.plaintext.fill` + teks |
| 7 | Verifikasi respons | `UIActivityViewController` (share sheet) muncul, atau alert error jika environment tidak mendukung |
| 8 | (Opsional, jika share sheet muncul) Pilih "Simpan ke Files" | File tersimpan di Files dengan nama `Struk_<invoiceNo>.pdf` |
| 9 | (Opsional) Buka file PDF dari Files | PDF dapat dibuka, menampilkan isi struk (header OURA STUDIO, detail invoice, item, total) |

## 4. Assertion & Verification Criteria (Definitive Checks)

| # | Expected | Cara verifikasi |
|---|---|---|
| E1 | `EditPenjualanSheet` terbuka dengan judul = invoiceNo | `app.navigationBars[invoiceNo].exists == true` |
| E2 | Section "Struk Penjualan" memiliki tombol "Simpan sebagai PDF" | `app.buttons` berisi teks "Simpan sebagai PDF" |
| E3 | Setelah tap tombol, **tidak silent** — setidaknya ada respons visual | Share sheet muncul **atau** alert error muncul (tidak ada layar diam tanpa respons) |
| E4 | Jika share sheet muncul: judul aktivitas berisi "Simpan ke Files" atau opsi share lain | `app.sheets` atau `app.collectionViews` share sheet ada |
| E5 | Jika disimpan ke Files: file `Struk_<invoiceNo>.pdf` ada dan bisa dibuka | FileManager / Files app menampilkan file PDF dengan nama yang benar |
| E6 | Jika environment tidak mendukung presentasi (mis. uji automated tanpa window aktif): alert error muncul, tidak crash | `app.alerts` berisi teks error, app tidak crash |
| E7 | Cetak struk thermal (`Cetak Struk`) tetap normal (regression) | Tombol cetak tetap responsive, tidak error baru |

## 5. Negative / Edge Case Scenarios

| # | Scenario | Expected |
|---|---|---|
| N1 | Order dengan `invoiceNo` yang berisi karakter aneh (jika ada data sedemikian) | Tidak crash saat generate nama file; sanitasi diterapkan |
| N2 | Disk penuh / temp tidak bisa ditulis | Alert error "Gagal membuat file PDF: ..." muncul, app tidak crash |
| N3 | Tap tombol berulang kali (double-tap) | Tidak crash; share sheet dapat muncul berkali-kali atau di-debounce |

## 6. Notes

- `app.buttons["Simpan sebagai PDF"]` — tergantung pada accessibility label yang di-set di SwiftUI. Jika tidak ditemukan, cari via `app.buttons` yang berisi teks "Simpan sebagai PDF" atau ikon `doc.plaintext.fill`.
- Share sheet di iOS UITest mungkin sulit di-trace via XCUITest standar. Jika tidak stabil, tandai step 7–8 sebagai **manual verification** dan fokus pada E3 (tidak silent).
- PDF di-generate sepenuhnya lokal di-device via `ReceiptPDFGenerator.generatePDF()` — tidak perlu koneksi jaringan/backend.
- Jika hasil uji menunjukkan share sheet masih belum muncul setelah perbaikan v3.86, periksa kembali resolusi `rootViewController` di `shareReceiptPDF()` baris 708–715 (`PenjualanListView.swift`).
