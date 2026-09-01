---
name: dev-bugfix
description: Specialized skill for diagnosing and fixing frontend (SwiftUI) and backend (FastAPI) bugs. ENFORCES absolute token-saving practices: NEVER read full handoff.md (max 30-50 lines), always reproduce bugs first, write surgical edits with replace, and update lightweight bug-spec files.
---

# Oura Studios — Bug-fixing Dev Skill

This skill governs diagnosing, reproducing, and fixing bugs across the FastAPI backend and iOS SwiftUI client. It is strictly optimized to prevent token bloat, maximize focus, and ensure high-integrity surgical resolutions.

---

## 🛑 CORE MANDATE: Token-Efficient & Specification-First Bug-fixing

> **⚠️ ZERO TOLERANCE FOR GUESSWORK & TOKEN BLOAT:**
> *   **NEVER read the full `handoff.md` file.** It exceeds 1,000 lines. Reading it wastes critical context tokens. Only read the first 30–50 lines to locate the Revision History.
> *   **NO CODE CHANGES BEFORE SPECIFICATION:** You must update the Revision History and create a lightweight bugfix spec BEFORE writing any code.
> *   **EMPIRICAL REPRODUCTION:** You must reproduce the bug first or clearly document its exact cause before applying a fix.

You must always execute this strict 3-step checklist BEFORE writing any bugfix code:

- [ ] **Step 1: Record Bugfix in Revision History (Top 30-50 lines of handoff.md only).**
      Read ONLY the first 30–50 lines of `doc/handoff.md` to identify the Revision History table.
      Insert a new version entry (e.g. `v3.xx.1` or similar patch/minor) with status **`PLANNED`** at the top of the table in both repositories:
      * `doc/handoff.md` (Frontend)
      * `../backend/doc/handoff.md` (Backend)

- [ ] **Step 2: Create a Lightweight Bug-Specification File.**
      ⚠️ **MANDATORY:** You MUST first read the root `CONTEXT.md` file as an initial reference to align with core business logic and system boundaries.
      Create `doc/versions/v3.xx-bugfix.md` in both repositories containing:
      * **Symptom & Impact:** What is failing and what is the business impact.
      * **Root Cause:** Explanation of why it fails.
      * **Reproduction Steps:** Step-by-step instructions or test code to reproduce the failure.
      * **Proposed Surgical Fix:** Exact target files, classes/functions, and the change logic.
      * **Validation Strategy:** Specific compile/test commands to prove the fix.

- [ ] **Step 3: Commit Bug-Specification.**
      Stage and commit the specification files before making any functional changes.

---

## 🛠 Step-by-Step Bugfix Lifecycle

### Phase 1: Research, Reproduction & Diagnosis (Token-Saving)
1.  **Initial Reference:** Always read the root `CONTEXT.md` first to understand the core context, domain boundaries, and rules.
2.  **Surgical Code Searches:** Use `grep_search` (with narrow scopes via `include_pattern`, `total_max_matches` set to <= 50$) or `XcodeGrep` to find relevant files.
3.  **Targeted File Reads:** Use `read_file` with explicit `start_line` and `end_line` parameters to inspect relevant code blocks. Do not read entire large files.
4.  **Trace and Verify:** Walk through the execution path from the entry point (controller/endpoint/UI view) down to the logic layer.
5.  **Confirm Root Cause:** Identify the exact file, line, and state/type conflict causing the bug.

### Phase 2: Planning & Specs
*   Execute the Core Mandate: Update the top 30-50 lines of `doc/handoff.md` and create `doc/versions/v3.xx-bugfix.md` containing the bug analysis and validation plan.

### Phase 3: Surgical Execution (Targeted Edits)
1.  **Strictly Surgical:** Do not refactor unrelated files, clean up unrelated warnings, or formatting.
2.  **Use `replace` instead of `write_file`:** For existing files, use the `replace` tool with ample context to ensure a precise, token-efficient, and unambiguous replacement.
3.  **Defensive Programming:** Maintain structural type safety, handle nulls gracefully on both sides of the contract, and avoid quick-and-dirty type casts or warnings suppressions.

### Phase 4: Verification & Local Compilation
1.  **Targeted Compilation:**
    *   **Swift:** Use `XcodeRefreshCodeIssuesInFile` first for fast local diagnostics, then `BuildProject`.
    *   **Python:** Use `python3 -m py_compile <modified_files>` to check syntax.
2.  **No Full Test Suites:** DO NOT execute `Run All Tests` or boot multiple simulators. 
3.  **Run Specific Test:** If a specific test exists or was created, run ONLY that test via `RunSomeTests` or targeted script execution.

### Phase 5: Commit and Git Push
*   Stage and commit changes with a clean semantic commit message (e.g., `fix: resolve null pointer exception in inventory list sync`).
*   **MANDATORY GIT PUSH:** Push changes to remote branches immediately before finalizing the task.

---

## 💎 Token Efficiency Cheat Sheet for Bug Fixes

| Tool | Recommended Parameters | Token-Saving Purpose |
| :--- | :--- | :--- |
| `read_file` | `start_line`, `end_line` | Avoids loading large files entirely. |
| `grep_search` | `include_pattern`, `total_max_matches: 50` | Avoids massive search dumps and reduces search noise. |
| `replace` | `allow_multiple: false` | Prevents accidental duplicate edits and keeps edits highly precise. |
| `write_file` | Only for *new* small files | Avoids sending entire modified large files through context. |
