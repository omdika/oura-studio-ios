---
name: test-implementer
description: Mengimplementasikan skrip pengujian otomatis (unit test, integration test, UI automation, security test, regression, atau functional flows) baik di sisi frontend maupun backend berdasarkan dokumen spesifikasi pengujian yang tersedia di workspace (seperti di folder doc/test/ atau folder pengujian lainnya). Skill ini akan membaca spesifikasi pengujian sebagai kebenaran tunggal, membuat/memperbarui kode pengujian pada target yang relevan, memverifikasi build/menjalankan pengujian, dan memperbarui status skrip uji menjadi terimplementasi. Trigger phrases: "implementasikan skrip pengujian", "tulis test case", "buat otomatisasi test", "implementasikan pengujian frontend", "buat backend integration test".
---

# Oura Studios — General Test Implementer Skill

Skill ini memandu AI Agent dalam menerjemahkan skenario uji statis apa pun yang didefinisikan dalam dokumen spesifikasi pengujian menjadi skrip pengujian otomatis yang fungsional, andal, dan idiomatis pada seluruh lapisan arsitektur (frontend iOS, backend FastAPI, database ledger, atau alur integrasi end-to-end).

---

## 1. Dokumen Referensi Otoritatif (Authoritative References)

Setiap kali skill ini diaktifkan, AI Agent **wajib** mencari dan menganalisis berkas spesifikasi pengujian yang relevan di dalam workspace sebagai referensi tunggal kebenaran fungsional. Contoh dokumen referensi meliputi:
*   **Strategi Pengujian Keamanan & Kontrak API:** `doc/test/api_test_strategy.md`
*   **Spesifikasi Detail Kasus Uji (BOLA, Regression, Sanity, dll.):** `doc/test/api1_bola_test_spec.md`, `doc/test/api1_bola_test_spec.md`, dll.
*   **Panduan Handoff & UI Spec:** `doc/handoff.md`, `doc/ui_spec.md`, dll.

Setiap kode pengujian yang diimplementasikan harus selaras dengan preconditions, langkah-langkah navigasi/pemicu, payload input, dan kriteria keberhasilan (assertions) yang tercantum di dalam spesifikasi tersebut.

---

## 2. Aturan Pemilihan Jenis & Folder Pengujian (Canonical Targets)

Tergantung pada tipe pengujian yang tercantum di dalam spesifikasi dokumen, tempatkan berkas pengujian otomatis pada folder target yang tepat:

### 2.1 Unit & Integration Tests (Logika Bisnis & Komunikasi API)
*   **Deskripsi:** Memvalidasi fungsi murni, parsing model, validasi data, kalkulasi matematika (seperti Cutting Optimizer), state transitions, atau pemanggilan REST API nyata.
*   **Frontend iOS (Swift):**
    *   **Folder Target:** `oura studio frontendTests/` (buat sub-folder jika diperlukan seperti `Security/`, `Calculations/`, `Models/` untuk pengorganisasian yang rapi).
    *   **Target Membership:** Tambahkan ke target **`oura studio frontendTests`**.
*   **Backend FastAPI (Python):**
    *   **Folder Target:** `tests/` di repositori backend (misalnya `tests/unit/` atau `tests/integration/`).

### 2.2 UI Automation Tests (Alur Antarmuka & Interaksi Pengguna)
*   **Deskripsi:** Memvalidasi navigasi tab, pengisian form, penekanan tombol, penampilan dialog/modal, dan alur visual pengguna dari ujung ke ujung.
*   **Frontend iOS (Swift):**
    *   **Folder Target:** `oura studio frontendUITests/` (atau sub-folder seperti `Security/`, `Functional/`).
    *   **Target Membership:** Tambahkan ke target **`oura studio frontendUITests`**.

---

## 3. Langkah-demi-Langkah Alur Kerja Agent (Execution Protocol)

AI Agent wajib mengeksekusi implementasi pengujian dengan mengikuti siklus **Research -> Strategy -> Execution (Plan, Act, Validate)** berikut ini secara disiplin:

```
[Mulai]
  │
  ├──> 1. Cari & Baca Spesifikasi Uji (misal: di `doc/test/`)
  │
  ├──> 2. Rancang Strategi & Struktur Kode Pengujian
  │
  ├──> 3. Tulis Kode Pengujian di Target yang Sesuai (Swift/Python)
  │
  ├──> 4. Kompilasi & Jalankan Test (`BuildProject` / `RunSomeTests` / shell command)
  │
  ├──> 5. JIKA SELESAI & LULUS -> Perbarui status skrip uji menjadi 'Implemented' di dokumen .md
  │
  └──> [Selesai]
```

### Detil Langkah Prosedur:

#### Langkah 1: Membaca dan Menganalisis Spesifikasi Uji (Research)
Agent wajib mencari dan membaca dokumen spesifikasi uji yang ingin diimplementasikan. Ekstrak rincian teknis berikut:
*   **Scope:** Apakah ini pengujian Frontend UI, Unit Test logika kalkulasi, atau Integration/Security API?
*   **Preconditions:** Apa keadaan awal aplikasi (misal: user logged in, database seeded dengan material tertentu)?
*   **Input / Steps:** Parameter, payload JSON, atau interaksi UI yang harus dikirim.
*   **Expected Results:** Nilai asersi (assertions) yang menandakan kelulusan pengujian (seperti status code HTTP, nilai HPP spesifik, atau kemunculan element visual tertentu).

#### Langkah 2: Merancang Strategi & Struktur Kode (Strategy)
*   Tentukan framework uji yang digunakan. Di sisi iOS, gunakan framework `Testing` modern (Swift Testing) untuk pengujian unit/integrasi non-UI, atau `XCTest` untuk UI automation dan integration konvensional. Di sisi backend, gunakan `pytest`.
*   Tentukan penamaan file dan fungsi uji agar mereferensikan ID Kasus Uji (misal: `testTC_SEC_001_MaterialsGet_BOLA`).

#### Langkah 3: Menulis Kode Pengujian (Act)
*   Tulis kode pengujian yang bersih, terdokumentasi, dan bebas dari hardcoded credentials (ambil token/API key dari environment variables jika diperlukan).
*   Gunakan asinkron (`async throws`) untuk pengujian jaringan atau operasi I/O asinkron.
*   Sertakan komentar tautan ke dokumen spesifikasi di baris teratas berkas pengujian:
  ```swift
  // Spec: doc/test/<nama_dokumen_spesifikasi>.md
  ```

#### Langkah 4: Memvalidasi Hasil Pengujian (Validate)
*   **iOS:** Jalankan tool `BuildProject` untuk memastikan tidak ada kesalahan kompilasi. Jalankan skrip uji tersebut menggunakan `RunSomeTests` atau `RunAllTests` untuk memvalidasi kelulusannya.
*   **Backend:** Jalankan perintah pytest di terminal melalui `run_shell_command` (misal: `pytest tests/`).
*   Jika pengujian gagal atau build error, analisis error log, perbaiki kode pengujian, dan ulangi langkah validasi hingga berhasil lulus.

#### Langkah 5: Memperbarui Status di Dokumen Spesifikasi
Setelah skrip pengujian berhasil dijalankan dan terbukti **LULUS (Passed)**, Agent **wajib** memperbarui status implementasi di dokumen spesifikasi markdown terkait:
*   Buka berkas spesifikasi markdown tempat kasus uji tersebut didefinisikan.
*   Ubah penanda status kasus uji yang bersangkutan menjadi terimplementasi:
    *   **Contoh:** `Status Skrip Uji: ⭕ Belum Diimplementasikan (Planned)` -> `Status Skrip Uji: ✅ Diimplementasikan (Implemented)`
*   Pastikan penggantian teks markdown ini presisi dan tidak merusak elemen pemformatan tabel atau tautan lainnya.

---

## 4. Panduan & Konvensi Tambahan

1.  **Immutability of Credentials:** Jangan pernah menulis kredensial sensitif secara statis di dalam file pengujian. Selalu gunakan variabel lingkungan atau Keychain Manager mock.
2.  **Mocking vs Real Connection:** Selalu periksa apakah pengujian harus diarahkan ke layanan tiruan (`MockAPIService`) atau endpoint live (`APIService`). Integrasikan parameter flag bypass autentikasi (`--uitest-bypass-auth`) jika diperlukan untuk pengujian UI otomatis.
3.  **Graceful Recovery:** Jika pengujian melibatkan manipulasi data (seperti `POST` atau `DELETE`), pastikan pengujian melakukan pengembalian state database (*cleanup/rollback*) agar tidak mengganggu jalannya skenario pengujian lain yang berjalan setelahnya.
4.  **Strict Validation & Fail Loudly (Prinsip Ketangguhan):** 
    *   Pengujian yang tangguh (*robust*) wajib menghasilkan respon yang sesuai dengan kondisi aslinya. Jika data prasyarat atau variabel lingkungan (seperti `JWT_OWNER`) tidak tersedia atau disabotase, pengujian **TIDAK BOLEH** disamarkan agar "selalu lulus" (*silent pass*) menggunakan bypass mock.
    *   Jika prasyarat pengujian hilang atau tidak valid, pengujian **wajib langsung digagalkan secara eksplisit** menggunakan `XCTFail()` atau melempar error (`throw`) di fase setup (`setUpWithError`), sehingga tim pengembang segera mengetahui adanya masalah konfigurasi lingkungan uji.
    *   Setiap asersi status code HTTP (`XCTAssertEqual`) wajib dieksekusi secara langsung tanpa dibungkus pengaman `if-else` yang melompati proses verifikasi sesungguhnya.
