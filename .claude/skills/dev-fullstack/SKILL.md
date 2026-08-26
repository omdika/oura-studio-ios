---
name: dev-fullstack
description: Coordinate and build both backend (FastAPI/SQLAlchemy) and frontend (SwiftUI) features for Oura Studios. Use this skill whenever a feature or change spans both frontend and backend layers (e.g., adding reports, modifying schemas, integrating new endpoints, sync operations, performance bottlenecks, or bug fixes across the stack). CRITICAL MANDATE: You MUST always update the handoff specifications first (handoff.md and versions/v3.xx.md) in both repositories before writing any functional code, README files, or other files.
---

# Oura Studios — Fullstack Dev Skill

This skill governs the end-to-end development of Oura Studios, ensuring tight synchronization between the FastAPI backend and the iOS SwiftUI client. It enforces design consistency, performance-first database patterns, and strict specification-driven development.

---

## 🛑 CORE MANDATE: Specification-First Development (No Code/README First!)

> **⚠️ ZERO TOLERANCE FOR CODE-FIRST DEVELOPMENT:**
> Under no circumstances should functional code, configuration files, README files, or other documentation be written **BEFORE** the `handoff.md` and version spec `doc/versions/v3.xx.md` are edited and updated in **BOTH** frontend and backend repositories. 

You must always execute this strict 3-step checklist **BEFORE** any implementation:

- [ ] **Step 1: Update Handoff Revision History.**
      Add the new version row (e.g. `v3.26`) with status **`PLANNED`** directly at the top of the *Revision History* table inside:
      *   `doc/handoff.md` (Frontend repo)
      *   `../backend/doc/handoff.md` (Backend repo)
- [ ] **Step 2: Create Version Specification File.**
      Create a dedicated detailed markdown file describing exactly what is going to change:
      *   `doc/versions/v3.xx.md` (Frontend repo)
      *   `../backend/doc/versions/v3.xx.md` (Backend repo)
- [ ] **Step 3: Commit and Push Specifications (Optional but Recommended).**
      Stage and commit the handoff changes before writing any code to maintain a clean git history of design-first thinking.

---

## 🛠 Step-by-Step Development Workflow

For every fullstack feature or modification, you must execute this lifecycle:

### Phase 1: Research & Diagnosis
*   Use parallel search tools (`grep_search`, `XcodeGrep`) and target file reads to identify points of interest.
*   Analyze model structures, relations, and current API callers.
*   Identify bottlenecks: check for N+1 queries, unindexed foreign keys, or synchronous multi-request loops on the client side.

### Phase 2: Design & Specification (Handoff Updates FIRST)
*   Update the `doc/handoff.md` and create `doc/versions/v3.xx.md` in **both repositories** as detailed in the Core Mandate. **Do not write READMEs, scripts, or application code in this phase.**

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
*   Perform empirical validation to confirm the fix or feature works completely.
*   Stage and commit modified/new files with clean, semantic messages (e.g. `feat(backend): ...`, `perf(frontend): ...`).
*   Push to their respective remote GitHub repositories (`origin main`).

---

## 💎 Technical & Performance Rules

1.  **No Client-Side N+1 Loops:** The iOS client must never fetch list items sequentially inside a loop. If a list screen needs data for multiple entities, create a bulk optimized `GET` endpoint on the backend and load the data in a single HTTP request.
2.  **Strict Navigation Conventions:** Hierarchical/drill-down views must use push navigation. Actions, creations, or forms must be presented as sheets/modals.
3.  **Strong Typing & Safety:** Maintain structural type-safety. Never suppress warnings or use prototype hacking. Always ensure nulls are handled defensively on both ends of the API contract.
