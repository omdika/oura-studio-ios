---
name: sdet-test-implementer
description: Mengimplementasikan strategi pengujian (API Integration & UI Automation) yang dibuat oleh `sdet-test-strategy` menjadi skrip uji nyata yang highly readable, scalable secara horizontal & vertikal, dan highly configurable.
---

# Oura Studios — SDET Test Implementer Skill

Skill ini bertugas menerjemahkan dokumen strategi pengujian (dari skill `sdet-test-strategy`) menjadi skrip uji nyata (XCUITest untuk UI dan Swift Testing/XCTest untuk API Integration) yang berkualitas tinggi, mudah dibaca, skalabel secara horizontal & vertikal, serta mudah dikonfigurasi.

---

## 📂 STRUKTUR & PRINSIP UTAMA SKILL

### 1. Folder & File Organization (Horizontal Scalability)
*   **Modularitas Penuh:** Setiap skrip uji harus berdiri sendiri dalam file terpisah di `test/scripts/` tanpa memodifikasi file induk terpusat secara merusak.
*   **Naming Conventions:** 
    *   Dokumen strategi: `test/docs/TC-{NNN}-{kebab-case-title}.md`
    *   Skrip uji: `test/scripts/TC{NNN}_{PascalCaseTitle}.swift`
*   **Dual-Linking Rule:** Skrip uji wajib memiliki komentar di baris pertama yang merujuk ke dokumen strateginya, dan dokumen strategi wajib mencantumkan tautan ke file skrip uji.

### 2. Keterbacaan Tinggi (High Readability & AAA Pattern)
*   Menggunakan pola **Arrange-Act-Assert (AAA)** atau **Given-When-Then** yang dituliskan secara eksplisit dalam komentar kode.
*   Nama fungsi pengujian wajib deskriptif, merepresentasikan skenario spesifik (contoh: `testTC101_TambahPenjualan_SuccessWithValidInputs()`).
*   Menghindari *hardcoded value* yang membingungkan dengan mendefinisikan *test data model* atau konstanta lokal yang jelas di bagian *Arrange*.

### 3. Skalabilitas Vertikal (Architectural Patterns)
*   **UI Testing (Robot Pattern):** Untuk menghindari kode XCUITest yang kotor dan berulang, gunakan **Robot Pattern** (Page Object Model versi modern). Buat objek Robot khusus untuk setiap layar (contoh: `PenjualanListRobot`, `TambahPenjualanRobot`) yang membungkus kueri elemen (`app.buttons`, `app.textFields`) dan aksi-aksi dasarnya. Pengujian utama hanya memanggil rangkaian metode berantai (*chainable methods*) dari robot tersebut.
*   **API Testing (Service Wrapper/Helper):** Buat utilitas pengujian bersama untuk menangani penyiapan data (*data seeding*), autentikasi bypass, dan verifikasi respons skema API tanpa harus menulis ulang kode HTTP request secara manual di setiap skrip uji.

### 4. Kemudahan Konfigurasi (High Configurability)
*   **Launch Arguments & Flags:** Skrip uji harus mendukung konfigurasi dinamis melalui `XCUIApplication().launchArguments` seperti:
    *   `--uitest-bypass-auth` untuk melompati layar login.
    *   `--use-mock-api` untuk memaksa aplikasi menggunakan data mock lokal.
    *   `--backend-url [URL]` untuk menguji endpoint lingkungan tertentu.
*   **API Data Toggle:** Skrip harus bisa berjalan dalam mode **Mock API** (menggunakan berkas JSON fixture lokal) atau **Real API** (menjalankan seeder/cleanup data di database nyata) berdasarkan konfigurasi environment yang mudah diubah tanpa mengubah logika pengujian utama.

---

## 📄 ARTIFAK TEMPLATE

### A. Template XCUITest dengan Robot Pattern (Swift)
Pola struktur Robot Pattern yang *chainable* agar kode tes bersih dan elegan:

```swift
// Doc: test/docs/TC-101-tambah-penjualan.md
import XCTest

extension oura_studio_frontendUITests {
    @MainActor
    func testTC101_TambahPenjualan_Success() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-bypass-auth", "--use-mock-api"]
        app.launch()
        
        // Arrange & Act (Menggunakan Robot Pattern)
        PenjualanListRobot(app: app)
            .goToTambahPenjualan()
            .pilihProduk("Kemeja Flanel")
            .isiJumlah(10)
            .isiTotalHarga(1500000)
            .simpan()
        // Assert
            .verifyPenjualanMunculDiDaftar("Kemeja Flanel", jumlah: "10")
    }
}
```

### B. Template Robot Helper Class
Mengabstraksikan elemen UI agar jika ada perubahan layout, perubahan hanya dilakukan di satu tempat (Robot Class):

```swift
class TambahPenjualanRobot {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
        XCTAssertTrue(app.navigationBars["Tambah Penjualan"].waitForExistence(timeout: 5))
    }
    
    func pilihProduk(_ nama: String) -> TambahPenjualanRobot {
        app.textFields["pilih_produk_dropdown"].tap()
        app.buttons[nama].tap()
        return self
    }
    
    func isiJumlah(_ nilai: Int) -> TambahPenjualanRobot {
        let field = app.textFields["jumlah_input_field"]
        field.tap()
        field.typeText("\(nilai)")
        return self
    }
    
    func isiTotalHarga(_ nilai: Int) -> TambahPenjualanRobot {
        let field = app.textFields["total_harga_input_field"]
        field.tap()
        field.typeText("\(nilai)")
        return self
    }
    
    @discardableResult
    func simpan() -> PenjualanListRobot {
        app.buttons["simpan_penjualan_button"].tap()
        return PenjualanListRobot(app: app)
    }
}
```

---

## 🛠 ALUR KERJA IMPLEMENTASI SKILL

Saat skill ini diaktifkan, ikuti langkah-langkah terstruktur berikut:

1.  **Langkah 1: Analisis Strategi Pengujian**
    *   Temukan dan baca berkas dokumen strategi pengujian di `test/docs/TC-xxx.md`.
    *   Pahami modul, jenis data strategy (Mock vs. Real), prasyarat (*preconditions*), dan detail langkah-langkah skenario.

2.  **Langkah 2: Verifikasi Accessibility Identifier**
    *   Buka berkas tampilan SwiftUI yang diuji (misal: `TambahPenjualanSheet.swift`).
    *   Pastikan semua komponen interaktif (tombol, bidang input, daftar item) telah memiliki pengidentifikasi aksesibilitas `.accessibilityIdentifier("...")` yang unik dan konsisten dengan dokumen `doc/ui_spec.md`.
    *   Jika belum, lakukan modifikasi pada file SwiftUI untuk menambahkannya terlebih dahulu sebelum menulis skrip tes.

3.  **Langkah 3: Pembuatan/Pembaruan Robot Helper**
    *   Jika belum ada kelas Robot untuk layar yang sedang diuji, buat kelas Robot baru di tempat terstruktur (misal dalam ekstensi pengujian atau file helper terpisah).
    *   Pastikan semua metode Robot mengembalikan nilai `self` (atau Robot layar berikutnya) demi mendukung pemanggilan berantai (*method chaining*).

4.  **Langkah 4: Penulisan Skrip Pengujian**
    *   Buat skrip pengujian baru di `test/scripts/TC{NNN}_{PascalCaseTitle}.swift` dengan mengimpor modul `XCTest` dan memperluas target pengujian `oura_studio_frontendUITests`.
    *   Tulis pengujian menggunakan pola AAA yang jelas.

5.  **Langkah 5: Validasi & Uji Coba**
    *   Gunakan `XcodeRefreshCodeIssuesInFile` pada file pengujian untuk mendeteksi kesalahan kompilasi secara instan.
    *   Gunakan `BuildProject` untuk memastikan proyek dapat terkompilasi dengan sempurna setelah kode baru ditambahkan.
    *   Jalankan tes menggunakan `RunSomeTests` atau `RunAllTests` untuk memastikan fungsionalitas tes berjalan hijau dan andal.
