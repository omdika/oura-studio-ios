---
name: dev-brainstorm
description: Collaborate with the user to brainstorm new features, architectural refactors, complex bug fixes, or comprehensive QA/testing strategies. Also supports Refinement Mode to improve existing concepts and test plans on disk. This skill is optimized for token efficiency. It guides the brainstorming session through structured phases and physically writes/creates or refines standardized version specifications (doc/versions/v3.xx.md) or specialized QA documents (test/docs/TC-xxx.md) directly to disk using file-writing tools, and updates handoff logs so that development or testing skills can execute them directly without token bloat.
---

# Oura Studios — Brainstorming & Planning Dev & QA Skill

This skill governs the initial collaborative phase of feature development, refactoring, bug investigation, or QA/testing strategy design. Its primary goal is to translate user ideas, business needs, bug reports, or quality assurance objectives into concrete, self-contained, and highly structured specification files (like `doc/versions/v3.xx.md` for features or `test/docs/TC-xxx.md` for QA strategies) that execution skills can run with immediately. It supports both **Creation Mode** (drafting new specifications) and **Refinement Mode** (improving existing files on disk).

---

## 🛑 CORE MANDATE: Token-Efficient & High-Signal Brainstorming

To prevent context window bloat and keep the conversation fast, cost-effective, and highly focused, this skill enforces a strict, structured brainstorming workflow.

1.  **NEVER Read or Write Large Files Fully:**
    *   Do NOT load `doc/handoff.md` fully (even though it has been refactored to be extremely compact). If you must read it, ONLY read the top 50 lines using `read_file`.
    *   Do NOT overwrite `doc/handoff.md` entirely. NEVER use `write_file` to rewrite the entire `doc/handoff.md` back.
    *   For existing context, read the specific modular specifications directly:
        *   `doc/api_contract.md` for database schemas, tables, constraints, API routes, and CRUD validation states.
        *   `doc/ui_spec.md` for screen specs, navigation tabs, layouts, and component properties.
        *   `doc/implementation_status.md` for open decisions, deployment milestones, and mock data setups.
    *   To update `doc/handoff.md` (Revision History), ONLY use the `replace` tool to perform high-precision surgical edits (e.g., inserting a new version row directly beneath the table header).
    *   Use highly targeted `grep_search` or line-limited `read_file` to understand other code files.
2.  **Strict Phase-Based Progression:**
    *   **Phase 1: Clarification & Research (Max 2 turns):** Gather requirements and research existing code/test boundaries. Ask at most 3 targeted, high-impact questions in a single turn.
    *   **Phase 2: Architectural & QA Proposal (Max 1-2 turns):** Propose exactly 1 or 2 options with clear pros/cons (including costing calculations, performance impact, or coverage & test automation complexity).
    *   **Phase 3: Physical Specification File Creation/Update & Handoff Integration (1 turn):** Physically create/write or update the final agreed-upon specification or test plan markdown file to disk (e.g. `doc/versions/v3.xx.md` or `test/docs/TC-xxx.md`) using file system tools (like `write_file`), and update the handoff/tracking files.
3.  **No Code/Script Implementation:**
    *   Do NOT write or modify functional code or XCUITest test scripts during the brainstorming phase. This skill is strictly for research, design, and specification.

---

## 🛠 Step-by-Step Brainstorming Workflow

### Phase 1: Clarification & Research
1.  **Determine Workflow Mode:**
    *   **Creation Mode (New Concepts):** If the request is for a new feature or QA strategy, research the relevant codebase boundaries.
    *   **Refinement Mode (Improving Existing Concepts):** If the request is to update/improve an existing `.md` file (e.g., `doc/versions/v3.43.md` or `test/docs/TC-xxx.md`), you MUST first use `read_file` to read the entire existing file to understand the current specification.
2.  **Analyze the Request:** Determine what business or quality domain is affected (Materials, Production, Products, Sales, Reports, or Test Automation/Regression).
3.  **Targeted Code/Doc Search:**
    *   Use `grep_search` to find relevant tables in the backend, views in the frontend, or existing test scripts in `test/scripts/` (e.g. `TC001_TambahPembelianKain.swift`).
    *   Check `CONTEXT.md` to align with the core business rules or testing standards (e.g. using swift-testing for unit tests, XCUITest for UI tests).
4.  **Ask Targeted Questions:** If requirements or requested updates are ambiguous, ask a maximum of 3 highly specific questions. For example:
    *   *Should this test cover API validation responses, UI-level transitions, or both?*
    *   *What are the exact edge cases, boundary values, or negative scenarios we need to assert?*

### Phase 2: Architectural & QA Proposal
Present a structured design option or improvement plan:
*   **For Creation Mode (New Concepts):** Propose a structured design option covering:
    *   **User Flow & UI Specs:** What screens/flows are added, changed, or under test? Does it use standard components (`CurrencyInputField`, etc.)?
    *   **Database, API, or Testing Impact:** What new endpoints, columns, mock data, or test targets are required?
    *   **Costing / HPP / Business Rules:** How does this affect core formulas, or what assertions are needed to verify costing correctness?
    *   **Complexity & Risks:** Identify potential flaky tests, database locking, sync issues, or test state pollution.
*   **For Refinement Mode (Improving Concepts):** Clearly outline the proposed modifications, additions, or deletions to the existing specification. Explain *why* these updates make the concept better or solve any new requirements.

### Phase 3: Physical File Creation/Update & Handoff Integration (The Deliverable)
Once the user approves the proposal, you MUST physically write/create or update the files directly to disk using file writing tools (e.g., `write_file`). Do not merely print them in the chat. They must exist on disk so that subsequent skills (like `dev-fullstack` or `test-write`) can execute them immediately.

#### For Feature / Refactor Brainstorming:
1.  **Update Handoff Revision History:**
    *   ONLY read the top 50 lines of `doc/handoff.md` to locate the Revision History table header (`| Version | Date | Changed by | Summary |` and `|---|---|---|---|`).
    *   **In Creation Mode:** Use the `replace` tool to surgically insert a new version row directly beneath the table header. Do NOT rewrite the entire file or use `write_file`.
        *Example `replace` pattern:*
        *   **old_string:**
            ```markdown
            | Version | Date | Changed by | Summary |
            |---|---|---|---|
            ```
        *   **new_string:**
            ```markdown
            | Version | Date | Changed by | Summary |
            |---|---|---|---|
            | v3.44 | 2026-08-28 | Frontend | **PLANNED: [Title]**. [Short description]. Rincian spesifikasi: `doc/versions/v3.44.md`. |
            ```
    *   **In Refinement Mode:** Use the `replace` tool with minimum surrounding context to update the status/notes of the existing version row in `doc/handoff.md` (e.g., updating a row from `PLANNED` to `IMPLEMENTED`).
2.  **Physically Create/Overwrite & Write Version Specification File:**
    *   **In Creation Mode:** Use `write_file` to create the lightweight markdown file `doc/versions/v3.xx.md` on disk (using the template below).
    *   **In Refinement Mode:** Use `write_file` to overwrite/update the existing file `doc/versions/v3.xx.md` with the new fully integrated specification.
    *   Ensure the file is completely saved and is entirely self-contained so execution skills (such as `dev-fullstack`) can read and execute it immediately.

#### For QA Strategy Brainstorming:
1.  **Physically Create/Overwrite & Write Test Case Documentation File:**
    *   **In Creation Mode:** Use `write_file` to create a dedicated file `test/docs/TC-xxx-[title].md` on disk following the QA Strategy template.
    *   **In Refinement Mode:** Use `write_file` to overwrite/update the existing file `test/docs/TC-xxx-[title].md` with the fully refined test scenarios.
    *   Ensure the file is completely saved and is highly declarative, defining the setup, injection, and assertion phases, so execution skills (such as `test-write`) can read and execute it immediately.

---

## 📄 Deliverable Templates

### A. Version Specification Template (`doc/versions/v3.xx.md`)
```markdown
# Version 3.xx - [Feature Title]

## 1. Problem / Opportunity
*   **Context:** [A concise 2-3 sentence description of the current state.]
*   **Objective:** [What does this specification achieve?]

## 2. User Flow & UX Specifications
*   **Entry Point:** [How does the user access this? (e.g., sheet modal from BerandaView)]
*   **UI Components:** [Identify standard components to use]
*   **Validation Rules (`canSave`):**
    *   [Constraint 1: e.g., "Quantity must be greater than 0"]
*   **State & Progressive Disclosure:** [e.g., "Disable Section B until Section A is valid"]

## 3. Database Schema Changes (FastAPI / SQLAlchemy)
*   **Affected Tables:** [Identify tables to modify or create]
*   **New / Modified Columns:**
    ```python
    column_name = Column(Type, nullable=True, default=...)
    ```

## 4. API Contract (FastAPI)
*   **Endpoints:**
    *   `POST /api/v1/new-endpoint`
        *   **Request/Response Body:** [JSON contracts]
        *   **Validation & Errors:** [List explicit errors: e.g., 409 Conflict]

## 5. Frontend Changes (SwiftUI)
*   **Codable Models & APIService:** [Updated definitions and routes]
*   **Views & Controllers:** [Specify exactly what files to create or edit]

## 6. Verification & Test Plan
*   **Smoke Test:** [How to verify compile and tab navigation work]
*   **Sanity Test Scenarios:** [Explicit scenarios to verify correctness]
```

### B. QA Strategy / Test Case Template (`test/docs/TC-xxx.md`)
```markdown
# Test Case: TC-xxx - [Test Case Title]

## 1. Objective & Scope
*   **Goal:** [What specific logic, edge case, or flow is being tested?]
*   **Target Module:** [e.g., Production Batch HPP calculation, Quick Sales Checkout]
*   **Test Type:** [e.g., Sanity UI Test, Integration, Regression API Test]

## 2. Pre-requisites & Setup (State Injection)
*   **Required DB State:** [What records must exist before testing? e.g., specific MaterialPurchase with Rp X cost]
*   **Authentication & Session:** [Auth state required]

## 3. Step-by-Step Execution Flow
1.  **Trigger Action:** [e.g., Fill TambahPembelianSheet, click Save]
2.  **Verify UI Transitions:** [e.g., Sheet is dismissed, Toast message is displayed]
3.  **Backend Verification:** [e.g., APIService is called, DB record is modified]

## 4. Assertion & Verification Criteria (Definitive Checks)
*   **Database Asserts:** [e.g., `material.current_avg_cost` recalculated to exactly Rp Y]
*   **UI / State Asserts:** [e.g., "Save button is disabled when quantity is negative"]
*   **Stock Ledger / Costing Asserts:** [e.g., `stock_ledger.change_qty` is -1, `unit_hpp_snapshot` matches batch HPP]
```

Using these structured templates ensures that developers, testers, or automated agent skills can execute implementation or script writing seamlessly with perfect context.
