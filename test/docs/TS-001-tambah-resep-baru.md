# Automation Test Strategy: Full Main Flow API Integration

| Field | Value |
|---|---|
| **Strategy ID** | TS-001 |
| **Implemented Script (API)** | [TS001_TambahResepBaruAPITests.swift](../scripts/TS001_TambahResepBaruAPITests.swift) |
| **Implemented Script (UI)** | [TS001_TambahResepBaruUITests.swift](../scripts/TS001_TambahResepBaruUITests.swift) |
| **Module Under Test** | Full Core Business Lifecycle (Bahan -> Resep -> Optimasi -> Produksi -> Penjualan) |
| **Data Strategy** | Real Data API (E2E Integration with Live State Injection & Reverse Teardown) |
| **Target Frameworks** | API Integration: Swift Testing / XCTest <br> UI Automation: SwiftUI + XCUITest |
| **Date Compiled** | 2026-08-31 |

---

## 1. Architectural Overview & Preconditions

Alur pengujian ini memvalidasi seluruh siklus bisnis inti Oura Studio mulai dari pengadaan bahan baku hingga pencatatan transaksi penjualan produk jadi. Pengujian diimplementasikan menggunakan pemanggilan HTTP asinkron langsung ke lingkungan Backend Real API.

### Target Environment & Base URL:
- **Backend Base URL:** `https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1`
- **Authentication:** Pengujian menggunakan Header Autentikasi `Authorization: Bearer <test_token>` dengan token JWT yang valid untuk akun administrator pengetesan.

### Preconditions & Setup:
Sebelum mengaktifkan flow pengujian terintegrasi ini, pastikan prasyarat sistem berikut terpenuhi:
1. **Material Base:** Minimal ada 1 entitas kain master (misalnya "Satin Putih") dan 1 entitas hardware master (misalnya "Karet Elastis 3mm") yang sudah terdaftar di database (tanpa purchase/riwayat transaksi aktif agar kalkulasi cost-basis bersih).
2. **Product Base:** Terdapat entitas master produk (misalnya "Scrunchie Premium") yang sudah siap diasosiasikan dengan resep baru.
3. **Supplier Base:** Opsional, karena supplier baru ("Supplier Indotex E2E") akan dibuat secara dinamis (inline) pada langkah pengadaan bahan pertama.

---

## 2. API Integration Test Suite (The Complete Core Flow)

Seluruh skenario pengujian di bawah ini berjalan secara berurutan (*sequential execution*) karena output dari satu langkah menjadi input wajib bagi langkah berikutnya.

```
[1. Tambah Pembelian] ──> [2. Edit Pembelian] ──> [3. Tambah Resep]
                                                          │
                                                          ▼
[6. Penjualan] <── [5. Konfirmasi Stok] <── [4. Optimasi Pola & Layout]
      │
      ▼
[7. Teardown & Cleanup (Reverse Order)]
```

### TS-001-API-01: Tambah Pembelian Bahan (Add Material Purchase)
*   **Objective:** Menambahkan transaksi pembelian bahan kain baru secara inline untuk menghitung weighted-average cost awal (cost basis) bahan tersebut.
*   **Endpoint under Test:** `POST /materials/{material_id}/purchases`
*   **Request Payload:**
    ```json
    {
      "width_cm": 150.0,
      "length_cm": 100.0,
      "total_cost": 50000.0,
      "supplier_name": "Supplier Indotex E2E",
      "purchased_at": "2026-08-31T00:00:00Z"
    }
    ```
*   **Execution Steps:**
    1. Kirim payload pembelian di atas ke ID bahan "Satin Putih".
    2. Simpan `purchase_id` dan `supplier_id` hasil response untuk langkah pengetesan selanjutnya.
*   **Assertion Points (Definitive Checks):**
    *   [ ] Response status code adalah `201 Created` atau `200 OK`.
    *   [ ] JSON field `id` (purchase_id) tidak bernilai null.
    *   [ ] JSON field `supplier_id` terbuat dan terisi secara otomatis dari supplier baru "Supplier Indotex E2E".
    *   [ ] Lakukan `GET /materials/{material_id}` dan verifikasi `current_avg_cost` bahan terhitung otomatis sebesar Rp 50,000 (untuk basis 100 cm).

---

### TS-001-API-02: Edit Pembelian Bahan (Edit Material Purchase)
*   **Objective:** Memperbarui data transaksi pembelian sebelum bahan tersebut dikonsumsi oleh produksi untuk menguji fleksibilitas mutasi data serta akurasi recalculation cost basis.
*   **Endpoint under Test:** `PATCH /materials/{material_id}/purchases/{purchase_id}`
*   **Request Payload:**
    ```json
    {
      "total_cost": 60000.0,
      "width_cm": 150.0,
      "length_cm": 100.0,
      "purchased_at": "2026-08-31T01:00:00Z"
    }
    ```
*   **Execution Steps:**
    1. Kirim request `PATCH` dengan body di atas menggunakan `purchase_id` yang didapatkan dari langkah TS-001-API-01.
*   **Assertion Points (Definitive Checks):**
    *   [ ] Response status code adalah `200 OK`.
    *   [ ] Lakukan `GET /materials/{material_id}` dan asersikan bahwa `current_avg_cost` bahan kain Satin Putih otomatis disesuaikan menjadi Rp 60,000.

---

### TS-001-API-03: Tambah Resep Baru (Add Recipe / Pattern Spec)
*   **Objective:** Membuat resep pengerjaan (Pattern Spec) baru yang menghubungkan kain, hardware, dimensi potong, waktu kerja, dan ukuran produk.
*   **Endpoint under Test:** `POST /pattern-specs`
*   **Request Payload:**
    ```json
    {
      "product_size_id": "uuid-test-size-m",
      "fabric_material_id": "uuid-test-kain-satin",
      "cut_width_cm": 22.0,
      "cut_height_cm": 18.0,
      "rotation_allowed": true,
      "est_labor_minutes": 10.0,
      "components": [
        {
          "material_id": "uuid-test-hardware-karet",
          "qty_per_unit": 5.0
        }
      ]
    }
    ```
*   **Execution Steps:**
    1. Kirim payload di atas dengan menyertakan ID ukuran produk "M" dan ID kain Satin Putih yang telah memiliki cost basis terverifikasi.
    2. Simpan `pattern_spec_id` hasil response untuk diuji pada bagian optimasi.
*   **Assertion Points (Definitive Checks):**
    *   [ ] Response status code adalah `201 Created` atau `200 OK`.
    *   [ ] JSON field `id` tidak null dan `is_active` bernilai `true`.
    *   [ ] Kalkulasi HPP bawaan (`hpp_fabric` dan `hpp_hardware`) otomatis terisi dan bernilai lebih besar dari 0 berdasarkan cost basis bahan.

---

### TS-001-API-04: Optimasi Pola (Pattern Optimization)
*   **Step 4A: Dapatkan Saran Potong (Get Layout Suggestion)**
    *   **Endpoint under Test:** `POST /cutting-optimizer/suggest`
    *   **Request Payload:**
        ```json
        {
          "material_purchase_id": "uuid-test-purchase-id",
          "candidates": [
            {
              "product_size_id": "uuid-test-size-m",
              "pattern_spec_id": "uuid-test-pattern-spec-id",
              "min_qty": 2
            }
          ]
        }
        ```
    *   **Assertion Points:**
        *   [ ] Response status code adalah `200 OK`.
        *   [ ] Mengembalikan list `layouts` dengan minimal satu opsi strategi (`max_qty`, `min_waste`, atau `max_profit`).
        *   [ ] Di dalam salah satu layout, pastikan `waste_pct` terhitung dan berisi daftar rekomendasi potongan.

*   **Step 4B: Simpan Layout Terpilih (Persist Layout)**
    *   **Endpoint under Test:** `POST /cutting-optimizer/layouts`
    *   **Request Payload:** (Menggunakan data item hasil rekomendasi dari Step 4A)
        ```json
        {
          "material_purchase_id": "uuid-test-purchase-id",
          "items": [
            {
              "product_size_id": "uuid-test-size-m",
              "pattern_spec_id": "uuid-test-pattern-spec-id",
              "orientation": "primary",
              "qty_suggested": 4,
              "fabric_length_used_cm": 88.0,
              "cost_per_piece": 13200.0
            }
          ]
        }
        ```
    *   **Assertion Points:**
        *   [ ] Response status code adalah `201 Created` atau `200 OK`.
        *   [ ] Mengembalikan `cutting_layout_id` yang akan digunakan untuk proses manufaktur selanjutnya.

---

### TS-001-API-05: Konfirmasi Produksi & Stok (Confirm Stock / Production Batch)
*   **Step 5A: Buat Batch Produksi Baru (Create Batch)**
    *   **Endpoint under Test:** `POST /production-batches`
    *   **Request Payload:**
        ```json
        {
          "cutting_layout_id": "uuid-test-cutting-layout-id"
        }
        ```
    *   **Assertion Points:**
        *   [ ] Response status code adalah `201 Created` atau `200 OK`.
        *   [ ] Mengembalikan entitas `ProductionBatch` dengan `status` awal `"draft"`.
        *   [ ] Simpan `production_batch_id` dan `item_id` (dari array `items` batch tersebut).

*   **Step 5B: Sesuaikan Jumlah Potong Aktual (Edit Actual Qty - Optional)**
    *   **Endpoint under Test:** `PATCH /production-batches/{batch_id}/items/{item_id}`
    *   **Request Payload:**
        ```json
        {
          "qty_actual": 4
        }
        ```
    *   **Assertion Points:**
        *   [ ] Response status code adalah `200 OK`.
        *   [ ] Atribut `qty_actual` ter-update menjadi `4` pada response item.

*   **Step 5C: Konfirmasi Produksi (Confirm Batch)**
    *   **Endpoint under Test:** `POST /production-batches/{batch_id}/confirm`
    *   **Assertion Points:**
        *   [ ] Response status code adalah `200 OK` atau `204 No Content`.
        *   [ ] Lakukan `GET /production-batches/{batch_id}` dan pastikan `status` berubah menjadi `"confirmed"`.
        *   [ ] Verifikasi mutasi stok jadi: Lakukan `GET /products/{sku}/sizes/{size_id}` dan asersikan `current_stock_qty` bertambah sebanyak `4`.
        *   [ ] Verifikasi pengurangan stok bahan: Periksa sisa panjang kain Satin Putih pada pembelian terkait berkurang `88.0 cm` secara akurat.

---

### TS-001-API-06: Penjualan Produk Jadi (Sales Transaction)
*   **Objective:** Memvalidasi transaksi penjualan produk jadi, pengurangan stok barang jadi di gudang secara real-time, serta perhitungan laba kotor transaksi secara otomatis.
*   **Endpoint under Test:** `POST /sales-orders`
*   **Request Payload:**
    ```json
    {
      "customer_name": "Budi Pembeli",
      "payment_method": "shopee_pay",
      "marketplace_fee_pct": 2.5,
      "items": [
        {
          "product_size_id": "uuid-test-size-m",
          "qty": 2,
          "unit_price": 25000.0,
          "discount": 0.0
        }
      ]
    }
    ```
*   **Execution Steps:**
    1. Kirim payload transaksi penjualan di atas menggunakan ID ukuran produk "M" yang baru saja di-stock dari langkah konfirmasi produksi.
    2. Simpan `sales_order_id` yang dikembalikan untuk proses cleanup data.
*   **Assertion Points (Definitive Checks):**
    *   [ ] Response status code adalah `201 Created` atau `200 OK`.
    *   [ ] JSON field `id` (sales_order_id) tidak bernilai null.
    *   [ ] Verifikasi pengurangan stok: Panggil `GET /products/{sku}/sizes/{size_id}` dan asersikan `current_stock_qty` telah berkurang dari `4` menjadi `2`.

---

## 3. UI Automation Test Suite (XCUITest Screen Flow)

Di bawah ini adalah pemetaan navigasi dan pengetesan antarmuka (UI) untuk merepresentasikan seluruh rangkaian fungsionalitas di atas dalam simulator iOS.

| Step | Screen / View | Action (Aksi Pengguna) | Target Element / Accessibility ID | Deskripsi / Nilai Input |
|---|---|---|---|---|
| 1 | Main Tab | Buka Tab Produksi | `app.tabBars.buttons["Produksi"]` | Tap tab utama produksi |
| 2 | Bahan List | Klik Tambah Pembelian | `app.buttons["Tambah Pembelian"]` | Membuka modal `TambahPembelianSheet` |
| 3 | Tambah Pembelian | Isi Form Pembelian & Simpan | `app.textFields["input-Panjang"]` <br> `app.textFields["input-Harga"]` <br> `app.buttons["btn-simpan-pembelian"]` | Input 100 cm, Rp 50,000, lalu simpan pembelian |
| 4 | Resep List | Pindah ke Subtab Resep | `app.buttons["subtab-resep"]` | Klik segmen resep pola |
| 5 | Tambah Resep | Buat Resep Baru | `app.buttons["fab-tambah"]` <br> `app.textFields["inline-search-Produk"]` <br> `app.buttons["btn-simpan-resep"]` | Hubungkan produk, kain, dan isi dimensi potong resep |
| 6 | Optimasi | Pindah ke Subtab Optimasi | `app.buttons["subtab-optimasi"]` | Klik segmen optimasi potong |
| 7 | Optimasi Wizard | Pilih Pembelian & Ajukan | `app.buttons["item-pembelian-Satin-Putih"]` <br> `app.buttons["btn-ajukan-optimasi"]` | Jalankan algoritma pemotongan pola kain |
| 8 | Optimasi Wizard | Gunakan Layout Terpilih | `app.buttons["btn-gunakan-layout"]` | Menyimpan layout terpilih ke sistem produksi |
| 9 | Produksi Batch | Konfirmasi Manufaktur | `app.buttons["subtab-produksi"]` <br> `app.buttons["btn-konfirmasi-batch"]` | Membuka draf produksi, isi qty, lalu konfirmasi stok |
| 10| Penjualan List | Catat Penjualan | `app.tabBars.buttons["Penjualan"]` <br> `app.buttons["Tambah Penjualan"]` <br> `app.buttons["btn-simpan-penjualan"]` | Masukkan detail kuantitas penjualan, nama pembeli, simpan |

---

## 4. Teardown & Post-Execution Cleanup (Real API Clean Slate)

Untuk menjaga kebersihan database di lingkungan produksi/staging asli (Real API), seluruh data pengujian yang dibuat wajib dihapus dalam **urutan terbalik** (*reverse hierarchical teardown*). Hal ini penting guna menghindari error integritas relasi tabel database (409 Conflict).

### Langkah-langkah Pembersihan Data Terstruktur:

1.  **Hapus Transaksi Penjualan:**
    *   **Endpoint:** `DELETE /api/v1/sales-orders/{sales_order_id}`
    *   *Tujuan:* Menghapus rekam jejak penjualan yang mengikat stok barang jadi.
2.  **Hapus Batch Produksi:**
    *   **Endpoint:** `DELETE /api/v1/production-batches/{production_batch_id}`
    *   *Tujuan:* Menghapus batch produksi manufaktur yang mengunci stok bahan dan barang jadi. (Jika endpoint standar menolak status 'confirmed' saat testing, lakukan bypass via endpoint khusus pengetesan atau tandai `status='draft'` sebelum memanggil delete).
3.  **Hapus Resep Pola (Pattern Spec):**
    *   **Endpoint:** `DELETE /api/v1/pattern-specs/{pattern_spec_id}`
    *   *Tujuan:* Menghapus spesifikasi pola yang mengikat relasi kain dan produk.
4.  **Hapus Ukuran Produk (Product Size):**
    *   **Endpoint:** `DELETE /api/v1/products/{sku}/sizes/{size_id}`
    *   *Tujuan:* Menghapus varian ukuran yang diuji.
5.  **Hapus Produk Master:**
    *   **Endpoint:** `DELETE /api/v1/products/{sku}`
    *   *Tujuan:* Menghapus entitas master produk agar SKU kembali bersih.
6.  **Hapus Transaksi Pembelian Bahan:**
    *   **Endpoint:** `DELETE /api/v1/materials/{material_id}/purchases/{purchase_id}`
    *   *Tujuan:* Menghapus rekam pembelian yang mengikat saldo persediaan bahan baku.
7.  **Hapus Supplier Pengujian:**
    *   **Endpoint:** `DELETE /api/v1/suppliers/{supplier_id}`
    *   *Tujuan:* Menghapus supplier percobaan untuk menyempurnakan kondisi clean-slate.
