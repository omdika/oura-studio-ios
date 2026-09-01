---
name: test-owasp-implementer
description: Melakukan implementasi skrip pengujian keamanan API otomatis berdasarkan dokumen strategi pengujian keamanan OWASP Top 10 (doc/test/api_test_strategy.md) dan spesifikasi detail kasus uji BOLA (doc/test/api1_bola_test_spec.md). Skill ini akan membaca dokumen tersebut sebagai referensi utama, menulis kode pengujian ke target pengujian unit (seperti oura studio frontendTests/), memvalidasi build, dan memperbarui status skrip uji dari 'Planned' menjadi 'Implemented' di dokumen spesifikasi setelah selesai. Trigger phrases: "implementasikan test bola", "tulis test case keamanan", "jalankan skrip uji api1", "buat pengujian owasp".
---

# Oura Studios — OWASP Test Implementer Skill

Skill ini memandu AI Agent dalam menerjemahkan skenario uji keamanan API statis (OWASP API Security Top 10) yang ada di folder `doc/test/` menjadi skrip pengujian otomatis fungsional (Swift asinkron menggunakan framework `Testing` atau `XCTest`) di dalam proyek iOS.

---

## 1. Dokumen Referensi Otoritatif (Authoritative References)

Setiap kali skill ini diaktifkan, AI Agent **wajib** membaca dan menggunakan dokumen berikut sebagai referensi tunggal kebenaran kontraktual pengujian:
1.  **Strategi Utama:** [`doc/test/api_test_strategy.md`](../../../doc/test/api_test_strategy.md)
2.  **Spesifikasi Detail BOLA (API1):** [`doc/test/api1_bola_test_spec.md`](../../../doc/test/api1_bola_test_spec.md)

Setiap modifikasi skrip harus selaras dengan endpoint, prasyarat, parameter header, payload, dan asersi yang didefinisikan dalam dokumen di atas.

---

## 2. Aturan Struktur Folder & Penamaan Berkas (Canonical Paths)

Skrip pengujian otomatis harus diletakkan pada folder target yang tepat sesuai dengan jenis pengujiannya:

### 2.1 Pengujian Integrasi / Kontrak API Keamanan (Swift)
*   **Folder Target:** `oura studio frontendTests/Security/`
*   **Penamaan Berkas:** `API{N}_{OWASPCategory}Tests.swift`
    *   Contoh untuk BOLA: `oura studio frontendTests/Security/API1_BOLASecurityTests.swift`
*   **Target Membership:** Berkas wajib ditambahkan sebagai anggota target Xcode **`oura studio frontendTests`** agar dapat dieksekusi selama unit testing berjalan.

### 2.2 Pengujian Alur UI Pengujian Keamanan (UI Automation)
*   **Folder Target:** `oura studio frontendUITests/Security/`
*   **Penamaan Berkas:** `API{N}_{OWASPCategory}FlowUITests.swift`
*   **Target Membership:** Berkas wajib ditambahkan sebagai anggota target Xcode **`oura studio frontendUITests`**.

---

## 3. Langkah-demi-Langkah Alur Kerja Agent (Execution Protocol)

AI Agent wajib mengeksekusi implementasi pengujian dengan mengikuti siklus **Research -> Strategy -> Execution (Plan, Act, Validate)** berikut ini:

```
[Mulai]
  │
  ├──> 1. Baca Skenario Uji di `doc/test/api1_bola_test_spec.md`
  │
  ├──> 2. Buat/Perbarui berkas pengujian Swift di `oura studio frontendTests/Security/`
  │
  ├──> 3. Validasi Build & Jalankan Test (`BuildProject` / `RunSomeTests`)
  │
  ├──> 4. JIKA TEST LULUS -> Ubah status 'Planned' menjadi 'Implemented' di spesifikasi .md
  │
  └──> [Selesai]
```

### Detil Langkah Prosedur:

#### Langkah 1: Membaca dan Menganalisis Spesifikasi Uji
Agent harus membuka `doc/test/api1_bola_test_spec.md` dan membaca kasus uji yang akan diimplementasikan (misalnya `TC-SEC-001` atau `TC-SEC-002`). Ambil informasi:
- Metode HTTP & Path Parameter (Resource UUID).
- Kebutuhan Header Token (`JWT_OWNER`, `JWT_ATTACKER`, atau tanpa token).
- Ekspektasi HTTP Status Code respons (misal `401` atau `403`).

#### Langkah 2: Membuat / Memperbarui Berkas Kode Pengujian (Act)
- Tulis kode pengujian integrasi Swift asinkron yang kokoh.
- Gunakan framework `XCTest` atau `Testing` baru (sesuai gaya penulisan test di folder proyek).
- Pastikan kode uji melakukan pemanggilan jaringan nyata menggunakan `URLSession.shared.data(for: request)` untuk memvalidasi proteksi backend secara real-time.
- Sertakan komentar tautan ke dokumen spesifikasi di baris teratas berkas:
  ```swift
  // Spec: doc/test/api1_bola_test_spec.md
  ```

#### Langkah 3: Memvalidasi Hasil Pengujian (Validate)
- Lakukan kompilasi proyek menggunakan tool `BuildProject`.
- Jalankan skrip pengujian spesifik yang baru ditulis menggunakan tool `RunSomeTests` atau `RunAllTests`.
- Pastikan tidak ada compiler warning atau error, serta asersi keamanan terbukti lulus (*assert passed*).

#### Langkah 4: Memperbarui Status Implementasi di Dokumen Spesifikasi
Setelah pengujian otomatis berhasil berjalan dan terverifikasi **LULUS (Passed)**, Agent **wajib** memperbarui status implementasi di dokumen spesifikasi `doc/test/api1_bola_test_spec.md`:
- Cari kasus uji yang bersangkutan di file `.md`.
- Ubah baris status:
  *   **Sebelumnya (Planned):**
      ```markdown
      *   **Status Skrip Uji:** ⭕ Belum Diimplementasikan (Planned)
      ```
  *   **Sesudahnya (Implemented):**
      ```markdown
      *   **Status Skrip Uji:** ✅ Diimplementasikan (Implemented)
      ```
- Pastikan penggantian ini akurat dan tidak merusak elemen teks markdown lainnya.

#### Langkah 5: Dokumentasi, Commit & Push
- Laporkan rangkuman penambahan skrip uji dan pembaruan dokumen spesifikasi kepada pengguna.
- Lakukan staging, commit, dan push perubahan secara berkala ke branch aktif Anda (`milestone-api-test`) sesuai permintaan pengguna.

---

## 4. Konvensi Penulisan Kode Uji (Code Conventions)

1.  **Asynchronous First:** Selalu gunakan asinkron (`async throws`) untuk setiap fungsi pengujian jaringan. Jangan memblokir utas (*thread blocking*).
2.  **Environment Variables:** Jangan pernah menuliskan token JWT asli di dalam kode (*no hardcoded credentials*). Ambil JWT dari variabel lingkungan seperti:
    ```swift
    let token = ProcessInfo.processInfo.environment["JWT_OWNER"]
    ```
3.  **Clean Up Database (Fixtures):** Jika pengujian memodifikasi data (seperti `PATCH` atau `POST`), pastikan pengujian mengembalikan state atau membersihkan data tersebut (jika didukung endpoint reset/rollback) agar database uji tetap konsisten untuk iterasi pengujian selanjutnya.
