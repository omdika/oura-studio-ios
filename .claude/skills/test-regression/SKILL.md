---
name: test-regression
description: Run a comprehensive pass across every previously-verified feature and entity in Oura Studios to catch anything a recent change silently broke. Use this skill before considering a milestone, a tab, or a significant chunk of work "done" — not after every small change (that's test-smoke and test-sanity's job). Trigger this when the user says things like "full test", "regression test", "before I move on", "is everything still working", or when preparing to consider a screen/feature complete.
---

# Oura Studios — Regression Test

The comprehensive pass. Where `test-smoke` checks "does it crash" and `test-sanity` checks "does the thing I just built work correctly," this skill checks "did building that thing break something else that used to work." This is the most expensive of the three tests to run — use it at milestones, not after every edit.

## Prerequisite

Only run this after `test-smoke` passes. There's no point running a full regression pass on a build that doesn't even launch.

## Structure: derive the test matrix from the handoff, don't improvise it

This skill's checklist should be *generated from* the handoff document's Section 5 (CRUD Audit table) and Section 2 (Screens & Flows), not written from memory — the handoff is the definitive list of what "working" means for this app, and it gets updated as the app evolves. Re-read both sections fresh at the start of each regression pass rather than reusing a stale mental checklist from last time.

## Part 1 — Entity CRUD matrix (from Section 5)

For every entity in the CRUD audit table, test every operation marked ✅ in its row, including the conditional ones:

| Entity | What to verify this pass |
|---|---|
| Material | Create (inline via purchase), edit (PATCH), archive (not hard-delete once used) |
| MaterialPurchase | Create; edit+delete both branches (unused = full access, consumed = locked fields/blocked delete) |
| Supplier | Create (inline + standalone), edit (rename), delete (blocked if referenced) |
| Product | Create (inline via Tambah Resep), rename, archive/delete both branches |
| ProductSize | Create via Tambah Resep (auto-creates one row per fabric); create via AddSizeSheet free mode and variant mode (prefilledSizeLabel); edit (selling_price, reorder_min_qty) by **sizeId UUID** not sizeLabel; archive/delete both branches by sizeId UUID. **Key invariant (v1.7):** uniqueness is `(product_id, size_label, fabric_variant_name)` — "M · Satin" and "M · Waffle" are two distinct rows, "M · Satin" cannot be added twice. |
| PatternSpec | Create (one spec per fabric in a Tambah Resep save — 2 fabrics selected → 2 calls → 2 specs); in-place edit (unused version); new-version edit (used version); delete (only if unused) |
| PatternComponent | Add/remove rows within a PatternSpec save (full-array-replace behavior) |
| CuttingLayout | Suggest, persist, discard (only while status='suggested', blocked once 'used') |
| ProductionBatch | Create draft, edit qty_actual pre-confirm, confirm (locks), delete draft only (blocked once confirmed) |
| StockLedger | Confirm it is NEVER directly editable/deletable anywhere in the app — this should fail loudly if you find a way to do it |
| SalesOrder | Create, mark paid, cancel (verify stock actually restocks to the correct ProductSize variant) |
| Settings | Edit existing keys; confirm no create/delete UI exists (none should) |

Don't just test the "allowed" branch of each conditional rule — deliberately try the disallowed branch too (e.g. try to delete a consumed MaterialPurchase, try to hard-delete a Product with sales history) and confirm it's correctly blocked with the right error, not silently succeeding or crashing.

## Part 2 — Screen-level pass (from Section 2)

Walk every screen and sub-tab listed in Section 2 end to end with realistic data volume (not just 1-2 items):

- Dashboard: low-stock alerts reflect actual current stock, per fabric variant
- Produksi → Bahan: search/filter, drill into Detail, add purchase (fresh and pre-filled paths), edit/delete both consumed/unconsumed branches
- Produksi → Resep: Daftar Resep grouped list, Tambah Resep full flow (single fabric AND multi-fabric), Editor both version branches, Riwayat Versi read-only
- Produksi → Optimasi: run full optimization flow. Verify candidate rows show the **selected purchase's fabric-specific dimensions** — not the first fabric in the spec regardless of selection.
- Produksi → Produksi: confirm a batch, verify the **correct ProductSize variant** gets stock (not just any row sharing the same sizeLabel)
- **Produk tab — 3-level navigation (v1.8):**
  - ProdukListView: product card shows size-label rows (M, L) aggregated across all fabric variants. Tap "M" → ProdukSizeGroupView, NOT ProdukDetailView.
  - ProdukSizeGroupView (Level 2): only this size's fabric variants shown. "Tambah Varian" opens AddSizeSheet in variant mode (sizeLabel locked, fabricVariantName required). Swipe-to-archive affects only that single variant.
  - ProdukSizeDetailView (Level 3): HPP breakdown, price advisor, edit selling price + reorder min all via sizeId UUID.
  - ProdukDetailView (reached via card header "›" only): shows grouped size labels, "Tambah Ukuran" in free mode (both fields editable).
- Penjualan: create sale (product picker shows full displayLabel "M · Satin Pelangi"), cancel a sale (stock restores to correct variant)
- Lainnya: reports render, settings persist

## Part 3 — Cross-cutting checks (things that span multiple screens)

- Edit a MaterialPurchase's cost → `material.current_avg_cost` updates → flows into new production batch HPP, does NOT retroactively change a confirmed batch
- Create a PatternSpec new version → old ProductionBatch records still reference old version cost
- Cancel a SalesOrder → restocked quantity appears in Produk stock views for the correct variant
- **Fabric variant stock isolation (regression-critical, v1.7):** confirm production for "L · Waffle Merah" increments ONLY `L · Waffle Merah` stock. `L · Satin Pelangi` must stay unchanged. Test this explicitly whenever Tambah Resep, confirmBatch, or productSizeId lookup logic is touched — this was a real production bug before v1.7.
- **Optimizer dimension isolation (v1.7):** select Waffle Merah purchase in Optimasi Step 2 → candidate rows must show Waffle's cut dimensions. Select Satin purchase → same spec shows Satin's dimensions. Verify the switch is live (re-selecting a different purchase updates the displayed dimensions immediately).

## Part 4 — Component-level bug regression (v2.3+, run whenever picker/form components are touched)

These are bugs that actually occurred in this codebase. If any of these regress, it means a component that was fixed has been broken again — flag explicitly as a **regression**, not just "a bug."

| # | What to verify | How to trigger | Pass criteria | Bug to catch |
|---|---|---|---|---|
| R1 | Picker sheet top-anchoring (iOS 26 Liquid Glass) | Open `SearchableDropdownField` or `TokenizedMultiSelectField` on any iOS 26 device/simulator | Nav bar title visible at top; list items fill below it; all items tappable | Content at screen center/bottom — `ZStack(alignment:.top)` used instead of `NavigationStack` |
| R2 | No keyboard "Done" toolbar | Tap `NumericInputField` or `InlineSearchDropdownField` | Standard keyboard with no toolbar row above it | A "Done" button appears — `.toolbar { ToolbarItemGroup(placement:.keyboard) }` re-added |
| R3 | InlineSearchDropdownField immediate display | Tap any `InlineSearchDropdownField` with `onCreateNew` without typing | Items list and "Tambah Baru" button visible immediately on focus | Empty dropdown until typing — list gated behind `isEditing` state |
| R4 | Sales report date filtering | Laporan Penjualan: switch between "7 Hari" and "3 Bulan" presets | Chart data changes; 7 Hari shows fewer points than 3 Bulan | Identical chart regardless of selection — `getSalesReport` ignoring `from`/`to` |
| R5 | DateRangeField preset chips | Open date picker sheet in Laporan Penjualan | Tapping "Bulan Ini" updates both Dari/Sampai DatePickers to the correct month boundaries | Preset taps do nothing, or from/to don't match the preset's expected boundaries |

## Reporting results

Organize the report by Part 1 / Part 2 / Part 3 / Part 4, pass/fail per row, with enough detail on any failure to reproduce it (exact steps, exact data used). Flag anything that passed in a previous regression run but fails now as a **regression** specifically (not just "a bug") so it's clear something that used to work broke — that distinction matters for prioritizing the fix. End with a clear overall verdict: ready for the milestone, or not yet, and why.
