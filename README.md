# Oura Studio — iOS Frontend Application

Oura Studio is a custom, high-performance, native iOS inventory and production management application designed specifically for a self-production handmade accessories business (scrunchies, headbands, etc.). 

The core mission of this application is to solve the complex problem of **accurate HPP (COGS) calculation** when raw fabric roll material is nested and cut into multiple finished goods with different size dimensions, alongside managing stock ledger tracking, pricing optimization, and sales recording.

---

## ✨ Highlights

### 📦 Shopee Bulk Upload — XLSX Export
One-tap export of all active products into a **Shopee Seller Centre-compatible `.xlsx`** file. Instead of generating a raw workbook, the app duplicates Shopee's official master template (`Shopee_mass_upload_2026-09-07_basic_template.xlsx`) via `openpyxl` and writes data starting at **Row 7** on the `Template` sheet — preserving the verification token and header metadata in Rows 1–6 so the file passes Shopee's internal parser.
*   **Auto-mapping:** `scrunchie` → Category ID `100146`, `pouch` → `101650`; brand field left empty; only variants with `selling_price > 0` are exported.
*   **Smart defaults:** Weight & dimensions auto-filled per category (Scrunchie: 50g / 10×10×2 cm, Pouch: 100g / 15×12×5 cm), logistics `channel_id.8003` (Regular Cashless) set to `Active`.
*   **Row rules:** Product name/description/parent SKU written only on the first variant row; `Variation Integration Code` filled on every variant row; variant SKU auto-generated as `[PARENT_SKU]-[SIZE]`.
*   **iOS flow:** `GET /api/v1/products/shopee-bulk-upload` → download to temp → move to Documents as `Shopee_Mass_Upload_<timestamp>.xlsx` → present **Share Sheet** (`UIActivityViewController`) for instant AirDrop / Save to Files / WhatsApp / Email. Entry via `square.and.arrow.up` button in `Products` toolbar → `ShopeeBulkUploadSheet` summary (counts per category).

### 🖨️ Bluetooth Thermal Printer Integration
Native **BLE thermal printing** for 57mm receipts and 33×15mm QR labels, built on `CoreBluetooth` (`TSPLPrinterService.swift` + `ReceiptGenerator.swift`).
*   **Dual-mode aware:** Handles ESC/POS (Receipt mode, continuous paper) vs. TSPL (Label mode) — printers switch via 5-sec FEED hold; receipt jobs are sent as ESC/POS and require Receipt mode.
*   **BLE robustness:** Auto-connects to last paired printer (`UserDefaults` `printerUUIDString`), scans with `nil` services to discover generic/UART printers (FFE0/FFE1), chunked `writeWithoutResponse` with inter-chunk delay, busy-window guard to avoid overlapping jobs, live `isPrinterReady`/`bluetoothState` publishers.
*   **Receipt UX:** `Auto Print Receipt` toggle in `Record Sale` (persisted via `UserDefaults`) — on `Save` with toggle ON, prints in background without blocking UI (toast: "Receipt printing..."); manual `Print Receipt` + `Save as PDF` (PDFKit + Share Sheet) on `Sales Detail` with QR codes for Instagram/TikTok and 32-char/line 57mm layout.
*   **Label printing:** Direct TSPL label print for QR variants — configurable width/height/gap, structured caption per-field layout, calibrated dot math to prevent overlap.

---

## 📸 Screenshots


| Preview | Screen & Description |
|---|---|
| <img width="1920"  alt="image" src="https://github.com/user-attachments/assets/f34ef79b-3cae-48b9-b738-38f9287a0968" /> | **01 — Home (Dashboard)** — Main screen greeting the user (`Good morning, Aswarhan`). `Today's Revenue Rp591,001` card with summary `26 transactions · 44 items sold · 99% margin`. Below are `Quick Actions` (Buy Material, Record Production, Pattern Optimization, Profit Report), `Stock Alerts` (e.g., muslin salu scrunchie... Out of Stock) and `Quick POS Cashier` (Record Sale / Scan & Sell). Bottom navigation: Home · Production · Products · Sales · More. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/8e39ac36-2ba8-4513-be35-af6febced91e" /> | **02 — Record Sale (POS Sheet)** — `Record Sale` sheet for quick transactions. `Sale Info` section: optional customer name, `Payment: Cash`, toggles `Paid` (on) & `Auto Print Receipt`. `Products Sold` section: e.g., `Black Velvet Scrunchie · L` (Available: 1 pcs) with `Qty` controls, `Unit Price Rp18,000`, `Discount Rp0`, `Add Product` button + QR Scan icon. `Summary` shows `Total Revenue Rp18,000`. `Cancel` / `Save` buttons in the header. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/45157fde-c935-4a64-bd1e-50e09fd55cba" /> | **03 — Production › Materials** — `Production` tab with 4 sub-tabs: `Materials` (active), Recipe, Optimization, Production. Search `Search materials...`, category filters (`All/Fabric/Thread/Hardware/Packaging`) and fabric family filter (`All Types, Generic Cotton, Yamaha Satin...`). Fabric list shows weighted-average cost per meter, e.g., `Dacron 5mm · Rp7,000/m`, `Red Floral Printed Cotton · Rp8,000/m`. FAB `+` to add a new material. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/e316175c-e8ed-41d7-a606-035dc5cd99fd" /> | **04 — Products (Finished Goods Catalog)** — `Products` header with search & QR/Share actions. Stats cards: `Total Products 67`, `Total Variants 240 var`, `Total Stock 247 pcs`, `Out of Stock 107 var`, `Capital Value Rp4,499,956` & `Potential Revenue Rp4,495,081` (*132 variants using selling price as cost*). Toggle `Filter by Stock Entry Date`. Product listing e.g., `nylon zipper box pouch` (SKU POUKOTZIPNYL) with variants `M Rp45,001 · 1 pcs` and `L Rp55,000 · 4`. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/d8d2416a-fe91-4f3a-99fe-ea4fad3242fc" /> | **05 — QR Generator** — `QR Generator` sheet for label printing. Search `Search product or size...` and toggle `Filter by Stock Entry Date`. Options `Select All` & `Select all sizes`. Each variant displays a QR code, size (`M/L`) and stock (`Stock: 1 pcs`), e.g., group `nylon zipper box pouch` (M 1 pcs, L 6 pcs) and `silver zipper box pouch` (M 3 pcs, L 3 pcs). QR codes are used for `Scan & Sell` / `Scan to Stock`. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/b44c22e0-8b6d-4dd0-9b16-070bbeaa491b" /> | **06 — Shopee Bulk Export** — `Shopee Export` sheet for marketplace. Generates a Shopee-template Excel file containing Scrunchie & Pouch product details ready to upload. Summary `Products Ready to Export`: `Scrunchie Category ID: 100146 (1 Product)` and `Pouch Category ID: 101650 (1 Product)`. Main button `Download Shopee Template` at the bottom. Speeds up bulk listing without manual input in Seller Centre. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/f254ad9f-acda-4db4-85e4-aa8319c93859" /> | **07 — Sales (Transaction History)** — `Sales` screen with `DateRangeField` filter (`Sep 20 – Sep 20, 2026`) and 3 summary cards: `Revenue Rp591,001`, `Sold 44 pcs`, `Transactions 26 trx`. Daily invoice list e.g., `INV-000112 Paid Rp28,000 (Cash · 2 items · 09:10)` expandable to show item details (`Black Yamaha Satin Scrunchie · M 1 pcs × Rp15,000 - Rp2,000`). FAB `+` for new sale & QR icon at top-right. |
| <img wwidth="1920" alt="image" src="https://github.com/user-attachments/assets/257238fe-52aa-4856-8ad4-5c10e159825b" /> | **08 — More › Reports & Settings** — `More` tab with segmented control `Reports` (active) / `Settings`. `Available Reports` menu: `Sales Report` (Revenue & profit per period), `Product Sales Ranking` (best-selling variants), `Product Margin Ranking` (highest margin), `Fabric Waste Analysis` (waste percentage per material). This screen is the business analytics hub. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/d324c387-660d-4c24-b8ab-e7d602c7544e" /> | **09 — Sales Report (Detail)** — `Sales Report` detail with `Time Range Aug 21 – Sep 20, 2026`. `Summary`: `Total Revenue Rp2,383,826`, `Total Profit Rp2,319,536`, `Transactions 110`, `Pcs Sold 166 pcs`. `Export JSON for AI` button for further analysis. `Per Period` table details daily revenue, e.g., `2026-08-23 Rp617,000 (26 transactions)`, `2026-08-30 Rp495,000 (23 transactions)`. |


---

## 📱 Core Features

1.  **Home (Dashboard):**
    *   Daily business performance summary widgets (Revenue, Order Count, Net Profit, Margin Percentage).
    *   Today's transaction list.
    *   Automatic low-stock warning/alert system.
2.  **Production (Production Hub):**
    *   **Materials:** Track remaining fabric roll length in centimeters (`remaining_length_cm`) and weighted-average cost. Active/archived material status management.
    *   **Recipes (Pattern Specs):** Fabric cut layout specs, hardware requirements, and labor components per product size.
    *   **Cutting Optimizer:** Cutting layout recommendation algorithm (*two-phase shelf-packing heuristic*) to find minimal waste and maximum profit strategies.
    *   **Production Batches:** Lock and freeze production costs (*cost-lock*) after confirming a physical cutting batch to add to finished-goods stock.
3.  **Products (Finished Goods Catalog):**
    *   3-level navigation structure (Product -> Size/Color -> Variant Detail).
    *   Top summary statistics (Total Product Types, Total Stock Quantity, Empty Variant Count).
    *   **Price Advisor:** Ideal selling price simulation tool based on target margin percentage, marketplace fees, and promo allocation.
    *   Supports Manual HPP (*Manual HPP Override*) when products are added outside the standard cutting optimization flow.
4.  **Sales (Point of Sale):**
    *   Quick cashier transaction recording with real-time product stock availability validation.
    *   Sales date-range filtering using the dynamic `DateRangeField` component.
    *   Quick stock adjustment sheet directly from the POS screen.
5.  **QR Code System (QR Code Integration):**
    *   **QR Generator:** Create and print A4 PDF sheets containing QR barcodes for dozens of selected product variants at once.
    *   **QR Scanner:** Universal fast barcode scanner (VisionKit) for cashier checkout (*Scan to Sell* / *QR Cart Mode*) and warehouse restocking (*Scan to Stock*).
6.  **Shopee Bulk Upload (XLSX Export):**
    *   One-tap generation of Shopee Mass Upload `.xlsx` from the official master template — preserves verification token, writes from Row 7, auto-maps categories/weights/dimensions, and shares via iOS Share Sheet.
7.  **Thermal Printing (Bluetooth BLE):**
    *   57mm ESC/POS receipt printing + 33×15mm TSPL QR label printing over BLE with auto-reconnect, chunked writes, busy-window guard, auto-print toggle, and PDF fallback — powered by `TSPLPrinterService` / `ReceiptGenerator`.

---

## 🛠 Technology Stack & Architecture

*   **Platform:** iOS 16.0+ (SwiftUI, Swift Concurrency `async/await`)
*   **Token Security:** Google SSO authentication stored securely locally via **iOS Keychain Manager**.
*   **Networking:** `APIService.swift` (communicates with the backend REST API, supports local mock mode via `MockAPIService.swift`).
*   **Printing & Sharing:** `CoreBluetooth` + TSPL/ESC-POS (`TSPLPrinterService.swift`), `PDFKit` for receipt PDF, `UIActivityViewController` for XLSX/PDF sharing; backend `openpyxl` for Shopee template cloning.
*   **UI/UX Standard:** Custom design system `OuraTheme.swift` — elegant, consistent, responsive, and dark-mode friendly.

---

## 💻 How to Run the App

1.  Open `oura studio frontend.xcodeproj` in **Xcode** (Xcode 15+ recommended).
2.  Make sure `APIService.swift` points to the active backend server address:
    ```swift
    var baseURL: String = "backend-api -url"
    ```
3.  Select an iOS simulator (e.g., iPhone 15) or connect your physical iPhone device.
4.  Press **Run** (`⌘ + R`) to build and launch the app.

---

## 📁 Project Folder Structure

```text
oura studio frontend/
├── Components/                 # Shared UI components (DateRangeField, Input, etc.)
├── Core/                       # AppState, Keychain, OuraTheme (Core Configuration)
├── Networking/                 # API Client handlers & Pydantic-mapped Models
├── Screens/                    # UI screens per feature (Auth, Home, Production, Products, etc.)
└── doc/                        # Handoff docs, revision specs & version history
```
