# Skill: test-maestro-healer

# Oura Studios — Maestro Test Script Healer Skill

This skill governs ANALYZING and HEALING Maestro test scripts that FAILED. It reads Maestro run artifacts (logs + screen hierarchy), identifies which locator (id / accessibilityText) is missing from the screen, and applies the correct replacement directly to the YAML file. It can also edit HTML reports when needed.

---

## ⚠️ Environment Gotchas (read first)

*   **Artifacts must exist:** Maestro must have been run at least once so `test-results/maestro-artifacts/` contains run directories with `logs/maestro.log` and `screen-hierarchy/step-*.json`.
*   **No simulator needed for healing:** Healer works offline on artifacts; no booted simulator required.
*   **Agent edits YAML directly:** After analysis, the agent will edit `test/scripts/*.yaml` to replace missing/wrong locators with valid ones found on screen.
*   **Agent can edit HTML:** If needed, the agent can also edit HTML report files (e.g. `test-results/allure-report/`) based on analysis results.

---

## 🩺 Healing Workflow

### Step 1: Scan which flows failed
The agent scans `test-results/maestro-artifacts/` and reads each flow's `maestro.log` to find `CommandFailed` entries.

Example output:
```
❌ TC004_TambahProdukManual | GAGAL step 7 | Element not found: Id matching regex: fab-tambah-produk
❌ TC006_JualHargaDiskon   | GAGAL step 7 | Element not found: Id matching regex: fab-tambah-penjualan
✅ TC003_DashboardFlow     | Lulus
```

### Step 2: Analyze a specific failed flow
The agent:
1. Reads `test-results/maestro-artifacts/<run>/<flow>/logs/maestro.log` for the error message.
2. Reads `test-results/maestro-artifacts/<run>/<flow>/screen-hierarchy/step-*.json` to collect all UI elements actually present on screen.
3. Compares the missing locator (from error) against available elements.
4. Determines the correct replacement (text or id that exists on screen).

### Step 3: Agent applies fixes directly to YAML
Based on the analysis, the agent edits `test/scripts/<flow>.yaml`:
- Replaces `id: "fab-tambah-produk"` → `tapOn: "Tambah"` (or whatever valid text/id exists on screen).
- Replaces `id: "fab-tambah-penjualan"` → `tapOn: "Tambah Produk"` (or whatever valid text/id exists on screen).
- Any other locator mismatches found during analysis.

### Step 4: Re-run Maestro to verify
After edits, the agent re-runs the fixed flow:
```bash
maestro test --format junit --output test-results/maestro/report-TC004.xml --test-output-dir test-results/maestro-artifacts test/scripts/TC004_TambahProdukManual.yaml
```

### Step 5: Edit HTML reports (optional)
If the user requests, the agent can also edit HTML report files in `test-results/allure-report/` to reflect corrected results or annotations.

---

## 🧰 Reference

*   **Artifact layout:** `test-results/maestro-artifacts/<timestamp>/<Flow>/logs/maestro.log` + `screen-hierarchy/step-*.json` + `screenshots/step-*.png`.
*   **YAML scripts:** `test/scripts/TC003_DashboardFlow.yaml`, `TC004_TambahProdukManual.yaml`, `TC005_TambahStokSatu.yaml`, `TC006_JualHargaDiskon.yaml`.
*   **Hygiene:** `test-results/` should stay git-ignored (regenerable).

---

## 🔍 Troubleshooting

*   `Tidak ada flow ditemukan di artifacts.` → Maestro belum pernah dijalankan, atau direktori artifacts kosong. Jalankan Maestro dulu via `test-maestro-run`.
*   `Tidak ada resource-id yang mirip di layar.` → ID yang dicari test benar-benar tidak ada. Periksa screenshot kegagalan (path dicetak di output) untuk menentukan elemen yang benar.
*   Step index dalam output healer adalah nomor langkah Maestro saat gagal, tidak selalu 1:1 dengan baris file YAML (karena `launchApp` dan perintah internal juga terhitung).

Base directory for this skill: /Users/handika/Desktop/PROJECT/oura-studio/frontend/oura studio frontend/.claude/skills/test-maestro-healer