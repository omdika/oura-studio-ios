# Oura Studios Project Context

Ini adalah ringkasan komprehensif dari proyek Oura Studios, yang mencakup gambaran umum, konsep inti, arsitektur, kontrak API, aturan bisnis, dan riwayat perubahan penting, yang disintesis dari semua dokumen `handoff.md` dan `SKILL.md` yang tersedia.

## 1. Gambaran Umum Proyek

*   **Nama Proyek:** Oura Studios
*   **Tujuan:** Aplikasi inventaris/produksi kustom untuk bisnis aksesori buatan tangan.
*   **Masalah Inti:** Perhitungan HPP (Harga Pokok Produksi) yang akurat untuk kain mentah yang dipotong menjadi berbagai ukuran produk dengan jenis kain yang berbeda, ditambah pelacakan penjualan, stok, dan margin.
*   **Model Sinkronisasi:** Multi-perangkat (membutuhkan backend nyata).
*   **Pengguna:** Aplikasi satu pemilik (single-tenant), bukan SaaS multi-tenant.

### 1.1 Tumpukan Teknologi

*   **Frontend:** Native iOS — Swift + SwiftUI, proyek Xcode standar.
*   **Backend:** Python + FastAPI. Menggunakan SQLAlchemy (ORM) dan Alembic (migrasi). Pydantic untuk skema request/response.
*   **Database:** PostgreSQL (Supabase-managed BaaS).
*   **Autentikasi:** Google Sign-In (OAuth 2.0) di klien iOS, JWT bearer token di setiap endpoint backend. Backend mengonfigurasi email pemilik yang diotorisasi (`AUTHORIZED_OWNER_EMAIL`).

## 2. Konsep Inti

### 2.1 Entitas dan Hubungannya

`Material` (kain, benang, hardware)
   └─ dibeli sebagai `MaterialPurchase` (batch, memiliki biaya, lebar, panjang)
        └─ dikonsumsi melalui `PatternSpec` (resep: berapa banyak material yang dibutuhkan SKU+ukuran+jenis-material)
             └─ direalisasikan dalam `CuttingLayout` (output optimizer: bagaimana pembelian tertentu dipotong)
                  └─ menjadi `ProductionBatch` (unit aktual yang diproduksi, HPP aktual)
                       └─ ditambahkan ke `StockLedger` (stok barang jadi)
                            └─ dijual melalui `SalesOrder` (mengurangi stok, mencatat margin)

### 2.2 Mengapa HPP Bukan Angka Tetap per SKU

*   **Konsumsi Kain:** Bergantung pada (SKU, ukuran, jenis kain) karena perilaku peregangan yang berbeda. `PatternSpec` dikunci oleh ketiganya.
*   **Biaya Kain per Potongan:** Bergantung pada bagaimana tata letak pemotongan bersarang pada lebar gulungan/potongan kain tertentu. HPP untuk kain dihitung **per batch pembelian + per tata letak**.

### 2.3 Klasifikasi Biaya

| Kelas | Contoh | Metode Pelacakan |
|---|---|---|
| `direct_precise` | Kain, hardware (klip, ring) | Dilacak per unit melalui PatternSpec + CuttingLayout |
| `direct_pooled` | Benang, jarum, lem | TIDAK dilacak per warna/unit. Biaya gabungan ÷ perkiraan hasil = tarif tetap per unit jadi |
| `labor` | Waktu pembuat | Tarif/menit × perkiraan menit per ukuran (dari PatternSpec) |
| `overhead` | Pengemasan, listrik, biaya platform | Tarif tetap per unit atau % dari harga |

### 2.4 Formula HPP per Unit

`HPP(sku, size) = fabric_cost_per_piece(dari CuttingLayout batch yang digunakan) + pooled_material_rate + hardware_cost + labor_minutes(sku,size) × labor_rate_per_minute + overhead_per_unit`

### 2.5 Optimizer Pemotongan (Masalah Penataan)

*   **Tujuan:** Untuk `MaterialPurchase` tertentu, hitung satu atau lebih `CuttingLayout` kandidat ({ukuran, qty, orientasi}) dan persentase limbah serta biaya per potong yang dihasilkan.
*   **Pendekatan:** Heuristik `shelf-packing` dua fase.
    *   **Fase 1:** Hitung `bestMinLen` per kandidat (minimum panjang kain yang dibutuhkan untuk menjamin `min_qty` lantai kandidat).
    *   **Fase 2:** Untuk setiap kandidat, cadangkan `futureMinLength` (jumlah `bestMinLen` dari kandidat yang tersisa) sebelum menghitung ruang yang tersedia.
*   **Output:** Saran, bukan hasil akhir. Pengguna mengonfirmasi/mengedit setelah pemotongan fisik.
*   **Aturan Filter Kandidat (v1.3):** `pattern_spec.fabric_material_id` kandidat harus cocok dengan `material_id` pembelian yang diajukan.

### 2.6 Formula Harga (Fitur "Price Advisor")

`selling_price = HPP ÷ (1 − target_margin − marketplace_fee_pct − promo_allocation_pct)`

*   **Margin:** `(harga - HPP) / harga`
*   **Markup:** `(harga - HPP) / HPP`

## 3. Skema Database (Ringkasan Kritis)

*   **`owner_account` (v1.1):** `id`, `google_sub` (UNIQUE), `email` (UNIQUE), `created_at`. Tidak ada `password_hash`.
*   **`material`:** `id`, `name`, `category`, `cost_class`, `purchase_unit`, `usage_unit`, `fabric_width_cm` (NUMERIC, nullable), `fabric_family` (VARCHAR(100), nullable, v3.15), `current_avg_cost`, `reorder_min_qty`, `is_archived` (BOOLEAN, v3.21 planned).
*   **`material_purchase`:** `id`, `material_id` (FK), `width_cm` (NUMERIC, fabric only), `length_cm` (NUMERIC, fabric/hardware v2.5), `qty` (NUMERIC, thread/hardware), `package_label`, `total_cost`, `supplier_id` (FK), `purchased_at`, `remaining_length_cm` (NUMERIC), `remaining_qty` (NUMERIC, v2.5).
*   **`product`:** `id`, `sku` (UNIQUE), `name`, `is_archived` (BOOLEAN).
*   **`product_size` (v1.7):** `id`, `product_id` (FK), `size_label`, `fabric_variant_name` (TEXT, nullable, UNIQUE bersama `product_id`, `size_label`), `reorder_min_qty`, `selling_price` (NUMERIC, v2.8), `is_archived` (BOOLEAN).
    *   **v3.19:** `manual_hpp_fabric`, `manual_hpp_pooled`, `manual_hpp_hardware`, `manual_hpp_labor`, `manual_hpp_overhead` (NUMERIC(14,4), nullable).
*   **`pattern_spec` (v2.15):** `id`, `product_size_id` (FK), `est_labor_minutes`, `is_active`, `effective_from`, `effective_to`. Tidak ada lagi `fabric_material_id`, `cut_width_cm`, `cut_height_cm`, `rotation_allowed` (dipindahkan ke `pattern_spec_fabric`).
*   **`pattern_spec_fabric` (v2.15):** `id`, `pattern_spec_id` (FK), `material_id` (FK), `cut_width_cm`, `cut_height_cm`, `rotation_allowed`, `fabric_label`, `sort_order`.
*   **`pattern_component`:** `id`, `pattern_spec_id` (FK), `material_id` (FK), `qty_per_unit`.
*   **`cutting_layout`:** `id`, `material_purchase_id` (FK), `status` (`suggested`|`used`|`discarded`), `waste_pct`, `total_fabric_cost`, `strategy` (TEXT, v2.16).
*   **`cutting_layout_item`:** `id`, `cutting_layout_id` (FK), `product_size_id` (FK), `pattern_spec_id` (FK), `orientation`, `qty_suggested`, `fabric_length_used_cm`, `cost_per_piece`.
*   **`production_batch` (v2.16):** `id`, `produced_at`, `status` (`draft`|`confirmed`), `notes`, `confirmed_at` (TIMESTAMPTZ, nullable, v2.12), `cutting_layout_strategy` (TEXT), `material_name` (TEXT). Tidak ada lagi `cutting_layout_id` (dipindahkan ke `production_batch_layout`).
*   **`production_batch_layout` (v2.16):** `id`, `production_batch_id` (FK), `cutting_layout_id` (FK), `sort_order`.
*   **`production_batch_item` (v2.16):** `id`, `production_batch_id` (FK), `product_size_id` (FK), `pattern_spec_id` (FK), `qty_actual`, `qty_suggested` (INTEGER, nullable), `cutting_layout_item_id` (FK, nullable), `material_purchase_id` (FK, nullable), `fabric_cost_per_piece`, `fabric_length_per_unit_cm` (NUMERIC, nullable), `hpp_fabric`, `hpp_pooled_material`, `hpp_hardware`, `hpp_labor`, `hpp_overhead`, `hpp_total`.
*   **`stock_ledger` (append-only):** `id`, `product_size_id` (FK), `change_qty`, `reason`, `ref_type`, `ref_id`, `unit_hpp_snapshot`, `note` (TEXT, nullable, v2.12).
*   **`material_usage_log` (v3.19):** `id`, `material_id` (FK), `material_purchase_id` (FK, nullable), `product_size_id` (FK, nullable), `deducted_cm`, `description`, `source`, `created_at`.
*   **`sales_order`:** `id`, `invoice_no` (UNIQUE), `customer_name`, `payment_method`, `marketplace_fee_pct`, `status` (`unpaid`|`paid`|`cancelled`), `sold_at`.
*   **`sales_order_item` (v3.18):** `id`, `sales_order_id` (FK), `product_size_id` (FK), `qty`, `unit_price`, `discount`, `unit_hpp_snapshot`, `line_profit`, `hpp_source` (VARCHAR(20)).
*   **`settings`:** `key` (PK), `value`, `updated_at`.

## 4. Ringkasan Kontrak API

*   **Base Path:** `/api/v1`.
*   **Autentikasi:** `Authorization: Bearer <token>` diperlukan di semua endpoint kecuali `/auth/google`. Token yang hilang/tidak valid/kedaluwarsa mengembalikan 401.
*   **Pola Umum:**
    *   `POST /auth/google`: Google ID token -> app JWT.
    *   `materials`: CRUD untuk material dan pembelian, termasuk `current_avg_cost` yang dihitung ulang. Validasi konsumsi pembelian.
    *   `suppliers`: CRUD untuk supplier.
    *   `pattern-specs`: CRUD untuk resep. Versi bersyarat (pembaruan di tempat vs. versi baru).
    *   `cutting-optimizer`: Menyarankan dan membuat tata letak pemotongan.
    *   `production-batches`: Membuat, memperbarui item, mengonfirmasi, dan menghapus batch produksi.
    *   `products`: CRUD untuk produk dan ukuran produk. Termasuk `price-advisor` dan `stock-from-bahan`.
    *   `stock`: Penyesuaian stok. `StockLedger` hanya `append-only`.
    *   `sales-orders`: Membuat, memperbarui status, dan membatalkan pesanan penjualan.
    *   `reports`: Berbagai laporan (dashboard, penjualan, ranking margin, kartu stok, limbah).
    *   `settings`: Mengelola pengaturan aplikasi.

## 5. Aturan Bisnis Kritis (Non-negosiabel)

1.  **Biaya Rata-rata Tertimbang Dihitung Ulang Secara Otomatis:** Setiap perubahan `MaterialPurchase` yang memengaruhi biaya/kuantitas/dimensi harus memicu perhitungan ulang `material.current_avg_cost`.
2.  **Konsumsi Mengunci Editabilitas:** `MaterialPurchase` hanya dapat diedit/dihapus jika tidak digunakan. Setelah sebagian dikonsumsi, bidang dimensi terkunci dan penghapusan diblokir (409).
3.  **Versi PatternSpec Bersyarat:** `POST /pattern-specs` memperbarui di tempat jika tidak ada `ProductionBatchItem` yang menggunakannya; jika ada, itu menonaktifkan yang lama dan menyisipkan versi baru.
4.  **StockLedger Hanya Tambah:** Tidak ada PATCH atau DELETE untuk baris `stock_ledger`. Koreksi dilakukan dengan menulis baris penyeimbang baru.
5.  **Arsip vs. Hapus Permanen Berdasarkan Riwayat:** Untuk `Material`, `Product`, dan `ProductSize`, hapus permanen hanya jika tidak ada referensi historis; jika ada, atur `is_archived = true`.
6.  **Batch Produksi Terkunci Permanen Setelah Konfirmasi:** Setelah `production_batch.status = 'confirmed'`, semua bidang HPP `production_batch_item` tidak dapat diubah.
7.  **Koreksi Penjualan Melalui Pembatalan + Restok:** `POST /sales-orders/{id}/cancel` menulis baris `stock_ledger` penyeimbang dan menandai pesanan dibatalkan; tidak ada endpoint untuk mengedit `sales_order_item` setelah dibuat.
8.  **`GET /reports/sales` Harus Menghormati Parameter `from`/`to`:** Parameter tanggal wajib dan harus memfilter data.
9.  **Koneksi Supabase Menggunakan Kunci Peran Layanan:** Untuk akses server-side, gunakan `SUPABASE_SERVICE_ROLE_KEY` untuk melewati RLS.
10. **`product_size` Constraint Keunikan (v1.7):** `UNIQUE(product_id, size_label, fabric_variant_name)`. `NULL` adalah nilai yang berbeda.
11. **Parameter Jalur Ukuran (v1.7):** Gunakan `sizeId: UUID` sebagai parameter jalur, bukan `sizeLabel: string`.
12. **Satu Spesifikasi per Kain (v1.7):** Setiap `PatternSpec` memiliki tepat satu `fabric_material_id`. Frontend membuat satu `PatternSpec` per kain yang dipilih, ditautkan ke `ProductSize` yang sesuai.
13. **Aturan Filter Kandidat Optimizer (v1.3):** `pattern_spec.fabric_material_id` kandidat harus cocok dengan `material_purchase` yang diajukan.
14. **Algoritma Optimizer Pemotongan (v1.5):** Heuristik `shelf-packing` dua fase.

## 6. Status Saat Ini & Perubahan Penting (Ringkasan Riwayat Versi)

### Backend

*   **v1.3 (2026-07-31):** Spesifikasi awal lengkap. Autentikasi diubah ke Google SSO. Filter kandidat optimizer diperbaiki.
*   **v2.3 (2026-08-05):** Backend beralih ke Supabase.
*   **v2.4 (2026-08-07):** Klarifikasi kontrak API (misalnya, `POST /pattern-specs` mengharapkan bidang datar, bukan array `fabrics[]`).
*   **v2.5 (2026-08-07):** `length_cm` opsional untuk pembelian hardware.
*   **v2.6 (2026-08-08):** `GET /reports/dashboard` menambahkan `today_units_sold`. `PATCH /production-batches/{id}/items/{item_id}` mengembalikan item yang diperbarui.
*   **v2.7 (2026-08-08):** Optimizer pemotongan: orientasi utama dan skala `waste_pct` diperbaiki.
*   **v2.8 (2026-08-08):** `latest_hpp_breakdown` di daftar ukuran, perbaikan bug `stale-draft`.
*   **v2.9 (2026-08-08):** Klarifikasi spesifikasi bidang daftar ukuran (membutuhkan `production_stock_qty`, `manual_stock_qty`, `latest_hpp_breakdown`, `selling_price`, `margin_pct`).
*   **v2.10 (2026-08-08):** Implementasi penuh spesifikasi v2.9.
*   **v2.11 (2026-08-09):** **OUTSTANDING:** Dashboard 5 bidang tingkat bulan, bidang pengayaan item SalesOrder.
*   **v2.12 (2026-08-09):** `production_batch` menambahkan kolom `confirmed_at`. `stock_ledger` menambahkan kolom `note`.
*   **v2.13 (2026-08-10):** Verifikasi konfirmasi HPP, perbaikan filter `hpp_hardware`, perbaikan pengurutan `confirmed_at`.
*   **v2.14 (2026-08-10):** **PLANNED:** `POST + DELETE /production-batches/{id}/items` untuk manajemen item batch manual.
*   **v2.15 (2026-08-12):** `pattern_spec_fabric` tabel gabungan multi-kain. `pattern_spec` tidak lagi memiliki bidang kain datar.
*   **v2.16 (2026-08-13):** `production_batch_layout` tabel gabungan multi-tata letak. `production_batch` tidak lagi memiliki `cutting_layout_id`. `cutting_layout` menambahkan `strategy`. `production_batch_item` `qty_suggested`, `material_purchase_id`, `fabric_length_per_unit_cm` menjadi nullable.
*   **v3.15 (2026-08-18):** `material` menambahkan `fabric_family`. Endpoint `GET /materials/families` baru.
*   **v3.17 (2026-08-19):** Endpoint baru `GET /product-sizes/{size_id}` untuk pencarian QR.
*   **v3.18 (2026-08-20):** **DIBUTUHKAN:** `POST /sales-orders` harus memiliki fallback HPP (batch -> manual -> pattern_spec -> none). `sales_order_item` menambahkan `hpp_source`.
*   **v3.19 (2026-08-21):** `product_size` menambahkan bidang `manual_hpp_*`. `material_usage_log` tabel baru. `POST /products/{sku}/sizes/{size_id}/stock-from-bahan` diperbarui untuk menggunakan `MaterialUsageLog` dan mengurangi komponen.
*   **v3.20 (2026-08-20):** Perbaikan bug backend: `GET /reports/margin-ranking` dan `avg_margin_pct` di dashboard sekarang menggunakan fallback HPP 4-tier.
*   **v3.21 (PLANNED):** Arsip Bahan (Material Archive). Backend memerlukan penambahan `is_archived` ke `PatchMaterialRequest` dan filter `GET /materials`.

### iOS Frontend

*   **v1.3 (2026-07-31):** Implementasi frontend lengkap (11 layar). Perbaikan bug optimizer, persistensi `MockAPIService`.
*   **v2.3 (2026-08-05):** Perbaikan tata letak lembar picker (iOS 26 Liquid Glass), penghapusan toolbar "Done" keyboard, tampilan daftar `InlineSearchDropdownField` segera, komponen `DateRangeField` baru, pemfilteran tanggal laporan penjualan `MockAPIService`.
*   **v2.4 (2026-08-07):** Perbaikan format API (misalnya, `GET /pattern-specs` datar, `GET /products/{sku}/sizes` datar tanpa rincian stok). `PATCH /products/{sku}` untuk arsip lunak.
*   **v2.5 (2026-08-07):** Pembelian hardware: bidang `length_cm` opsional.
*   **v2.6 (2026-08-08):** `GET /reports/dashboard` menambahkan `today_units_sold`. `PATCH /production-batches/{id}/items/{item_id}` mengembalikan item.
*   **v2.7 (2026-08-08):** `GET /products/{sku}/sizes` harus menyertakan semua bidang pengayaan (termasuk `latest_hpp_breakdown`).
*   **v2.8 (2026-08-09):** Validasi stok di `TambahPenjualanSheet` + penyesuaian stok cepat.
*   **v2.9 (2026-08-09):** `DashboardSummary`: bidang tingkat bulan opsional.
*   **v3.0 (2026-08-09):** Sisa Kain: tampilan sisa per pembelian + total sisa di header.
*   **v3.1 (2026-08-10):** Tambah Produk Lengkap: Produk + Resep dalam satu alur.
*   **v3.2 (2026-08-10):** **PLANNED:** Tambah Item ke Batch Produksi Manual (`POST /production-batches/{id}/items`, `DELETE /production-batches/{id}/items/{item_id}`).
*   **v3.12 (2026-08-17):** Rincian HPP + Price Advisor inline di Tab Produksi.
*   **v3.14 (2026-08-18):** Tab Resep Multi-Ukuran + Pemilih Tipe Produk.
*   **v3.15 (2026-08-18):** **PLANNED:** `fabric_family` di Material.
*   **v3.16 (2026-08-19):** Varian Kain di `TambahResepSheet`.
*   **v3.17 (2026-08-19):** **PLANNED:** QR Code: Generate, Print, Scan Produk & Penjualan.
*   **v3.18 (2026-08-20):** Mode Keranjang QR + Fallback HPP untuk Stok Manual.
*   **v3.19 (2026-08-20):** Override Manual HPP + ScanToStock yang Ditingkatkan.
*   **v3.20 (2026-08-20):** Perbaikan bug sesi: Unit HPP, Generator QR, Laporan, Kondisi Balapan UI.
*   **v3.21 (PLANNED):** Arsip Bahan (Material Archive).

## 7. Rencana Skalabilitas (Database & Deployment)

*   **Status Saat Ini:** FastAPI tunggal di Cloud Run (1 vCPU/512Mi, `containerConcurrency: 80`, `maxScale: 20`, `minScale: 0`). DB Supabase Postgres (pool `pool_size=5`, `max_overflow=10`).
*   **Bottleneck:**
    1.  Kelebihan koneksi DB di bawah konkurensi.
    2.  Cold start (karena `minScale: 0`).
    3.  Tidak ada caching untuk endpoint laporan yang banyak membaca.
    4.  Satu titik kegagalan DB (tidak ada replika baca).
*   **Rencana Skala:**
    *   **Sekarang:** Batasi koneksi DB per kontainer secara eksplisit (misalnya, `pool_size=3`, `max_overflow=2`). Atur `minScale: 1` di Cloud Run. Konfirmasi `SUPABASE_DB_URL` menggunakan pooler. Tambahkan indeks DB sesuai pola kueri.
    *   **Berikutnya:** Replika baca untuk laporan. Cache hasil laporan/HPP yang dihitung. Sesuaikan konkurensi Cloud Run. Pemantauan terstruktur.
    *   **Nanti:** Hanya jika model bisnis berubah secara signifikan (multi-tenant, memisahkan layanan, multi-wilayah).
*   **Non-tujuan:** Kubernetes, antrean pesan, dekomposisi layanan mikro, lapisan caching khusus tanpa beban terukur.

## 8. Strategi Pencadangan

*   **Mekanisme:** Cloud Run Job + Cloud Scheduler. `pg_dump` database Supabase dan mengunggahnya ke bucket GCS.
*   **Retensi:** Aturan siklus hidup bucket GCS (penghapusan otomatis berbasis usia, misalnya 30 hari).
*   **Alat:** `scripts/backup_supabase.py`, `Dockerfile.backup`, `requirements-backup.txt`.
*   **Konfigurasi:** `SUPABASE_DB_URL` disimpan di Secret Manager.

## 9. Kekhususan Frontend (iOS)

*   **Aturan Struktural Non-negosiabel:**
    1.  Hubungan hierarkis menggunakan navigasi push, hubungan tindakan menggunakan modal/sheet.
    2.  Bangun komponen bersama sekali, gunakan kembali di mana-mana (input numerik/mata uang, pemilih tanggal, dropdown yang dapat dicari, multi-pilih bertoken, pilih tunggal chip/pil).
    3.  Pengungkapan progresif di lembar pembuatan (semua bagian terlihat, bagian selanjutnya dinonaktifkan hingga bagian sebelumnya selesai).
    4.  Hormati tabel audit CRUD (Bagian 5 handoff).
    5.  Navigasi bawah tetap: Beranda · Produksi · Produk · Penjualan · Lainnya.
    6.  Setiap tombol tindakan harus memiliki properti terhitung `canSave: Bool` yang terhubung ke `.disabled(!canSave)` dan umpan balik visual.
*   **Alur Kerja:** Baca handoff, gunakan kembali komponen, terapkan status layar (kosong, memuat, terisi, error), hubungkan panggilan API nyata.

## 10. Strategi Pengujian

*   **`test-smoke`:** Cepat lulus/gagal. Membangun, meluncurkan, setiap layar dapat dijangkau tanpa crash.
*   **`test-sanity`:** Verifikasi tingkat kebenaran yang terfokus untuk fitur yang baru dibangun/diubah, termasuk logika bisnis dan nilai yang dihitung. Menggunakan contoh yang dikerjakan dari handoff.
*   **`test-regression`:** Pemeriksaan komprehensif di setiap fitur yang sebelumnya diverifikasi untuk menangkap apa pun yang rusak secara diam-diam oleh perubahan terbaru.
*   **`test-write`:** Menulis dokumen kasus uji baru dan/atau skrip otomatisasi XCUITest.

---
