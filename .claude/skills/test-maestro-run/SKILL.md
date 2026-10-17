---
name: test-maestro-run
description: Execute Maestro UI test flows and generate Allure reports with inline screenshots for Oura Studios. Use when the user asks to run tests, re-run, view results/screenshots, or build Allure reports. Trigger phrases: "run maestro", "jalankan test maestro", "generate allure report", "report allure", "lihat screenshot allure". Test authoring lives in the sibling skill test-maestro-write.
---

# Oura Studios — Maestro Test Execution & Reporting Skill

This skill governs RUNNING Maestro flows and REPORTING via Allure only. It never authors flows (see `test-maestro-write`). Token-efficient: verify env, run, attach, report.

---

## ⚠️ Environment Gotchas (read first)

*   **Minimal PATH:** non-interactive shells may have `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, hiding both CLIs. Binaries live at:
    *   Maestro: `~/.maestro/bin/maestro` (installed via `curl -FsSL https://get.maestro.mobile.dev | bash`)
    *   Allure: `/opt/homebrew/bin/allure` (via `brew install allure`)
    *   Fix per command: `export PATH="$HOME/.maestro/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"`
*   **Simulator must be booted** with the app installed — verify, don't assume:
    ```bash
    xcrun simctl list devices booted
    xcrun simctl listapps booted | grep -i "oura"
    ```
    Expected: a Booted device (e.g. iPhone 17 Pro) + `handika.oura-studio-frontend`.
*   **Auth precondition:** flows assume logged-in state. Never add `clearState: true` unless login persistence is verified.

---

## 📊 Execution Workflow

### Step 1: Run Maestro (JUnit + Screenshots)
```bash
mkdir -p test-results/maestro

# --test-output-dir WAJIB agar takeScreenshot tersimpan:
#   test-results/maestro-artifacts/<timestamp>/<Flow>/takeScreenshot/*.png
maestro test --format junit --output test-results/maestro/report.xml --test-output-dir test-results/maestro-artifacts test/scripts/TC{NNN}_{PascalCaseTitle}.yaml
```

### Step 2: Attach Screenshots & Generate Allure
JUnit XML carries no images, so convert JUnit + newest PNGs into an Allure result with attachments (helper already at `test/attach_screenshots.py`):
```bash
python3 test/attach_screenshots.py --flow TC{NNN}_{PascalCaseTitle} --tc TC-{NNN}

# Generate from allure-results (NOT from XML directly) so screenshots render inline
allure generate test-results/allure-results -o test-results/allure-report --clean
```

### Step 3: Open the Report
```bash
allure open test-results/allure-report
```
Screenshots appear under each test's **Attachments** tab. (Blocks the shell; for verification-only runs, Step 2 output + `find test-results/allure-report/data -name "*.png"` suffices.)

---

## 🧰 Reference

*   **Helper:** `test/attach_screenshots.py [--flow FLOW] [--tc TC-NNN]` — reads status from `test-results/maestro/report.xml`, copies newest `maestro-artifacts/*/FLOW/takeScreenshot/*.png` into `test-results/allure-results/` as `<uuid>-result.json` + attachments. Reusable for every TC.
*   **Artifact layout:** `test-results/maestro-artifacts/` is timestamped per run — old runs accumulate; screenshots shown are always from the latest run dir.
*   **Hygiene:** `test-results/` should stay git-ignored (report XML, artifacts, allure HTML are all regenerable).
*   **Troubleshooting:**
    *   `maestro/allure not found` → PATH gotcha above, not a missing install.
    *   Flow fails on `takeScreenshot` with `Invalid path` → path names a directory, contains `..`, or resolved empty.
    *   `assertVisible` fails right after launch → app likely sitting on login (Google SSO), not dashboard — precondition issue, not a product bug.
