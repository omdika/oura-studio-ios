# Strategi Pengujian Keamanan & Kontrak API (OWASP API Security Top 10)
## Oura Studio — Platform Manajemen Inventaris & HPP

Dokumen ini mendefinisikan strategi pengujian API end-to-end yang komprehensif untuk backend Oura Studio (FastAPI) dan integrasi klien iOS. Strategi ini dirancang dengan mengadopsi standar industri **OWASP API Security Top 10 (2023)** untuk menjamin bahwa seluruh operasi bisnis—mulai dari kalkulasi HPP presisi hingga pencatatan transaksi penjualan—berjalan dengan aman, andal, dan bebas dari kerentanan keamanan kritis.

---

## 1. Pendahuluan & Model Keamanan

### 1.1 Konteks Aplikasi
Oura Studio adalah aplikasi manajemen inventaris dan kalkulasi HPP (*Cost of Goods Sold*) berbasis multi-device untuk bisnis produksi aksesoris (*scrunchies*, dll.). Aplikasi ini bergantung pada kalkulasi matematika yang presisi (algoritma *cutting optimizer* dua fase), konsistensi perubahan status (*state transitions*), dan keandalan data transaksi.

### 1.2 Model Keamanan Saat Ini (Single-Owner Model)
*   **Delegated Authentication:** Autentikasi didelegasikan sepenuhnya ke **Google Sign-In OAuth 2.0**.
*   **Authorization:** Menggunakan model kepemilikan tunggal (*single-owner*). Setiap request yang masuk ke backend wajib menyertakan token JWT aplikasi (`Authorization: Bearer <token>`), kecuali endpoint penukaran token `/auth/google`.
*   **Access Control:** Backend memvalidasi email pengguna dari Google ID Token dengan variabel lingkungan `AUTHORIZED_OWNER_EMAIL`. Hanya email yang cocok yang diizinkan masuk dan diberikan JWT akses berdurasi 30 hari. Tidak ada pemisahan peran (*roles/permissions*) internal—pemilik yang sah memiliki kontrol penuh atas seluruh data.

---

## 2. Pemetaan OWASP API Security Top 10 pada API Oura Studio

Berikut adalah analisis risiko keamanan berdasarkan klasifikasi OWASP API Security Top 10 (2023) beserta strategi mitigasi dan metode pengujian taktisnya pada Oura Studio.

### API1:2023 — Broken Object Level Authorization (BOLA)
*   **Risiko pada Oura Studio:** Penyerang memanipulasi pengidentifikasi objek (seperti UUID `material_id`, `purchase_id`, `sizeId`, `batch_id`, atau `sales_order_id`) untuk membaca atau mengubah data milik pemilik sah.
*   **Strategi Mitigasi:** Backend wajib memvalidasi bahwa `owner_account.id` yang diekstrak dari JWT token adalah pemilik sah dari seluruh resource yang diakses.
*   **Skenario Pengujian:**
    1.  Melakukan request `GET /materials/{id}` dengan UUID acak atau milik akun uji lain tanpa header Authorization yang valid.
    2.  Melakukan request `PATCH /products/{sku}/sizes/{sizeId}` menggunakan JWT milik pengguna yang tidak terdaftar di `AUTHORIZED_OWNER_EMAIL`.
    3.  **Ekspektasi:** Response mengembalikan status `401 Unauthorized` atau `403 Forbidden`.
*   **Spesifikasi Pengujian Detail:** Detail pemetaan API, skenario positif/negatif, prasyarat data (*fixtures*), dan struktur skrip pengujian otomatis dapat dilihat pada sub-dokumen: **[`api1_bola_test_spec.md`](api1_bola_test_spec.md)**.

### API2:2023 — Broken Authentication
*   **Risiko pada Oura Studio:** Kerentanan pada alur pertukaran token `/auth/google` atau penggunaan JWT aplikasi yang lemah (misalnya token tanpa verifikasi tanda tangan, algoritma `none`, atau masa kedaluwarsa yang tidak diterapkan).
*   **Strategi Mitigasi:**
    *   Backend harus memvalidasi Google ID Token secara ketat (tanda tangan Google, masa kedaluwarsa, dan klaim `aud` harus sesuai dengan Client ID iOS).
    *   JWT aplikasi ditandatangani menggunakan kunci rahasia yang kuat (`JWT_SECRET`) dengan algoritma HS256, serta menerapkan kedaluwarsa 30 hari yang divalidasi pada setiap request.
*   **Skenario Pengujian:**
    1.  Mengirimkan `POST /auth/google` dengan `id_token` yang kedaluwarsa atau palsu.
    2.  Mengirimkan request ke `/materials` dengan menyertakan JWT aplikasi yang ditandatangani menggunakan algoritma `"none"`.
    3.  Mengirimkan request dengan token JWT yang tanda tangannya dimanipulasi.
    4.  **Ekspektasi:** Response mengembalikan `400 Bad Request` atau `401 Unauthorized`.

### API3:2023 — Broken Object Property Level Authorization
*   **Risiko pada Oura Studio:** Pengguna mencoba memodifikasi properti internal, kalkulasi otomatis, atau field baca-saja (*read-only*) secara langsung melalui payload request.
*   **Strategi Mitigasi:**
    *   Field-field sensitif seperti `current_avg_cost` pada Material, `hpp_total` pada Batch Item, dan `line_profit` serta `unit_hpp_snapshot` pada Sales Order Item harus dihitung secara eksklusif oleh backend dan tidak boleh diterima dari input pengguna.
    *   Data pembelian kain/hardware yang sudah memiliki rekaman konsumsi tidak boleh diubah dimensinya (`width_cm`, `length_cm`, `qty` ditolak).
*   **Skenario Pengujian:**
    1.  Mengirimkan `PATCH /materials/{id}` dengan payload `{ "current_avg_cost": 1000 }` dan memverifikasi bahwa nilai tersebut diabaikan atau ditolak.
    2.  Mengirimkan `PATCH /materials/{id}/purchases/{purchase_id}` untuk pembelian yang sudah dikonsumsi (misal: dirujuk oleh Cutting Layout), mencoba mengubah `width_cm`.
    3.  **Ekspektasi:** Field baca-saja diabaikan/ditolak dengan `400 Bad Request` jika mencoba mengubah dimensi pembelian terkonsumsi.

### API4:2023 — Unrestricted Resource Consumption
*   **Risiko pada Oura Studio:** Request berlebihan atau payload raksasa yang mengakibatkan penurunan performa server (*Denial of Service*), khususnya pada algoritma penataan pola potong (*Cutting Optimizer*).
*   **Strategi Mitigasi:**
    *   Membatasi ukuran payload JSON maksimum yang diterima server.
    *   Menerapkan batasan jumlah elemen (*maximum candidates*) pada endpoint `POST /cutting-optimizer/suggest`.
    *   Menerapkan batasan rentang tanggal maksimum pada endpoint laporan (`/reports/sales` atau `/reports/waste-by-material`).
*   **Skenario Pengujian:**
    1.  Mengirimkan request `POST /cutting-optimizer/suggest` dengan jumlah kandidat ukuran sangat besar (misalnya 10.000 kandidat).
    2.  Meminta laporan `/reports/sales?from=2000-01-01&to=2100-12-31` (rentang waktu 100 tahun).
    3.  **Ekspektasi:** Server menolak request dengan status `400 Bad Request` disertai pesan kesalahan yang jelas, mencegah terjadinya *out-of-memory* atau CPU starvation.

### API5:2023 — Broken Function Level Authorization (BFLA)
*   **Risiko pada Oura Studio:** Pengguna yang tidak sah memanggil fungsi-fungsi administratif atau operasi perubahan status sensitif yang dapat merusak integritas keuangan dan stok.
*   **Strategi Mitigasi:**
    *   Seluruh endpoint transisi status (seperti konfirmasi batch `/production-batches/{id}/confirm`, pembatalan penjualan `/sales-orders/{id}/cancel`, dan perubahan pengaturan `/settings`) wajib dilindungi oleh middleware otorisasi yang sama.
*   **Skenario Pengujian:**
    1.  Mencoba menembak `POST /production-batches/{id}/confirm` tanpa menyertakan JWT atau menggunakan token palsu.
    2.  Mencoba mengubah pengaturan global melalui `PATCH /settings` dengan kredensial tidak valid.
    3.  **Ekspektasi:** Server mengembalikan `401 Unauthorized`.

### API6:2023 — Unrestricted Access to Sensitive Business Flows
*   **Risiko pada Oura Studio:** Penipuan logika bisnis, seperti melakukan konfirmasi ganda pada satu batch produksi, membuat penjualan dengan kuantitas negatif, atau menghapus data referensi yang sedang aktif digunakan.
*   **Strategi Mitigasi:**
    *   **Immutability:** Batch produksi yang sudah berstatus `confirmed` tidak boleh diubah atau dikonfirmasi ulang.
    *   **Data Validation:** Transaksi penjualan wajib memvalidasi ketersediaan stok fisik di `stock_ledger` sebelum diproses, serta melarang kuantitas atau harga bernilai negatif.
    *   **Cascade Restrictions:** Penghapusan produk/ukuran atau bahan yang sudah memiliki riwayat transaksi ditolak atau dialihkan secara otomatis menjadi mekanisme arsip (`is_archived = true`).
*   **Skenario Pengujian:**
    1.  Mengirimkan `POST /production-batches/{id}/confirm` untuk kedua kalinya pada batch yang sudah terkonfirmasi.
    2.  Membuat Sales Order lewat `POST /sales-orders` dengan kuantitas item bernilai negatif (`qty: -5`).
    3.  Melakukan `DELETE /products/{sku}/sizes/{sizeId}` untuk ukuran produk yang sudah memiliki riwayat penjualan aktif.
    4.  **Ekspektasi:** Request konfirmasi ganda menghasilkan `409 Conflict`, kuantitas negatif ditolak dengan `400 Bad Request`, and penghapusan produk berriwayat dialihkan ke status arsip dengan mengembalikan status yang informatif.

### API7:2023 — Server-Side Request Forgery (SSRF)
*   **Risiko pada Oura Studio:** Backend dipaksa mengirimkan HTTP request ke URL internal atau pihak ketiga yang tidak aman saat memproses integrasi eksternal.
*   **Strategi Mitigasi:**
    *   Alur verifikasi token Google (`https://oauth2.googleapis.com/tokeninfo`) harus menggunakan URL yang dideklarasikan secara keras (*hardcoded*) di dalam kode atau konfigurasi backend yang aman. Backend tidak boleh menerima input URL eksternal yang dinamis dari pengguna.
*   **Skenario Pengujian:**
    1.  Mencoba menyisipkan parameter URL khusus pada endpoint login untuk mengalihkan verifikasi tokeninfo ke server lokal palsu.
    2.  **Ekspektasi:** Pengalihan URL diabaikan sepenuhnya; backend hanya terhubung ke server resmi Google API.

### API8:2023 — Security Misconfiguration
*   **Risiko pada Oura Studio:** Kebocoran informasi sensitif (seperti detail *stack trace*, skema database internal, atau versi library) melalui error message server, atau konfigurasi CORS (*Cross-Origin Resource Sharing*) yang terlalu longgar.
*   **Strategi Mitigasi:**
    *   Konfigurasi CORS diatur secara ketat hanya mengizinkan origin klien yang sah (atau dibatasi pada level aplikasi native jika tidak diakses via browser).
    *   Gunakan penanganan error global (*global exception handler*) untuk menangkap kesalahan sistem dan mengembalikan pesan error yang bersih tanpa *stack trace* mentah.
*   **Skenario Pengujian:**
    1.  Mengirimkan payload JSON dengan format yang rusak (*malformed*) ke endpoint API.
    2.  Mengirimkan parameter UUID dengan tipe string non-UUID (misal: `/materials/bukan-uuid`).
    3.  **Ekspektasi:** Server mengembalikan `400 Bad Request` dengan pesan umum yang aman, bukan stack trace internal dari framework FastAPI atau database PostgreSQL.

### API9:2023 — Improper Inventory Management
*   **Risiko pada Oura Studio:** Meninggalkan endpoint pengembangan (*staging/debug/shadow APIs*) tetap aktif di lingkungan produksi, atau membiarkan dokumentasi API internal (seperti Swagger UI) terbuka bebas tanpa pengamanan.
*   **Strategi Mitigasi:**
    *   Gunakan versi rute yang terstruktur jelas (`/api/v1`).
    *   Nonaktifkan fitur OpenAPI/Docs otomatis FastAPI (`/docs` dan `/redoc`) di lingkungan produksi, atau batasi aksesnya hanya untuk IP internal developer.
*   **Skenario Pengujian:**
    1.  Mengakses `/docs` atau `/openapi.json` di server production tanpa autentikasi tambahan.
    2.  Mencoba mengakses rute spekulatif seperti `/api/v0/materials` atau `/api/debug/state`.
    3.  **Ekspektasi:** Mengembalikan `404 Not Found` atau `401 Unauthorized`.

### API10:2023 — Unsafe Consumption of APIs
*   **Risiko pada Oura Studio:** Layanan eksternal Google mengalami gangguan (*outage*), menyebabkan sistem hang, kebocoran resource, atau kegagalan penanganan error yang tidak elegan.
*   **Strategi Mitigasi:**
    *   Menerapkan batas waktu koneksi (*connection timeout*) dan batas coba ulang (*retry limits*) pada integrasi HTTP eksternal ke Google API.
    *   Menangani kegagalan Google API secara anggun (*graceful degradation*).
*   **Skenario Pengujian:**
    1.  Simulasi jaringan terputus ke Google API saat memproses login.
    2.  **Ekspektasi:** Backend merespons dengan cepat menggunakan status `503 Service Unavailable` atau `502 Bad Gateway` disertai instruksi bahwa layanan autentikasi eksternal sedang mengalami gangguan, tanpa menyebabkan timeout server backend.

---

## 3. Matriks Skenario Uji Keamanan API (Test Matrix)

| ID Uji | Kategori OWASP | Endpoint | Metode HTTP | Input / Kondisi | Ekspektasi Hasil | Metode Validasi |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-SEC-001** | API1: BOLA | `/materials/{id}` | `GET` | UUID material sah, request tanpa token JWT | `401 Unauthorized` | Automated Integration Test |
| **TC-SEC-002** | API1: BOLA | `/products/{sku}/sizes/{sizeId}` | `PATCH` | `sizeId` UUID sah, JWT milik akun non-owner | `403 Forbidden` | Automated Integration Test |
| **TC-SEC-003** | API2: Auth | `/auth/google` | `POST` | `id_token` kosong atau format asal-asalan | `400 Bad Request` | Integration Test |
| **TC-SEC-004** | API2: Auth | `/auth/google` | `POST` | `id_token` valid Google, tapi `aud` bukan Client ID iOS kita | `403 Forbidden` | Integration Test |
| **TC-SEC-005** | API2: Auth | `/materials` | `GET` | Header `Authorization: Bearer <JWT_Tanpa_Tanda_Tangan>` (algoritma `none`) | `401 Unauthorized` | Integration Test / Bruno |
| **TC-SEC-006** | API3: Property | `/materials/{id}` | `PATCH` | Payload mencoba mengubah `"current_avg_cost"` secara manual | Nilai diabaikan; database tidak berubah | DB Verification |
| **TC-SEC-007** | API3: Property | `/materials/{id}/purchases/{purchase_id}` | `PATCH` | Mencoba merubah `width_cm` pada pembelian yang sudah dirujuk Cutting Layout | `400 Bad Request` | API Contract Verification |
| **TC-SEC-008** | API4: Resource | `/cutting-optimizer/suggest` | `POST` | Payload berisi > 1.000 kandidat ukuran | `400 Bad Request` (Payload limits exceeded) | Stress Testing |
| **TC-SEC-009** | API4: Resource | `/reports/sales` | `GET` | Parameter rentang tanggal `from` dan `to` terpaut 100 tahun | `400 Bad Request` | Integration Test |
| **TC-SEC-010** | API5: BFLA | `/production-batches/{id}/confirm` | `POST` | Request eksekusi konfirmasi tanpa JWT yang valid | `401 Unauthorized` | Integration Test |
| **TC-SEC-011** | API5: BFLA | `/settings` | `PATCH` | Request perubahan konfigurasi tarif tanpa JWT pemilik | `401 Unauthorized` | Integration Test |
| **TC-SEC-012** | API6: Flow | `/production-batches/{id}/confirm` | `POST` | Batch ID yang sudah berstatus `confirmed` dikirimkan kembali untuk konfirmasi ulang | `409 Conflict` (Batch already confirmed) | Integration Test |
| **TC-SEC-013** | API6: Flow | `/sales-orders` | `POST` | Item penjualan dikirim dengan `"qty": -10` atau `"unit_price": -5000` | `400 Bad Request` | Integration Test |
| **TC-SEC-014** | API6: Flow | `/products/{sku}` | `DELETE` | SKU produk yang memiliki riwayat penjualan aktif dikirim untuk dihapus | Produk diarsipkan (`is_archived = true`), record database tetap ada | DB Verification / API Response |
| **TC-SEC-015** | API8: Misconfig| `/materials/bukan-uuid` | `GET` | Mengirim string non-UUID pada path parameter UUID | `400 Bad Request` (bukan 500 Internal Error) | Integration Test |
| **TC-SEC-016** | API8: Misconfig| `/any-endpoint` | `GET` | Mengirim payload JSON rusak (*parse error*) | `400 Bad Request` bersih (tanpa database stack trace) | Integration Test |
| **TC-SEC-017** | API10: Unsafe | `/auth/google` | `POST` | Google API tokeninfo down / timeout | `503 Service Unavailable` atau `502 Bad Gateway` (respons cepat < 5 detik) | Mock Network Interruption |

---

## 4. Metodologi Pengujian & Tooling

Strategi pengujian ini dikembangkan agar mudah dikelola dan dapat diintegrasikan ke dalam alur pengembangan secara berkelanjutan:

### 4.1 Automated Security & Integration Testing (Prioritas Utama)
*   **Backend Level (Python/FastAPI):**
    *   Menggunakan **Pytest** dikombinasikan dengan **HTTPX** (`TestClient` dari FastAPI).
    *   Membuat modul pengujian khusus `tests/security/` untuk mengisolasi skenario pengujian OWASP Top 10 secara terprogram.
    *   Setiap pengujian memicu database transaksi *in-memory* (atau database uji terpisah yang disetel ulang setiap sesi) untuk memvalidasi perubahan state secara akurat.
*   **Integration Level (Klien iOS):**
    *   Memperluas pustaka pengujian integrasi Swift (seperti `APIIntegrationTests.swift` yang ditambahkan pada revisi v3.47) untuk memverifikasi fungsionalitas autentikasi, serta memastikan penanganan respons HTTP error (`401`, `403`, `409`, `400`) pada sisi klien berjalan dengan mulus tanpa menyebabkan aplikasi crash.

### 4.2 Manual / Exploratory Testing (Interactive Diagnostics)
*   Menggunakan tools klien REST modern seperti **Bruno** atau **Postman** dengan koleksi environment yang terenkripsi.
*   Koleksi request Bruno (`.bru` files) wajib disimpan dalam repositori backend di folder `/docs/bruno-collection` agar seluruh tim pengembang memiliki akses ke koleksi uji coba API yang up-to-date.

### 4.3 Static Application Security Testing (SAST)
*   Menjalankan tool **Bandit** untuk memindai kode Python secara statis guna mendeteksi penggunaan fungsi tidak aman, penulisan hardcoded password, atau konfigurasi enkripsi yang lemah sebelum proses build.
*   Menjalankan linter **Ruff** atau **Flake8** untuk memastikan kualitas penulisan kode tetap terjaga secara konsisten.

---

## 5. Panduan Pengembangan Lebih Lanjut (Extensibility Guide)

Dokumen ini dirancang sebagai panduan hidup (*living document*). Ketika fitur baru atau perubahan arsitektur dilakukan di masa depan, tim pengembang harus memperbarui strategi pengujian ini dengan langkah-langkah berikut:

1.  **Jika Menambahkan Endpoint Baru:**
    *   Identifikasi input ID objek yang rentan terhadap **BOLA (API1)** dan pastikan middleware otorisasi memvalidasi kepemilikan data sebelum memproses manipulasi objek.
    *   Tambahkan baris skenario pengujian baru ke dalam **Matriks Skenario Uji (Section 3)** dengan format yang seragam.
    *   Tulis unit test otomatis yang sesuai untuk memvalidasi batasan hak akses tersebut.
2.  **Jika Mengalihkan ke Sistem Multi-Tenant (Banyak Pemilik Toko):**
    *   Model keamanan harus didefinisikan ulang dari *Single-Owner* menjadi *Multi-Tenant*.
    *   Setiap kueri database SQL wajib memvalidasi `tenant_id` atau `owner_account_id` pada klausa `WHERE`.
    *   Strategi pengujian harus diperluas untuk menguji kebocoran data lintas-tenant secara ketat (memastikan Akun A tidak dapat melihat/mengubah data milik Akun B meskipun menyertakan UUID objek yang valid).
3.  **Integrasi CI/CD:**
    *   Rangkaian pengujian keamanan otomatis (`pytest tests/security/`) wajib dijalankan secara otomatis pada setiap pull request melalui alur **GitHub Actions**.
    *   Build dilarang bergabung (*merge blocked*) jika terdapat pengujian keamanan yang gagal atau jika Bandit mendeteksi kerentanan dengan tingkat keparahan tinggi (*high severity*).
