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
4.  **Tap Action:** Tap on `"Beli Bahan"` to open the sheet.
5.  **Assert Transition:** Modal sheet `"Tambah Pembelian"` is visible.
6.  **Tap Action:** Tap `"Batal"` to dismiss the sheet.
7.  **Assert Dismissal:** Back on main dashboard, and `"OURA STUDIOS"` is visible again.

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

# 4. Tap on "Beli Bahan" to open the sheet
- tapOn: "Beli Bahan"

# 5. Assert that the sheet has successfully opened
- assertVisible: "Tambah Pembelian"

# 6. Tap "Batal" to dismiss the sheet
- tapOn: "Batal"

# 7. Assert that we are back on the main dashboard
- assertVisible: "OURA STUDIOS"
```

## 5. Execution & Allure Report Generation

Follow these command-line instructions to run the test and export the results to Allure:

### Step 1: Run Maestro and Output JUnit XML
```bash
# Create results directory
mkdir -p test-results/maestro

# Run the test flow and export XML
maestro test --format junit --output test-results/maestro/report.xml test/scripts/TC003_DashboardFlow.yaml
```

### Step 2: Generate and Open Allure Report
```bash
# Generate the interactive HTML Allure report
allure generate test-results/maestro -o test-results/allure-report --clean

# View the report in your browser
allure open test-results/allure-report
```
