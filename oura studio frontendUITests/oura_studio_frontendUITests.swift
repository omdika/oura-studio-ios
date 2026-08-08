import XCTest

final class oura_studio_frontendUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    func screenshot(_ app: XCUIApplication, name: String) {
        let s = app.screenshot()
        let att = XCTAttachment(screenshot: s)
        att.name = name; att.lifetime = .keepAlways; add(att)
    }

    func tapDone(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.exists { done.tap() }
    }

    /// Taps an item by text — handles both sheet pickers (plain buttons with explicit identifier)
    /// and regular UICollectionView-backed lists (cell-based fallback).
    /// SearchableDropdownField / TokenizedMultiSelectField items have identifier "item-<text>".
    func tapCell(in app: XCUIApplication, text: String, timeout: TimeInterval = 6) {
        // Preferred path: explicit button identifier set on sheet picker items.
        // Plain buttons in a ScrollView are always hittable in iOS 26 unlike List cells.
        let btn = app.buttons["item-\(text)"]
        if btn.waitForExistence(timeout: 2) {
            let hittable = NSPredicate(format: "isHittable == true")
            expectation(for: hittable, evaluatedWith: btn, handler: nil)
            waitForExpectations(timeout: 4)
            btn.tap()
            return
        }

        // Fallback: regular List cell (Produk list, Bahan list, etc.)
        let cell = app.cells.containing(.staticText, identifier: text).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: timeout), "Could not find '\(text)' in list")
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: cell, handler: nil)
        waitForExpectations(timeout: 4)
        cell.tap()
    }

    // MARK: - Silk Putih recipe → variant → Pergerakan Stok

    @MainActor
    func testSilkPutihRecipeAndStockDeduction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-bypass-auth"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8),
                      "Tab bar harus muncul setelah launch")
        screenshot(app, name: "00_beranda")

        // ─────────────────────────────────────────────────────────────────────
        // STEP 1 — Tambah resep: Scrunchie L · Silk Putih
        // ─────────────────────────────────────────────────────────────────────

        app.tabBars.buttons["Produksi"].tap()
        XCTAssertTrue(app.buttons["Resep"].waitForExistence(timeout: 8))
        app.buttons["Resep"].tap()

        let btnTambahResep = app.buttons["Tambah Resep"]
        XCTAssertTrue(btnTambahResep.waitForExistence(timeout: 4),
                      "Tombol Tambah Resep harus muncul di ResepListView")
        btnTambahResep.tap()

        // ── TambahResepSheet ──

        // Select product "Scrunchie" via InlineSearchDropdownField (no modal — renders inline).
        // Using inline avoids the iOS 26 nested-modal touch-intercept issue.
        let produkSearchField = app.textFields["inline-search-Produk"]
        XCTAssertTrue(produkSearchField.waitForExistence(timeout: 4),
                      "Inline search field untuk Produk harus muncul di TambahResepSheet")
        produkSearchField.tap()

        // Inline items appear below the search field — wait for the specific button identifier
        XCTAssertTrue(app.buttons["item-Scrunchie"].waitForExistence(timeout: 5),
                      "Item button Scrunchie harus muncul di inline dropdown Produk")

        // Dismiss keyboard before tapping — keyboard's tap-dismiss gesture would otherwise
        // intercept the synthesized touch, eating it to hide keyboard instead of firing button action.
        tapDone(app)

        screenshot(app, name: "02_before_scrunchie_tap")
        tapCell(in: app, text: "Scrunchie")
        screenshot(app, name: "02b_after_scrunchie_tap")

        // Size chips appear after product selection
        XCTAssertTrue(app.buttons["L"].waitForExistence(timeout: 5),
                      "Size chip L harus muncul setelah Scrunchie dipilih")
        app.buttons["L"].tap()

        // Select fabric "Silk Putih" via TokenizedMultiSelectField
        let fabricField = app.buttons["tokenized-field-Kain yang Digunakan"]
        XCTAssertTrue(fabricField.waitForExistence(timeout: 3))
        fabricField.tap()

        XCTAssertTrue(app.staticTexts["Silk Putih"].waitForExistence(timeout: 3),
                      "Silk Putih harus muncul di fabric multi-select sheet")
        tapCell(in: app, text: "Silk Putih")
        app.buttons["Selesai"].tap()

        // Fill Silk Putih dimensions
        let panjangField = app.textFields["Panjang (cm)"]
        XCTAssertTrue(panjangField.waitForExistence(timeout: 3))
        panjangField.tap(); panjangField.typeText("50"); tapDone(app)

        let lebarField = app.textFields["Lebar (cm)"]
        XCTAssertTrue(lebarField.waitForExistence(timeout: 3))
        lebarField.tap(); lebarField.typeText("25"); tapDone(app)

        let laborField = app.textFields["Est. Waktu Kerja"]
        XCTAssertTrue(laborField.waitForExistence(timeout: 3))
        laborField.tap(); laborField.typeText("12"); tapDone(app)

        let simpanResep = app.navigationBars.buttons["Simpan"]
        XCTAssertTrue(simpanResep.waitForExistence(timeout: 3))
        simpanResep.tap()

        XCTAssertTrue(app.buttons["Tambah Resep"].waitForExistence(timeout: 5),
                      "Harus kembali ke ResepListView setelah simpan")
        screenshot(app, name: "01_resep_silk_putih_added")

        // ─────────────────────────────────────────────────────────────────────
        // STEP 2 — Tambah Varian: Scrunchie L · Silk Putih (2 pcs)
        // ─────────────────────────────────────────────────────────────────────

        app.tabBars.buttons["Produk"].tap()

        // Navigate into Scrunchie product detail
        XCTAssertTrue(app.staticTexts["Scrunchie"].waitForExistence(timeout: 4))
        tapCell(in: app, text: "Scrunchie")

        // Tap size group "L" — it's a tappable row / section header
        XCTAssertTrue(app.staticTexts["L"].waitForExistence(timeout: 3))
        tapCell(in: app, text: "L")

        let tambahVarian = app.buttons["Tambah Varian"]
        XCTAssertTrue(tambahVarian.waitForExistence(timeout: 3))
        tambahVarian.tap()

        // ── AddSizeSheet (variant mode) ──

        // Tap "Pilih kain..." row to open FabricPickerSheet
        XCTAssertTrue(app.staticTexts["Pilih kain..."].waitForExistence(timeout: 3))
        tapCell(in: app, text: "Pilih kain...")

        // FabricPickerSheet: select Silk Putih
        XCTAssertTrue(app.staticTexts["Silk Putih"].waitForExistence(timeout: 3),
                      "Silk Putih harus muncul di FabricPickerSheet")
        tapCell(in: app, text: "Silk Putih")

        // Stok Awal: enter 2 pcs
        let jumlahField = app.textFields["Jumlah (pcs)"]
        XCTAssertTrue(jumlahField.waitForExistence(timeout: 3))
        jumlahField.tap(); jumlahField.typeText("2"); tapDone(app)

        let simpanVarian = app.navigationBars.buttons["Simpan"]
        XCTAssertTrue(simpanVarian.waitForExistence(timeout: 3))
        simpanVarian.tap()

        XCTAssertTrue(app.staticTexts["Silk Putih"].waitForExistence(timeout: 5),
                      "Varian Silk Putih harus muncul di detail produk setelah disimpan")
        screenshot(app, name: "02_scrunchie_L_silk_putih_2pcs")

        // ─────────────────────────────────────────────────────────────────────
        // STEP 3 — Bahan Silk Putih → Pergerakan Stok
        // ─────────────────────────────────────────────────────────────────────

        app.tabBars.buttons["Produksi"].tap()
        let bahanTab = app.buttons["Bahan"]
        XCTAssertTrue(bahanTab.waitForExistence(timeout: 4))
        bahanTab.tap()

        XCTAssertTrue(app.staticTexts["Silk Putih"].waitForExistence(timeout: 4))
        tapCell(in: app, text: "Silk Putih")

        XCTAssertTrue(app.staticTexts["Riwayat Pembelian"].waitForExistence(timeout: 4),
                      "BahanDetailView harus memuat dan tampilkan Riwayat Pembelian")
        screenshot(app, name: "03_bahan_detail_silk_putih")

        app.swipeUp()
        screenshot(app, name: "04_pergerakan_stok_area")

        XCTAssertTrue(
            app.staticTexts["Pergerakan Stok"].waitForExistence(timeout: 4),
            "Seksi Pergerakan Stok harus tampil"
        )

        let deductionEntries = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '-'")
        )
        XCTAssertGreaterThan(deductionEntries.count, 0,
            "Harus ada minimal 1 entri pengurangan di Pergerakan Stok")

        screenshot(app, name: "05_pergerakan_stok_verified")
    }

    // MARK: - TC-001 Tambah Pembelian Kain (Existing Material, Positive Case)
    // Doc: test/docs/TC-001-tambah-pembelian-kain.md

    @MainActor
    func testTC001_TambahPembelianKain() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-bypass-auth"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8),
                      "Tab bar harus muncul setelah launch")
        screenshot(app, name: "TC001_00_launch")

        // ── Navigate: Produksi → Bahan ──────────────────────────────────────
        app.tabBars.buttons["Produksi"].tap()
        // "Bahan" adalah default sub-tab, langsung verifikasi tombol "+" muncul
        XCTAssertTrue(app.buttons["subtab-bahan"].waitForExistence(timeout: 8),
                      "Sub-tab Bahan harus muncul di segmentPicker")
        screenshot(app, name: "TC001_01_bahan_list")

        // ── Buka TambahPembelianSheet ────────────────────────────────────────
        let addBtn = app.buttons["Tambah Pembelian"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 4),
                      "Tombol Tambah Pembelian harus muncul di BahanListView")
        addBtn.tap()

        XCTAssertTrue(app.navigationBars["Tambah Pembelian"].waitForExistence(timeout: 10),
                      "TambahPembelianSheet harus terbuka")
        screenshot(app, name: "TC001_02_sheet_open")

        // ── Pilih bahan: Satin Pelangi ────────────────────────────────────────
        let dropdownBahan = app.buttons["dropdown-Bahan"]
        XCTAssertTrue(dropdownBahan.waitForExistence(timeout: 6),
                      "Dropdown Bahan harus muncul di sheet")

        // Tunggu loadData() selesai — dropdown di-disable selama loading mock data
        let enabledPred = NSPredicate(format: "isEnabled == true")
        expectation(for: enabledPred, evaluatedWith: dropdownBahan, handler: nil)
        waitForExpectations(timeout: 8)
        dropdownBahan.tap()

        XCTAssertTrue(app.navigationBars["Bahan"].waitForExistence(timeout: 5),
                      "Picker sheet Bahan harus terbuka")
        screenshot(app, name: "TC001_03_bahan_picker")

        // Gunakan identifier eksplisit "item-{name}" — lebih reliable dari staticText
        let satinBtn = app.buttons["item-Satin Pelangi"]
        XCTAssertTrue(satinBtn.waitForExistence(timeout: 6),
                      "Satin Pelangi harus muncul di picker Bahan")
        screenshot(app, name: "TC001_03b_item_visible")

        satinBtn.tap()

        // Tunggu kembali ke TambahPembelianSheet
        XCTAssertTrue(app.navigationBars["Tambah Pembelian"].waitForExistence(timeout: 6),
                      "Harus kembali ke TambahPembelianSheet setelah pilih bahan")

        // Section Detail Pembelian muncul setelah material dipilih
        XCTAssertTrue(app.textFields["Lebar (cm)"].waitForExistence(timeout: 6),
                      "Field Lebar harus muncul setelah material dipilih (kategori Kain)")
        screenshot(app, name: "TC001_04_material_selected")

        // ── Isi dimensi ───────────────────────────────────────────────────────
        let lebarField = app.textFields["Lebar (cm)"]
        lebarField.tap()
        lebarField.typeText("150")
        tapDone(app)

        let panjangField = app.textFields["Panjang (cm)"]
        XCTAssertTrue(panjangField.waitForExistence(timeout: 3))
        panjangField.tap()
        panjangField.typeText("200")
        tapDone(app)

        screenshot(app, name: "TC001_05_dimensi_filled")

        // ── Isi Total Biaya ───────────────────────────────────────────────────
        let biayaField = app.textFields["Total Biaya"]
        XCTAssertTrue(biayaField.waitForExistence(timeout: 3))
        biayaField.tap()
        biayaField.typeText("45000")
        tapDone(app)

        screenshot(app, name: "TC001_06_biaya_filled")

        // ── Verifikasi Simpan aktif, lalu simpan ─────────────────────────────
        let simpanBtn = app.navigationBars.buttons["Simpan"]
        XCTAssertTrue(simpanBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(simpanBtn.isEnabled,
                      "Tombol Simpan harus aktif setelah semua field wajib terisi")
        simpanBtn.tap()

        // ── Verifikasi kembali ke BahanListView ───────────────────────────────
        XCTAssertTrue(app.buttons["Bahan"].waitForExistence(timeout: 6),
                      "Harus kembali ke BahanListView setelah simpan")
        XCTAssertFalse(app.navigationBars["Tambah Pembelian"].exists,
                       "Sheet Tambah Pembelian harus sudah tertutup")
        screenshot(app, name: "TC001_07_back_to_list")

        // ── Verifikasi entri baru di BahanDetailView ──────────────────────────
        XCTAssertTrue(app.staticTexts["Satin Pelangi"].waitForExistence(timeout: 4))
        tapCell(in: app, text: "Satin Pelangi")

        XCTAssertTrue(app.staticTexts["Riwayat Pembelian"].waitForExistence(timeout: 5),
                      "BahanDetailView harus memuat Riwayat Pembelian")
        screenshot(app, name: "TC001_08_detail_riwayat")

        // Verifikasi dimensi pembelian baru tampil (150 × 200)
        let dimensiText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '150' AND label CONTAINS '200'")
        ).firstMatch
        XCTAssertTrue(dimensiText.waitForExistence(timeout: 4),
                      "Entri pembelian baru harus menampilkan dimensi 150 × 200 cm")

        // Verifikasi total biaya tampil
        let biayaText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '45'")
        ).firstMatch
        XCTAssertTrue(biayaText.exists,
                      "Entri pembelian baru harus menampilkan total biaya Rp45.000")

        screenshot(app, name: "TC001_09_verified")
    }

    // MARK: - Launch performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
