---
name: dev-fullstack
description: Coordinate and build backend (FastAPI) and frontend (SwiftUI) features for Oura Studios. CRITICAL MANDATE: You MUST update specifications FIRST before code. Update ONLY top 30-50 lines of handoff.md (Revision History) and create lightweight doc/versions/v3.xx.md in both repos. NEVER read full handoff.md. For DB schemas/API endpoints use api_contract.md; for screens use ui_spec.md.
---

# Oura Studios — Fullstack Dev Skill

This skill governs the end-to-end development of Oura Studios, ensuring tight synchronization between the FastAPI backend and the iOS SwiftUI client. It enforces design consistency, performance-first database patterns, and strict specification-driven development.

---

## 🛑 CORE MANDATE: Specification-First Development (Token-Efficient & Strict)

> **⚠️ ZERO TOLERANCE FOR CODE-FIRST DEVELOPMENT & FULL FILE READS:**
> Under no circumstances should functional code or configuration files be written BEFORE the revision history and version specs are updated.
> NEVER use full `read_file` on `handoff.md`. Always operate with targeted line limits to conserve API tokens. For domain-specific schemas, UI rules, or status, load only the modular spec files:
> - `doc/api_contract.md` for DB tables, Pydantic schemas, API endpoints, and CRUD audit rules.
> - `doc/ui_spec.md` for SwiftUI screen list, bottom navigation, and layout interactivities.
> - `doc/implementation_status.md` for open decisions, frontend milestone checklists, and seed data.

You must always execute this strict 3-step checklist BEFORE any implementation:

- [ ] **Step 1: Update Handoff Revision History (TOKEN EFFICIENT).**
      ⚠️ DO NOT read the entire `handoff.md` file! 
      Use `head` or read ONLY the first 30-50 lines of `doc/handoff.md` to locate the Revision History table.
      Add the new version row (e.g. `v3.22`) with status **`PLANNED`** directly at the top of the table in BOTH repos:
      * `doc/handoff.md` (Frontend repo)
      * `../backend/doc/handoff.md` (Backend repo)

- [ ] **Step 2: Create Version Specification File.**
      Create a dedicated lightweight markdown file `doc/versions/v3.xx.md` in BOTH repos.
      * Base the context ONLY on `context.md`, `doc/api_contract.md` (for backend/API), `doc/ui_spec.md` (for frontend UI), and targeted code search (`grep`). DO NOT load full historical handoffs.

- [ ] **Step 3: Commit Specifications.**
      Stage and commit the specifications before writing functional code.
---

## 🛠 Step-by-Step Development Workflow

For every fullstack feature or modification, you must execute this lifecycle:

### Phase 1: Research & Diagnosis
*   Use parallel search tools (`grep_search`, `XcodeGrep`) and target file reads to identify points of interest.
*   Analyze model structures, relations, and current API callers.
*   Identify bottlenecks: check for N+1 queries, unindexed foreign keys, or synchronous multi-request loops on the client side.

### Phase 2: Design & Specification (Token-Efficient Handoff Updates FIRST)
*   **Targeted Handoff Update:** Update ONLY the first 30–50 lines of `doc/handoff.md` (Revision History table) in both repositories using line-limited insertion. **DO NOT** use `read_file` to load the full `handoff.md` file.
*   **Create Version Spec:** Create a lightweight `doc/versions/v3.xx.md` file in both repositories. Base the context solely on `context.md` and targeted code searches (`grep`).
*   **Strict Boundary:** Do not write READMEs, scripts, or functional application code in this phase.

### Phase 3: Backend Implementation (FastAPI)
*   **Database & Schemas:** Update Pydantic schemas in `app/schemas/` or entity schemas.
*   **Routers & Queries:** Implement router endpoints in `app/routers/` using performance-first database patterns:
    *   *Avoid N+1 SQL queries:* Leverage `joinedload` on relationships (e.g. `.options(joinedload(ProductSize.product))`).
    *   *Safe Aggregations:* Use fallback values to prevent `NoneType` compilation crashes (e.g., `int(val) if val is not None else 0`).
*   **Compile Check:** Compile Python files via `python3 -m py_compile <files>` to ensure zero syntax errors.

### Phase 4: Frontend Implementation (SwiftUI)
*   **Network Models:** Update `Models/` or create new Codable models.
*   **APIService:** Update `APIService.swift` to invoke the new backend endpoint, avoiding loop-based client-side N+1 requests by fetching in bulk.
*   **UI Views:** Build or modify views using native SwiftUI, adhering to `OuraTheme.Colors` and card styles. Ensure action buttons are tied to `canSave` state and disabled properly when necessary.
*   **Compile Check:** Run `XcodeRefreshCodeIssuesInFile` and `BuildProject` to confirm successful build compilation.

### Phase 5: Verification & Push to Git
*   Perform static compile checks ONLY to confirm the fix works.
*   **NO AUTOMATED TESTS / NO PARALLEL SIMULATORS:** 
    * DO NOT execute `Run All Tests`, `Get Test List`, `xcodebuild test`, or automated UI tests.
    * DO NOT spawn or clone multiple iOS Simulators.
    * Use only `BuildProject` for Swift and `python3 -m py_compile` for Python.
*   **MANDATORY GIT PUSH:** Stage, commit with clean semantic messages, and **PUSH** changes to remote repository (`git push origin main` or active branch) in BOTH frontend and backend repositories before finishing the task.
---

## 💎 Technical & Performance Rules

1.  **No Client-Side N+1 Loops:** The iOS client must never fetch list items sequentially inside a loop. If a list screen needs data for multiple entities, create a bulk optimized `GET` endpoint on the backend and load the data in a single HTTP request.
2.  **Strict Navigation Conventions:** Hierarchical/drill-down views must use push navigation. Actions, creations, or forms must be presented as sheets/modals.
3.  **Strong Typing & Safety:** Maintain structural type-safety. Never suppress warnings or use prototype hacking. Always ensure nulls are handled defensively on both ends of the API contract.
