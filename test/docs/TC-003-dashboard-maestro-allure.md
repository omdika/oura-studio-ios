# Test Case: TC-003 - Dashboard (BerandaView) Maestro Automation & Allure Reporting

## 1. Objective & Scope
*   **Goal:** To verify the core UI layout of the main Dashboard (`BerandaView`) and validate the transition to the "Tambah Pembelian" (Beli Bahan) modal sheet.
*   **Target Module:** Dashboard / Beranda
*   **Test Type:** Sanity UI Test (Maestro Automation)
*   **Report System:** Allure Report (via JUnit XML Export)

---

## 2. Pre-requisites & Setup
*   **iOS Simulator:** Open and running (e.g., iPhone 15 Pro).
*   **App Status:** The app `handika.oura-studio-frontend` is installed on the simulator.
*   **Dependencies:**
    *   **Maestro CLI:** Installed via `curl -FsSL https://get.maestro.mobile.dev | bash`
    *   **Allure CLI:** Installed via `brew install allure`

---

## 3. Maestro Test Definition (`test/scripts/dashboard_flow.yaml`)
Create this file in `test/scripts/dashboard_flow.yaml` to run the automated test:

```yaml
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

---

## 4. Execution & Allure Report Generation

Follow these command-line instructions to run the test and export the results to Allure:

### Step 1: Run Maestro and Output JUnit XML
Maestro natively outputs standard JUnit XML format, which Allure reads perfectly.
```bash
# Create results directory
mkdir -p test-results/maestro

# Run the test flow and export XML
maestro test --format junit --output test-results/maestro/report.xml test/scripts/dashboard_flow.yaml
```

### Step 2: Generate and Open Allure Report
```bash
# Generate the interactive HTML Allure report
allure generate test-results/maestro -o test-results/allure-report --clean

# View the report in your browser
allure open test-results/allure-report
```
