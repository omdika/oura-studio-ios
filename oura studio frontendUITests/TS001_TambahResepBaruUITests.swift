// Doc: test/docs/TS-001-tambah-resep-baru.md
import XCTest

final class TS001_TambahResepBaruUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testTS001_FullBusinessLifecycleUI() throws {
        let nav = NavigationRobot(app)
        let bahanList = BahanListRobot(app)
        let resepList = ResepListRobot(app)
        let optimasi = OptimasiRobot(app)
        let produksi = ProduksiBatchRobot(app)
        let penjualan = PenjualanListRobot(app)
        
        print("🎬 Starting TS-001 UI Automation Test...")
        
        nav.tapProduksiTab()
        nav.tapSubTabBahan()
        
        let purchaseForm = bahanList.tapTambahPembelian()
        
        purchaseForm.selectBahan("Satin Putih")
        purchaseForm.inputLebar(150)
        purchaseForm.inputPanjang(100)
        purchaseForm.inputHarga(50000)
        purchaseForm.tapSimpan()
        
        nav.tapSubTabResep()
        let resepForm = resepList.tapTambahResep()
        
        resepForm.selectProduk("Scrunchie Premium")
        resepForm.selectKain("Satin Putih")
        resepForm.inputDimensiKain(width: 22, height: 18)
        resepForm.inputLaborMinutes(10)
        resepForm.tapSimpan()
        
        nav.tapSubTabOptimasi()
        optimasi.selectSpec(productName: "Scrunchie Premium", sizeLabel: "M")
        
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'roll-row-'")
        let firstRoll = app.buttons.matching(predicate).firstMatch
        if firstRoll.exists {
            firstRoll.tap()
        } else {
            app.buttons.element(boundBy: 0).tap()
        }
        
        optimasi.tapHitungOptimasi()
        optimasi.tapGunakanLayout()
        optimasi.tapLanjutKeProduksi()
        
        nav.tapSubTabProduksi()
        produksi.expandBatchCard()
        produksi.adjustItemQty(to: 4)
        produksi.tapKonfirmasiBatch()
        
        nav.tapPenjualanTab()
        let penjualanForm = penjualan.tapTambahPenjualan()
        
        penjualanForm.tapTambahProduk()
        penjualanForm.selectProdukFromPicker(displayName: "Scrunchie Premium · M")
        penjualanForm.inputQty(to: 2)
        penjualanForm.tapSimpanPenjualan()
        
        print("🎉 TS-001 UI Automation E2E Flow Completed Successfully!")
    }
}
