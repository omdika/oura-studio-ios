# Oura Studio — iOS Frontend Application

Oura Studio is a custom, high-performance, native iOS inventory and production management application designed specifically for a self-production handmade accessories business (scrunchies, headbands, etc.). 

The core mission of this application is to solve the complex problem of **accurate HPP (COGS) calculation** when raw fabric roll material is nested and cut into multiple finished goods with different size dimensions, alongside managing stock ledger tracking, pricing optimization, and sales recording.

---

## 📸 Tangkapan Layar (Screenshots)



| Preview | Layar & Keterangan |
|---|---|
| <img width="1920"  alt="image" src="https://github.com/user-attachments/assets/f34ef79b-3cae-48b9-b738-38f9287a0968" /> | **01 — Beranda (Dashboard)** — Layar utama yang menyapa pengguna (`Selamat pagi, Aswarhan`). Kartu `Pendapatan Hari Ini Rp591.001` dengan ringkasan `26 transaksi · 44 item terjual · 99% margin`. Di bawahnya ada `Aksi Cepat` (Beli Bahan, Catat Produksi, Optimasi Pola, Laporan Laba), `Peringatan Stok` (contoh: scrunchie muslin salu... Habis) dan `Kasir Penjualan Kilat` (Catat Penjualan / Scan & Jual). Navigasi bawah: Beranda · Produksi · Produk · Penjualan · Lainnya. |
| <img width="768" height="1580" alt="image" src="https://github.com/user-attachments/assets/8e39ac36-2ba8-4513-be35-af6febced91e" /> | **02 — Catat Penjualan (POS Sheet)** — Sheet `Catat Penjualan` untuk transaksi kilat. Bagian `Info Penjualan`: nama pelanggan opsional, metode `Pembayaran: Cash`, toggle `Sudah Lunas` (aktif) & `Cetak Struk Otomatis`. Bagian `Produk Dijual`: contoh `Scrunchie Bludru Hitam · L` (Tersedia: 1 pcs) dengan kontrol `Qty`, `Harga Satuan Rp18.000`, `Diskon Rp0`, tombol `Tambah Produk` + ikon QR untuk Scan. `Ringkasan` menampilkan `Total Pendapatan Rp18.000`. Tombol `Batal` / `Simpan` di header. |
| <img width="774" height="1560" alt="image" src="https://github.com/user-attachments/assets/45157fde-c935-4a64-bd1e-50e09fd55cba" /> | **03 — Produksi › Bahan** — Tab `Produksi` dengan 4 sub-tab: `Bahan` (aktif), Resep, Optimasi, Produksi. Fitur pencarian `Cari bahan...`, filter kategori (`Semua/Kain/Benang/Hardware/Packaging`) dan filter famili kain (`Semua Jenis, Katun Generic, Satin Yamaha...`). Daftar kain menampilkan biaya rata-rata tertimbang per meter, mis. `Dakron 5mm · Rp7.000/m`, `Katun Printing Bunga MErah · Rp8.000/m`. FAB `+` untuk tambah bahan baru. |
| <img width="341" height="706" alt="image" src="https://github.com/user-attachments/assets/e316175c-e8ed-41d7-a606-035dc5cd99fd" /> | **04 — Produk (Katalog Barang Jadi)** — Header `Produk` dengan pencarian & aksi QR/Share. Kartu statistik: `Total Produk 67`, `Total Varian 240 var`, `Total Stok 247 pcs`, `Stok Kosong 107 var`, `Nilai Modal Rp4.499.956` & `Potensi Omset Rp4.495.081` (*132 varian pakai harga jual sbg modal). Toggle `Filter berdasarkan Tanggal Masuk Stok`. Listing produk mis. `pouch kotak zipper nylon` (SKU POUKOTZIPNYL) dengan varian `M Rp45.001 · 1 pcs` dan `L Rp55.000 · 4`. |
| <img width="345" height="714" alt="image" src="https://github.com/user-attachments/assets/d8d2416a-fe91-4f3a-99fe-ea4fad3242fc" /> | **05 — Generator QR** — Sheet `Generator QR` untuk cetak label. Ada pencarian `Cari produk atau ukuran...` dan toggle `Filter berdasarkan Tanggal Masuk Stok`. Opsi `Pilih Semua` & `Pilih semua ukuran`. Tiap varian menampilkan QR code, ukuran (`M/L`) dan stok (`Stok: 1 pcs`), contoh grup `pouch kotak zipper nylon` (M 1 pcs, L 6 pcs) dan `pouch kotak zipper slvr` (M 3 pcs, L 3 pcs). QR ini dipakai untuk `Scan & Jual` / `Scan to Stock`. |
| <img width="342" height="715" alt="image" src="https://github.com/user-attachments/assets/b44c22e0-8b6d-4dd0-9b16-070bbeaa491b" /> | **06 — Ekspor Massal Shopee** — Sheet `Ekspor Shopee` untuk marketplace. Deskripsi: menghasilkan file Excel template Shopee berisi detail produk Scrunchie & Pouch siap unggah. Ringkasan `Produk Siap Ekspor`: `Scrunchie Kategori ID: 100146 (1 Produk)` dan `Pouch Kategori ID: 101650 (1 Produk)`. Tombol utama `Unduh Template Shopee` di bawah. Fitur ini mempercepat listing massal tanpa input manual di Seller Centre. |
| <img width="336" height="712" alt="image" src="https://github.com/user-attachments/assets/f254ad9f-acda-4db4-85e4-aa8319c93859" /> | **07 — Penjualan (Riwayat Transaksi)** — Layar `Penjualan` dengan filter `DateRangeField` (`20 Sep – 20 Sep 2026`) dan 3 kartu ringkasan: `Pendapatan Rp591.001`, `Terjual 44 pcs`, `Transaksi 26 trx`. Daftar invoice harian mis. `INV-000112 Lunas Rp28.000 (Cash · 2 item · 09:10)` yang bisa di-expand untuk melihat rincian item (`Scrunchie Satin Yamaha Hitam · M 1 pcs × Rp15.000 - Rp2.000`). FAB `+` untuk catat penjualan baru & ikon QR di kanan atas. |
| <img width="348" height="715" alt="image" src="https://github.com/user-attachments/assets/257238fe-52aa-4856-8ad4-5c10e159825b" /> | **08 — Lainnya › Laporan & Pengaturan** — Tab `Lainnya` dengan segmented control `Laporan` (aktif) / `Pengaturan`. Menu `Laporan Tersedia`: `Laporan Penjualan` (Pendapatan & profit per periode), `Ranking Penjualan Produk` (varian paling laris), `Ranking Margin Produk` (margin tertinggi), `Analisis Waste Kain` (persentase sisa kain per bahan). Layar ini jadi pusat analitik bisnis. |
| <img width="347" height="711" alt="image" src="https://github.com/user-attachments/assets/d324c387-660d-4c24-b8ab-e7d602c7544e" /> | **09 — Laporan Penjualan (Detail)** — Detail `Laporan Penjualan` dengan `Rentang Waktu 21 Agu – 20 Sep 2026`. `Ringkasan`: `Total Pendapatan Rp2.383.826`, `Total Profit Rp2.319.536`, `Transaksi 110`, `Pcs Terjual 166 pcs`. Tombol `Export JSON untuk AI` untuk analisis lanjutan. Tabel `Per Periode` merinci pendapatan harian, mis. `2026-08-23 Rp617.000 (26 transaksi)`, `2026-08-30 Rp495.000 (23 transaksi)`. |


---

## 📱 Fitur Utama (Core Features)

1.  **Beranda (Dashboard):**
    *   Widget ringkasan metrik performa bisnis harian (Pendapatan, Jumlah Order, Profit Bersih, Persentase Margin).
    *   Daftar transaksi hari ini.
    *   Sistem notifikasi/alert otomatis untuk barang dengan stok menipis (*low-stock warning*).
2.  **Produksi (Production Hub):**
    *   **Bahan (Materials):** Pelacakan panjang sisa roll kain dalam centimeter (`remaining_length_cm`) dan biaya rata-rata tertimbang (*weighted-average cost*). Manajemen status bahan aktif/arsip.
    *   **Resep (Pattern Specs):** Spesifikasi tata letak potongan kain, kebutuhan hardware, dan komponen tenaga kerja per ukuran produk.
    *   **Optimasi Potong (Cutting Optimizer):** Algoritma rekomendasi tata letak potong (*two-phase shelf-packing heuristic*) untuk mencari strategi sisa kain (*waste*) minimal dan profit maksimal.
    *   **Batch Produksi (Production Batch):** Mengunci dan membekukan biaya produksi (*cost-lock*) setelah konfirmasi batch potong fisik untuk dimasukkan ke stok jadi.
3.  **Produk (Finished Goods Catalog):**
    *   Struktur navigasi 3-level (Produk -> Ukuran/Warna -> Detail Varian).
    *   Ringkasan statistik atas (Total Jenis Produk, Total Kuantitas Stok, Jumlah Varian Kosong).
    *   **Price Advisor:** Alat simulasi harga jual ideal berdasarkan persentase target margin, marketplace fee, dan promo biaya.
    *   Mendukung pengisian HPP Manual (*HPP Manual Override*) jika produk ditambahkan di luar alur optimasi potong biasa.
4.  **Penjualan (Point of Sale):**
    *   Pencatatan transaksi kasir kilat dengan validasi ketersediaan stok produk secara real-time.
    *   Filter rentang tanggal penjualan menggunakan komponen dinamis `DateRangeField`.
    *   Lembar penyesuaian stok kilat (*quick stock adjustment*) langsung dari layar POS.
5.  **Sistem Kode QR (QR Code Integration):**
    *   **QR Generator:** Membuat dan mencetak lembar PDF A4 berisi barcode QR untuk puluhan varian produk terpilih sekaligus.
    *   **QR Scanner:** Pemindai barcode kilat universal (VisionKit) untuk checkout kasir (*Scan to Sell* / *QR Cart Mode*) maupun restock gudang (*Scan to Stock*).

---

## 🛠 Spesifikasi Teknologi & Arsitektur

*   **Platform:** iOS 16.0+ (SwiftUI, Swift Concurrency `async/await`)
*   **Keamanan Token:** Autentikasi Google SSO disimpan aman secara lokal via **iOS Keychain Manager**.
*   **Networking:** `APIService.swift` (berkomunikasi dengan REST API backend, mendukung mode local mock via `MockAPIService.swift`).
*   **UI/UX Standard:** Menggunakan panduan desain kustom `OuraTheme.swift` yang elegan, konsisten, responsif, dan ramah terhadap mode gelap (*Dark Mode*).

---

## 💻 Panduan Menjalankan Aplikasi

1.  Buka folder `oura studio frontend.xcodeproj` di **Xcode** (rekomendasi Xcode 15+).
2.  Pastikan konfigurasi `APIService.swift` mengarah ke alamat server backend yang aktif:
    ```swift
    var baseURL: String = "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1"
    ```
3.  Pilih simulator iOS (misalnya iPhone 15) atau hubungkan perangkat iPhone fisik Anda.
4.  Tekan tombol **Run** (`⌘ + R`) untuk mengompilasi dan memulai aplikasi.

---

## 📁 Struktur Folder Proyek

```text
oura studio frontend/
├── Components/                 # Komponen UI bersama (DateRangeField, Input, dll)
├── Core/                       # AppState, Keychain, OuraTheme (Konfigurasi Utama)
├── Networking/                 # Handler API Client & Pydantic-mapped Models
├── Screens/                    # Layar UI per fitur (Auth, Beranda, Produksi, Produk, dll)
└── doc/                        # Dokumentasi handoff, spesifikasi revisi, & riwayat versi
```
