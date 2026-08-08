// Doc: test/docs/TC-002-tambah-pembelian-hardware-dengan-panjang.md
import XCTest

extension oura_studio_frontendUITests {

    // MARK: - TC-002 Tambah Pembelian Hardware Baru dengan Panjang (Positive Case)

    @MainActor
    func testTC002_TambahPembelianHardwareDenganPanjang() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-bypass-auth"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8),
                      "Tab bar harus muncul setelah launch")
        screenshot(app, name: "TC002_00_launch")

        // ── Navigate: Produksi → Bahan ──────────────────────────────────────
        app.tabBars.buttons["Produksi"].tap()
        XCTAssertTrue(app.buttons["Bahan"].waitForExistence(timeout: 6))
        app.buttons["Bahan"].tap()

        // ── Buka TambahPembelianSheet ────────────────────────────────────────
        // TODO(accessibility): tambahkan .accessibilityLabel("Tambah Pembelian")
        // pada tombol "+" di BahanListView jika identifier belum ada.
        let addBtn = app.buttons["Tambah Pembelian"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 4))
        addBtn.tap()

        XCTAssertTrue(app.navigationBars["Tambah Pembelian"].waitForExistence(timeout: 5),
                      "TambahPembelianSheet harus terbuka")
        screenshot(app, name: "TC002_01_sheet_open")

        // ── Buka picker Bahan dan ketik nama baru ────────────────────────────
        let dropdownBahan = app.buttons["dropdown-Bahan"]
        XCTAssertTrue(dropdownBahan.waitForExistence(timeout: 4))
        dropdownBahan.tap()

        XCTAssertTrue(app.navigationBars["Bahan"].waitForExistence(timeout: 4),
                      "Picker sheet Bahan harus terbuka")
        screenshot(app, name: "TC002_02_picker_open")

        // Ketik nama bahan baru di search field
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Karet Elastis")
        screenshot(app, name: "TC002_03_typed_name")

        // Tap "Tambah 'Karet Elastis'" — tombol muncul setelah ketik
        // TODO(accessibility): tambahkan .accessibilityIdentifier("btn-tambah-baru")
        // di SearchableDropdownField untuk identifier yang lebih stabil.
        let tambahBtn = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Tambah'")
        ).firstMatch
        XCTAssertTrue(tambahBtn.waitForExistence(timeout: 4),
                      "Tombol 'Tambah ...' harus muncul di picker setelah mengetik nama baru")
        tambahBtn.tap()

        // ── Verifikasi mode "Bahan Baru" ─────────────────────────────────────
        XCTAssertTrue(
            app.staticTexts["Bahan baru — belum tersimpan"].waitForExistence(timeout: 4),
            "Form harus masuk mode 'Bahan Baru' setelah inline create"
        )
        XCTAssertTrue(app.staticTexts["Karet Elastis"].exists,
                      "Nama bahan baru harus tampil di form")
        screenshot(app, name: "TC002_04_creating_new_material")

        // ── Pilih Kategori: Hardware ─────────────────────────────────────────
        XCTAssertTrue(app.buttons["Hardware"].waitForExistence(timeout: 4),
                      "Chip 'Hardware' harus tersedia di Kategori selector")
        app.buttons["Hardware"].tap()
        screenshot(app, name: "TC002_05_hardware_selected")

        // ── Verifikasi field Jumlah DAN Panjang muncul (v2.5) ────────────────
        XCTAssertTrue(app.textFields["Jumlah"].waitForExistence(timeout: 4),
                      "Field Jumlah harus muncul untuk kategori Hardware")
        XCTAssertTrue(app.textFields["Panjang (cm)"].waitForExistence(timeout: 4),
                      "[v2.5 regression] Field Panjang (cm) harus muncul untuk Hardware — " +
                      "jika tidak muncul, isHardware tidak aktif atau perubahan v2.5 hilang")
        screenshot(app, name: "TC002_06_fields_jumlah_panjang")

        // ── Isi Jumlah ────────────────────────────────────────────────────────
        let jumlahField = app.textFields["Jumlah"]
        jumlahField.tap()
        jumlahField.typeText("3")
        tapDone(app)

        // ── Isi Panjang ────────────────────────────────────────────────────────
        let panjangField = app.textFields["Panjang (cm)"]
        panjangField.tap()
        panjangField.typeText("100")
        tapDone(app)

        screenshot(app, name: "TC002_07_dimensi_filled")

        // ── Isi Total Biaya ────────────────────────────────────────────────────
        let biayaField = app.textFields["Total Biaya"]
        XCTAssertTrue(biayaField.waitForExistence(timeout: 3))
        biayaField.tap()
        biayaField.typeText("15000")
        tapDone(app)

        screenshot(app, name: "TC002_08_biaya_filled")

        // ── Verifikasi Simpan aktif ────────────────────────────────────────────
        let simpanBtn = app.navigationBars.buttons["Simpan"]
        XCTAssertTrue(simpanBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(simpanBtn.isEnabled,
                      "Tombol Simpan harus aktif: Jumlah > 0 + Total Biaya > 0 (Panjang opsional tapi sudah diisi)")
        simpanBtn.tap()

        // ── Verifikasi kembali ke BahanListView ───────────────────────────────
        XCTAssertTrue(app.buttons["Bahan"].waitForExistence(timeout: 8),
                      "Harus kembali ke BahanListView setelah simpan")
        XCTAssertFalse(app.navigationBars["Tambah Pembelian"].exists,
                       "Sheet harus tertutup setelah Simpan berhasil")
        screenshot(app, name: "TC002_09_back_to_list")

        // ── Verifikasi "Karet Elastis" muncul di list ─────────────────────────
        XCTAssertTrue(app.staticTexts["Karet Elastis"].waitForExistence(timeout: 5),
                      "Material baru 'Karet Elastis' harus muncul di BahanListView")
        screenshot(app, name: "TC002_10_material_in_list")

        // ── Masuk ke BahanDetailView dan verifikasi riwayat ───────────────────
        tapCell(in: app, text: "Karet Elastis")

        XCTAssertTrue(app.staticTexts["Riwayat Pembelian"].waitForExistence(timeout: 5),
                      "BahanDetailView harus memuat Riwayat Pembelian")
        screenshot(app, name: "TC002_11_detail_view")

        // Verifikasi entri menampilkan info panjang (100 cm atau 300 cm total)
        let panjangEntry = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '100'")
        ).firstMatch
        XCTAssertTrue(panjangEntry.waitForExistence(timeout: 4),
                      "Entri pembelian harus menampilkan info panjang 100 cm")

        // Verifikasi total biaya
        let biayaEntry = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '15'")
        ).firstMatch
        XCTAssertTrue(biayaEntry.exists,
                      "Entri pembelian harus menampilkan total biaya Rp15.000")

        screenshot(app, name: "TC002_12_verified")
    }
}
