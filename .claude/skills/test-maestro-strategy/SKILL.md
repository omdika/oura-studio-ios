---
name: test-maestro-strategy
description: Compile Maestro-native UI test strategy for Oura Studios — what to test, TC breakdown, and feasibility. Use when the user asks for strategi maestro, test plan maestro, matrix coverage maestro, or TS-NNN strategy. Outputs TS-NNN strategy doc only, no YAML, no run. YAML authoring lives in test-maestro-write, execution lives in test-maestro-run.
---

# Oura Studios — Maestro Test Strategy Skill

This skill governs STRATEGY for Maestro UI tests only. It never writes YAML flows or runs tests (see `test-maestro-write`, `test-maestro-run`). Token-efficient and Maestro-native.

---

## 🛑 CORE MANDATE

1.  **Strategy ONLY:** No `test/scripts/*.yaml` writes. No `maestro test`, no `allure` commands. Output is ONE file: `doc/test/TS-{NNN}-{kebab-case-title}-strategy.md` + TC stubs listed inside it.
2.  **Canonical paths (non-negotiable):**
    *   Strategy: `doc/test/TS-{NNN}-{kebab-case-title}-strategy.md`
    *   Scenario docs (created later by `test-maestro-write`): `doc/test/TC-{NNN}-{kebab-case-title}.md`
    *   Flows (created later): `test/scripts/TC{NNN}_{PascalCaseTitle}.yaml`
3.  **Token Conservation:** No full-file reads on long files. Use targeted grep for `Text("...")`, `title: "..."`, `.navigationTitle(...)` to get real labels. Keep replies direct (<5 lines prose).

---

## 📁 Canonical Structure

```
doc/test/
├── TS-{NNN}-{kebab-case-title}-strategy.md   ← THIS SKILL outputs this
└── TC-{NNN}-{kebab-case-title}.md            ← test-maestro-write outputs this later
test/scripts/
└── TC{NNN}_{PascalCaseTitle}.yaml          ← test-maestro-write outputs this later
```

### ID Assignment
*   `ls doc/test/` → find highest `TS-NNN` and highest `TC-NNN` independently. Increment by 1. If none exist, start at `TS-001` / `TC-001`.
*   Strategy `TS-NNN` groups 2-6 `TC-NNN` flows for ONE feature/screen.

### Linking Rule (strategy must declare it)
*   Strategy doc must contain a table: `| TC-ID | Title | Type | Priority | Maestro Flow (planned) |`
*   Planned flow path format: `test/scripts/TC{NNN}_{PascalCaseTitle}.yaml` (not yet existing — marked `(planned)`).

---

## 🔀 When To Use What (avoid overlap)

| Ask | Skill |
|---|---|
| `strategi maestro untuk X`, `test plan maestro`, `matrix TC maestro` | **this skill** |
| `buat maestro test`, `tulis flow maestro`, `maestro yaml` | `test-maestro-write` |
| `run maestro`, `jalankan test maestro`, `generate allure report` | `test-maestro-run` |
| HPP calc, API contract, `XCTAssert*`, button `isEnabled` | `sdet-test-strategy` / `test-write` (NOT Maestro) |
| Masih ide kabur, belum jelas scope | `dev-brainstorm` dulu, baru ke sini |

---

## ✅ Maestro Feasibility Filter (mandatory per TC)

Mark each TC as `Feasible` or `Delegate`. Maestro CAN:

*   `launchApp`, `assertVisible` / `assertNotVisible`, `tapOn`, `back`
*   `inputText` (tap field first), `eraseText`, `takeScreenshot: TC{NNN}_NN_Name`
*   `runFlow: {when: {visible: "X"}}` for optional sheets/permissions
*   Read-only journeys: navigate → assert → dismiss with `Batal`/`back`

Maestro CANNOT (mark as `Delegate`, do NOT put in Maestro matrix):

*   Assert button `isEnabled == false`, `waitForExistence(timeout:)` precision → delegate to XCUITest (`test-write`)
*   Verify HPP/margin/stock math, API status codes, DB state → delegate to API tests (`sdet-test-strategy`)
*   Mock API / network error injection → delegate to XCUITest + `MockAPIService`
*   Destructive write without cleanup (save/delete that pollutes DB) → only allow if TC explicitly declares cleanup steps, else keep read-only

---

## 📝 Strategy Document Template (`TS-NNN`)

```markdown
# TS-{NNN} — {Feature} - Maestro Strategy

| Field | Value |
|---|---|
| **ID** | TS-{NNN} |
| **Feature** | {Screen/module, e.g. Dashboard / BerandaView} |
| **Type** | Maestro UI (black-box journey) |
| **App ID** | `handika.oura-studio-frontend` |
| **Added Date** | {YYYY-MM-DD} |

## 1. Objective & Scope
*   **Goal:** {1-2 sentences, what journey is covered}
*   **Out-of-scope (delegated):** {e.g. HPP math → API, disabled-state → XCUITest}

## 2. Pre-requisites & Setup
*   **Simulator:** Booted (e.g. iPhone 17 Pro), app installed.
*   **Auth:** Logged-in precondition (Google SSO). No `clearState: true`.
*   **Seed labels (grep-verified):** `"OURA STUDIOS"`, `"{Button}"`, `"{Sheet Title}"`

## 3. TC Matrix (planned — YAML by test-maestro-write)

| TC-ID | Title | Type | Priority | Feasibility | Planned Maestro Flow |
|---|---|---|---|---|---|
| TC-{NNN} | {e.g. Dashboard + open sheet} | Positive | P1 | Feasible | `test/scripts/TC{NNN}_{Pascal}.yaml` (planned) |
| TC-{NNN+1} | {e.g. Sheet dismiss} | Negative/Edge | P2 | Feasible | `test/scripts/...yaml` (planned) |

## 4. Per-TC Step Outline (assert-level, no YAML syntax)
### TC-{NNN} — {Title}
1. Launch → assert `"..."` visible → screenshot `TC{NNN}_01_...`
2. Tap `"{Button}"` → assert `"{Sheet}"` visible → screenshot `TC{NNN}_02_...`
3. Tap `"Batal"`/`back` → assert back → screenshot `TC{NNN}_03_...`

## 5. Screenshot Policy
*   `takeScreenshot: TC{NNN}_NN_Name` at start, each transition/assert, end. No `..`, no empty, no dir path.
```

**Priority guide:** P1 = core journey broken = app unusable. P2 = validation/dismiss/list sync. P3 = edge/cosmetic.

---

## 🛠 Workflow (max 3 turns)

### Phase 1: Scope + Label Discovery (1 turn)
1.  Confirm feature/screen. If ambiguous, ask max 2 questions.
2.  `grep` SwiftUI source for real strings (`Text(`, `title:`, `navigationTitle`). Never invent labels.
3.  `ls doc/test/` for highest TS/TC numbers.

### Phase 2: Matrix + Feasibility (1 turn)
1.  Propose 2-6 TCs with Type/Priority/Feasibility. Apply Feasibility Filter — drop or mark `Delegate` anything Maestro can't do.
2.  Get user approval on matrix (no file yet).

### Phase 3: Write Strategy File (1 turn)
1.  Write `doc/test/TS-{NNN}-{kebab-case-title}-strategy.md` using template above.
2.  Do NOT create `TC-*.md` or `*.yaml` — those belong to `test-maestro-write`. State in final reply: `Next: test-maestro-write for TC-xxx`.

---

## 🛡️ Safety Rules (non-negotiable, must appear in strategy §2)

*   **Read-only by default:** all TCs assert + dismiss (`Batal`/`back`). Write paths only with explicit cleanup.
*   **Auth precondition:** Google Sign-In. Document logged-in assumption; fresh-install lands on login, not dashboard.
*   **Verify labels by grep** before writing any step — never invent button/sheet strings.
