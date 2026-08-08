// Doc: test/docs/TC-001-tambah-pembelian-kain.md
import XCTest

extension oura_studio_frontendUITests {

    // MARK: - TC-001 Tambah Pembelian Kain (Existing Material, Positive Case)

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
        XCTAssertTrue(app.buttons["Bahan"].waitForExistence(timeout: 6),
                      "Sub-tab Bahan harus muncul")
        app.buttons["Bahan"].tap()
        screenshot(app, name: "TC001_01_bahan_list")

        // ── Buka TambahPembelianSheet ────────────────────────────────────────
        // TODO(accessibility): tambahkan .accessibilityLabel("Tambah Pembelian")
        // pada tombol "+" di BahanListView jika identifier belum ada.
        let addBtn = app.buttons["Tambah Pembelian"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 4),
                      "Tombol Tambah Pembelian harus muncul di BahanListView")
        addBtn.tap()

        XCTAssertTrue(app.navigationBars["Tambah Pembelian"].waitForExistence(timeout: 5),
                      "TambahPembelianSheet harus terbuka")
        screenshot(app, name: "TC001_02_sheet_open")

        // ── Pilih bahan: Satin Pelangi ────────────────────────────────────────
        let dropdownBahan = app.buttons["dropdown-Bahan"]
        XCTAssertTrue(dropdownBahan.waitForExistence(timeout: 4),
                      "Dropdown Bahan harus muncul di sheet")
        dropdownBahan.tap()

        XCTAssertTrue(app.navigationBars["Bahan"].waitForExistence(timeout: 4),
                      "Picker sheet Bahan harus terbuka")
        screenshot(app, name: "TC001_03_bahan_picker")

        tapCell(in: app, text: "Satin Pelangi")

        // Picker tutup, section Detail Pembelian muncul
        XCTAssertTrue(app.textFields["Lebar (cm)"].waitForExistence(timeout: 4),
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
}
