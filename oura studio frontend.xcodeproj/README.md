# Oura Studio — iOS Frontend Application

Oura Studio is a custom, high-performance, native iOS inventory and production management application designed specifically for a self-production handmade accessories business (scrunchies, headbands, etc.). 

The core mission of this application is to solve the complex problem of **accurate HPP (COGS) calculation** when raw fabric roll material is nested and cut into multiple finished goods with different size dimensions, alongside managing stock ledger tracking, pricing optimization, and sales recording.

---

## 📱 Fitur Utama (Core Features)

1.  **Beranda (Dashboard):**
    *   Widget ringkasan metrik performa bisnis harian (Pendapatan, Jumlah Order, Profit Bersih, Persentase Margin).
    *   Daftar transaksi hari ini.
    *   Sistem notifikasi/alert otomatis untuk barang dengan stok menipis (*low-stock warning*).
2.  **Produksi (Production Hub):**
    *   **Bahan (Materials):** Pelacakan panjang sisa roll kain dalam centimeter (`remaining_length_cm`) dan biaya rata-rata tertimbang (*weighted-average cost*). Manajemen status bahan aktif/arsip.
    *   **Resep (Pattern Specs):** Spesifikasi tata letak potongan kain, kebutuhan hardware, dan komponen tenaga kerja per ukuran produk.
    *   **Optimasi Potong (Cutting Optimizer):** Algoritma rekomendasi tata letak potong (*two-phase shelf-packing heuristic*) untuk mencari strategi minimum sisa kain (*waste*) dan profit maksimal.
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
