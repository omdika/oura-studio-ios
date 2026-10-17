---
name: test-maestro-write
description: Design, document, and write Maestro UI test flows (YAML) for Oura Studios — spec-first, no execution. Use when the user asks to create or update a Maestro test, flow, or scenario doc. Trigger phrases: "buat maestro test", "tambah test maestro", "tulis flow maestro", "maestro yaml". Execution & reporting live in test-maestro-run.
---

# Oura Studios — Maestro Test Writing Skill

This skill governs WRITING declarative Maestro UI tests only. It never runs tests or builds reports (see `test-maestro-run`). Token-efficient and spec-first.

---

## 🛑 CORE MANDATE

1.  **Xcode Visibility Rule:** Scenario docs MUST live in **`doc/test/`** (`doc/test/TC-{NNN}-{kebab-case-title}.md`).
2.  **Spec FIRST, YAML second:** Do NOT write YAML before the doc exists/is updated.
    -   **Step 1:** Create/update `doc/test/TC-{NNN}-{kebab-case-title}.md`.
    -   **Step 2:** Write/refine `test/scripts/TC{NNN}_{PascalCaseTitle}.yaml`.
3.  **Token Conservation:** No full-file reads on long files; use targeted grep for button labels/text. Keep replies direct, high-signal (<3 lines prose).

---

## 📁 Canonical Structure

```
oura studio frontend/
├── doc/
│   └── test/
│       └── TC-{NNN}-{kebab-case-title}.md            ← Scenario Doc
└── test/
    └── scripts/
        └── TC{NNN}_{PascalCaseTitle}.yaml         ← Maestro YAML Script
```

### Linking Rule
*   Doc must contain: `**Maestro Flow:** \`test/scripts/TC{NNN}_{PascalCaseTitle}.yaml\``
*   YAML must start with: `# Doc: doc/test/TC-{NNN}-{kebab-case-title}.md`

---

## 📝 Scenario Document Template

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
*   **Auth:** {Logged-in precondition — see Safety Rules.}

## 3. Step-by-Step Flow & Assertions
1.  **Launch App:** App opens to main screen.
2.  **Assert UI:** Header `"OURA STUDIOS"` must be visible.
3.  **Screenshot:** Capture `TC{NNN}_01_Awal`.
4.  **Tap Action:** Tap on `"{Button Text}"`.
5.  **Assert Transition:** Element `"{Expected Element}"` is visible.
```

---

## 🛠 Maestro YAML Reference

```yaml
# Doc: doc/test/TC-{NNN}-{kebab-case-title}.md
appId: handika.oura-studio-frontend
---
- launchApp
- assertVisible: "OURA STUDIOS"
- takeScreenshot: TC{NNN}_01_Awal
- tapOn: "Beli Bahan"
- assertVisible: "Tambah Pembelian"
- takeScreenshot: TC{NNN}_02_SheetTerbuka
- tapOn: "Batal"
- assertVisible: "OURA STUDIOS"
- takeScreenshot: TC{NNN}_03_Akhir
```

### Recommended Commands
*   **Launch:** `- launchApp` (no `clearState: true` until login persistence is verified — see Safety).
*   **Assert:** `- assertVisible: "Text"` / `- assertNotVisible: "Text"`
*   **Tap:** `- tapOn: "Text"`; prefer accessibility id selectors for flaky/dynamic text where available.
*   **Type:** `- inputText: "..."` (tap field first); `- eraseText: {n}`
*   **Back/dismiss:** `- back`
*   **Wait:** prefer assertions; `- delay: 1000` only if needed.
*   **Screenshots (default ON):** `- takeScreenshot: TC{NNN}_01_NamaState` at key states (start, each transition/assert, end). `path` = filename w/o extension, subdirs allowed, never `..` or empty (flow fails otherwise). Output lands in `takeScreenshot/` of the flow's artifact bundle.
*   **Conditional:** `- runFlow: {when: {visible: "X"}, commands: [...]}` for optional sheets/permissions.

### Safety Rules (non-negotiable)
*   **Read-only by default:** flows assert + dismiss (`Batal`/`back`). Never tap save/delete/destructive buttons unless the TC explicitly covers a write path with cleanup.
*   **Auth precondition:** app uses Google Sign-In. Document the logged-in precondition in §2; do not assume fresh-install lands on dashboard.
*   **Verify labels by grep** (`Text("...")`, `title: "..."`, `.navigationTitle(...)`) before writing selectors — never invent strings.
