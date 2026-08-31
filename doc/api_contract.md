# Oura Studios — Database Schema & API Contract

This document contains the backend database schema, the REST API contract, and the CRUD audit logic. It is optimized for the **Backend** role.

---

## 3. Database Schema

```sql
-- ===== AUTH (updated v1.1 — Google SSO replaces email+password) =====

CREATE TABLE owner_account (
    id          UUID PRIMARY KEY,
    google_sub  TEXT NOT NULL UNIQUE,   -- Google's stable user ID ('sub' claim from the verified ID token)
    email       TEXT NOT NULL UNIQUE,   -- from Google, for display/logging only — not the auth lookup key
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Still a single-row-in-practice table. No password_hash column — auth is fully delegated to Google.
-- Row is auto-provisioned on the owner's FIRST successful Google Sign-In (when the verified email matches
-- the AUTHORIZED_OWNER_EMAIL env var). On subsequent sign-ins, the backend verifies google_sub matches
-- the existing row (google_sub is stable; email can change in Google, so don't use email as lookup key).
-- No roles/permissions table: every authenticated request has full access to everything.
-- Recovery (owner changes Google account): update AUTHORIZED_OWNER_EMAIL in env + DELETE the owner_account
-- row — the next sign-in will re-provision with the new google_sub.

-- ===== MATERIALS =====

CREATE TABLE material (
    id              UUID PRIMARY KEY,
    name            TEXT NOT NULL,              -- "Satin Putih", "Benang Merah"
    category        TEXT NOT NULL,               -- 'fabric' | 'thread' | 'hardware' | 'packaging'
    cost_class      TEXT NOT NULL,               -- 'direct_precise' | 'direct_pooled'
    purchase_unit   TEXT NOT NULL,               -- 'meter' | 'roll' | 'pack' | 'pcs'
    usage_unit      TEXT NOT NULL,               -- 'cm' | 'cm2' | 'pcs'
    fabric_width_cm NUMERIC,                     -- nullable, only for category='fabric': typical/default width, used to pre-fill (not lock) new purchase entries
    current_avg_cost NUMERIC NOT NULL DEFAULT 0, -- weighted average cost per usage_unit
    reorder_min_qty NUMERIC,
    is_archived     BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE supplier (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE material_purchase (
    id              UUID PRIMARY KEY,
    material_id     UUID NOT NULL REFERENCES material(id),
    width_cm        NUMERIC,          -- fabric only ("Lebar (cm)") — every fabric purchase is a bounded rectangle, no piece/roll distinction
    length_cm       NUMERIC,          -- fabric: "Panjang (cm)" of the roll. hardware (optional): length per unit, e.g. 100cm for elastic bands — when set, enables remaining_length_cm tracking for that purchase
    qty             NUMERIC,          -- thread/hardware: jumlah gulung / jumlah pcs. hardware with length_cm: qty × length_cm = total length purchased
    package_label   TEXT,             -- thread only, optional: 'Kecil' | 'Besar' or similar — descriptive only, not used in cost calc
    total_cost      NUMERIC NOT NULL,
    supplier_id     UUID REFERENCES supplier(id),   -- nullable, optional field
    purchased_at    DATE NOT NULL,
    remaining_length_cm NUMERIC,     -- fabric: decremented as CuttingLayouts consume it. hardware with length_cm: initialized to qty × length_cm, decremented as PatternSpec components consume it. null for count-only hardware (no length_cm) and thread/packaging
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== PRODUCTS & RECIPES =====

CREATE TABLE product (
    id          UUID PRIMARY KEY,
    sku         TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,           -- "Scrunchie"
    is_archived BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE product_size (
    id                  UUID PRIMARY KEY,
    product_id          UUID NOT NULL REFERENCES product(id),
    size_label          TEXT NOT NULL,           -- 'XS','S','M','L','XL','XXL'
    fabric_variant_name TEXT,                    -- nullable; e.g. 'Satin Pelangi', 'Waffle Merah'. NULL means no
                                                 -- fabric-specific variant. Each (size_label, fabric_variant_name)
                                                 -- combination is a distinct row with its own stock counter.
    reorder_min_qty     NUMERIC,                 -- minimum finished-goods stock before low-stock alert triggers
    is_archived         BOOLEAN NOT NULL DEFAULT false, -- soft-delete: see CRUD audit in Section 6
    UNIQUE(product_id, size_label, fabric_variant_name)
    -- NOTE v1.7: constraint changed from UNIQUE(product_id, size_label) — size_label alone is no longer unique
    -- when fabric variants exist. Backend must enforce this composite key on create and reject duplicates with 409.
);

-- Recipe: keyed by (product_size, fabric material) since consumption differs per fabric type.
-- Versioned: don't hard-delete, deactivate + insert new row, so historical batches keep original costing basis.
CREATE TABLE pattern_spec (
    id                  UUID PRIMARY KEY,
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    fabric_material_id  UUID NOT NULL REFERENCES material(id),
    cut_width_cm        NUMERIC NOT NULL,
    cut_height_cm       NUMERIC NOT NULL,
    rotation_allowed    BOOLEAN NOT NULL DEFAULT true,
    est_labor_minutes   NUMERIC NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    effective_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    effective_to        TIMESTAMPTZ
);

-- Non-fabric components needed per product_size (hardware: clips, rings; direct_precise class)
CREATE TABLE pattern_component (
    id                  UUID PRIMARY KEY,
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    material_id         UUID NOT NULL REFERENCES material(id),
    qty_per_unit        NUMERIC NOT NULL
);

-- ===== CUTTING OPTIMIZER =====

CREATE TABLE cutting_layout (
    id                  UUID PRIMARY KEY,
    material_purchase_id UUID NOT NULL REFERENCES material_purchase(id),
    status              TEXT NOT NULL DEFAULT 'suggested', -- 'suggested' | 'used' | 'discarded'
    waste_pct           NUMERIC,
    total_fabric_cost   NUMERIC NOT NULL,   -- cost allocated across this layout (usually = purchase total_cost)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cutting_layout_item (
    id                  UUID PRIMARY KEY,
    cutting_layout_id   UUID NOT NULL REFERENCES cutting_layout(id),
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    orientation         TEXT NOT NULL,      -- 'normal' | 'rotated'
    qty_suggested       INTEGER NOT NULL,
    fabric_length_used_cm NUMERIC NOT NULL, -- length of roll consumed for this row/group
    cost_per_piece      NUMERIC NOT NULL    -- derived: (share of total_fabric_cost) / qty_suggested
);

-- ===== PRODUCTION =====

CREATE TABLE production_batch (
    id                  UUID PRIMARY KEY,
    cutting_layout_id   UUID REFERENCES cutting_layout(id), -- nullable: batch can exist without optimizer (manual entry)
    produced_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    status              TEXT NOT NULL DEFAULT 'draft',      -- 'draft' | 'confirmed'
    notes               TEXT
);

CREATE TABLE production_batch_item (
    id                  UUID PRIMARY KEY,
    production_batch_id UUID NOT NULL REFERENCES production_batch(id),
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    pattern_spec_id     UUID NOT NULL REFERENCES pattern_spec(id),
    qty_actual          INTEGER NOT NULL,        -- user-confirmed, may differ from cutting_layout_item.qty_suggested
    hpp_fabric          NUMERIC NOT NULL,
    hpp_pooled_material NUMERIC NOT NULL,        -- thread etc.
    hpp_hardware        NUMERIC NOT NULL,
    hpp_labor           NUMERIC NOT NULL,
    hpp_overhead        NUMERIC NOT NULL,
    hpp_total           NUMERIC NOT NULL         -- sum of above; locked once batch confirmed
);

-- ===== STOCK =====

CREATE TABLE stock_ledger (
    id                  UUID PRIMARY KEY,
    product_size_id     UUID NOT NULL REFERENCES product_size(id),
    change_qty          INTEGER NOT NULL,        -- + for production/return, - for sale/damage
    reason              TEXT NOT NULL,           -- 'production' | 'sale' | 'adjustment' | 'damage' | 'return'
    ref_type            TEXT,                    -- 'production_batch' | 'sales_order'
    ref_id              UUID,
    unit_hpp_snapshot   NUMERIC,                 -- HPP at time of this movement (for COGS on sale)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== SALES =====

CREATE TABLE sales_order (
    id              UUID PRIMARY KEY,
    invoice_no      TEXT NOT NULL UNIQUE,
    customer_name   TEXT,
    payment_method  TEXT,                        -- 'cash' | 'transfer' | 'qris' | 'marketplace'
    marketplace_fee_pct NUMERIC DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'unpaid', -- 'unpaid' | 'paid'
    sold_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sales_order_item (
    id                  UUID PRIMARY KEY,
    sales_order_id      UUID NOT NULL REFERENCES sales_order(id),
    product_size_id      UUID NOT NULL REFERENCES product_size(id),
    qty                  INTEGER NOT NULL,
    unit_price           NUMERIC NOT NULL,
    discount             NUMERIC NOT NULL DEFAULT 0,
    unit_hpp_snapshot    NUMERIC NOT NULL,        -- pulled from stock_ledger at sale time
    line_profit          NUMERIC NOT NULL         -- (unit_price - discount - unit_hpp_snapshot) * qty
);

-- ===== SETTINGS =====

CREATE TABLE settings (
    key         TEXT PRIMARY KEY,   -- 'labor_rate_per_minute' | 'default_overhead_per_unit' | 'pooled_material_rate:thread' etc.
    value       NUMERIC NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 4. API Contract

Base path: `/api/v1`. All bodies JSON. **Auth is required on every endpoint below except `/auth/google`** — see Section 0 for why. Every request other than the Google sign-in exchange must carry `Authorization: Bearer <token>`; a missing/invalid/expired token returns 401.

### Auth (updated v1.1)

```
POST   /auth/google
  body: { "id_token": "<google_id_token>" }
  → returns { access_token, expires_at } (app-issued JWT bearer token)

  Backend verification steps (must happen in this order):
  1. Call Google's tokeninfo endpoint to verify the id_token is authentic and not expired:
       GET https://oauth2.googleapis.com/tokeninfo?id_token=<id_token>
     OR use google-auth-library (Python: `google.oauth2.id_token.verify_oauth2_token`)
     for offline verification using Google's public keys (preferred for production — no extra HTTP call).
  2. Verify `aud` claim in the decoded token matches your iOS OAuth client ID
     (prevents tokens from other apps being replayed here).
  3. Extract `sub` (stable Google user ID) and `email` from the verified token payload.
  4. Check `email` against AUTHORIZED_OWNER_EMAIL env var → 403 Forbidden if it doesn't match.
  5. Upsert owner_account:
       - If no row exists yet: INSERT (google_sub, email) — first-time provisioning.
       - If a row exists: verify google_sub matches the stored row → 403 if it doesn't
         (prevents a different Google account with a matching email from taking over).
  6. Issue an app-level JWT (signed with your own secret key, not Google's) containing owner_account.id.
     Return { access_token, expires_at }.

  Error responses:
  → 400 if id_token is missing or malformed
  → 401 if Google reports the token is invalid or expired
  → 403 if the verified email doesn't match AUTHORIZED_OWNER_EMAIL, or google_sub conflicts

  -- Required environment variables for the backend:
       AUTHORIZED_OWNER_EMAIL   the owner's Google email address (e.g. owner@gmail.com)
       GOOGLE_CLIENT_ID         the iOS OAuth 2.0 client ID from Google Cloud Console
                                (used to verify the `aud` claim in step 2 above)
       JWT_SECRET               secret key for signing app-level JWTs
  -- Token lifetime: recommend 30-day expiry for a single-owner app (no public attack surface).
     No refresh-token flow needed — owner simply re-authenticates via Google on expiry.
     See Section 6 for remaining open decisions.
```

### Materials

```
POST   /materials
GET    /materials
GET    /materials/{id}
PATCH  /materials/{id}

POST   /materials/{id}/purchases
  body: { width_cm?, length_cm?, qty?, package_label?, total_cost, supplier_id?, supplier_name?, purchased_at }
  -- fabric materials: width_cm + length_cm required (plain bounded rectangle, no purchase-type distinction), qty/package_label omitted
  -- thread materials: qty required, package_label optional, width_cm/length_cm omitted
  -- hardware materials: qty required; length_cm optional (only for length-tracked hardware like elastic bands); package_label/width_cm omitted
  --   if length_cm present: server initializes remaining_length_cm = qty × length_cm; cost_per_cm = total_cost / remaining_length_cm
  --   if length_cm absent: count-only tracking; remaining_length_cm stays null
  -- supplier: pass supplier_id if an existing supplier was picked from the dropdown; pass supplier_name instead to create
     a new Supplier inline (same "+ Tambah supplier baru" pattern as material creation); omit both if left blank (optional)
  → creates MaterialPurchase, updates material.current_avg_cost (weighted average)

GET    /materials/{id}/purchases

PATCH  /materials/{id}/purchases/{purchase_id}
  body: { width_cm?, length_cm?, qty?, total_cost?, supplier_id?, supplier_name?, purchased_at? }
  -- if the purchase is untouched (fabric/length-hardware: remaining_length_cm == qty × length_cm; count-only hardware: no stock_ledger rows reference it):
     all fields may be updated.
  -- if the purchase has any recorded consumption: width_cm/length_cm/qty are rejected (400) if present in the
     body — only total_cost, supplier_id/supplier_name, purchased_at may be changed.
  → recalculates material.current_avg_cost from all purchases after saving

DELETE /materials/{id}/purchases/{purchase_id}
  -- allowed only if untouched (same condition as above); returns 409 Conflict if the purchase has any
     recorded consumption (referenced by a CuttingLayout or stock_ledger entry), since deleting it would
     orphan locked production-batch cost history.
  → on success, recalculates material.current_avg_cost from remaining purchases
```

### Suppliers

```
POST   /suppliers
  body: { name }
  → creates Supplier. Also creatable inline via material_purchase's supplier_name shortcut above — this
    standalone endpoint exists for cases where Claude Design wants a direct create action outside that flow.

GET    /suppliers?search=
  → for the Supplier field's autocomplete dropdown, same pattern as material search
```

### Pattern Specs (Recipes)

```
POST   /pattern-specs
  body: { product_size_id, fabric_material_id, cut_width_cm, cut_height_cm,
          rotation_allowed, est_labor_minutes, components: [{material_id, qty_per_unit}] }
  → if no active spec exists yet for this (product_size_id, fabric_material_id): creates it directly
  → if an active spec exists and has zero ProductionBatchItem rows against it: updates that same row in place
  → if an active spec exists and has at least one ProductionBatchItem row against it: deactivates it and
    inserts a new versioned row (the original "always version forward" behavior)
  -- see Section 5's CRUD audit for why the middle case (in-place update) was added
  -- validation: fabric_material_id and every components[].material_id must reference a Material with at least
     one MaterialPurchase on record (no cost basis = can't compute HPP). The Bahan/Hardware picker in the
     Tambah Resep UI should only list materials satisfying this, per Section 2's "must already have a purchase
     on record" rule.

GET    /pattern-specs?product_id=&size=&fabric_material_id=
GET    /pattern-specs/{id}
```

### Cutting Optimizer

```
POST   /cutting-optimizer/suggest
  body: {
    material_purchase_id,
    candidates: [ { product_size_id, pattern_spec_id, min_qty? } ]
  }
  → runs two-phase shelf-packing heuristic (see Section 1.5 for full algorithm spec), returns candidate layouts (not persisted yet)
  -- min_qty: the algorithm guarantees this candidate receives at least min_qty pieces IF geometrically possible.
  --   Uses bestMinLen reservation (not primaryRowHeight-based) to avoid over-reserving the roll for one candidate's
  --   future minimum. Falls back to the alternative orientation if the primary orientation doesn't fit in available space.
  --   If min_qty cannot be satisfied for any candidate (geometry truly doesn't allow it), that candidate receives 0
  --   and is omitted from the layout — it is NOT an error condition. Backend must implement the same two-phase logic.
  response: {
    layouts: [
      {
        strategy: "max_qty" | "min_waste" | "max_profit",
        waste_pct: number,
        items: [
          { product_size_id, pattern_spec_id, orientation, qty_suggested,
            fabric_length_used_cm, cost_per_piece }
        ]
      }
    ]
  }

POST   /cutting-optimizer/layouts
  body: { material_purchase_id, chosen from one of the suggested layouts (items array) }
  → persists as CuttingLayout + CuttingLayout_items, status='suggested'
  → returns cutting_layout_id

POST   /cutting-optimizer/layouts/{id}/discard
```

### Production

```
POST   /production-batches
  body: { cutting_layout_id? }
  → creates draft ProductionBatch, pre-filled items from layout if provided (qty_actual = qty_suggested initially)

PATCH  /production-batches/{id}/items/{item_id}
  body: { qty_actual }
  → user edits actual qty after physical cutting
  -- updated v2.6: response must be the updated item only (NOT the parent batch object)
  response: {
    id, production_batch_id, product_size_id, pattern_spec_id,
    qty_actual, qty_suggested?,
    fabric_cost_per_piece?,
    hpp_fabric, hpp_pooled_material, hpp_hardware, hpp_labor, hpp_overhead, hpp_total
  }
  -- hpp_* will be 0.0 for draft batches; populated after confirm

POST   /production-batches/{id}/confirm
  → computes hpp_fabric / hpp_pooled_material / hpp_hardware / hpp_labor / hpp_overhead / hpp_total per item
    using: cutting_layout_item.cost_per_piece (fabric), settings pooled rates, pattern_component costs,
           est_labor_minutes × labor_rate_per_minute, overhead settings
  → writes stock_ledger rows (reason='production', unit_hpp_snapshot = hpp_total)
  → decrements material_purchase.remaining_length_cm and hardware material stock
  → sets production_batch.status = 'confirmed' (immutable after this)

GET    /production-batches/{id}
GET    /production-batches?status=
```

### Products / Stock

```
POST   /products
  body: { name, sku? }   -- sku auto-suggested from name (slug) if omitted, but must end up unique
  → creates Product. This is the only path new product types (e.g. "Pouch") get created — triggered from the "Tambah Resep" flow's "+ Buat produk baru" step, not a standalone product-creation screen.

POST   /products/{sku}/sizes
  body: { size_label, fabric_variant_name?, reorder_min_qty? }
  -- fabric_variant_name (v1.7): optional; if provided, this ProductSize represents one specific fabric
  --   variant (e.g. "Satin Pelangi"). Multiple sizes can share the same size_label as long as their
  --   fabric_variant_name differs. NULL fabric_variant_name is treated as a distinct value for uniqueness
  --   (i.e. "M" with no variant and "M · Satin Pelangi" are two different rows).
  -- Uniqueness: (product_id, size_label, fabric_variant_name) — return 409 if a duplicate is attempted.
  → creates ProductSize under an existing product. Triggered from "Tambah Resep" flow's "+ Buat ukuran baru"
    step, or auto-created by TambahResepSheet when a (sizeLabel + fabric) combination does not yet exist.

GET    /products
GET    /products/{sku}/sizes
  -- response: array of ProductSize objects. Each object MUST include all fields below.
  -- (updated v2.7: list endpoint must return the same HPP/stock/price fields as the detail endpoint —
  --  the iOS client uses this list in fetchSizeToProductMap() to populate RINCIAN HPP in batch confirmation)
  response per item: {
    id, product_id, size_label,
    fabric_variant_name,          -- nullable; display label = "{size_label} · {fabric_variant_name}" if set
    reorder_min_qty,              -- nullable Double
    selling_price,                -- nullable Double
    is_archived,
    current_stock_qty,            -- Int, total stock
    production_stock_qty,         -- Int, from confirmed batches (0 if none)
    manual_stock_qty,             -- Int, from manual stock adjustments (0 if none)
    latest_hpp_breakdown: {       -- null if this size has never been through a confirmed batch
      fabric, pooled_material, hardware, labor, overhead, total   -- all Double
    },
    margin_pct                    -- nullable Double (selling_price → HPP margin)
  }

GET    /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID, NOT sizeLabel: String — required because multiple sizes
  --   can share the same size_label when fabric variants exist
  response includes: current_stock_qty, reorder_min_qty, latest_hpp_breakdown, selling_price, margin_pct,
                     fabric_variant_name

PATCH  /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID
  body: { selling_price?, reorder_min_qty? }

POST   /products/{sku}/sizes/{sizeId}/price-advisor
  -- (v1.7) path parameter is now sizeId: UUID
  body: { target_margin_pct, marketplace_fee_pct?, promo_allocation_pct? }
  response: { suggested_price, resulting_margin_pct, resulting_markup_pct }

DELETE /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID (was size_label string in earlier versions)
  -- same archive-vs-hard-delete logic as before: archive if history exists, hard-delete if unused

POST   /stock/adjustments
  body: { product_size_id, change_qty, reason, note? }
  → manual stock opname / damage adjustment
```

### Sales

```
POST   /sales-orders
  body: {
    customer_name?, payment_method, marketplace_fee_pct?,
    items: [ { product_size_id, qty, unit_price, discount? } ]
  }
  → validates stock availability, pulls unit_hpp_snapshot from current stock cost,
    writes stock_ledger (reason='sale', negative qty), computes line_profit per item

GET    /sales-orders
GET    /sales-orders/{id}
PATCH  /sales-orders/{id}   body: { status }   -- mark paid
```

### Reports

```
GET /reports/dashboard
  -- added v1.2: single-call summary for the Beranda (Dashboard) screen
  -- updated v2.6: today_units_sold added
  response: {
    today_revenue, today_order_count, today_units_sold, today_profit,
    low_stock_alerts: [ { product_size_id, product_name, size_label, current_stock_qty, reorder_min_qty } ]
  }
  -- today_units_sold: SUM(qty) from sales_order_items where sold_at is today (server timezone)
  -- today is determined by server timezone; no parameters needed

GET /reports/sales?from=&to=&group_by=day|week|month
GET /reports/margin-ranking?sort=margin_pct
GET /reports/stock-card/{product_size_id}
GET /reports/waste-by-material?from=&to=
GET /reports/low-stock          -- finished products (product_size) below reorder_min_qty
```

### Settings

```
GET    /settings
PATCH  /settings   body: { key, value }
```

---

## 5. CRUD Audit — completeness check across all entities

| Entity | Create | Edit | Delete |
|---|---|---|---|
| Material | ✅ inline via first purchase | ✅ `PATCH /materials/{id}` (name, reorder_min_qty, etc.) | **No hard delete.** Added `is_archived` flag — see below. |
| MaterialPurchase | ✅ spec'd earlier | ✅ full if unused, cost/date/supplier-only if consumed — spec'd earlier | ✅ if unused / 🚫 blocked (409) if consumed — spec'd earlier |
| Supplier | ✅ inline via purchase, or `POST /suppliers` | ⚠️ was missing — added `PATCH /suppliers/{id}` below | ⚠️ was missing — added below, allowed only if unused |
| Product | ✅ inline via Tambah Resep | ⚠️ was missing — added `PATCH /products/{sku}` below (rename only; sku immutable) | **No hard delete once any size has history.** Added `is_archived` — see below. |
| ProductSize | ✅ inline via Tambah Resep (auto-created per fabric variant in v1.7) | ✅ `PATCH .../sizes/{sizeId}` — path param is UUID since v1.7 (was sizeLabel string) | ✅ `DELETE .../sizes/{sizeId}` — archive if used, hard-delete if never used; path param is UUID since v1.7 |
| PatternSpec (Resep) | ✅ spec'd earlier | ✅ always creates a new version — **refined below**: if the current version has zero production batches against it, editing updates it in place instead of spawning a version, to avoid version-number noise from typo fixes | ⚠️ was missing — added below, allowed only if the version has zero production batches against it |
| PatternComponent (hardware in a recipe) | ✅ part of the `components` array in `POST /pattern-specs` | ✅ same — the whole array is replaced on each save, no per-row endpoint needed | ✅ same — omitting a row from the array on save removes it |
| CuttingLayout | ✅ spec'd earlier | N/A (layouts aren't edited, just re-run via suggest) | ✅ `POST /cutting-optimizer/layouts/{id}/discard` already existed — **clarified below**: only valid while `status='suggested'` |
| ProductionBatch | ✅ spec'd earlier | ✅ `qty_actual` editable pre-confirm; fully locked post-confirm | ⚠️ was missing for the draft (pre-confirm) case — added below |
| StockLedger | ✅ system-written on every production/sale/adjustment | 🚫 **by design, never** | 🚫 **by design, never** — append-only audit log; corrections happen via a new offsetting adjustment, not by touching history. Worth stating explicitly rather than leaving as an apparent oversight. |
| SalesOrder | ✅ spec'd earlier | 🚫 **by design, not supported** — line items aren't edited after creation (money/stock have already moved); correct via cancel below, then re-enter | ⚠️ was missing entirely — added `POST /sales-orders/{id}/cancel` below (reverses stock, doesn't hard-delete the record so history isn't lost) |
| Settings | ✅ fixed key set, no creation needed | ✅ `PATCH /settings` already existed | 🚫 not applicable — fixed set of known keys, nothing to delete |

### New/updated endpoints from this audit

```
PATCH  /suppliers/{id}
  body: { name }

DELETE /suppliers/{id}
  -- allowed only if zero MaterialPurchase rows reference this supplier_id; 409 Conflict otherwise

PATCH  /products/{sku}
  body: { name }
  -- sku itself is immutable after creation (it's the stable identifier used throughout the API)

DELETE /products/{sku}/sizes/{sizeId}
  -- (v1.7) path parameter is now sizeId: UUID (was size_label string before v1.7)
  -- if this ProductSize has zero PatternSpec, zero stock_ledger, and zero sales_order_item history:
     hard-deletes it
  -- otherwise: sets is_archived = true instead (hides it from Tambah Resep pickers and Products list going
     forward, but keeps historical reports/HPP intact); returns which of the two happened so the UI can
     message it correctly ("Ukuran dihapus" vs "Ukuran diarsipkan karena sudah punya riwayat")

DELETE /products/{sku}
  -- same archive-vs-delete logic as above, applied across all of that product's sizes

PATCH  /materials/{id}
  -- (already existed) now also accepts { is_archived }

  -- archiving hides the material from Tambah Pembelian / Tambah Resep pickers, but existing purchases,
     pattern specs, and reports referencing it are unaffected

DELETE /pattern-specs/{id}
  -- allowed only if zero ProductionBatchItem rows reference this exact pattern_spec version; 409 otherwise
  -- note the refined edit behavior: POST /pattern-specs, when updating a spec that currently has zero
     ProductionBatchItem rows against it, updates that same row in place (no new version row inserted).
     Once at least one batch has been produced against a version, further edits always insert a new
     versioned row as originally spec'd — this avoids meaningless version numbers from same-day typo fixes.

POST   /cutting-optimizer/layouts/{id}/discard
  -- (already existed) clarified: only valid while status='suggested'; returns 409 if status='used'
     (a ProductionBatch already exists from this layout)

DELETE /production-batches/{id}
  -- allowed only while status='draft' (nothing has been written to stock_ledger or remaining_length_cm yet,
     since that only happens at confirm) — lets the user abandon a batch they started by mistake
  -- once status='confirmed', this always 409s — already-established immutability rule

POST   /sales-orders/{id}/cancel
  body: { reason? }
  → writes offsetting stock_ledger rows (reason='return', positive qty) for every item in the order,
    restoring finished-goods stock; sets sales_order.status = 'cancelled' (record is kept, not deleted,
    so sales history/reports stay accurate)
```
