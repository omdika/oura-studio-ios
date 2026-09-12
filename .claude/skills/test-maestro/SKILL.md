---
name: test-maestro
description: Design, document, and write Maestro UI automated tests for Oura Studios, and generate reports using Allure. Use this skill whenever the user asks to create, run, or update Maestro automated test flows and Allure reporting. Trigger phrases: "buat maestro test", "tambah test maestro", "run maestro", "generate allure report", "report allure".
---

# Oura Studios — Maestro UI Test & Allure Reporting Skill

This skill governs the creation of declarative UI automation tests using Maestro, and the reporting of those test results using Allure. It is highly optimized for **Token Efficiency** and **Xcode Visibility**, ensuring that specifications are defined first, files are visible inside Xcode, and tool executions use minimal context.

---

## 🛑 CORE MANDATE: Token-Efficient & Spec-First Development

Following the standards of the `dev-fullstack` skill, this skill enforces a strict, specification-driven workflow with zero-tolerance for code-first or guess-work development:

1.  **Xcode Visibility Rule:** 
    All scenario documentation markdown files MUST be written directly inside the **`doc/`** folder (e.g., `doc/TC-{NNN}-{kebab-case-title}.md`) so they are fully visible and editable in Xcode's Navigator.
2.  **Strict Handoff & Spec Updates FIRST:**
    Do NOT write the Maestro YAML script before updating documentation.
    -   **Step 1:** Create or update the test specification in the Xcode-visible `doc/TC-{NNN}-{kebab-case-title}.md` file.
    -   **Step 2:** Write/refine the Maestro YAML test script under the `test/scripts/` directory.
3.  **Token Conservation:**
    -   NEVER use full file reads on long files unless absolutely necessary.
    -   Use targeted `grep_search` to find button labels, text elements, and view flows rather than reading entire source files.
    -   Keep your interactive feedback extremely direct, clear, and high-signal (less than 3 lines of prose per response).

---

## 📁 Canonical Directory & File Naming Structure

To maintain consistency and cross-referencing:

```
oura studio frontend/
├── doc/
│   └── TC-{NNN}-{kebab-case-title}.md            ← Scenario Doc (Visible in Xcode!)
└── test/
    └── scripts/
        └── TC{NNN}_{PascalCaseTitle}.yaml         ← Maestro YAML Script
```

### Linking Rule
*   **The Scenario Doc (`doc/TC-xxx.md`)** must contain:
    ```markdown
    **Maestro Flow:** `test/scripts/TC{NNN}_{PascalCaseTitle}.yaml`
    ```
*   **The Maestro YAML Script (`test/scripts/TCxxx.yaml`)** must start with a comment pointing back to the doc:
    ```yaml
    # Doc: doc/TC-{NNN}-{kebab-case-title}.md
    ```

---

## 📝 Part 1: Scenario Document Template (`doc/TC-xxx.md`)

```markdown
# TC-{NNN} — {Short Title} - Maestro UI Test

| Field | Value |
|---|---|
| **ID** | TC-{NNN} |
| **Feature** | {Screen or module under test} |
| **Type** | Positive / Negative / Edge Case |
| **Priority** | P1 / P2 / P3 |
| **Maestro Flow** | `test/scripts/TC{NNN}_{PascalCaseTitle}.yaml` |
| **Added Date** | {YYYY-MM-DD} |

## 1. Objective & Scope
*   **Goal:** {What logic, transition, or UI state is being verified?}

## 2. Pre-requisites & Setup
*   **Simulator:** Running iOS Simulator (e.g. iPhone 17 Pro).
*   **App Status:** Installed Bundle ID `handika.oura-studio-frontend`.

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Assert UI:** Header `"OURA STUDIOS"` must be visible.
3.  **Tap Action:** Tap on `"{Button Text}"`.
4.  **Assert Transition:** Element `"{Expected Element}"` is visible.
```

---

## 🛠 Part 2: Maestro YAML Reference & Best Practices

All Maestro scripts use simple declarative YAML files:

```yaml
# Doc: doc/TC-{NNN}-{kebab-case-title}.md
appId: handika.oura-studio-frontend
---
- launchApp
- assertVisible: "OURA STUDIOS"
- tapOn: "Beli Bahan"
- assertVisible: "Tambah Pembelian"
- inputText: "Nama Bahan"
- eraseText: 5
- tapOn: "Batal"
- assertVisible: "OURA STUDIOS"
```

### Recommended Commands:
*   **Launch App:** `- launchApp` (optional: `clearState: true` to clear app data)
*   **Assert Visibility:** `- assertVisible: "Text Label"` or `- assertNotVisible: "Text"`
*   **Tapping:** `- tapOn: "Button Text"` (or tap using coordinates `- tapOn: {x: 100, y: 200}`)
*   **Typing Text:** `- inputText: "Your Text"` (always tap the text field first)
*   **Erase Text:** `- eraseText: {number_of_characters}`
*   **Navigation Back / Dismiss:** `- back`
*   **Waiting:** Prefer declarative assertions, but if needed: `- delay: 1000` (in milliseconds)
*   **Conditional/Optional Steps:**
    ```yaml
    - runFlow:
        when:
          visible: "Text that might appear"
        commands:
          - tapOn: "Ok"
    ```

---

## 📊 Part 3: Allure Integration & CLI Execution Workflow

Maestro can export JUnit XML, which Allure directly parses. Use the following commands to execute tests and view report results:

### Step 1: Run Maestro Test & Save JUnit XML
```bash
# Create directory for test results
mkdir -p test-results/maestro

# Run test flow and export XML
maestro test --format junit --output test-results/maestro/report.xml test/scripts/TC{NNN}_{PascalCaseTitle}.yaml
```

### Step 2: Generate Allure Report
```bash
# Build a clean Allure HTML report from the XML directory
allure generate test-results/maestro -o test-results/allure-report --clean
```

### Step 3: Open the Interactive Report
```bash
# Host the generated report locally and open in default browser
allure open test-results/allure-report
```
