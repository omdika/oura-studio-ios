# Oura Studios — Open Decisions & Implementation Status

This document contains open decisions to confirm, along with the detailed current frontend implementation status, history of regression bug fixes, mock data definitions, and live backend connection details.

---

## 6. Open Decisions for Design/Dev to Confirm

1. ~~**Weighted-average vs FIFO** for material cost~~ — **resolved in v1.2**: weighted average confirmed and implemented throughout MockAPIService and all cost-recalc logic.
2. **Pooled material rate recompute cadence** — manual (settings screen) vs. auto-recalculated from monthly thread purchases ÷ monthly output.
3. **Rounding rule for prices** — round to nearest 500/1000 IDR in the price advisor output.
4. **Backend hosting/deployment platform** — e.g. Railway, Render, Fly.io, or self-hosted (see Section 0; stack itself is now confirmed, hosting is not).
5. ~~**JWT token lifetime and refresh strategy**~~ — **resolved in v1.1**: 30-day expiry, no refresh token. Owner re-authenticates via Google on expiry (acceptable for a single-owner app).
6. **(New — v1.1) Google Cloud Console setup:** before the backend can be deployed, the following must be configured in Google Cloud Console:
   - Create an OAuth 2.0 client ID for **iOS** (type: "iOS application"), providing the app's bundle ID (`handika.oura-studio-frontend`).
   - Note the resulting iOS client ID — this goes into the iOS app's `LoginView.swift` (replacing the `YOUR_GOOGLE_CLIENT_ID` placeholder at line ~104) and into the backend's `GOOGLE_CLIENT_ID` env var.
   - No server-side client ID is needed separately — the iOS client ID is sufficient since the backend only verifies the token Google already issued, not initiates its own OAuth flow.
7. **(New — v1.1) Authorized owner email:** must be set as `AUTHORIZED_OWNER_EMAIL` in the backend's environment before deploying. This is the one Google account permitted to authenticate. Changing it requires a backend redeploy + clearing the `owner_account` table row.

---

## 7. Frontend Implementation Status (as of v2.4 — 2026-08-07)

All 11 frontend milestones are **complete**. The iOS app is now connected to the **live backend** (`APIService.shared.useMock = false` by default as of v2.4). JWT is stored in Keychain under service `"id.ourastudio.app"`. Google Sign-In is implemented but blocked pending GCP OAuth Client ID configuration — auth currently works via manually stored JWT.

| # | Screen / Module | Status | Files |
|---|---|---|---|
| 1 | Networking layer + all models | ✅ Done | `APIService.swift`, `MockAPIService.swift`, `Models/` |
| 2 | Auth (Google SSO, Keychain) | ✅ Done | `LoginView.swift`, `AppState.swift`, `KeychainManager.swift` |
| 3 | Shared components | ✅ Done | `NumericInputField`, `CurrencyInputField`, `OuraDatePickerField`, `ChipSingleSelect`, `TokenizedMultiSelectField`, `SearchableDropdownField`, `InlineSearchDropdownField` |
| 4 | Bottom nav + Produksi inner tabs | ✅ Done | `MainTabView.swift`, `ProduksiTabView.swift` |
| 5 | Produksi → Bahan | ✅ Done | `BahanListView`, `BahanDetailView`, `TambahPembelianSheet`, `EditPembelianSheet` |
| 6 | Produksi → Resep | ✅ Done | `ResepListView`, `TambahResepSheet`, `ResepEditorView`, `ResepVersionHistoryView` |
| 7 | Produksi → Optimasi + Batch confirm | ✅ Done | `OptimasiView`, `ProduksiBatchView` |
| 8 | Produk (list + price advisor) | ✅ Done | `ProdukListView`, `ProdukDetailView` |
| 9 | Penjualan | ✅ Done | `PenjualanListView`, `TambahPenjualanSheet` |
| 10 | Lainnya (Reports + Settings + Keluar) | ✅ Done | `LainnyaView.swift`, `ReportsView.swift`, `SettingsView.swift` |
| 11 | Beranda / Dashboard | ✅ Done | `BerandaView.swift` |
| 12 | API Integration & Contract Tests | ✅ Done (v3.47) | `APIIntegrationTests.swift` |
| 13 | BOLA Security API Tests | ✅ Done (v3.48) | `Security/TC_BOLA_A1_Materials.swift`, `TC_BOLA_B1_Products.swift`, `TC_BOLA_C1_Production.swift`, `TC_BOLA_D1_Sales.swift` |

### Bug fixes applied (v1.3)

Three bugs identified during regression testing and fixed:

| # | Bug | Fix location | Impact |
|---|---|---|---|
| 1 | `createOrUpdatePatternSpec` matched by `productSizeId` only — 2nd fabric's spec overwrote the 1st | `MockAPIService.swift` | Resep multi-fabric: saving Satin then Waffle for same size now creates two separate active specs correctly |
| 2 | `cancelSalesOrder` changed status but did not restore `currentStockQty` | `MockAPIService.swift` | Cancelling a sale now correctly increments stock back for each item |
| 3 | `getProductionBatches` always returned `[]` — `_productionBatches` was not a persistent state var | `MockAPIService.swift` | Tab Produksi now shows batches created from Optimasi; `confirmBatch`, `updateBatchItem`, `deleteProductionBatch` all now operate on the shared in-memory store |

### Optimasi → Produksi flow (v1.3)

After "Gunakan Layout Ini":
1. `createLayout` → `createProductionBatch(cuttingLayoutId:)` are called
2. Success screen appears showing: batch strategy name, total pcs, per-product breakdown
3. Two actions: **"Lanjut ke Produksi"** (switches inner tab to Produksi, resets Optimasi state) · **"Mulai Optimasi Baru"** (resets Optimasi state, stays on tab)
4. The new batch appears immediately in Tab Produksi as a draft

Candidate filter: Step 2 now filters PatternSpecs to only those whose `fabrics[].materialId == selectedPurchase.materialId`. Specs using a different fabric are excluded.

### Bug fixes applied (v1.7)

Four bugs fixed as part of the fabric-variant refactor:

| # | Bug | Root cause | Fix |
|---|---|---|---|
| 1 | Confirming a Waffle Merah production batch updated the wrong size's stock | `TambahResepSheet.save()` bundled all fabrics into one `PatternSpec` linked to one `productSizeId` — a Waffle Merah batch item still pointed to the Satin ProductSize | `save()` now creates one spec per fabric, each linked to the correct `(sizeLabel + fabricVariantName)` ProductSize |
| 2 | Optimizer showed wrong cut dimensions when non-first fabric was selected | `candidateRow` always read `spec.fabrics.first?.cutLengthCm` regardless of which purchase was selected | Now looks up `spec.fabrics.first(where: { $0.materialId == selectedPurchase?.materialId })` for fabric-specific dimensions |
| 3 | TambahResepSheet size picker showed duplicate "M" chips when M·Satin and M·Waffle both existed | `ForEach` iterated all `ProductSizeDetail` objects, showing `size.sizeLabel` for each — two "M" chips appeared | Added `uniqueSizeLabels` computed property (Set deduplication by `sizeLabel`); size picker now shows one chip per label |
| 4 | `patchProductSize`, `archiveProductSize`, `getPriceAdvisor` matched by `sizeLabel: String` — ambiguous once two sizes share the same label | String-based lookup in mock and real API paths | All three functions changed to `sizeId: UUID` parameter; mock lookups changed to `$0.id == sizeId` |

### Mock data state (v2.0)

Seed data matches confirmed owner specs. **Cut dimensions are authoritative** — use these when building the real backend's initial seed SQL.

**Bahan (fabric only):**

| Nama | Lebar | 1 Pembelian | Total Biaya |
|---|---|---|---|
| Satin Pelangi | 200 cm | 200×100 cm | Rp 45.000 |
| Waffle Merah | 150 cm | 150×100 cm | Rp 32.000 |

**Product: Scrunchie** (SKU: SCRUNCHIE) — 4 ProductSize variants, 4 PatternSpecs:

| Size | Kain | Cut (panjang × lebar) | Labor |
|---|---|---|---|
| M | Satin Pelangi | 90 × 20 cm | 10 menit |
| M | Waffle Merah | 80 × 18 cm | 10 menit |
| L | Satin Pelangi | 100 × 22 cm | 12 menit |
| L | Waffle Merah | 90 × 21 cm | 12 menit |

- No sales orders, no hardware components, no benang materials in seed (intentional for focused flow testing)
- Settings: labor Rp 50/menit, overhead Rp 300/unit, thread pool Rp 500/unit, packaging pool Rp 200/unit

### UI/UX fixes and improvements (v2.3)

| # | Change | Files | Details |
|---|---|---|---|
| 1 | Picker sheet layout — iOS 26 Liquid Glass fix | `SearchableDropdownField.swift`, `TokenizedMultiSelectField.swift` | `fullScreenCover` content anchored at screen center/bottom, not top — caused by iOS 26 Liquid Glass layout changes. Fixed by wrapping the entire sheet body in `NavigationStack`; the navigation bar naturally pins content to top. Both pickers now use `NavigationStack { VStack { searchBar + Divider + ScrollView + Spacer } }` with `.navigationTitle(label).navigationBarTitleDisplayMode(.inline)` and a `.cancellationAction` / `.confirmationAction` toolbar button. |
| 2 | Keyboard "Done" toolbar removed | `NumericInputField.swift`, `InlineSearchDropdownField.swift` | `ToolbarItemGroup(placement: .keyboard)` with "Done" button removed from both components. The extra tap was unnecessary — users can dismiss the keyboard by tapping outside the field. `@FocusState` retained in both for border highlight on focus. |
| 3 | InlineSearchDropdownField immediate display + "Tambah Baru" | `InlineSearchDropdownField.swift` | Dropdown list was gated behind `isEditing` state, requiring user to tap before list appeared. Changed to `if !filtered.isEmpty || onCreateNew != nil` — list shows immediately on focus. "Tambah Baru" (create button) is now always visible when `onCreateNew != nil`; shows "Tambah Baru" with empty query, "Tambah '\<query\>'" with non-empty query and no exact match, hidden when exact match exists. |
| 4 | ReportsView — DateRangeField component | `ReportsView.swift` | Two `OuraDatePickerField` + "Muat Laporan" button replaced with `DateRangeField` private struct. Single tappable button shows localized range label (e.g. "5 Agu – 5 Agu 2026"). Presents `DateRangePickerSheet` (private struct) as `.medium` detent sheet with: 5 preset chips (7 Hari, 30 Hari, Bulan Ini, Bulan Lalu, 3 Bulan) + two compact `DatePicker` rows (Dari / Sampai) + "Terapkan" button that triggers `onApply` callback. Applied to both `SalesReportDetailView` and `WasteReportView`. |
| 5 | Sales report date filtering + seed data | `MockAPIService.swift` | `getSalesReport(from:to:groupBy:)` was ignoring date params and returning random generated data. Rewrote to filter `_salesOrders` by `soldAt` date using `Calendar.startOfDay` comparison. Added `seedSalesOrders()` creating 17 `SalesOrder` objects spread over 0–30 days ago, using known product size UUIDs (M·Satin, M·Waffle, L·Satin, L·Waffle, L·Silk). `_salesOrders` now initialized from seed instead of `[]`. |

### Mock data state (v2.3)

All data from v2.0 preserved, with sales orders added:

**Sales orders (new in v2.3):** 17 seeded orders spanning the last 30 days. Orders reference 5 product size variants with realistic quantities and prices. Use date range presets in `ReportsView → Laporan Penjualan` to view different subsets.

### Live backend status (v2.4)

The app now runs against the live backend by default (`useMock = false`). JWT is stored in Keychain under service `"id.ourastudio.app"`. The remaining setup steps are:

1. ~~Set `APIService.shared.useMock = false`~~ — **Done.**
2. ~~Set `APIService.shared.baseURL`~~ — **Done.** Pointing to Cloud Run URL.
3. **Pending:** Replace the `YOUR_GOOGLE_CLIENT_ID` placeholder in `LoginView.swift` with the actual iOS OAuth client ID from GCP console.
4. **Pending:** Configure `AUTHORIZED_OWNER_EMAIL` on the backend.
5. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` — set on backend server (not iOS client).
