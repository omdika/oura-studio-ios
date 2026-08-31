---
name: sdet-test-strategy
description: Compiles a highly structured, scalable, and readable automation test strategy using an SDET approach. It generates markdown-based strategies organizing tests by explicit scenarios, covering both API Integration (with toggleable Mock/Real API configurations) and UI tests. Features token-saving rules for efficient handoff and codebase reading.
---

# Oura Studios — SDET Automation Test Strategy Skill

This skill governs the design, structuring, and compilation of comprehensive, scalable, and highly readable **Automation Test Strategies** with an **SDET (Software Development Engineer in Test)** approach. It focuses on drafting detailed, scenario-by-scenario testing specifications that cover both **API Integration Tests** and **UI Tests**, with built-in flexibility to toggle between **Mock API** or **Real API** data strategies based on project requirements.

---

## 🛑 CORE MANDATE: Token-Efficient & High-Signal Strategy Formulating

To prevent context window bloat and maintain a fast, cost-effective, and highly focused interaction, this skill enforces a strict, structured strategy phase.

1.  **NEVER Read or Write Large Files Fully:**
    *   Do NOT fully load `doc/handoff.md` or large source files unless absolutely necessary. For specific specifications, use the modular files:
        *   `doc/api_contract.md` for database schemas, tables, constraint validations, and backend API contract routes.
        *   `doc/ui_spec.md` for SwiftUI view elements, screen navigation, forms, and accessibility identifiers.
        *   `doc/implementation_status.md` for open decisions, seed data, and milestone status.
    *   If reading a long file is required, use `read_file` with explicit `start_line` and `end_line` parameters (aim for 50-100 line chunks).
    *   To update files like `doc/handoff.md` (Revision History), ONLY use the `replace` tool to make targeted surgical edits. Do NOT use `write_file` to overwrite large documents.
2.  **Strict Phase-Based SDET Process:**
    *   **Phase 1: Context & Requirements Gathering (Max 1-2 turns):** Inspect the target screens/endpoints using high-precision tools like `grep_search`. Define the boundaries, constraints, and whether to use **Mock API** or **Real API** data strategies.
    *   **Phase 2: Strategy Drafting & Feedback (Max 1-2 turns):** Propose the testing matrix, identifying dependencies, UI accessibility identifiers, and endpoint contracts.
    *   **Phase 3: File Generation (1 turn):** Physically write the compiled strategy markdown to disk under `test/docs/` (e.g., `test/docs/TC-xxx-[feature]-strategy.md`) so that test executors/scripts can read it.
3.  **SDET-Driven Architecture:**
    *   Design with **scalability and readability** in mind: group assertions clearly into Setup, Action, and Assertion phases.
    *   Establish reusable utility paradigms, page-object/robot patterns for UI, and automated seed factory patterns for backend.

---

## 🛠 SDET Test Strategy Core Principles

### 1. API Integration vs. UI Automation Split
A complete SDET strategy addresses verification at both the programmatic layer (API Integration) and the visual presentation layer (UI/UX).

*   **API Integration Testing:**
    *   Focuses on verifying contract compliance, request/response validation, data serialization, and response codes (e.g., `200 OK`, `400 Bad Request`, `422 Unprocessable Entity`).
    *   Asserts business calculations, formulas (such as costing, margins, and HPP), and state transitions.
*   **UI Testing (SwiftUI + XCUITest):**
    *   Focuses on user journey, layout compliance, form inputs, validation triggers (enabling/disabling of buttons), and modal sheet workflows.
    *   Leverages explicit `.accessibilityIdentifier` elements rather than brittle text matching.

### 2. Flexible API Data Strategy (Toggleable)
The strategy must explicitly declare the API data pattern and specify how test states are managed:

*   **Option A: Mock API Strategy** (Fast, isolated, deterministic):
    *   *Usage:* Ideal for UI testing, rapid CI feedback, or offline-capable verification.
    *   *Approach:* Declare exact JSON fixtures and specify Mock Server or client-side Mock API overrides (`MockAPIService`).
    *   *Verification:* Ensure edge cases (network timeouts, slow responses, validation errors) are simulated.
*   **Option B: Real Data API Strategy** (E2E integration, real database mutations):
    *   *Usage:* Verifying true system boundaries, third-party sync, database constraints, and end-to-end user flows.
    *   *Approach:* Define a clear **State Injection** plan. Seed pre-requisite records (such as specific fabrics or inventory balances) directly or via API endpoints before running tests.
    *   *Cleanup:* Specify precise post-test cleanup/teardown steps (e.g., DELETE endpoints or database rollbacks) to prevent state pollution.

---

## 📄 Standardized SDET Test Strategy Template (`test/docs/TC-xxx.md`)

When generating a test strategy document, use the following standardized Markdown template to ensure high readability and scalability.

```markdown
# Automation Test Strategy: [Feature/Module Name]

| Field | Value |
|---|---|
| **Strategy ID** | TS-[NNN] / TC-[NNN] |
| **Module Under Test** | [e.g., Production Batch Costing, Sales Checkout] |
| **Data Strategy** | [Mock API / Real API] |
| **Target Frameworks**| API Integration: [e.g., Swift Testing / Python pytest] <br> UI Automation: [XCUITest] |
| **Date Compiled** | [YYYY-MM-DD] |

---

## 1. Architectural Overview & Preconditions
[Provide a brief 3-4 sentence overview of the technical architecture of this feature and how the test automation framework interacts with it.]

### Preconditions & Setup:
*   **Authentication:** [Specify credentials or token bypass flags, e.g., `--uitest-bypass-auth`]
*   **Required State / Seed Data:**
    *   [Database record A, e.g., "Supplier 'Indotex' exists with ID 10"]
    *   [Material record B, e.g., "Kain Satin with cost Rp 50,000/meter"]
*   **Environment Config:** [e.g., Backend Base URL, mock/live API flag toggle]

---

## 2. API Integration Test Suite (Per Scenario)

### TS-[NNN]-API-01: [Scenario Title - e.g., Positive Purchase Material Entry]
*   **Objective:** [What behavior or business logic is being validated?]
*   **Endpoint under Test:** `POST /api/v1/materials/purchase`
*   **Test Data Setup:**
    ```json
    {
      "supplier_id": 10,
      "material_id": 5,
      "quantity": 10.0,
      "unit_cost": 50000.0
    }
    ```
*   **Execution Steps:**
    1. Send request payload with authentication token.
    2. Retrieve response and parse JSON.
*   **Assertion Points (Definitive Checks):**
    *   [ ] Response status code is `200 OK` or `201 Created`.
    *   [ ] JSON field `id` is not null.
    *   [ ] Database state check: Retrieve purchase record by ID and verify `status` is "Draft".
    *   [ ] Costing verification: Trigger HPP recalculation endpoint and verify output matches `Rp 50,000`.

### TS-[NNN]-API-02: [Scenario Title - e.g., Negative Validation Constraint]
*   **Objective:** [e.g., Verify negative quantities are rejected]
*   **Endpoint under Test:** `POST /api/v1/materials/purchase`
*   **Test Data Setup:**
    ```json
    {
      "supplier_id": 10,
      "material_id": 5,
      "quantity": -1.0,
      "unit_cost": 50000.0
    }
    ```
*   **Assertion Points:**
    *   [ ] Response status code is `422 Unprocessable Entity` or `400 Bad Request`.
    *   [ ] Error message contains validation field: `"quantity must be greater than 0"`.

---

## 3. UI Automation Test Suite (Per Scenario)

### TS-[NNN]-UI-01: [Scenario Title - e.g., Navigating and Submitting Valid Form]
*   **Objective:** [Validate the form is fillable, button state triggers, and sheet dismisses on success.]
*   **Data Strategy Context:** [e.g., Mocking API response to return success, or Live API with seeded data]
*   **Automation Steps:**
    | Step | Action | Element / Identifier | Target Interaction |
    |---|---|---|---|
    | 1 | Navigate to Bahan tab | `app.tabBars.buttons["Produksi"]` | Tap |
    | 2 | Select "Bahan" segment | `app.buttons["Bahan"]` | Tap |
    | 3 | Tap Floating Add Button | `app.buttons["Tambah Pembelian"]` | Tap |
    | 4 | Select Supplier | `app.buttons["dropdown-Supplier"]` | Tap → Tap `app.buttons["item-Indotex"]` |
    | 5 | Input Quantity | `app.textFields["Jumlah (m)"]` | Type "10.0" |
    | 6 | Input Unit Price | `app.textFields["Harga per Meter"]` | Type "50000" |
    | 7 | Submit Form | `app.navigationBars.buttons["Simpan"]` | Tap |
*   **Verification & Assertion Points:**
    *   [ ] Navigation check: Form sheet dismisses (`XCTAssertFalse(app.sheets["Tambah Pembelian"].exists)`).
    *   [ ] List synchronization check: The new entry "Indotex" with quantity "10.0m" appears in the scroll view.
    *   [ ] Screenshot validation: Capture screen state after submission.

### TS-[NNN]-UI-02: [Scenario Title - e.g., Validation Feedback and Disable State]
*   **Objective:** [Verify save button remains disabled until mandatory fields are filled.]
*   **Automation Steps:**
    | Step | Action | Element / Identifier | Target Interaction |
    |---|---|---|---|
    | 1 | Open "Tambah Pembelian" Form | `app.buttons["Tambah Pembelian"]` | Tap |
    | 2 | Check Save Button State | `app.navigationBars.buttons["Simpan"]` | Verify disabled state |
    | 3 | Input Quantity only | `app.textFields["Jumlah (m)"]` | Type "10.0" |
    | 4 | Re-check Save Button State | `app.navigationBars.buttons["Simpan"]` | Verify still disabled |
*   **Verification & Assertion Points:**
    *   [ ] `XCTAssertFalse(app.navigationBars.buttons["Simpan"].isEnabled)` before inputting price.
    *   [ ] UI error prompt or validation banner is rendered on empty fields if applicable.

---

## 4. Teardown & Post-Execution Cleanup (Real API Only)
*   **Strategy:** [Describe cleanup approach to maintain test isolation]
    *   *Step 1:* Issue standard `DELETE /api/v1/materials/purchase/{id}` command.
    *   *Step 2:* Verify purchase list no longer returns deleted ID.
```

---

## 🚀 SDET Step-by-Step Strategy Formulation Workflow

### Phase 1: Setup & Target Analysis (Token-Efficient)
1.  **Analyze Request Scope:** Check which business domain (Penjualan, Produk, Produksi, Bahan, Resep) or features are targeted.
2.  **Targeted Discovery:**
    *   Run `grep_search` to find existing `.swift` files for views, or `.py` files for controllers/schemas to extract current accessibility IDs and endpoint routes.
    *   Check `test/docs/` to avoid naming/ID collisions. Increment the highest TC/TS-xxx number by 1.
3.  **Confirm Data Strategy:** Clarify if the strategy should design around a Mock API or a Real Data API (with state injection & teardown).

### Phase 2: Formulating the Strategy
1.  **Map Out Scenarios:** List both Positive, Negative, and Edge scenarios clearly. Ensure tests are grouped logically.
2.  **Ensure Readability & Scalability:**
    *   Avoid monolithic test descriptions. Keep steps clean and direct.
    *   Declare specific elements and accessibility identifiers in the UI test section.

### Phase 3: Strategy File Delivery
1.  **Write Strategy to Disk:** Use `write_file` to physically save the compiled markdown strategy to `test/docs/TC-xxx-[kebab-case-title].md`.
2.  **Update Handoff / Tracker:** Use the `replace` tool to perform a surgical update on `doc/handoff.md` (or the tracking sheet) to mark the strategy as drafted and ready. Do NOT write the entire handoff file back.
