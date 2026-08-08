---
name: test-smoke
description: Run a fast pass/fail check that the Oura Studios app builds, launches, and every screen is reachable without crashing — no deep verification of business logic. Use this skill immediately after any build or code change, before doing anything else, and before handing off to sanity or regression testing. Trigger this whenever the user says things like "does it build", "quick check", "smoke test", or right after a dev skill finishes implementing something.
---

# Oura Studios — Smoke Test

The fastest possible check that nothing is fundamentally broken. This is not about correctness of business logic (HPP math, versioning rules, etc.) — it's purely "does the app start, and can I get to every screen without it crashing or hanging." Should take a few minutes, not longer. Run this after every single build, every time, no exceptions.

## What this skill does NOT check

Don't verify calculations, don't verify CRUD edge cases, don't verify data persistence correctness. That's `test-sanity` and `test-regression`'s job. If you catch yourself computing an expected HPP value or checking whether a delete was correctly blocked, you've drifted into sanity-testing — that's fine to note, but don't let it slow down the smoke pass itself.

## Checklist

Read the handoff document's Section 2 (Screens & Flows) once to get the current screen list — the checklist below reflects the structure at the time this skill was written, but the handoff is the source of truth if the app has grown new screens since.

**Launch & navigation**
- [ ] App builds without errors or warnings that block compilation
- [ ] App launches to the Beranda (Dashboard) screen without crashing
- [ ] Bottom nav has exactly 5 tabs: Beranda, Produksi, Produk, Penjualan, Lainnya — tapping each one navigates without crashing

**Produksi tab (4 sub-tabs)**
- [ ] Bahan sub-tab renders its list (even if empty) without crashing
- [ ] Resep sub-tab renders its list without crashing
- [ ] Optimasi sub-tab renders without crashing
- [ ] Produksi sub-tab renders without crashing
- [ ] Switching between all 4 sub-tabs repeatedly doesn't crash or leak obvious memory issues

**Core sheets/modals open and close**
- [ ] Tambah Pembelian sheet opens (from Bahan tab's "+" and from a material's Detail) and closes via "×" without crashing
- [ ] Tambah Resep sheet opens and closes without crashing
- [ ] Tapping into a Detail screen (material or pattern spec) and back-navigating returns cleanly to the list at its prior scroll position (not required to verify the scroll position is *exactly* right — just that it doesn't crash or reset to a blank state)
- [ ] "Tambah Varian" from `ProdukSizeGroupView` opens `AddSizeSheet`; tapping the fabric row opens `FabricPickerSheet` modal without crashing; the modal closes (via selection or "Batal") without crashing

**Produk tab — 3-level navigation (updated v1.8)**
The Produk tab now has a 3-level hierarchy. All three levels must be reachable without crashing:
- [ ] Produk tab list renders without crashing — each product card shows size-label rows (M, L, …), not individual fabric variants
- [ ] Tapping a size-label row (e.g. "M") navigates to `ProdukSizeGroupView` without crashing and shows fabric variants (M · Satin Pelangi, M · Waffle Merah, …)
- [ ] Tapping a fabric variant row in `ProdukSizeGroupView` navigates to `ProdukSizeDetailView` without crashing
- [ ] Tapping the product card header (product name + "›") navigates to `ProdukDetailView` without crashing — this is a separate navigation target from the size rows
- [ ] Back-navigating from each level returns to the previous level without crashing

**Penjualan / Lainnya**
- [ ] Penjualan tab renders without crashing
- [ ] Lainnya tab renders without crashing

**Basic network sanity (not correctness, just "doesn't hang or crash")**
- [ ] If a backend is connected, at least one list screen successfully loads data (or shows an empty/error state gracefully) rather than an infinite spinner or crash

## Known UI bug patterns to watch for (v2.3+)

These are real bugs that occurred in this codebase. If you see any of the following during the smoke pass, flag them explicitly — don't just note "something looked off":

| Symptom | Likely root cause | Fix reference |
|---|---|---|
| Sheet content appears at screen center or bottom instead of anchored to top | iOS 26 Liquid Glass changes `fullScreenCover` layout behavior — `ZStack(alignment:.top)` and `VStack.frame(maxHeight:.infinity)` both fail to override this | `SearchableDropdownField` and `TokenizedMultiSelectField` should use `NavigationStack` inside `fullScreenCover` (fixed in v2.3) |
| A "Done" button appears in the keyboard toolbar above a numeric or search field | `ToolbarItemGroup(placement: .keyboard)` was added and not removed | `NumericInputField` and `InlineSearchDropdownField` should have no keyboard toolbar (fixed in v2.3) |
| `InlineSearchDropdownField` shows an empty field with no list until user types | List was gated behind `isEditing` state | Should show existing items immediately on focus; "Tambah Baru" button visible without typing (fixed in v2.3) |
| Laporan Penjualan chart shows identical data regardless of which date range is selected | `getSalesReport` was ignoring `from`/`to` params | Chart data must change when date range preset is changed (fixed in v2.3) |

## Reporting results

Report as a simple pass/fail list matching the checklist above, not prose. For any failure, include: which item failed, what happened instead (crash log, error message, or hang description), and which screen/action triggered it. Don't attempt to fix failures as part of this skill — hand failures back to `dev-frontend` or `dev-backend` as appropriate, with enough detail to reproduce.

If everything passes, say so plainly and suggest whether `test-sanity` (if a specific feature just changed) or `test-regression` (if this is a milestone checkpoint) is the appropriate next step.
