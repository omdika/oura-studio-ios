---
name: dev-fullstack
description: Coordinate and build both backend (FastAPI/SQLAlchemy) and frontend (SwiftUI) features for Oura Studios. Use this skill whenever a feature or change spans both frontend and backend layers (e.g., adding reports, modifying schemas, integrating new endpoints, sync operations, performance bottlenecks, or bug fixes across the stack). CRITICAL MANDATE: You MUST always update the handoff specifications first in both repositories before writing any functional code, and ensure all changes are successfully committed and pushed to their respective Git repositories.
---

# Oura Studios — Fullstack Dev Skill

This skill governs the end-to-end development of Oura Studios, ensuring tight synchronization between the FastAPI backend and the iOS SwiftUI client. It enforces design consistency, performance-first database patterns, and strict specification-driven development.

---

## 🛑 CORE MANDATE: Specification-First Development (No Code First!)

Under no circumstances should functional code be written before the intended design and API contracts are fully documented. You must always perform the following steps **before** touching any business logic:

1.  **Analyze the Requirement:** Determine whether changes are required in the backend schema, API router, frontend network model, or UI view layers.
2.  **Update Handoff & Version Docs First:**
    *   **Frontend Repo:** Update the `doc/handoff.md` Revision History table and create a specific version document under `doc/versions/v3.xx.md`.
    *   **Backend Repo:** Update the `../backend/doc/handoff.md` Revision History table and create a corresponding version document under `../backend/doc/versions/v3.xx.md`.
    *   Ensure the version docs contain detailed API contracts, database queries, and layout/view specifications.
3.  **Obtain Conceptual Alignment:** Confirm the plan with the user before executing the code.

---

## 🛠 Step-by-Step Development Workflow

For every fullstack feature or modification, you must execute this lifecycle:

### Phase 1: Research & Diagnosis
*   Use parallel search tools (`grep_search`, `XcodeGrep`) and target file reads to identify points of interest.
*   Analyze model structures, relations, and current API callers.
*   Identify bottlenecks: check for N+1 queries, unindexed foreign keys, or synchronous multi-request loops on the client side.

### Phase 2: Design & Specification (Specs First)
*   Write and commit the specification plans (`v3.xx.md` and `handoff.md` in both repos) as detailed in the Core Mandate.

### Phase 3: Backend Implementation (FastAPI)
*   **Database & Schemas:** Update Pydantic schemas in `app/schemas/reports.py` or entity schemas.
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
