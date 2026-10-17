# TC-003 — Dashboard Flow - Maestro UI Test

| Field | Value |
|---|---|
| **ID** | TC-003 |
| **Feature** | Dashboard / Beranda (`BerandaView`) |
| **Type** | Positive / Sanity UI Test |
| **Priority** | P1 |
| **Maestro Flow** | `test/scripts/TC003_DashboardFlow.yaml` |
| **Added Date** | 2026-09-09 |

## 1. Objective & Scope
*   **Goal:** To verify the core UI layout of the main Dashboard (`BerandaView`) and validate the transition to the "Tambah Pembelian" (Beli Bahan) modal sheet.

## 2. Pre-requisites & Setup
*   **Simulator:** Running iOS Simulator (e.g. iPhone 17 Pro).
*   **App Status:** Installed Bundle ID `handika.oura-studio-frontend`.
*   **Dependencies:**
    *   **Maestro CLI:** Installed via `curl -FsSL https://get.maestro.mobile.dev | bash`
    *   **Allure CLI:** Installed via `brew install allure`

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Assert Header:** Element `"OURA STUDIOS"` must be visible.
3.  **Assert Main Headings:** Section headings `"Aksi Cepat"` and `"Pendapatan Hari Ini"` must be visible.
4.  **Screenshot:** Capture `TC003_01_Dashboard` (dashboard awal).
5.  **Tap Action:** Tap on `"Beli Bahan"` to open the sheet.
6.  **Assert Transition:** Modal sheet `"Tambah Pembelian"` is visible.
7.  **Screenshot:** Capture `TC003_02_SheetTambahPembelian` (sheet terbuka).
8.  **Tap Action:** Tap `"Batal"` to dismiss the sheet.
9.  **Assert Dismissal:** Back on main dashboard, and `"OURA STUDIOS"` is visible again.
10. **Screenshot:** Capture `TC003_03_KembaliDashboard` (akhir, bukti kembali).

## 4. Maestro Test Definition (`test/scripts/TC003_DashboardFlow.yaml`)

```yaml
# Doc: doc/test/TC-003-dashboard-maestro-allure.md
appId: handika.oura-studio-frontend
---
# 1. Launch the application
- launchApp

# 2. Assert the Header elements exist
- assertVisible: "OURA STUDIOS"

# 3. Assert main section headings exist
- assertVisible: "Aksi Cepat"
- assertVisible: "Pendapatan Hari Ini"

# 4. Screenshot dashboard awal
- takeScreenshot: TC003_01_Dashboard

# 5. Tap on "Beli Bahan" to open the sheet
- tapOn: "Beli Bahan"

# 6. Assert that the sheet has successfully opened
- assertVisible: "Tambah Pembelian"

# 7. Screenshot sheet terbuka
- takeScreenshot: TC003_02_SheetTambahPembelian

# 8. Tap "Batal" to dismiss the sheet
- tapOn: "Batal"

# 9. Assert that we are back on the main dashboard
- assertVisible: "OURA STUDIOS"

# 10. Screenshot akhir (bukti kembali ke dashboard)
- takeScreenshot: TC003_03_KembaliDashboard
```

## 5. Execution & Allure Report Generation

Follow these command-line instructions to run the test and export the results to Allure:

### Step 1: Run Maestro and Output JUnit XML
```bash
# Create results directory
mkdir -p test-results/maestro

# Run the test flow and export XML (+ screenshots ke test-results/maestro-artifacts/*/takeScreenshot/)
maestro test --format junit --output test-results/maestro/report.xml --test-output-dir test-results/maestro-artifacts test/scripts/TC003_DashboardFlow.yaml
```

### Step 2: Lampirkan Screenshot + Generate Allure Report
```bash
# Ubah JUnit + PNG terbaru menjadi Allure result ber-attachment
python3 test/attach_screenshots.py

# Generate dari allure-results (bukan dari XML langsung agar screenshot inline)
allure generate test-results/allure-results -o test-results/allure-report --clean

# View the report in your browser (screenshot tampil di tab Attachments tiap test)
allure open test-results/allure-report
```
