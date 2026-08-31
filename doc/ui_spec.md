# Oura Studios — UI Spec & Screens Flow

This document details the screens, user flows, and interactive components of the Oura Studios iOS app. It is optimized for the **Design/Frontend** role.

---

## Screens & Flows (for Claude Design mockups)

### Bottom navigation (confirmed by mockup)
5 tabs: `Beranda` (Dashboard) · `Produksi` (the 4-tab screen below) · `Produk` (Products/Finished Goods, screen #3) · `Penjualan` (Sales, screen #4) · `Lainnya` (likely houses Reports + Settings, screens #5-6). Note that **Produk is its own bottom-nav destination, separate from the Produksi tabs** — don't nest Products inside the Produksi screen.

### Screen list

0. **Login (updated in v1.1 — was email+password, now Google SSO)** — gates every other screen; the app opens here if no valid stored JWT exists in the iOS Keychain. The screen shows: the Oura Studios brand mark (scissors icon, app name, tagline), and a single **"Sign in with Google"** button styled per Google's button design guidelines (white background, Google G icon, "Sign in with Google" label, rounded rectangle border). No email or password fields.

   **Button tap flow:**
   1. iOS presents a Google OAuth consent screen via `ASWebAuthenticationSession` (the standard system browser sheet — no external SDK required).
   2. Owner authenticates with their Google account.
   3. iOS receives a Google `id_token` in the OAuth callback URL fragment.
   4. App calls `POST /auth/google` with `{ "id_token": "<google_id_token>" }`.
   5. Backend verifies the token with Google, checks the email against `AUTHORIZED_OWNER_EMAIL`, and returns `{ access_token, expires_at }`.
   6. App stores the JWT in the **iOS Keychain** (never UserDefaults or plaintext) and navigates to Beranda.

   **Error handling:** if the backend returns 403 (unauthorized Google account), show an inline error "Akun Google ini tidak diizinkan". If the user cancels the consent screen, silently return to the login screen (no error shown). Any network error shows an inline message.

   **No password, no "Buat akun", no "Lupa password"** — these concepts don't exist in this auth model. Recovery (e.g. owner changes Google account) is handled by updating `AUTHORIZED_OWNER_EMAIL` on the backend and clearing the `owner_account` row.

   A **"Keluar" (log out)** action exists in the Lainnya tab — clears the stored Keychain token and returns to this screen.
1. **Dashboard** — today's sales, low-stock alerts for finished products (product+size below minimum stock), quick actions
2. **Produksi** (core differentiator area) — one screen, **4 tabs**: `Bahan` · `Resep` · `Optimasi` · `Produksi`. These were originally spec'd as 4 separate screens; the mockup consolidates them into one tabbed flow, which is the correct IA — keep this structure. The 4 tabs form a left-to-right working sequence (bahan masuk → resep dipakai → dioptimasi → jadi batch), but each tab is also independently accessible (e.g. to just check material stock without starting a production run).

   **Tab: Bahan** (Materials)
   - **Correction from earlier draft:** this is NOT three equal sub-tabs. `Daftar` → `Detail` is a hierarchical drill-down (list → item), and `Tambah Pembelian` is a contextual action, not a peer destination. Modeling all three as same-level tabs forces the tab order (left–middle–right) to fight the actual usage order (list → detail → add, which visually means left → right → middle) — that mismatch is what made the earlier version feel like backtracking. Fix: use push navigation for the drill-down, and a modal/sheet for the action.

   - **`Daftar`** (the only persistent view under the Bahan tab):
     - Search box at top: textbox with live autocomplete dropdown as the user types (inline, not a separate screen).
     - Picking a suggestion, or tapping any row → **pushes** a Detail screen on top (standard list-detail navigation, with a **back** button/gesture returning to Daftar — not a tab switch).
     - Typing without picking a suggestion filters the list in place.
     - A **"+" button in the header** (top-right) opens the **Tambah Pembelian modal** with the Bahan field empty/searchable — this is the entry point for logging a purchase without already having a specific material open.
     - List: name, category, unit cost, stock qty, Menipis/Rendah color coding — unchanged from before.

   - **`Detail`** (pushed screen, not a tab):
     - Scoped to one material. Shows `avg Rp X/m` badge (live `material.current_avg_cost`), **Riwayat Pembelian** and **Pergerakan Stok** sections (both reverse-chronological; tapping a consumption row jumps to that Production Batch, tapping a purchase row opens it for edit — full edit/delete behavior spec'd below, since this was previously just a one-line mention with no real spec).
     - A **"+ Tambah Pembelian" button** here opens the same modal as above, but with the Bahan field **pre-filled and locked** (small "Ubah" link to override if needed) — this is the expected default path when logging a restock for a material you're already looking at.
     - Back navigation returns to `Daftar` at its prior scroll position (don't reset the list/search).

   - **`Tambah Pembelian`** (modal/bottom sheet, presented over Daftar or Detail — not a tab):
     - Triggered only from the two "+" entry points above, never a standalone tab destination.
     - Bahan field: same searchable dropdown pattern; pre-filled+locked when opened from Detail, empty+searchable when opened from Daftar's header "+".

     - **"Buat bahan baru" flow — exact states (this is where the mockup currently overlaps two elements that should never be visible at the same time):**
       1. **Typing state:** user types in Bahan field → dropdown appears below it showing matching existing materials (if any) + a **"+ Buat bahan baru: '[nama yang diketik]'"** row at the bottom of that same dropdown list, live-updating as they type.
       2. **Tap "+ Buat bahan baru...":** the dropdown **closes completely** (it does not stay open or float above what comes next — this is the bug in the current mockup, where the dropdown suggestion and the new-material panel are stacked on top of each other). The Bahan field itself now shows the typed name in a **locked/confirmed state** (same visual treatment as an existing material being selected), with a small **"Baru"** badge next to it so it's clear this isn't an existing record.
       3. **New-material panel expands inline**, pushing the rest of the form down (not overlapping it): a **Kategori** selector (Kain / Benang / Hardware, single-select, no default — user must choose) appears directly below the confirmed Bahan field.
       4. **Conditional field by category:** if `Kategori = Kain`, a **"Lebar Kain (cm)"** field appears — this sets `material.fabric_width_cm`, a **default/typical width for this fabric**, not a hard lock (see the field-linkage note below for why it's a suggestion, not a constraint). If `Benang` or `Hardware`, no extra field appears here — Kategori alone is enough to create the material record.
       5. Once Kategori (and Lebar Kain, if Kain) is filled, the rest of the form below (dimensions, Total Biaya, Tanggal, Supplier) becomes active/scrollable into view — it was always present, just visually de-emphasized while the new-material panel is incomplete.
       - **Field linkage:** if the user just set "Lebar Kain (cm)" in step 4, the **"Lebar (cm)"** field further down in the same form **auto-fills from it as a starting suggestion** (they usually describe the same fabric) — but stays **fully editable**, since an individual purchase (e.g. a remnant or an odd cut) can legitimately be narrower than the fabric's typical width. Don't lock it.
       - This "+ Buat bahan baru" path is the **only** way new materials get created — there is no separate "add material" screen anywhere else in the app.

     - **No Potong/Roll purchase-type toggle** — this was in an earlier draft and is now removed per explicit direction: every fabric purchase is entered the same way, as one bounded **Lebar (cm) × Panjang (cm)** rectangle, whether it's a small remnant or a large bolt. This also simplifies the cutting optimizer (Section 1.5) — it no longer needs to special-case "fixed-width roll" vs "bounded piece," every purchase is just a bounded rectangle.

     - **Category-conditional fields (full spec):**

       **If Kategori = Kain:**
       - `Lebar (cm)` and `Panjang (cm)` — both plain numeric fields, no toggle, no mode switching. Pre-filled from the material's typical `fabric_width_cm` if set (see field linkage above), fully editable.
       - Common fields below: Total Biaya, Tanggal, Supplier.

       **If Kategori = Benang:**
       - `Ukuran Kemasan` toggle: **Kecil** | **Besar** — purely descriptive metadata to help the owner recognize which purchase record is which later in Riwayat Pembelian; it does not feed into HPP math, since thread stays a pooled/flat-rate cost regardless of spool size (see Section 1.3).
       - `Jumlah (gulung)` — a single numeric quantity field.
       - Common fields: Total Biaya, Tanggal, Supplier.

       **If Kategori = Hardware:**
       - `Jumlah (pcs)` — numeric quantity field, how many pieces/units were purchased.
       - `Panjang (cm)` *(opsional)* — length per unit, for length-based hardware like elastic bands (karet elastis), ribbon/pita, or zipper tape that is bought and consumed by length, not just by piece count. Leave blank for ring/clip/snap-type hardware that has no meaningful length dimension.
       - Common fields: Total Biaya, Tanggal, Supplier.
       - **Behavior when `Panjang` is filled:** the purchase is length-tracked — `remaining_length_cm` (= `qty × length_cm`) is decremented as the hardware is consumed in production, identical to how fabric rolls are tracked. Cost per cm is `total_cost / (qty × length_cm)`. `canSave` requires `qty > 0`; `length_cm` is truly optional (a hardware purchase with only `qty` and no `length_cm` remains valid).
       - **Behavior when `Panjang` is blank:** count-based only — `qty` tracks total stock, cost per unit is `total_cost / qty`. No `remaining_length_cm` tracking. This is the existing behavior for ring/clip/hook-type hardware and remains the default.
       - **Why both?** A single accessory product may use both types: "Ring Elastis 3mm" (by length) and "D-ring 2cm" (by piece). The form must support either in the same session, not force a category sub-type choice.
       - (No package-size toggle for hardware — that's only for thread/yarn.)
       - **`material.usage_unit` for length-based hardware:** when a new hardware material is created inline in Tambah Pembelian with `Panjang (cm)` filled, its `usage_unit` is set to `"cm"` instead of the default `"pcs"`. This is important because `usage_unit` flows downstream into the Resep screens — the component qty field label and unit suffix both derive from `material.usage_unit`. A karet elastis with `usage_unit = "cm"` will show "Karet Elastis per unit (cm)" in the resep form, prompting the user to enter centimetres consumed per product rather than piece count. Count-only hardware keeps `usage_unit = "pcs"`.

     - **Component-level behavior — spec'd precisely so Claude Design can build these as functioning, not just visual, elements:**
       - **Numeric fields (Lebar, Panjang, Jumlah):** numeric keypad only (no letters), decimal allowed with comma as the separator per Indonesian convention (e.g. "5,2"), must be > 0 to allow saving — show inline validation (field border/text turns to an error color, small message below) rather than blocking keystrokes.
       - **Total Biaya:** numeric keypad, auto-formats live as the user types into Rupiah grouping (typing "712500" displays as "Rp 712.500" progressively, not just on blur) — this is a currency-input component, not a plain number field.
       - **Tanggal (date picker):** tapping the field opens the platform-native iOS date picker (wheel or calendar sheet, whichever matches the rest of the app's date pickers — keep consistent across the whole app, don't mix styles). Defaults to **today's date**. **Cannot select a future date** (a purchase can't happen after today) — future dates should be disabled/greyed in the picker, not just rejected after selection. Displayed format matches the rest of the app: "27 Jul 2026" (day, abbreviated month, year).
       - **Bahan and Supplier fields:** both use the identical searchable-dropdown-with-inline-create pattern (see Supplier spec directly below) — same component, reused, not two different implementations.
       - **Close ("×") button:** if any field in the sheet has been changed from its opening state, tapping "×" shows a confirm-discard prompt ("Buang perubahan?" / batal / buang) before closing — don't silently discard a half-filled purchase entry. If nothing was changed, close immediately with no prompt.
       - **"Simpan Pembelian" button:** disabled (visually muted, not tappable) until all required fields for the current category are valid. On tap: brief loading state on the button itself, then either success (sheet dismisses per the flow already described) or an inline error if the save fails (don't lose the user's entered data on failure — keep the sheet open with the error shown).

     - **Supplier field — same pattern as Bahan, now fully specified:**
       - This requires treating Supplier as its own record, not a free-text string — otherwise "Toko Kain Abadi" and "toko kain abadi" fragment into separate suppliers with no way to see combined purchase history per supplier later.
       - Same interaction as Bahan: tap/type in the Supplier field → dropdown shows matching existing suppliers as the user types, live-filtered → tap one to select. If no match, an inline **"+ Tambah supplier baru: '[nama]'"** row at the bottom of the dropdown creates a new Supplier record on tap — no separate screen, no extra fields required (just the name; unlike materials, suppliers don't need a category or dimensions to be usable).
       - Supplier is **optional** — unlike Bahan, a purchase can be saved without one (some purchases might not have a clear supplier on record).

     - **"Simpan Pembelian"** → sheet dismisses, returning to Detail (creating it via push if the sheet was opened from Daftar) with the new purchase at the top of Riwayat Pembelian and avg cost already updated. No tab-hopping at any point in this flow.

   - **Edit & Delete Pembelian (previously undocumented — full spec):**
     - **This is not simple CRUD.** A purchase's `total_cost`/`qty`/dimensions feed into `material.current_avg_cost` (a running weighted average), and once any of that purchase's fabric length has been consumed by a `CuttingLayout`, changing its dimensions retroactively would make the consumption math inconsistent. So editability depends on **whether the purchase has already been used**.
     - **Tapping a row in Riwayat Pembelian** opens the same `Tambah Pembelian` sheet UI, pre-filled with that purchase's data, titled "Edit Pembelian" instead of "Tambah Pembelian" and with a "Simpan Perubahan" button instead of "Simpan Pembelian".
     - **If the purchase is untouched** (fabric: `remaining_length_cm` still equals the original purchased length, i.e. nothing has been cut from it yet; thread/hardware: no stock_ledger consumption rows reference it) — **all fields are freely editable**, including Lebar/Panjang/Jumlah. Saving triggers a full recalculation of `material.current_avg_cost` from all that material's purchases.
     - **If the purchase has already been partially or fully consumed** — `Lebar (cm)` / `Panjang (cm)` / `Jumlah` become **locked** (greyed, not editable) with a short explanatory note ("Sudah dipakai di produksi — dimensi tidak bisa diubah"). **Total Biaya, Tanggal, and Supplier remain editable** regardless of consumption state, since correcting a mistyped price or wrong supplier doesn't affect physical stock tracking. Editing Total Biaya still triggers the avg-cost recalculation.
     - **Delete:** a trash/delete icon on the Edit Pembelian sheet (or a swipe-to-delete gesture on the Riwayat Pembelian row — pick one, be consistent with other list-delete patterns in the app).
       - **If untouched** (same condition as above): delete is allowed, behind a confirm dialog ("Hapus pembelian ini? Tindakan ini tidak bisa dibatalkan."). On confirm: removes the `MaterialPurchase` to recreate the weighted average.
       - **If already consumed at all:** delete is **disabled**, not just discouraged — removing it would orphan the `CuttingLayout`/`ProductionBatch` records that reference it and corrupt their locked HPP history. Show the same explanatory note as the dimension-lock case above, and don't offer a "force delete" escape hatch; a wrong purchase entry that's already been used should be corrected via the editable fields (cost/supplier/date) rather than removed.

   - **Pagination:** this list grows continuously (every purchase can introduce cost changes; long-running shops will have 30+ materials). Design with pagination/infinite-scroll in mind, not a single static screen — show at least 15-20 sample rows across a couple of fabric types, thread colors, and hardware types when mocking this up, so the scroll/pagination behavior is visible, not just the 6 items in the current mockup.


   **Tab: Resep** (Pattern Specs)
   - **Same structural fix as Tab Bahan:** `Daftar Resep` and `Editor` are not equal peer tabs. `Daftar Resep` is the persistent view; `Editor` is always entered *with context* (either "add new" or "edit this specific row"), never opened blank without knowing why. Use push navigation, not tab-switching, for the same reason explained in Tab: Bahan above.

   - **`Daftar Resep`** (persistent view):
     - Grouped by product name (e.g. "SCRUNCHIE", "IKAT RAMBUT" headers). Each row under a group = one **unique ProductSize** — i.e. one unique `productSizeId`. **Gabungkan specs** (multiple fabrics sharing the same base ProductSize) appear as ONE row showing all fabric names joined ("Waffle Blue · Waffle Red · Waffle Hijau") with no dimension tag. **Pisah specs** (each fabric has its own ProductSize with `fabricVariantName`) each appear as their own row with a dimension tag (W×H cm). Row shows estimated labor minutes from the first spec in the group.
     - Tapping a row → **pushes** to `Editor`, which receives ALL PatternSpecs for that `productSizeId` (as `[PatternSpec]`). For gabungkan rows this means all fabric specs open together; for single-fabric rows it's the same as before.
     - **"Riwayat Versi"** button inside the Editor pushes to a read-only version-history screen for the representative spec's `productSizeId`.
     - **"+" button in the header** → starts the **Tambah Resep** flow (see below) — this is the only "create new" entry point, consistent with how Tambah Pembelian works in Tab Bahan.

   - **"Tambah Resep" flow — full spec, including multi-fabric selection** (the earlier draft only allowed picking one fabric at a time and left component behavior too vague for a real implementation; both are fixed below, and a full worked example is included so the flow is unambiguous end-to-end).

     - **Presentation:** one scrollable bottom sheet with numbered sections, not a multi-screen wizard. All sections are visible at once (progressive disclosure — later sections are visually de-emphasized/inactive until earlier ones are filled, but the user can scroll and see the whole shape of the form). **"Simpan Resep"** stays pinned at the bottom, disabled until every required field is valid.

     - **1. Pilih Produk — full spec & layout:**
       - **Rule:** exactly one product must be selected — this is a hard single-select, never multiple. A `PatternSpec` always belongs to one `Product` via one `ProductSize`; there's no such thing as a recipe shared across two different products.
       - **Layout:** section header "1. PILIH PRODUK" (label style matches the mockup's numbered-section convention), followed by a **horizontally-wrapping row of chips** — existing products first, in the order returned by `GET /products` (suggest: alphabetical or most-recently-used), then the **"+ Tambah Produk Baru"** chip always last in the row so it doesn't shift position as products are added over time.
       - **Chip states:**
         - *Unselected:* light/outline fill, dark text (matches "Ikat Rambut" styling in the reference screenshot).
         - *Selected:* solid filled background (matches "Scrunchie" styling in the reference screenshot) — only one chip in this row can be in this state at a time.
         - *"+ Tambah Produk Baru":* dashed border, muted text — visually distinct from real data chips so it always reads as an action, not a 3rd product choice.
       - **Tap behavior:** tapping an unselected existing chip selects it and deselects whatever was previously selected (radio-button semantics — not a toggle, you can't "deselect" down to zero once one is chosen, since Ukuran and Bahan below depend on a product being set). Tapping the already-selected chip does nothing (no-op, not a deselect).
       - **"+ Tambah Produk Baru" expansion:** tapping it does **not** navigate to a new screen or open a separate modal — it expands **inline, directly below the chip row**, pushing section 2 further down. The expansion shows: a **Nama Produk** text field (autofocaused, keyboard opens immediately), and directly below it a smaller **SKU** field that live-auto-fills as an uppercase slug of whatever's typed in Nama Produk (e.g. typing "Pouch Serut" → SKU field shows "POUCH-SERUT" automatically), with the SKU field remaining manually editable if the user wants to override it. Two small buttons close this expansion: **"Batal"** (collapses the expansion, discards the typed name, no chip is added) and **"Tambah"** (only enabled once Nama Produk is non-empty and SKU is non-empty/unique — validate SKU uniqueness against `GET /products` before enabling; show inline error under the SKU field if a duplicate is typed, e.g. "SKU sudah dipakai"). Confirming with "Tambah" collapses the expansion, inserts a new selected chip with that name into the chip row (positioned just before the "+" chip), and this new product becomes the current selection for the rest of the sheet.
       - Nothing below section 1 is enabled/visible in an interactive state until a product is selected (existing or newly created) — sections 2-4 stay visually muted/disabled, consistent with the earlier progressive-disclosure note.

     - **2. Pilih Ukuran — full spec & layout:**
       - **Rule:** exactly one size must be selected — also a hard single-select, same reasoning as Produk (one `PatternSpec` = one `ProductSize`).
       - **Layout:** identical structural pattern to section 1 — header "2. PILIH UKURAN", horizontally-wrapping chip row scoped to **only the currently-selected product's existing sizes** (re-fetch/filter this list every time the Produk selection in section 1 changes — if the user switches products after having picked a size, the size selection resets, since sizes don't carry across products).
       - **Chip contents, in order:** existing sizes for that product (in whatever order they were created, or a recognized-progression order XS→S→M→L→XL→XXL if all labels match that convention), then a **suggested next-size chip** if the existing sizes form a recognizable progression with a gap at the top (e.g. XS/S/M/L present → show "+ Buat ukuran 'XL'"; if sizes are already XS-XXL, no suggestion chip appears since there's no obvious next size), then a plain **"+ Ukuran lain..."** chip last.
       - **Selected/unselected chip states:** identical visual treatment to section 1's chips (filled = selected, outline = unselected).
       - **"+ Buat ukuran '[X]'" (the auto-suggested one):** single tap immediately creates and selects that size — no further text entry needed, since the label is already fully determined by the suggestion.
       - **"+ Ukuran lain..." expansion:** tapping it expands inline below the chip row (same pattern as Produk's "+ Tambah Produk Baru") with a single **Label Ukuran** text field (e.g. for entering "Kecil", "Sedang", "XXXL", or any custom label) and **"Batal"**/**"Tambah"** buttons, same validation pattern (non-empty, and unique within this product's existing sizes — reject "M" if "M" already exists for this product, with inline error "Ukuran ini sudah ada").
       - Sections 3-4 stay disabled/muted until a size is selected, same progressive-disclosure rule as before.


     - **3. Pilih Bahan (Kain) — full spec & layout, multi-select search+dropdown (this is the part that most needs precise spec):**
       - **Rule:** one *or more* fabrics may be selected — this is the one field in the whole sheet that's intentionally multi-select, because a single Tambah Resep session commonly needs to define the recipe for more than one fabric at once (e.g. Satin *and* Waffle for the same new size). Do not build this as a single-select chip row like sections 1-2 above.
       - **Layout:** section header "3. PILIH BAHAN (KAIN)", followed by **one field** (not a chip row) that looks like a text input but behaves as a tokenized multi-select — visually: a rounded-rectangle container matching the other text-input fields in this app (same border/fill as e.g. the Lebar/Panjang fields elsewhere), tall enough to wrap to 2+ lines once several tokens are added. A small search icon at the field's left edge signals it's searchable, not just typed free text.
       - This field is a **tokenized multi-select search input** (the same interaction family as an email "To:" field with recipient chips), not single-select chips.
       - **Exact interaction sequence:**
         1. User taps the Bahan field → keyboard opens, an empty text input is focused (any already-selected fabrics show as small removable chips/tokens to the left inside the same field, e.g. "Satin Putih ×").
         2. User types (e.g. "sat") → a dropdown list appears directly below the field, live-filtered to matching **Kain** materials that already have at least one purchase on record (same eligibility rule as before — a recipe can't be defined against a fabric with no cost history). Materials already selected as tokens are excluded from this list (or shown greyed/disabled) so they can't be picked twice.
         3. Tapping a result in the dropdown **adds it as a token/chip inside the field** (does not close the field or navigate away) and **clears the text input**, which stays focused so the user can immediately type the next fabric name. This repeats for as many fabrics as needed.
         4. Tapping the "×" on any existing token removes just that fabric.
         5. If the typed text matches no existing (purchased) material, show a short inline note ("Bahan belum ditemukan — tambahkan dulu di Tab Bahan") instead of a "+ Buat baru" option — fabric creation is intentionally not available inline here, same rule as the single-select version had, now just restated for the multi-select case.
       - **Minimum 1 fabric required** to proceed to section 4; no maximum.

     - **4. Detail Resep — one card per selected fabric (this is the section that changes shape based on step 3, and needs the most explicit spec for Claude Code to get right):**
       - If 2 fabrics were selected in step 3 (e.g. "Satin Putih" and "Waffle Merah"), this section renders **2 separate cards**, each headed by that fabric's name, each fully independent with its own: Lebar Potong (cm), Tinggi Potong (cm), Rotasi Diizinkan toggle, Komponen Hardware list (add/remove rows), Estimasi Waktu Kerja (menit). This mirrors why fabric-specific recipes exist in the first place (Section 1.2) — satin and waffle behave differently when cut, so their dimensions are never shared, even though they're being defined in the same sitting.
       - **Convenience action, not a default:** below the first card, offer a small **"Salin Komponen Hardware ke bahan lain"** button — hardware (e.g. "Ring Elastis 3mm × 1 pcs") is the one part that's usually identical across fabrics for the same size, so this copies just the Komponen Hardware rows from card 1 into any other cards that are still empty. It never touches Lebar/Tinggi/Rotasi/Waktu Kerja, since those are exactly the values expected to differ per fabric — auto-copying them would undermine the reason multi-fabric cards exist.
       - Each card validates independently; **"Simpan Resep" stays disabled until every card's required fields are filled**, not just the first one. **Required fields for each fabric card:** Lebar Potong > 0 AND Tinggi Potong > 0 (mandatory — a fabric entry with zero dimensions cannot produce a valid HPP). Optional fields per card: Rotasi toggle (defaults to on), Komponen Hardware (can be empty), Estimasi Waktu Kerja (menit, optional — defaults to 0 if blank). **Required fields for each component row:** qty > 0 (mandatory — adding a component with qty=0 is meaningless and must be treated as an incomplete entry, not a valid save). The "mandatory when selected" rule: any field that becomes visible only because the user made a selection (fabric card because a fabric token was added; component row because a component was added) is mandatory — the act of selecting it creates an obligation to fill its required sub-fields before saving. If a sub-field is unfilled, block save AND show a clear inline error naming which specific item is incomplete, rather than silently dropping the incomplete entry from the saved data.

     - **Save behavior (client-side batching — spec'd explicitly since the backend has one `PatternSpec` per fabric, not a bulk endpoint):** tapping **"Simpan Resep"** issues one `POST /pattern-specs` call per card (see Section 4 API contract) — e.g. 2 fabrics selected → 2 calls, one for Satin's card and one for Waffle's card, each carrying that card's own dimensions/rotation/hardware/labor-minutes plus the shared `product_size_id`. Show one combined loading state while all calls are in flight. **If all succeed:** dismiss the sheet, return to `Daftar Resep` with both new rows visible under the product group. **If some fail and some succeed:** don't discard the whole sheet — keep it open, mark which card(s) failed with an inline error, keep the successful card(s) visually confirmed, and let the user retry just the failed one(s) rather than re-entering everything.

     - **Contextual pre-fill:** if "+ Tambah Resep" is opened while already viewing a specific pattern spec (e.g. from the "Scrunchie · M · Satin" Editor, or from a row in Daftar Resep), **Produk and Ukuran pre-select to that context** and show as already-chosen (e.g. "M (sudah ada)" highlighted) — the common real case is "same product and size, just need recipes for one or more different fabrics," so only Bahan (step 3) and Detail Resep (step 4) need fresh input. Opening "+ Tambah Resep" from the bare `Daftar Resep` list (not from within a specific spec) starts with nothing pre-selected.

     - **Worked example, to make the whole flow concrete:** adding a brand-new size to an existing product, for two fabrics at once —
       1. Pilih Produk: tap the existing **"Scrunchie"** chip.
       2. Pilih Ukuran: existing sizes show as chips (XS, S, M, L, XL); tap **"+ Buat ukuran 'XXL'"** (auto-suggested since XL is the current largest) → confirms **"XXL"** as a new ProductSize.
       3. Pilih Bahan: type "sat" → tap **"Satin Putih"** from the dropdown (becomes a token) → type "waf" → tap **"Waffle Merah"** (becomes a second token). Field now shows two chips: "Satin Putih ×" "Waffle Merah ×".
       4. Detail Resep shows two cards:
          - **Satin Putih card:** Lebar Potong `22`, Tinggi Potong `18`, Rotasi Diizinkan on, Komponen Hardware: "Ring Elastis 3mm × 1 pcs", Estimasi Waktu Kerja `12` menit.
          - **Waffle Merah card:** Lebar Potong `19`, Tinggi Potong `17`, Rotasi Diizinkan on, Komponen Hardware: (tap "Salin Komponen Hardware ke bahan lain" → "Ring Elastis 3mm × 1 pcs" appears here too), Estimasi Waktu Kerja `12` menit.
       5. Tap **"Simpan Resep"** → two `POST /pattern-specs` calls fire (XXL·Satin, XXL·Waffle) → both succeed → sheet dismisses → `Daftar Resep` now shows two new rows under "SCRUNCHIE": "XXL · Satin" and "XXL · Waffle".

     - **Component-level behavior — spec'd so both Claude Design (visual states) and Claude Code (functional implementation) build the same thing:**
       - **Chip/pill single-select (Produk, Ukuran):** tap toggles selection; selecting a new chip in the same group visually deselects the previous one (radio-button semantics, not checkbox). The "+" chip is visually distinct (dashed border or lighter fill, matching the existing mockup convention) from real data chips.
       - **Tokenized multi-select search field (Bahan):** functionally a combobox + token list, not a plain `<select>`. Needs: a text input that stays mounted and focused after each token is added (don't dismiss keyboard or blur), a dropdown/listbox positioned directly below the input that updates on every keystroke (debounce ~200-300ms if hitting a live search endpoint), token chips rendered inline within the same input's bounding box (wrapping to a second line if needed, input continues after the last token), and a per-token "×" tap target large enough for touch (not a tiny inline glyph).
       - **Numeric fields (Lebar Potong, Tinggi Potong, Estimasi Waktu Kerja):** reuse the exact same numeric-input component already spec'd under Tab Bahan → Tambah Pembelian's "Component-level behavior" (numeric keypad, comma decimal, must be > 0) — do not build a second implementation with different behavior.
       - **Rotasi Diizinkan:** standard on/off switch/toggle component, default **on** (matches `pattern_spec.rotation_allowed DEFAULT true`).
       - **Komponen Hardware — see the dedicated "Tambah Hardware — full spec & layout" block right after this list for complete detail (row layout, picker behavior, validation).** Summary: each fabric card's Komponen Hardware section is an add/remove list of {material, qty} rows, reusing the same search+dropdown picker pattern as Bahan but single-select per row.
       - **"Salin Komponen Hardware ke bahan lain" button:** only appears once at least 2 fabric cards exist and the first card has at least 1 hardware component filled; disabled/hidden otherwise. A single tap, not a toggle — running it twice after further edits just re-copies the current state of card 1 into the others (overwriting, with a brief confirm if the target cards already have their own entries, so a copy doesn't silently clobber manually-entered data).

     - **Tambah Hardware — full spec & layout (this was previously a single vague bullet; here's the complete technical doc for Claude Code and Claude Design):**
       - **Where this lives:** inside **each fabric card** in section 4 (Detail Resep) — not a separate top-level section of the sheet. If 2 fabrics are selected, there are 2 independent Komponen Hardware lists, one per card, since hardware needs can differ by fabric too (rare, but e.g. a lined satin variant might need an extra snap that an unlined waffle variant doesn't).
       - **Section layout within a card, top to bottom:**
         1. A small label **"KOMPONEN HARDWARE"** (matches the muted all-caps label style used for "LEBAR POTONG (CM)" etc. elsewhere in the same card).
         2. **Zero or more hardware rows** (see row layout below), stacked vertically, each separated by a thin divider line (same divider style as the rest of the card's fields).
         3. An **"+ Tambah Komponen"** row at the bottom of the list — full-width, dashed border, centered text, matching the visual style already used for "+ Tambah Komponen" in the reference Editor screenshot. This stays pinned as the last item in the list — new rows insert above it, never below.
       - **Empty state:** if zero hardware rows exist yet, the section shows just the label and the "+ Tambah Komponen" row (no "no components" placeholder text needed — the add row itself communicates the empty state clearly enough). This is a valid, save-able state — hardware is optional (see validation below).
       - **Row layout (each existing hardware row), left to right:**
         - **Material picker** (left, flexible width — takes up most of the row): shows the selected hardware material's name once picked (e.g. "Ring Elastis 3mm"), or a muted placeholder "Pilih hardware..." before anything is picked. Tapping it opens the **same search+dropdown pattern as the Bahan field** (search box appears, typing filters a dropdown of Hardware-category materials with at least one purchase on record — same eligibility rule as fabric), but this picker is **single-select per row** (not tokenized/multi-select like Bahan) — picking one result fills this row's material and closes the dropdown, it does not add a token, since a hardware row is exactly one material.
         - **Qty field** (right, fixed narrow width, e.g. "× 1 pcs" or "× 5 cm"): reuses the same numeric-input component spec'd elsewhere (numeric keypad, must be > 0). The unit suffix shown is `material.usage_unit` — "pcs" for count-based hardware (rings, clips), "cm" for length-based hardware (karet elastis, ribbon). This unit is set when the material is first created in Tambah Pembelian and flows through to the Resep screen automatically — no separate toggle needed.
         - **Remove affordance** (far right, small "×" or trash icon, minimum comfortable touch target ~44×44pt): tapping it removes this row immediately — no confirmation needed, since re-adding a row is trivial and this isn't a destructive action against saved data (the whole sheet hasn't been submitted yet).
       - **"+ Tambah Komponen" tap behavior:** appends a new empty row (picker shows placeholder, qty field empty) directly above the "+ Tambah Komponen" row itself, and immediately opens that new row's material picker (auto-focus) so the user can start typing right away without an extra tap.
       - **Duplicate prevention:** once a material is picked in one row, it's excluded from the dropdown in every other row within the *same card* (a recipe shouldn't list "Ring Elastis 3mm" twice with two different quantities — if more is needed, that's one row with a higher qty). This exclusion is per-card only — the same hardware material can appear in both the Satin card and the Waffle card independently, since those are entirely separate recipes.
       - **Validation:** a row with a picked material but empty/zero qty is invalid (blocks "Simpan Resep", inline error under that row's qty field). A row that's still at the placeholder/unpicked state is only invalid if the user tries to leave it half-filled (e.g. qty typed but no material picked) — an untouched empty row from "+ Tambah Komponen" that's simply removed again causes no error. Zero hardware rows total is valid (optional, as stated above).



   - **`Editor`** (pushed screen, entered only via a tapped row in `Daftar Resep` — never a freestanding tab, and distinct from the "Tambah Resep" sheet above):
     - Header shows context: "Scrunchie · XS" (product · size — no fabric name, since the editor may show multiple fabrics).
     - **Display mode:** shows all fabrics from all specs in the group together — one "Kain / Dimensi / Rotasi" block per fabric, stacked. Est. Kerja from the first spec.
     - **Edit mode:** `TokenizedMultiSelectField` pre-populated with all fabric tokens; per-fabric dimension cards for each; gabungkan/pisah toggle appears when ≥2 fabrics selected (default gabungkan). On save: update/create one spec per fabric in `editFabricIds`; delete specs for fabrics that were removed (if `canDelete`). Components taken from the first spec (shared across all fabrics in a gabungkan group).
     - **Versioning behavior** depends on whether ANY spec in the group has been used: if all have `usedInBatchCount == 0` → "Simpan Perubahan" (in-place edit); if any has `usedInBatchCount > 0` → dotted-box notice + "Simpan Versi Baru".
     - **Delete** available only if ALL specs in the group have `usedInBatchCount == 0`. Deletes all specs in the group.

   - **Pagination:** grows with every SKU × size × fabric-type combination (e.g. 2 products × 5 sizes × 2 fabrics = 20 rows already). Mock with enough rows to require scrolling within the grouped list, and to exercise the "Muat Lebih Banyak" pattern already shown in the mockup.

   **Tab: Optimasi** (Cutting Optimizer)

   The optimizer is per-physical-roll: one optimization session selects **one specific MaterialPurchase** (one roll/bolt), not a fabric type. Multiple purchases of the same fabric (e.g. Satin Putih beli dua kali) appear as separate selectable rows — each with their own remaining length and cost basis. The optimizer adapts its canvas dimensions to whichever roll the user selects.

   The **PatternSpec (Resep)** is linked to a fabric **material type** (not to a specific purchase), so the same spec applies to any roll of that fabric. The specific roll's dimensions are what the optimizer uses as the cutting canvas.

   **3-step flow:**

   - **Step 1 — Pilih Kain:** list all MaterialPurchases of category=fabric with `remaining_length_cm > 0`. Each row shows material name, roll dimensions (width × remaining length), and cost. User selects exactly one.

   - **Step 2 — Pilih Pola Kandidat:** **candidate filter rule (v1.3 — previously missing from spec):** only PatternSpecs where `fabrics[].materialId == selectedPurchase.materialId` are shown. A spec that uses Waffle Merah will not appear when Satin Putih is selected, even if both products have specs for the same size. This is correct — the optimizer packs pieces from ONE fabric roll at a time, so only specs whose cut dimensions reference that fabric type are relevant. The backend's `POST /cutting-optimizer/suggest` must also validate this: reject any candidate whose PatternSpec does not reference the submitted `material_purchase_id`'s material (400 Bad Request).
     - Each candidate row is checkable; once checked, a small "Min qty" field appears (optional floor constraint for the optimizer).

   - **Step 3 — Hasil:** calls `POST /cutting-optimizer/suggest`, returns up to 3 candidate layouts (Waste Minimum, Max Qty, Max Profit). User picks one → "Gunakan Layout Ini" → calls `POST /cutting-optimizer/layouts` + `POST /production-batches` → shows a **success screen** with batch summary (strategy name, total pcs, product breakdown) and two actions:
     - **"Lanjut ke Produksi"** — switches to the Produksi tab (the batch is now visible there as a draft)
     - **"Mulai Optimasi Baru"** — resets to Step 1 for the next roll

   This tab's output feeds directly into the Produksi tab — the "Lanjut ke Produksi" affordance is implemented (not a dead-end).

   **Tab: Produksi** (Production Batch Confirm)
   - Header shows draft provenance: **"Draft · dari Layout '[strategy name]'"** — e.g. "dari Layout 'Waste Minimum'" — so the user always knows which optimizer suggestion this batch came from (or "Manual" if no optimizer was used).
   - **Qty Aktual per Ukuran**: one row per (product, size) in this batch, showing the optimizer's suggested qty struck through, with an editable actual-qty field next to it — this is where defects/miscounts get corrected before locking.
   - **Rincian HPP** (per size, shown for the size currently selected — tap a row to switch): legend rows for Kain (fabric), Bahan Pooled (thread), Hardware, Tenaga Kerja, Overhead, dan HPP Total. This is the "trust-building" breakdown from Section 1.4 — always show all 5 components, never just the total. **Data source:** `latest_hpp_breakdown` from `GET /products/{sku}/sizes` — populated by the iOS `fetchSizeToProductMap()` enrichment pass. **Hidden if null** (first-ever production of a size has no prior confirmed HPP to reference — section is simply not shown; does not block confirmation). This is not the HPP computed by the current batch; it is the last confirmed HPP for reference only.
   - `Konfirmasi & Tambah ke Stok` button → calls `POST /production-batches/{id}/confirm`. Warning text "Setelah dikonfirmasi, biaya batch ini terkunci dan tidak dapat diubah" shown below the button — irreversible cost-lock, not just a stock update.

3. **Products (Finished Goods) — 3-level navigation (updated v1.8)**

   The product tab uses a 3-level drill-down. The flat "all variants in one list" layout from earlier drafts does not scale once a product has many fabric types (e.g. 10 fabrics × 3 sizes = 30 rows in a single card).

   **Level 1 — ProdukListView (product list):**
   - One card per product. Each card has two clickable areas:
     - **Card header (product name + SKU + "›")** → navigates to `ProdukDetailView` (product management: rename, archive, add size).
     - **Size label rows inside the card** (M, L, XL, …) → navigates to `ProdukSizeGroupView`. Each row shows: size label, aggregate stock (sum of all fabric variants), worst-case stock badge (Habis/Menipis), variant count if > 1, and lowest selling price.
   - These are independent NavigationLinks — tapping "M" does NOT go through the product detail screen.

   **Level 2 — ProdukSizeGroupView (fabric variants for one size):**
   - Title: "Scrunchie · M"
   - Aggregate card: product name, size label large, variant count, total stock.
   - "Varian Kain" section: lists all non-archived `ProductSize` rows where `sizeLabel == selectedLabel` — e.g. "M · Satin Pelangi", "M · Waffle Merah". Each row shows fabric name (not the full displayLabel), stock, HPP, margin.
   - **"Tambah Varian"** button: opens `AddSizeSheet` with `sizeLabel` pre-filled and locked. User selects a fabric from `FabricPickerSheet` — a searchable bottom sheet that lists **all fabrics in bahan inventory**. Fabrics that already have an active PatternSpec for this (product + size) are marked "Ada di resep" (green badge) and enable the optional "Stok Awal" field after selection. Fabrics without a matching spec are shown without the badge — selecting one still creates the variant but does not deduct bahan stock (no spec = no cut dimensions available). If the user types a fabric name that doesn't match any inventory item, a "Tambah '[X]'" row appears at the bottom so they can name a brand-new fabric variant not yet in inventory (no spec, no bahan deduction). A footer note under the selected fabric tells the user which path applies before they save.
   - Swipe-to-archive: archives a single fabric variant (not the whole size group).
   - Tapping a row → Level 3.

   **Level 3 — ProdukSizeDetailView (one specific size + fabric):**
   - Title: displayLabel ("M · Satin Pelangi").
   - Info card: stock, fabric name, selling price, margin, reorder min. Edit button to change selling price and reorder min.
   - HPP breakdown card (fabric / pooled / hardware / labor / overhead / total) — only shown after at least one confirmed production batch exists for this variant.
   - Price Advisor: collapsible section. Inputs: target margin %, marketplace fee %. Output: suggested price, actual margin, markup. "Gunakan Harga Ini" applies the suggested price via PATCH.

   **ProdukDetailView (product management — reached from card header, not from size rows):**
   - Shows same size-label groups (M, L) as `ProdukListView`, each linking to `ProdukSizeGroupView`. "Jumlah Ukuran" shows unique size label count (not total variant count).
   - Actions: rename product (inline alert), archive product (with confirmation). "Tambah Ukuran" button opens `AddSizeSheet` with no prefill — user enters both size label and optional fabric variant.

   **Rationale:** separating "sizes" from "fabric variants of a size" is the critical UX decision here. A product with 3 sizes and 5 fabric types would otherwise produce 15 undifferentiated rows in a flat list. The 3-level hierarchy makes it clear that M/L/XL are structural size differences, while Satin/Waffle/Linen are production variants of the same structural size.

   - **Pagination:** same pattern as Bahan/Resep — mock with enough SKU × size × fabric rows to exercise scroll/pagination.
4. **Sales**
   - New sale: pick product(s)+qty, discount, payment method → auto-deducts stock, computes profit using HPP at time of sale
   - Sales history / invoice list — this one especially needs realistic pagination in mockups, since sales entries accumulate daily; show at least 20-30 sample invoices spanning several days/weeks so date-grouping and pagination/infinite-scroll are both visible.
5. **Reports**
   - Sales by period, best/worst margin products, stock card (kartu stok) per product, waste rate by material, low-stock alerts (finished products)
6. **Settings**
   - Labor rate/minute, overhead rate, pooled material rates (thread etc.), marketplace fee defaults

### Sample data & pagination — general note for Claude Design
Several screens above (Bahan, Resep, Products, Sales) are lists that will realistically grow well past what fits on one screen. When generating mockups, use enough sample rows (15-30, varied dates/values/categories) to actually exercise scrolling and pagination UI (e.g. "load more", numbered pages, or infinite scroll — pick one pattern and use it consistently across all list screens), rather than the 2-6 item examples used earlier in this doc for illustration. The 2-6 item examples in Section 1 and the screenshots referenced during design review are illustrative only, not the target data volume for final mockups.

### Key UX principles to carry into mockups
- The **Optimasi tab** (within Produksi) is the hero feature — give it the most visual/design attention (a simple 2D layout preview, even schematic, helps trust the numbers).
- Always show HPP breakdown (fabric / hardware / labor / overhead) stacked, not just a total — builds user trust in the number.
- Distinguish clearly in UI copy between "suggested/estimated" values (pre-confirm) and "actual/locked" values (post-confirm) — different visual treatment (e.g. dashed vs solid, "draft" badge). The mockup's strikethrough-suggested / editable-actual pattern in the Produksi tab is a good implementation of this — keep it.
- Margin vs markup must never be ambiguous — always label explicitly.
