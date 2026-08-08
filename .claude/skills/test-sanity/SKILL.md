---
name: test-sanity
description: Verify that a specific, recently-built or recently-changed feature in Oura Studios actually works correctly end to end, including its business logic and computed values — not just that it doesn't crash. Use this skill right after a dev skill finishes implementing or modifying a specific screen, endpoint, or calculation, and after test-smoke has already passed. Trigger this whenever the user says things like "check if X works", "verify the HPP calc", "test the new feature", or after any change to costing/versioning/CRUD logic specifically.
---

# Oura Studios — Sanity Test

Focused, correctness-level verification of *whatever just changed* — not a full app pass (that's `test-regression`). This skill exists because Oura Studios has genuinely non-trivial business logic (joint-product costing, weighted-average cost, conditional versioning, consumption-gated edit locks), and a screen that renders correctly can still compute the wrong number or allow an action that should be blocked.

## Prerequisite

Only run this after `test-smoke` has passed for the relevant area — no point sanity-testing calculations on a screen that crashes on open.

## Step 1 — Scope the test to what actually changed

Identify what was just built or modified (from the conversation, a diff, or the user's description). Map it back to the specific handoff section(s) it corresponds to — Section 1 for the underlying logic, Section 2 for the UI behavior, Section 3/4 for schema/API, Section 5 for CRUD rules. Don't re-test unrelated areas here — that's regression's job.

## Step 2 — Verify against the handoff's own worked examples where they exist

The handoff includes concrete worked numbers specifically so they can be used as test fixtures without inventing new data:
- **HPP breakdown example** (Section 1.6): a Scrunchie M in Satin with known fabric/labor/overhead costs and a known resulting HPP total and margin %. If you just built or changed HPP calculation, run this exact scenario through the actual implementation and check the output matches.
- **Cutting optimizer example** (Section 1.5): a 100×150cm piece with S (100×20) and L (120×30) patterns, with known yield/waste results for different layout strategies. Use this to verify the optimizer's output, not made-up dimensions — the handoff already worked out the correct answer by hand.
- **Tambah Resep worked example** (Section 2, Tab Resep): adding "Scrunchie XXL" in both Satin and Waffle in one flow, resulting in exactly 2 new PatternSpec rows. Use this to verify the multi-fabric creation flow end to end, including that both `POST /pattern-specs` calls actually fire and both rows appear in Daftar Resep afterward.

If the feature you're testing doesn't have a ready-made worked example in the handoff, construct a small one yourself with round numbers, compute the expected result by hand first, then verify the implementation matches — don't just eyeball whether the output "looks plausible."

## Step 3 — Verify the specific business rule(s) that apply to this feature

Pull the relevant rule(s) from Section 5's CRUD audit table (or Section 1's core concepts) and test them directly, not just the happy path:
- If testing MaterialPurchase edit/delete: verify an *unused* purchase is fully editable/deletable, then verify a *consumed* purchase correctly locks dimension fields and blocks delete (409), not just that the happy-path edit works.
- If testing PatternSpec save: verify a *never-used* spec updates in place (no new version, no `effective_from` change), then verify a spec with at least one production batch against it correctly creates a new version instead.
- If testing HPP/cost calculations: verify `material.current_avg_cost` actually recalculates after a purchase edit/delete, not just after create.
- If testing archive/delete logic (Material, Product, ProductSize): verify an entity with zero history hard-deletes, and one with any history archives instead — check both branches, not just one.

## Step 4 — Check the UI reflects the correct state, not just that the API returns correctly

If this is a frontend or full-stack feature, verify the UI actually shows the right thing after the action — e.g. after confirming a production batch, does the Bahan tab's material Detail show the updated `remaining_length_cm` and the new stock_ledger consumption entry, not just that the API call succeeded.

## Step 5 — Check for silent data drops on save

This is a recurring bug class in this codebase: a save appears to succeed (no error shown, no crash) but some of the user's input was silently discarded. It happens when save logic uses filtering instead of validation. Always check for this when the feature involves a form with multi-select + per-item sub-fields (e.g. multiple fabrics with dimensions, multiple components with qty).

**The test**: Select multiple items in a multi-select, intentionally leave one item's sub-field empty (e.g. add a second fabric but don't fill Panjang/Lebar), then tap Save. **Expected**: a clear error message naming the incomplete item, save blocked. **Bug**: save appears to succeed, item silently dropped, user never told.

**What causes this pattern in the code** — look for these and flag them as potential silent-drop sites:
- `compactMap { guard someCondition else { return nil } }` on user-entered collections → filters instead of validates
- `try?` on API calls or data transformations → swallows errors silently
- `guard let x = optional else { return }` / `guard let x = optional else { return [] }` in async loaders → silent empty result on any failure
- `?? []` / `?? 0` applied to user input rather than just defaults → masks missing required values

**Other save completeness checks** for any form that touches multiple entities:
- After saving a multi-fabric spec, verify the resulting `PatternSpec.fabrics` array count matches exactly what was selected — not just that the call didn't error.
- After adding a component, verify it appears in the detail view — not just that the sheet dismissed.
- After editing a numeric field (price, reorder min, qty), verify the new value is actually reflected in the list/detail, not the old one.

## Step 6 — Fabric variant isolation checks (required whenever fabric variants or production is involved)

These are the highest-value checks for the fabric-variant feature (v1.7+). Each one caught a real production bug and must be explicitly verified — they look correct on the surface but are easy to get wrong in implementation.

**Stock routing correctness** — the most important invariant in the whole system:
- Create a production batch that produces "L · Waffle Merah" (fabricVariantName = "Waffle Merah").
- Confirm the batch.
- Expected: `L · Waffle Merah`'s `currentStockQty` increments. `L · Satin Pelangi`'s qty stays unchanged.
- Bug to catch: the wrong ProductSize variant's stock gets incremented because `patternSpec.productSizeId` points to the wrong row. This happens when TambahResepSheet incorrectly links all fabric specs to a single ProductSize instead of one per fabric.

**One-spec-per-fabric rule** — verify TambahResepSheet creates the right number of PatternSpecs:
- Add a recipe for "Scrunchie L" selecting BOTH Satin Pelangi and Waffle Merah.
- Expected: exactly 2 PatternSpec rows created, one for each fabric — each linked to its own ProductSize (L · Satin Pelangi and L · Waffle Merah respectively). If L · Waffle Merah ProductSize didn't exist yet, it should be auto-created.
- Bug to catch: both fabrics end up in a single PatternSpec (old behavior before v1.7 fix), or only one PatternSpec is created.

**Optimizer dimension isolation** — verify candidate rows show the correct cut dimensions per selected purchase:
- Seed: Satin Pelangi spec (cut 120×25), Waffle Merah spec (cut 100×25) for the same size.
- In Optimasi Step 2, select a Waffle Merah purchase.
- Expected: candidate row for that size shows "100×25 cm" (Waffle's dimensions), not "120×25 cm" (Satin's dimensions).
- Bug to catch: the optimizer always shows `fabrics.first` dimensions regardless of which fabric purchase is selected.

**3-level product navigation routing** — verify each tap target goes to the correct screen:
- Tapping a size-label row (e.g. "M") in `ProdukListView` → must arrive at `ProdukSizeGroupView` showing only M variants. Must NOT arrive at `ProdukDetailView`.
- Tapping the product card header "›" in `ProdukListView` → must arrive at `ProdukDetailView`. Must NOT navigate to any size-specific screen.
- From `ProdukSizeGroupView`, tapping a fabric variant → must arrive at `ProdukSizeDetailView` for that specific variant. Verify the navigation title matches the variant's displayLabel (e.g. "M · Satin Pelangi").

**Composite uniqueness enforcement** — verify (sizeLabel + fabricVariantName) uniqueness is enforced, not just sizeLabel alone:
- Try to add a size "M · Satin Pelangi" when one already exists. Expected: blocked (canSave = false or 409 from API).
- Try to add "M · Waffle Merah" when only "M · Satin Pelangi" exists. Expected: allowed (different fabricVariantName, not a duplicate).
- Try to add "M" (no fabric variant) when "M · Satin Pelangi" exists. Expected: allowed (null fabricVariantName ≠ "Satin Pelangi").

**AddSizeSheet variant mode + FabricPickerSheet** — verify the sheet and its modal behave correctly when opened from `ProdukSizeGroupView` (v2.1):
- Open "Tambah Varian" from the M size group view.
- Expected: sizeLabel field is pre-filled with "M" and locked (read-only); fabric selection shows a chevron button (not a Picker dropdown); canSave = false until a fabric is selected; title is "Tambah Varian Kain".
- Tap the fabric row button → `FabricPickerSheet` modal must open showing ALL fabrics from bahan inventory (not just resep fabrics). Fabrics that have an active PatternSpec for this (product + size) must show the green "Ada di resep · bisa kurangi stok bahan" badge; other fabrics appear without badge.
- Type in the search bar: partial match filters the list; typing a name that doesn't match any existing fabric shows a "Tambah '[X]'" row at the bottom. Tapping it should select that name as the fabric with selectedSpecId = nil (no bahan deduction, no Stok Awal field).
- Select a fabric that IS in the resep → verify: (a) the picker dismisses and shows the selected name on the button; (b) the green checkmark badge appears next to the name; (c) footer text says "ada di resep — stok bahan dapat dikurangi otomatis"; (d) the Stok Awal section becomes visible.
- Select a fabric that is NOT in the resep → verify: (a) name appears on button without checkmark; (b) footer says "tidak ada di resep — stok bahan tidak akan dikurangi"; (c) Stok Awal section is hidden.
- Save without filling Stok Awal → variant is created with zero stock (no bahan deduction attempted). Verify the saved variant appears in the M group only, not the L group.
- Save with Stok Awal filled (resep fabric only) → verify bahan stock for that fabric's purchase decrements by the expected amount based on cut dimensions × qty.

## Step 7 — Known bug regression checks (required whenever the listed areas are touched)

These bugs were real issues in this codebase, fixed in v2.3. Verify these whenever the listed component or screen is changed:

### 7a. Sheet layout — iOS 26 Liquid Glass (SearchableDropdownField, TokenizedMultiSelectField)

- Open `SearchableDropdownField` (e.g. Bahan field in TambahPembelianSheet; Supplier field).
- Open `TokenizedMultiSelectField` (e.g. Pilih Bahan in TambahResepSheet).
- **Expected:** Sheet content (nav bar title + search box + list) is anchored at the top. Items are immediately visible and tappable.
- **Bug to catch:** Content floats at screen center or bottom. Root cause: iOS 26 Liquid Glass changes `fullScreenCover` anchoring — `ZStack(alignment:.top)` does NOT fix it. Fix requires `NavigationStack` inside `fullScreenCover`.

### 7b. Keyboard "Done" toolbar (NumericInputField, InlineSearchDropdownField)

- Tap any `NumericInputField` (Lebar, Panjang, qty fields, etc.) or `InlineSearchDropdownField`.
- **Expected:** Standard keyboard. No toolbar above it.
- **Bug to catch:** A "Done" button or extra toolbar row appears above the keyboard. Means `.toolbar { ToolbarItemGroup(placement: .keyboard) }` was re-added.

### 7c. InlineSearchDropdownField immediate list + "Tambah Baru" (InlineSearchDropdownField with onCreateNew)

- Tap any `InlineSearchDropdownField` with `onCreateNew` set (e.g. Supplier field) — do not type anything.
- **Expected:** Existing items appear immediately. "Tambah Baru" button visible at bottom without typing.
- **Bug to catch:** Empty dropdown until user types. List is gated behind `isEditing` state that only becomes true after first keypress.

### 7d. Sales report date range filtering (ReportsView, MockAPIService.getSalesReport)

- Open Lainnya → Laporan Penjualan.
- Select preset "7 Hari" → tap Terapkan.
- **Expected:** Chart updates to show only orders within the last 7 days. Revenue/profit changes.
- Select "3 Bulan" → chart must show the full 30-day spread (covers all 17 seed orders).
- **Bug to catch:** Chart shows identical data regardless of date range. Means `getSalesReport` is ignoring `from`/`to` params.

## Reporting results

For each check: state what was tested, the expected value/behavior (with the calculation shown if it's a numeric check), the actual result, and pass/fail. If something fails, be specific enough that `dev-frontend` or `dev-backend` can fix it without re-deriving the expected behavior from scratch — quote the relevant handoff section if it clarifies the expected behavior.
