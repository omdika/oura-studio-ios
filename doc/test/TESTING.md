# TESTING — Panduan Jalankan Tes & Laporan Allure (Frontend iOS)

Dokumen ini adalah referensi lengkap untuk menjalankan tes UI Maestro dan menghasilkan laporan Allure di `oura studio frontend`. Ringkasan cepat ada di `README.md` → `## 🧪 QA & Test Automation`.

## 1. Prasyarat

| Alat | Cara install |
|------|--------------|
| Xcode 15+ (untuk iOS Simulator) | App Store / developer.apple.com |
| Maestro CLI | `curl -FsSL https://get.maestro.mobile.dev \| bash` |
| Allure CLI | `brew install allure` |
| Python 3 | Sudah bawaan macOS |

**Simulator:** nyalakan satu iOS Simulator (contoh iPhone 17 Pro) dan pastikan app dengan Bundle ID `handika.oura-studio-frontend` sudah terinstall (build via Xcode sekali, atau `xcrun simctl install`).

Semua perintah dijalankan dari root folder `oura studio frontend/`.

## 2. Jalankan Satu Alur Tes

Contoh dengan `TC003_DashboardFlow.yaml`:

```bash
# 1. Siapkan direktori hasil
mkdir -p test-results/maestro

# 2. Jalankan flow Maestro → export JUnit XML + screenshot
maestro test --format junit \
  --output test-results/maestro/report.xml \
  --test-output-dir test-results/maestro-artifacts \
  test/scripts/TC003_DashboardFlow.yaml

# 3. Lampirkan screenshot terbaru ke Allure result (test-results/allure-results/)
python3 test/attach_screenshots.py --flow TC003_DashboardFlow --tc TC-003

# 4. Generate laporan Allure HTML
allure generate test-results/allure-results -o test-results/allure-report --clean

# 5. Buka laporan di browser
allure open test-results/allure-report
```

Catatan:
- `--test-output-dir` menaruh screenshot per run di `test-results/maestro-artifacts/<timestamp>/<flow>/takeScreenshot/`.
- `attach_screenshots.py` mengambil PNG terbaru dari folder itu dan menampilkannya di tab **Attachments** tiap tes dalam laporan Allure.
- `allure generate ... --clean` membersihkan `test-results/allure-report` lama sebelum generate ulang.

## 3. Daftar Alur Tes (Maestro Flow)

Semua ada di `test/scripts/`:

| File | TC ID | Skenario | Tipe | Dokumen |
|------|-------|----------|------|---------|
| `TC003_DashboardFlow.yaml` | TC-003 | Dashboard + sheet Beli Bahan (read-only) | Sanity / Positive | `doc/test/TC-003-dashboard-maestro-allure.md` |
| `TC004_TambahProdukManual.yaml` | TC-004 | Tambah produk manual (Free Size) | Write | `doc/test/TC-004-tambah-produk-manual.md` |
| `TC005_TambahStokSatu.yaml` | TC-005 | Stok Free Size 0 → 1 pcs | Write | `doc/test/TC-005-tambah-stok-satu.md` |
| `TC006_JualHargaDiskon.yaml` | TC-006 | Jual 1 pcs, harga Rp1.000, diskon Rp1.000 → total Rp0 | Write | `doc/test/TC-006-jual-harga-diskon.md` |

Strategi lanjutan (journey produk Rp0 → penjualan): `doc/test/TS-001-produk-nol-rupiah-ke-penjualan-strategy.md`.

## 4. Jalankan Semua Tes Sekaligus

Contoh one-liner di terminal (bash/zsh):

```bash
for f in test/scripts/TC*.yaml; do
  flow=$(basename "$f" .yaml)
  echo "=== Menjalankan $flow ==="
  maestro test --format junit \
    --output test-results/maestro/report.xml \
    --test-output-dir test-results/maestro-artifacts \
    "$f"
  python3 test/attach_screenshots.py --flow "$flow" --tc "${flow:5}"
done

allure generate test-results/allure-results -o test-results/allure-report --clean
allure open test-results/allure-report
```

> Catatan: `attach_screenshots.py` menimpa `test-results/allure-results/` setiap pemanggilan (`shutil.rmtree`). Untuk laporan **gabungan** semua tes, jalankan `attach_screenshots.py` per flow lalu gabungkan `allure-results` secara manual, atau sederhanakan dengan generate laporan per TC dan buka masing-masing.

## 5. Struktur Folder `test-results/`

```
test-results/
├── maestro/                 # JUnit XML hasil maestro test (report.xml + per-TC)
├── maestro-artifacts/       # Screenshot & artefak per run (disusun per timestamp)
├── allure-results/          # Hasil Allure (result JSON + attachment PNG)
├── allure-report/           # Laporan Allure HTML (output `allure generate`)
└── report.xml               # JUnit gabungan (contoh hasil terakhir)
```

Folder `test-results/` dan artefak di dalamnya biasanya **tidak di-commit** (cek `.gitignore`); hanya digunakan sebagai output lokal setelah menjalankan tes.

## 6. Troubleshooting Umum

| Masalah | Penyebab mungkin | Solusi |
|---------|------------------|--------|
| `maestro: command not found` | Belum install atau PATH belum ter-update | Install ulang Maestro, restart terminal, atau gunakan path penuh ke binary Maestro |
| Simulator tidak terbuka / app belum terinstall | Xcode belum build atau simctl belum dijalankan | Build via Xcode sekali, lalu `xcrun simctl install <udid> <app>.app` |
| `Element not found: ...` di report.xml | Elemen UI belum muncul atau ID berubah | Pastikan app di layar yang benar, cek teks elemen terbaru di `Screens/` atau doc TC terkait |
| `allure: command not found` | Belum install Allure CLI | `brew install allure` |
| Laporan Allure tidak ada screenshot | `attach_screenshots.py` belum dijalankan atau folder screenshot kosong | Jalankan skrip setelah `maestro test`, pastikan ada PNG di `test-results/maestro-artifacts/*/<flow>/takeScreenshot/` |

## 7. Catatan CI

Workflow GitHub saat ini (`.github/workflows/jekyll-gh-pages.yml`) hanya untuk publish docs, **belum ada CI yang menjalankan tes Maestro/Allure**. Untuk menambahkan CI tes, diperlukan runner macOS dengan Xcode + simulator, install Maestro & Allure, lalu menjalankan langkah di bagian 2–4 dan meng-upload `test-results/allure-report` sebagai artefak.

---
Sumber per-TC: `doc/test/TC-*.md` | Strategi: `doc/test/TS-001-produk-nol-rupiah-ke-penjualan-strategy.md`