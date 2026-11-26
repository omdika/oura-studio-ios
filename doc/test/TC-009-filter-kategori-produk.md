# Test Case: TC-009 - Filter Kategori + Distribusi Size per Varian di Produk List

## 1. Objective & Scope
*   **Goal:** Memverifikasi filter kategori (pouch / scrunchie / all) di `ProdukListView` berefek ke komponen total (Total Produk, Total Varian, Total Stok, Stok Kosong) dan list produk, serta distribusi jumlah size per varian (XS–XXL + Free Size) yang tampil di atas list.
*   **Target Module:** `Screens/Produk/ProdukListView.swift` (filter kategori, total cards, size distribution section).
*   **Test Type:** Sanity UI Test (manual / Maestro).

## 2. Pre-requisites & Setup (State Injection)
*   App sudah login (JWT tersimpan di Keychain) dan berada di halaman Produk (tab Produk).
*   Backend/mock memiliki data produk dengan kategori bervariasi: minimal 1 produk `pouch` dan 1 produk `scrunchie`, masing-masing memiliki beberapa varian size (XS, S, M, L, XL, XXL, Free Size) dengan campuran `currentStockQty` (ada yang 0 untuk stok kosong).
*   Semua produk non-archived untuk baseline "all".

## 3. Step-by-Step Execution Flow
1.  **Buka halaman Produk.** Verifikasi default kategori = "all" (tidak ada chip kategori terpilih / chip "all" aktif).
2.  **Verifikasi baseline "all":** Total Produk = jumlah semua produk non-archived; list menampilkan semua produk; distribusi size mencakup semua ukuran dari semua produk.
3.  **Tap chip "pouch".** Verifikasi `requestReload` terpicu, list baru hanya menampilkan produk dengan `category == "pouch"` (non-archived).
4.  **Verifikasi total saat pouch:** Total Produk / Total Varian / Total Stok / Stok Kosong dihitung dari data pouch saja (lebih kecil atau sama dengan baseline "all").
5.  **Tap chip "scrunchie".** Verifikasi list hanya menampilkan produk kategori "scrunchie"; total menyesuaikan ke data scrunchie.
6.  **Kembali ke "all".** Verifikasi list dan total kembali ke baseline semua produk.
7.  **Kombinasi filter:** Aktifkan "pouch" + ketik search + aktifkan filter tanggal → list hanya produk pouch yang cocok search dan dalam rentang tanggal; total dihinterséksi dari ketiga filter.
8.  **Verifikasi urutan distribusi size:** Chip ukuran selalu dalam urutan XS, S, M, L, XL, XXL, Free Size; count = 0 untuk ukuran yang tidak ada dalam data terfilter.

## 4. Assertion & Verification Criteria (Definitive Checks)
*   **UI Asserts:**
    *   Chip kategori tersedia: "all" (default), "pouch", "scrunchie"; hanya satu terpilih pada satu waktu.
    *   Saat "pouch" dipilih, tiap baris list punya `product.category == "pouch"`; tidak ada produk scrunchie atau kategori lain.
    *   Distribusi size muncul di atas list produk; setiap label (XS..XXL, Free Size) menunjukkan count varian non-archived milik produk yang lolos filter.
*   **Total Asserts (saat kategori aktif):**
    *   `Total Produk` == count produk non-archived dalam kategori terpilih.
    *   `Total Varian` == count `ProductSizeDetail` non-archived milik produk dalam kategori terpilih.
    *   `Total Stok` == SUM `currentStockQty` dari varian di atas.
    *   `Stok Kosong` == count varian dengan `currentStockQty == 0` di atas.
    *   Ketika kembali ke "all", total kembali ke nilai `productStats` (global).
*   **Backend/API:** Tidak ada endpoint baru yang dipanggil; `GET /products` dan `GET /product-sizes` existing (load-all saat filter aktif, pagination saat all).
