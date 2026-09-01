// Doc: test/docs/TS-001-tambah-resep-baru.md
import XCTest

class BaseRobot {
    let app: XCUIApplication
    
    init(_ app: XCUIApplication) {
        self.app = app
    }
    
    @discardableResult
    func wait(seconds: TimeInterval = 2.0) -> Self {
        Thread.sleep(forTimeInterval: seconds)
        return self
    }
}

final class NavigationRobot: BaseRobot {
    @discardableResult
    func tapProduksiTab() -> Self {
        let btn = app.tabBars.buttons["Produksi"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Tab Produksi should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapPenjualanTab() -> Self {
        let btn = app.tabBars.buttons["Penjualan"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Tab Penjualan should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapSubTabBahan() -> Self {
        let btn = app.buttons["subtab-bahan"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Subtab Bahan should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapSubTabResep() -> Self {
        let btn = app.buttons["subtab-resep"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Subtab Resep should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapSubTabOptimasi() -> Self {
        let btn = app.buttons["subtab-optimasi"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Subtab Optimasi should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapSubTabProduksi() -> Self {
        let btn = app.buttons["subtab-produksi"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Subtab Produksi should exist")
        btn.tap()
        return self
    }
}

final class BahanListRobot: BaseRobot {
    @discardableResult
    func tapTambahPembelian() -> TambahPembelianRobot {
        let btn = app.buttons["Tambah Pembelian"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Button Tambah Pembelian should exist")
        btn.tap()
        return TambahPembelianRobot(app)
    }
}

final class TambahPembelianRobot: BaseRobot {
    @discardableResult
    func selectBahan(_ name: String) -> Self {
        let dropdown = app.buttons["dropdown-Bahan"]
        XCTAssertTrue(dropdown.waitForExistence(timeout: 3.0), "Bahan dropdown should exist")
        dropdown.tap()
        
        let searchField = app.textFields["search-picker-Bahan"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3.0), "Bahan search field should exist")
        searchField.tap()
        searchField.typeText(name)
        
        let item = app.buttons["item-\(name)"]
        XCTAssertTrue(item.waitForExistence(timeout: 3.0), "Material item '\(name)' should exist in list")
        item.tap()
        return self
    }
    
    @discardableResult
    func inputLebar(_ val: Double) -> Self {
        let tf = app.textFields["input-Lebar"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Lebar field should exist")
        tf.tap()
        tf.press(forDuration: 1.5)
        tf.typeText("\(Int(val))")
        return self
    }
    
    @discardableResult
    func inputPanjang(_ val: Double) -> Self {
        let tf = app.textFields["input-Panjang"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Panjang field should exist")
        tf.tap()
        tf.typeText("\(Int(val))")
        return self
    }
    
    @discardableResult
    func inputHarga(_ val: Double) -> Self {
        let tf = app.textFields["input-Biaya"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Harga/Biaya field should exist")
        tf.tap()
        tf.typeText("\(Int(val))")
        return self
    }
    
    @discardableResult
    func tapSimpan() -> BahanListRobot {
        let btn = app.buttons["btn-simpan-pembelian"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Simpan Pembelian button should exist")
        XCTAssertTrue(btn.isEnabled, "Simpan Pembelian button should be enabled")
        btn.tap()
        return BahanListRobot(app)
    }
}

final class ResepListRobot: BaseRobot {
    @discardableResult
    func tapTambahResep() -> TambahResepRobot {
        let btn = app.buttons["Tambah Resep"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Button Tambah Resep should exist")
        btn.tap()
        return TambahResepRobot(app)
    }
}

final class TambahResepRobot: BaseRobot {
    @discardableResult
    func selectProduk(_ name: String) -> Self {
        let tf = app.textFields["inline-search-Produk"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Inline search Produk field should exist")
        tf.tap()
        tf.typeText(name)
        
        let suggestion = app.buttons["item-\(name)"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3.0), "Product suggestion '\(name)' should appear")
        suggestion.tap()
        return self
    }
    
    @discardableResult
    func selectKain(_ name: String) -> Self {
        let field = app.buttons["tokenized-field-Kain yang Digunakan"]
        XCTAssertTrue(field.waitForExistence(timeout: 3.0), "Kain multi-select field should exist")
        field.tap()
        
        let search = app.textFields["search-picker-Kain yang Digunakan"]
        XCTAssertTrue(search.waitForExistence(timeout: 3.0), "Kain search field should exist")
        search.tap()
        search.typeText(name)
        
        let row = app.buttons["item-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3.0), "Kain row should appear")
        row.tap()
        
        let done = app.buttons["Selesai"]
        XCTAssertTrue(done.waitForExistence(timeout: 3.0), "Selesai button should exist")
        done.tap()
        return self
    }
    
    @discardableResult
    func inputDimensiKain(width: Double, height: Double) -> Self {
        let tfWidth = app.textFields["input-Lebar Potong"]
        XCTAssertTrue(tfWidth.waitForExistence(timeout: 3.0), "Lebar Potong input should exist")
        tfWidth.tap()
        tfWidth.typeText("\(Int(width))")
        
        let tfHeight = app.textFields["input-Panjang Potong"]
        XCTAssertTrue(tfHeight.waitForExistence(timeout: 3.0), "Panjang Potong input should exist")
        tfHeight.tap()
        tfHeight.typeText("\(Int(height))")
        return self
    }
    
    @discardableResult
    func inputLaborMinutes(_ val: Double) -> Self {
        let tf = app.textFields["input-Est. Waktu Kerja"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Labor minutes input should exist")
        tf.tap()
        tf.typeText("\(Int(val))")
        return self
    }
    
    @discardableResult
    func tapSimpan() -> ResepListRobot {
        let btn = app.buttons["btn-simpan-resep"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Simpan Resep button should exist")
        btn.tap()
        return ResepListRobot(app)
    }
}

final class OptimasiRobot: BaseRobot {
    @discardableResult
    func selectSpec(productName: String, sizeLabel: String) -> Self {
        let row = app.buttons["spec-row-\(productName)-\(sizeLabel)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5.0), "Pattern spec row should exist")
        row.tap()
        return self
    }
    
    @discardableResult
    func selectRoll(id: UUID) -> Self {
        let row = app.buttons["roll-row-\(id.uuidString)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3.0), "Roll row should exist")
        row.tap()
        return self
    }
    
    @discardableResult
    func tapHitungOptimasi() -> Self {
        let btn = app.buttons["btn-primary-hitung-optimasi"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Hitung Optimasi button should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapGunakanLayout() -> Self {
        let btn = app.buttons["btn-gunakan-layout"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Gunakan Layout Ini button should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func tapLanjutKeProduksi() -> Self {
        let btn = app.buttons["btn-primary-lanjut-ke-produksi"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Lanjut ke Produksi button should exist")
        btn.tap()
        return self
    }
}

final class ProduksiBatchRobot: BaseRobot {
    @discardableResult
    func expandBatchCard() -> Self {
        let toggle = app.buttons["batch-card-toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5.0), "Batch card toggle should exist")
        toggle.tap()
        return self
    }
    
    @discardableResult
    func adjustItemQty(to val: Int) -> Self {
        let tf = app.textFields["input-item-qty"]
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Qty item field should exist")
        tf.tap()
        tf.press(forDuration: 1.0)
        tf.typeText("\(val)")
        return self
    }
    
    @discardableResult
    func tapKonfirmasiBatch() -> Self {
        let btn = app.buttons["btn-konfirmasi-batch"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Konfirmasi & Tambah ke Stok button should exist")
        btn.tap()
        return self
    }
}

final class PenjualanListRobot: BaseRobot {
    @discardableResult
    func tapTambahPenjualan() -> TambahPenjualanRobot {
        let btn = app.buttons["Tambah Penjualan"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5.0), "Button Tambah Penjualan should exist")
        btn.tap()
        return TambahPenjualanRobot(app)
    }
}

final class TambahPenjualanRobot: BaseRobot {
    @discardableResult
    func tapTambahProduk() -> Self {
        let btn = app.buttons["Tambah Produk"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Tambah Produk button should exist")
        btn.tap()
        return self
    }
    
    @discardableResult
    func selectProdukFromPicker(displayName: String) -> Self {
        let row = app.buttons["\(displayName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5.0), "Product size row in picker should exist")
        row.tap()
        return self
    }
    
    @discardableResult
    func inputQty(to val: Int) -> Self {
        let tf = app.textFields.firstMatch
        XCTAssertTrue(tf.waitForExistence(timeout: 3.0), "Qty field inside item card should exist")
        tf.tap()
        tf.typeText("\(val)")
        return self
    }
    
    @discardableResult
    func tapSimpanPenjualan() -> PenjualanListRobot {
        let btn = app.buttons["btn-simpan-penjualan"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3.0), "Simpan Penjualan button should exist")
        btn.tap()
        return PenjualanListRobot(app)
    }
}
