# Spesifikasi Pengujian Keamanan API — API1:2023: Broken Object Level Authorization (BOLA)
## Oura Studio — Platform Manajemen Inventaris & HPP

Dokumen ini adalah sub-dokumentasi teknis detail yang memetakan seluruh skenario pengujian untuk kerentanan **API1:2023 — Broken Object Level Authorization (BOLA)** pada Oura Studio. Dokumen ini dirancang dengan struktur terstandarisasi yang sangat presisi agar dapat dibaca langsung oleh **AI Agent** untuk menggenerasikan skrip pengujian otomatis (Swift/XCTest atau Python/Pytest) secara terperinci.

---

## 1. Pendahuluan & Model Keamanan BOLA Oura Studio

### 1.1 Apa itu BOLA pada Oura Studio?
BOLA terjadi ketika penyerang (atau pengguna lain) memanipulasi pengidentifikasi unik objek (Resource UUID) di dalam parameter jalur request (*path parameter*) atau payload untuk membaca atau memodifikasi data milik pengguna lain yang bukan haknya.

### 1.2 Konteks Model Akses tunggal (Single-Owner) & Multi-Tenant (Masa Depan)
*   **Keadaan Saat Ini (Single-Owner):** Oura Studio dirancang untuk satu pemilik utama (`AUTHORIZED_OWNER_EMAIL`). Mitigasi BOLA diuji dengan memastikan bahwa **pengguna yang masuk menggunakan akun Google lain** (yang bukan owner) ditolak secara konsisten saat mencoba mengakses Resource UUID milik Owner yang valid.
*   **Desain Masa Depan (Multi-Tenant):** Jika aplikasi dikembangkan untuk mendukung banyak pemilik toko (*multi-owner/multi-tenant*), BOLA diuji dengan memastikan **Pemilik Toko A** tidak dapat membaca atau memodifikasi Resource UUID milik **Pemilik Toko B**, meskipun Pemilik Toko A memiliki JWT token yang valid untuk tokonya sendiri.

---

## 2. Prasyarat & Penyiapan Pengujian (Pre-requisites)

Untuk menjalankan skrip pengujian otomatis, sistem pengujian wajib menyiapkan 3 konteks autentikasi berikut:

```
[Klien Uji]
  ├─ Owner Token (JWT_OWNER)        -> Berasal dari login AUTHORIZED_OWNER_EMAIL (Akses Sah)
  ├─ Attacker Token (JWT_ATTACKER)  -> Berasal dari login Google Akun non-owner (Akses Tidak Sah)
  └─ No Token (Unauthenticated)     -> Request tanpa header 'Authorization'
```

### Variabel Lingkungan Pengujian (Test Environment Variables):
*   `BASE_URL`: Basis path API (default: `https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1`)
*   `JWT_OWNER`: Token bearer milik pemilik sah.
*   `JWT_ATTACKER`: Token bearer milik penyerang (Google account lain yang sah secara format tapi tidak terdaftar sebagai owner).

---

## 3. Matriks Skenario Uji Detail (BOLA Test Cases)

Dokumen ini mengelompokkan skenario uji berdasarkan modul data utama. Setiap skenario mendefinisikan kasus positif (akses sah) dan kasus negatif (akses BOLA).

---

### Modul A: Materials & Purchases (Bahan & Pembelian)

Modul ini mengelola data bahan mentah kain, benang, dan hardware, serta rekaman pembelian individualnya.

#### 1. Endpoint: `GET /materials/{id}`
*   **Persyaratan Data (Fixtures):**
    *   Terdapat `material_id` valid milik Owner di database (Contoh: `a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d` - Satin Pelangi).
*   **Kasus Uji A.1.1 (Positive Case - Owner Akses Sah):**
    *   **Metode & Path:** `GET /materials/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Ekspektasi Hasil:** `200 OK`, mengembalikan data detail material Satin Pelangi.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testMaterialsGet_AsOwner_ReturnsSuccess`
*   **Kasus Uji A.1.2 (Negative Case - Attacker Akses BOLA):**
    *   **Metode & Path:** `GET /materials/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Ekspektasi Hasil:** `403 Forbidden` atau `404 Not Found` (mencegah enumerasi ID).
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testMaterialsGet_AsAttacker_ReturnsForbidden`
*   **Kasus Uji A.1.3 (Negative Case - Tanpa Autentikasi):**
    *   **Metode & Path:** `GET /materials/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
    *   **Header:** Kosong
    *   **Ekspektasi Hasil:** `401 Unauthorized`
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testMaterialsGet_NoToken_ReturnsUnauthorized`

#### 2. Endpoint: `PATCH /materials/{id}`
*   **Persyaratan Data (Fixtures):**
    *   Terdapat `material_id` valid milik Owner.
*   **Kasus Uji A.2.1 (Positive Case - Owner Edit Sah):**
    *   **Metode & Path:** `PATCH /materials/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Payload:** `{ "name": "Satin Pelangi Premium" }`
    *   **Ekspektasi Hasil:** `200 OK` atau `204 No Content`, nama berubah di database.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testMaterialsPatch_AsOwner_ReturnsSuccess`
*   **Kasus Uji A.2.2 (Negative Case - Attacker Edit BOLA):**
    *   **Metode & Path:** `PATCH /materials/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Payload:** `{ "name": "Satin Di-hack" }`
    *   **Ekspektasi Hasil:** `403 Forbidden` (nama Satin Pelangi tidak boleh berubah).
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testMaterialsPatch_AsAttacker_ReturnsForbidden`

#### 3. Endpoint: `PATCH /materials/{id}/purchases/{purchase_id}`
*   **Persyaratan Data (Fixtures):**
    *   Terdapat `material_id` dan `purchase_id` valid milik Owner.
*   **Kasus Uji A.3.1 (Positive Case - Owner Edit Pembelian Sah):**
    *   **Metode & Path:** `PATCH /materials/a1b2.../purchases/p9999-uuid-pembelian`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Payload:** `{ "total_cost": 50000 }`
    *   **Ekspektasi Hasil:** `200 OK`, biaya pembelian terperbarui, `current_avg_cost` material dihitung ulang secara otomatis.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testPurchasePatch_AsOwner_ReturnsSuccess`
*   **Kasus Uji A.3.2 (Negative Case - Attacker Mencoba Meretas Biaya Pembelian):**
    *   **Metode & Path:** `PATCH /materials/a1b2.../purchases/p9999-uuid-pembelian`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Payload:** `{ "total_cost": 100 }`
    *   **Ekspektasi Hasil:** `403 Forbidden`, nilai pembelian di database aman tidak berubah.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_A1_Materials.swift` -> `testPurchasePatch_AsAttacker_ReturnsForbidden`

---

### Modul B: Products, Sizes & Pattern Specs (Produk & Resep)

Modul ini mengelola data produk jadi, ukuran (ProductSize) beserta varian kainnya, dan spesifikasi pemotongan kain (PatternSpec/Resep).

#### 1. Endpoint: `GET /products/{sku}/sizes/{sizeId}`
*   **Persyaratan Data (Fixtures):**
    *   Terdapat SKU produk milik Owner (`SCRUNCHIE`) dan `sizeId` UUID yang valid milik Owner (Contoh: `s1111-uuid-ukuran-m`).
*   **Kasus Uji B.1.1 (Positive Case):**
    *   **Metode & Path:** `GET /products/SCRUNCHIE/sizes/s1111-uuid-ukuran-m`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Ekspektasi Hasil:** `200 OK`, mengembalikan detail ukuran "M" beserta HPP breakdown dan ketersediaan stok fisik.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_B1_Products.swift` -> `testProductSizeGet_AsOwner_ReturnsSuccess`
*   **Kasus Uji B.1.2 (Negative Case - BOLA):**
    *   **Metode & Path:** `GET /products/SCRUNCHIE/sizes/s1111-uuid-ukuran-m`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Ekspektasi Hasil:** `403 Forbidden`
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_B1_Products.swift` -> `testProductSizeGet_AsAttacker_ReturnsForbidden`

#### 2. Endpoint: `PATCH /products/{sku}/sizes/{sizeId}`
*   **Persyaratan Data (Fixtures):**
    *   Terdapat SKU `SCRUNCHIE` and `sizeId` UUID yang valid.
*   **Kasus Uji B.2.1 (Positive Case):**
    *   **Metode & Path:** `PATCH /products/SCRUNCHIE/sizes/s1111-uuid-ukuran-m`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Payload:** `{ "selling_price": 15000 }`
    *   **Ekspektasi Hasil:** `200 OK` atau `204 No Content`, harga jual diperbarui.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_B1_Products.swift` -> `testProductSizePatch_AsOwner_ReturnsSuccess`
*   **Kasus Uji B.2.2 (Negative Case - BOLA):**
    *   **Metode & Path:** `PATCH /products/SCRUNCHIE/sizes/s1111-uuid-ukuran-m`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Payload:** `{ "selling_price": 500 }`
    *   **Ekspektasi Hasil:** `403 Forbidden`
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_B1_Products.swift` -> `testProductSizePatch_AsAttacker_ReturnsForbidden`

---

### Modul C: Production Batches (Produksi Batch)

Modul ini mengelola batch pemotongan fisik dan perakitan produk jadi yang memengaruhi saldo stok material dan stok produk siap jual.

#### 1. Endpoint: `POST /production-batches/{id}/confirm`
*   **Keamanan Kritis:** Operasi ini memicu decrement stok material sisa panjang kain dan increment stok produk jadi. Kegagalan otorisasi BOLA di sini akan mengacaukan seluruh audit keuangan dan logistik.
*   **Persyaratan Data (Fixtures):**
    *   Terdapat batch produksi berstatus `draft` dengan `id` valid milik Owner (Contoh: `b5555-uuid-batch-draft`).
*   **Kasus Uji C.1.1 (Positive Case):**
    *   **Metode & Path:** `POST /production-batches/b5555-uuid-batch-draft/confirm`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Ekspektasi Hasil:** `200 OK`, status berubah menjadi `confirmed`, stock ledger terisi secara otomatis, kain berkurang, stock produk bertambah.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_C1_Production.swift` -> `testProductionConfirm_AsOwner_ReturnsSuccess`
*   **Kasus Uji C.1.2 (Negative Case - BOLA):**
    *   **Metode & Path:** `POST /production-batches/b5555-uuid-batch-draft/confirm`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Ekspektasi Hasil:** `403 Forbidden`, status batch tetap `draft`, stok fisik aman tidak bergerak.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_C1_Production.swift` -> `testProductionConfirm_AsAttacker_ReturnsForbidden`

---

### Modul D: Sales Orders (Penjualan)

Modul ini mencatat nota transaksi penjualan produk ke konsumen dan memotong saldo stok produk jadi.

#### 1. Endpoint: `POST /sales-orders/{id}/cancel`
*   **Keamanan Kritis:** Pembatalan penjualan mengembalikan stok produk jadi dan membuat kueri komparasi profit di dashboard berantakan jika dieksekusi oleh pihak luar.
*   **Persyaratan Data (Fixtures):**
    *   Terdapat sales order berstatus `paid` dengan `id` valid milik Owner (Contoh: `o7777-uuid-sales-paid`).
*   **Kasus Uji D.1.1 (Positive Case):**
    *   **Metode & Path:** `POST /sales-orders/o7777-uuid-sales-paid/cancel`
    *   **Header:** `Authorization: Bearer {{JWT_OWNER}}`
    *   **Payload:** `{ "reason": "Saran pembatalan dari owner" }`
    *   **Ekspektasi Hasil:** `200 OK`, status penjualan menjadi `cancelled`, stok produk dikembalikan utuh ke stock ledger.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_D1_Sales.swift` -> `testSalesCancel_AsOwner_ReturnsSuccess`
*   **Kasus Uji D.1.2 (Negative Case - BOLA):**
    *   **Metode & Path:** `POST /sales-orders/o7777-uuid-sales-paid/cancel`
    *   **Header:** `Authorization: Bearer {{JWT_ATTACKER}}`
    *   **Payload:** `{ "reason": "Dibatalkan oleh hacker" }`
    *   **Ekspektasi Hasil:** `403 Forbidden`, status nota tetap `paid` dan stok produk tidak berubah.
    *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
    *   **Link ke Skrip:** `test/scripts/TC_BOLA_D1_Sales.swift` -> `testSalesCancel_AsAttacker_ReturnsForbidden`

---

## 4. Struktur Logika Pengujian untuk AI Agent (Automation Target Code Structure)

Ketika AI Agent diminta untuk menggenerasikan skrip pengujian keamanan otomatis ini, ia wajib mengikuti pola kelas pengujian (*test class skeleton*) di bawah ini.

### 4.1 Contoh Struktur Target: Swift / XCTest Integration (iOS Client View)

```swift
import XCTest
@testable import oura_studio_frontend

final class API1_BOLASecurityTests: XCTestCase {
    let baseURL = URL(string: "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1")!
    var ownerToken: String = ""
    var attackerToken: String = ""
    
    // Sample authoritative resource UUIDs stored for testing
    let sampleMaterialID = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d" // Satin Pelangi
    let sampleProductSizeID = "s1111-uuid-ukuran-m"
    let sampleBatchID = "b5555-uuid-batch-draft"
    let sampleSalesOrderID = "o7777-uuid-sales-paid"

    override func setUpWithError() throws {
        super.setUp()
        // Ambil token JWT uji dari variable environment atau Keychain lokal uji
        ownerToken = ProcessInfo.processInfo.environment["JWT_OWNER"] ?? "MOCK_OWNER_JWT_SECRET_KEY"
        attackerToken = ProcessInfo.processInfo.environment["JWT_ATTACKER"] ?? "MOCK_ATTACKER_JWT_SECRET_KEY"
        
        XCTAssertFalse(ownerToken.isEmpty, "Pre-requisite: JWT_OWNER environment variable must be set!")
        XCTAssertFalse(attackerToken.isEmpty, "Pre-requisite: JWT_ATTACKER environment variable must be set!")
    }

    // MARK: - Modul A: Materials BOLA Tests

    func testMaterialsGet_AsOwner_ReturnsSuccess() async throws {
        let url = baseURL.appendingPathComponent("materials/\(sampleMaterialID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Owner should easily fetch their own material!")
    }

    func testMaterialsGet_AsAttacker_ReturnsForbidden() async throws {
        let url = baseURL.appendingPathComponent("materials/\(sampleMaterialID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        // Assert BOLA Protection
        XCTAssertTrue(httpResponse.statusCode == 403 || httpResponse.statusCode == 404, 
                      "BOLA Security: Attacker must be forbidden (403) or not find (404) owner's material!")
    }

    // MARK: - Modul C: Production Confirm BOLA Tests

    func testProductionConfirm_AsAttacker_ReturnsForbidden() async throws {
        let url = baseURL.appendingPathComponent("production-batches/\(sampleBatchID)/confirm")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        // Assert BOLA Protection
        XCTAssertEqual(httpResponse.statusCode, 403, 
                       "CRITICAL: Non-owner hacker must NEVER confirm draft batches (BOLA leak)!")
    }
}
```

---

## 5. Rencana Remediasi & Tindakan Pengembang (Remediation Guide)

Jika pengujian otomatis di atas mendeteksi kebocoran BOLA (HTTP `200` atau `204` dikembalikan kepada pengguna yang tidak berhak), pengembang backend FastAPI wajib menerapkan perbaikan kode berikut:

1.  **Gunakan Dependency Injection untuk Owner Current User:**
    Setiap endpoint transaksional harus menyuntikkan (*inject*) user yang terautentikasi melalui skema keamanan FastAPI Dependency Injection.
2.  **Kueri Database Berbasis Pemilik:**
    Jangan pernah melakukan kueri objek murni berbasis ID mentah tanpa memvalidasi kepemilikan.
    *   **Salah (Rentan BOLA):**
        ```python
        @app.get("/materials/{id}")
        def get_material(id: UUID, db: Session = Depends(get_db)):
            return db.query(Material).filter(Material.id == id).first()
        ```
    *   **Benar (Aman dari BOLA):**
        ```python
        @app.get("/materials/{id}")
        def get_material(id: UUID, current_user: User = Depends(get_current_owner), db: Session = Depends(get_db)):
            material = db.query(Material).filter(Material.id == id, Material.owner_id == current_user.id).first()
            if not material:
                raise HTTPException(status_code=404, detail="Material not found")
            return material
        ```
3.  **Gunakan UUID v4:**
    Menggunakan UUID versi 4 (acak) alih-alih ID integer berurutan (`1`, `2`, `3`) untuk seluruh objek data. Hal ini membatasi kemampuan penyerang melakukan serangan enumerasi ID murni (*brute-force resource guessing*).
