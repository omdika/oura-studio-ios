// Doc: test/docs/TS-001-tambah-resep-baru.md
import XCTest
@testable import oura_studio_frontend

struct TestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class TS001_TambahResepBaruAPITests: XCTestCase {
    
    private let api = APIService.shared
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 1. Membaca nilai dari variable environment DEV_BEARER_TOKEN
        guard let devToken = ProcessInfo.processInfo.environment["DEV_BEARER_TOKEN"],
              !devToken.isEmpty else {
            print("⚠️ DEV_BEARER_TOKEN not found or empty. Skipping TS-001 API Integration tests.")
            throw XCTSkip("DEV_BEARER_TOKEN not found or empty. Skipping TS-001 API Integration tests.")
        }
        
        // 2. Menginisialisasi APIService, menonaktifkan mode mock, dan mengatur header otentikasi
        api.useMock = false
        api.authToken = devToken
    }
    
    func testTS001_FullBusinessLifecycleE2E() async throws {
        print("🚀 Starting TS-001-API Integration Test Suite...")
        
        // --- 0. PRECONDITIONS & SETUP ---
        // Fetch or create master materials and products so we don't depend on pre-existing db state.
        
        let materials = try await api.getMaterials()
        let fabricMaterial = try await getOrCreateFabric(named: "Satin Putih - E2E Test", from: materials)
        let hardwareMaterial = try await getOrCreateHardware(named: "Karet Elastis 3mm - E2E Test", from: materials)
        
        let products = try await api.getProducts()
        let product = try await getOrCreateProduct(named: "Scrunchie Premium - E2E Test", sku: "SCR-PREM-E2E-TEST", from: products)
        
        let productSizes = try await api.getProductSizes(sku: product.sku)
        let productSize = try await getOrCreateProductSize(sku: product.sku, sizeLabel: "M", from: productSizes)
        
        print("📦 Setup prerequisites done.")
        print("Fabric Material ID: \(fabricMaterial.id)")
        print("Hardware Material ID: \(hardwareMaterial.id)")
        print("Product SKU: \(product.sku), Size ID: \(productSize.id)")
        
        // Variables to keep track of dynamically created entities for teardown
        var purchaseId: UUID? = nil
        var hardwarePurchaseId: UUID? = nil
        var supplierId: UUID? = nil
        var patternSpecId: UUID? = nil
        var cuttingLayoutId: UUID? = nil
        var productionBatchId: UUID? = nil
        var salesOrderId: UUID? = nil
        
        do {
            // --- TS-001-API-01: Tambah Pembelian Bahan ---
            print("Step 1: Create purchase...")
            let purchaseReq = CreatePurchaseRequest(
                widthCm: 150.0,
                lengthCm: 100.0,
                qty: nil,
                packageLabel: nil,
                totalCost: 50000.0,
                supplierId: nil,
                supplierName: "Supplier Indotex E2E",
                purchasedAt: "2026-08-31T00:00:00Z"
            )
            let purchase = try await api.createPurchase(materialId: fabricMaterial.id, purchaseReq)
            purchaseId = purchase.id
            supplierId = purchase.supplierId
            
            XCTAssertNotNil(purchase.id, "Purchase ID should not be nil")
            XCTAssertNotNil(purchase.supplierId, "Supplier ID should be automatically created")
            
            // Create a companion purchase for the hardware material (so it has at least one purchase on record for recipe validation)
            print("Step 1B: Create hardware purchase...")
            let hwPurchaseReq = CreatePurchaseRequest(
                widthCm: nil,
                lengthCm: 10.0,  // length of elastic band per unit (10 cm)
                qty: 50.0,       // 50 units
                packageLabel: nil,
                totalCost: 10000.0,
                supplierId: supplierId,
                supplierName: nil,
                purchasedAt: "2026-08-31T00:00:00Z"
            )
            let hwPurchase = try await api.createPurchase(materialId: hardwareMaterial.id, hwPurchaseReq)
            hardwarePurchaseId = hwPurchase.id
            XCTAssertNotNil(hwPurchase.id, "Hardware purchase should succeed")
            
            // Verify material's current average cost updated automatically (weighted-average)
            let updatedFabricAfterPurchase = try await api.getMaterial(id: fabricMaterial.id)
            XCTAssertEqual(updatedFabricAfterPurchase.currentAvgCost, 500.0, accuracy: 0.01)
            
            // --- TS-001-API-02: Edit Pembelian Bahan ---
            print("Step 2: Edit purchase...")
            guard let pId = purchaseId else {
                XCTFail("Purchase ID is missing")
                throw TestError(message: "Purchase ID is missing")
            }
            let editPurchaseReq = PatchPurchaseRequest(
                widthCm: 150.0,
                lengthCm: 100.0,
                qty: nil,
                totalCost: 60000.0,
                supplierId: supplierId,
                supplierName: nil,
                purchasedAt: "2026-08-31T00:00:00Z"
            )
            let updatedPurchase = try await api.patchPurchase(materialId: fabricMaterial.id, purchaseId: pId, editPurchaseReq)
            XCTAssertEqual(updatedPurchase.totalCost, 60000.0)
            
            // Verify updated avg cost
            let updatedFabricAfterEdit = try await api.getMaterial(id: fabricMaterial.id)
            XCTAssertEqual(updatedFabricAfterEdit.currentAvgCost, 600.0, accuracy: 0.01)
            
            // --- TS-001-API-03: Tambah Resep Baru ---
            print("Step 3: Create Pattern Spec / Recipe...")
            let specReq = CreatePatternSpecRequest(
                productSizeId: productSize.id,
                fabrics: [
                    CreatePatternSpecRequest.FabricInput(
                        materialId: fabricMaterial.id,
                        cutLengthCm: 18.0,
                        cutWidthCm: 22.0,
                        rotationAllowed: true
                    )
                ],
                estLaborMinutes: 10.0,
                components: [
                    CreatePatternSpecRequest.ComponentInput(
                        materialId: hardwareMaterial.id,
                        qtyPerUnit: 5.0
                    )
                ]
            )
            let patternSpec = try await api.createOrUpdatePatternSpec(specReq)
            patternSpecId = patternSpec.id
            XCTAssertNotNil(patternSpec.id)
            XCTAssertTrue(patternSpec.isActive)
            
            // --- TS-001-API-04: Optimasi Pola ---
            print("Step 4A: Get Layout Suggestion...")
            let suggestReq = SuggestOptimizerRequest(
                materialPurchaseId: pId,
                candidates: [
                    OptimizerCandidate(
                        productSizeId: productSize.id,
                        patternSpecId: patternSpec.id,
                        minQty: 2
                    )
                ]
            )
            let suggestions = try await api.suggestLayouts(suggestReq)
            XCTAssertFalse(suggestions.isEmpty, "Should return at least one suggestion")
            
            guard let chosenLayout = suggestions.first else {
                XCTFail("No layouts suggested")
                throw TestError(message: "No layouts suggested")
            }
            XCTAssertGreaterThan(chosenLayout.totalQty, 0)
            XCTAssertLessThanOrEqual(chosenLayout.wastePct, 100.0)
            
            print("Step 4B: Persist Layout...")
            let createLayoutReq = CreateLayoutRequest(
                materialPurchaseId: pId,
                strategy: chosenLayout.strategy.rawValue,
                items: chosenLayout.items.map { item in
                    CreateLayoutRequest.CreateLayoutItemInput(
                        productSizeId: item.productSizeId,
                        patternSpecId: item.patternSpecId,
                        orientation: item.orientation,
                        qtySuggested: item.qtySuggested,
                        fabricLengthUsedCm: item.fabricLengthUsedCm,
                        costPerPiece: item.costPerPiece
                    )
                }
            )
            let persistedLayout = try await api.createLayout(createLayoutReq)
            cuttingLayoutId = persistedLayout.id
            XCTAssertNotNil(persistedLayout.id)
            
            // --- TS-001-API-05: Konfirmasi Produksi & Stok ---
            print("Step 5A: Create Production Batch...")
            guard let layoutId = cuttingLayoutId else {
                XCTFail("Cutting Layout ID is missing")
                throw TestError(message: "Cutting Layout ID is missing")
            }
            let batch = try await api.createProductionBatch(cuttingLayoutIds: [layoutId])
            productionBatchId = batch.id
            XCTAssertEqual(batch.status, "draft")
            XCTAssertFalse(batch.items.isEmpty)
            
            let batchItem = batch.items[0]
            
            print("Step 5B: Adjust Actual Qty...")
            let updatedItem = try await api.updateBatchItem(batchId: batch.id, itemId: batchItem.id, qtyActual: 4)
            XCTAssertEqual(updatedItem.qtyActual, 4)
            
            print("Step 5C: Confirm Production...")
            try await api.confirmBatch(id: batch.id)
            
            let confirmedBatch = try await api.getProductionBatch(id: batch.id)
            XCTAssertEqual(confirmedBatch.status, "confirmed")
            
            // Verify stock adjustment of finished product size
            let productSizeAfterProduction = try await api.getProductSizeById(id: productSize.id)
            XCTAssertGreaterThanOrEqual(productSizeAfterProduction.currentStockQty, 4, "Stock of product size should increase")
            
            // --- TS-001-API-06: Penjualan Produk Jadi ---
            print("Step 6: Sales Transaction...")
            let salesReq = CreateSalesOrderRequest(
                customerName: "Budi Pembeli",
                paymentMethod: "shopee_pay",
                marketplaceFeePct: 0.025,
                items: [
                    CreateSalesOrderRequest.ItemInput(
                        productSizeId: productSize.id,
                        qty: 2,
                        unitPrice: 25000.0,
                        discount: 0.0
                    )
                ]
            )
            let salesOrder = try await api.createSalesOrder(salesReq)
            salesOrderId = salesOrder.id
            XCTAssertNotNil(salesOrder.id)
            
            // Verify stock reduction of finished product size
            let productSizeAfterSale = try await api.getProductSizeById(id: productSize.id)
            XCTAssertEqual(productSizeAfterSale.currentStockQty, productSizeAfterProduction.currentStockQty - 2, "Stock of product size should decrease by 2")
            
        } catch {
            print("❌ E2E Flow failed during execution: \(error.localizedDescription)")
            await performTeardown(
                salesOrderId: salesOrderId,
                productionBatchId: productionBatchId,
                patternSpecId: patternSpecId,
                cuttingLayoutId: cuttingLayoutId,
                purchaseId: purchaseId,
                fabricMaterialId: fabricMaterial.id,
                hardwarePurchaseId: hardwarePurchaseId,
                hardwareMaterialId: hardwareMaterial.id,
                supplierId: supplierId
            )
            throw error
        }
        
        // --- TS-001-API-07: Teardown & Post-Execution Cleanup ---
        print("🧹 Running success teardown...")
        await performTeardown(
            salesOrderId: salesOrderId,
            productionBatchId: productionBatchId,
            patternSpecId: patternSpecId,
            cuttingLayoutId: cuttingLayoutId,
            purchaseId: purchaseId,
            fabricMaterialId: fabricMaterial.id,
            hardwarePurchaseId: hardwarePurchaseId,
            hardwareMaterialId: hardwareMaterial.id,
            supplierId: supplierId
        )
        
        print("✅ TS-001 API Integration Test Suite complete!")
    }
    
    // MARK: - Helpers for Prerequisites Setup
    
    private func getOrCreateFabric(named name: String, from materials: [Material]) async throws -> Material {
        if let existing = materials.first(where: { $0.name == name && $0.category == .fabric }) {
            return existing
        }
        let req = CreateMaterialRequest(
            name: name,
            category: "fabric",
            costClass: "fabric",
            purchaseUnit: "cm",
            usageUnit: "cm",
            fabricWidthCm: 150.0,
            fabricFamily: "Satin"
        )
        return try await api.createMaterial(req)
    }
    
    private func getOrCreateHardware(named name: String, from materials: [Material]) async throws -> Material {
        if let existing = materials.first(where: { $0.name == name && $0.category == .hardware }) {
            return existing
        }
        let req = CreateMaterialRequest(
            name: name,
            category: "hardware",
            costClass: "hardware",
            purchaseUnit: "pcs",
            usageUnit: "pcs",
            fabricWidthCm: nil,
            fabricFamily: nil
        )
        return try await api.createMaterial(req)
    }
    
    private func getOrCreateProduct(named name: String, sku: String, from products: [Product]) async throws -> Product {
        if let existing = products.first(where: { $0.sku == sku }) {
            return existing
        }
        return try await api.createProduct(name: name, sku: sku)
    }
    
    private func getOrCreateProductSize(sku: String, sizeLabel: String, from sizes: [ProductSizeDetail]) async throws -> ProductSizeDetail {
        if let existing = sizes.first(where: { $0.sizeLabel == sizeLabel }) {
            return existing
        }
        return try await api.createProductSize(sku: sku, sizeLabel: sizeLabel, fabricVariantName: nil, reorderMinQty: nil)
    }
    
    // MARK: - Teardown / Cleanup Implementation
    
    private func performTeardown(
        salesOrderId: UUID?,
        productionBatchId: UUID?,
        patternSpecId: UUID?,
        cuttingLayoutId: UUID?,
        purchaseId: UUID?,
        fabricMaterialId: UUID?,
        hardwarePurchaseId: UUID?,
        hardwareMaterialId: UUID?,
        supplierId: UUID?
    ) async {
        print("🔄 Performing Reverse Teardown & Post-Execution Cleanup...")
        
        if let orderId = salesOrderId {
            do {
                _ = try await api.cancelSalesOrder(id: orderId, reason: "E2E Test Teardown")
                print("  🗑 Cancelled Sales Order: \(orderId)")
            } catch {
                print("  ⚠️ Failed to cancel Sales Order: \(error.localizedDescription)")
            }
        }
        
        if let batchId = productionBatchId {
            do {
                try await api.deleteProductionBatch(id: batchId)
                print("  🗑 Deleted Production Batch: \(batchId)")
            } catch {
                print("  ⚠️ Failed to delete Production Batch: \(error.localizedDescription)")
            }
        }
        
        if let layoutId = cuttingLayoutId {
            do {
                try await api.discardLayout(id: layoutId)
                print("  🗑 Discarded Cutting Layout: \(layoutId)")
            } catch {
                print("  ⚠️ Failed to discard Cutting Layout: \(error.localizedDescription)")
            }
        }
        
        if let specId = patternSpecId {
            do {
                try await api.deletePatternSpec(id: specId)
                print("  🗑 Deleted Pattern Spec: \(specId)")
            } catch {
                print("  ⚠️ Failed to delete Pattern Spec: \(error.localizedDescription)")
            }
        }
        
        if let hpId = hardwarePurchaseId, let hmId = hardwareMaterialId {
            do {
                try await api.deletePurchase(materialId: hmId, purchaseId: hpId)
                print("  🗑 Deleted Hardware Purchase: \(hpId)")
            } catch {
                print("  ⚠️ Failed to delete Hardware Purchase: \(error.localizedDescription)")
            }
        }
        
        if let hmId = hardwareMaterialId {
            do {
                _ = try await api.archiveMaterial(id: hmId)
                print("  📂 Archived Hardware Material: \(hmId)")
            } catch {
                print("  ⚠️ Failed to archive Hardware Material: \(error.localizedDescription)")
            }
        }
        
        if let pId = purchaseId, let fmId = fabricMaterialId {
            do {
                try await api.deletePurchase(materialId: fmId, purchaseId: pId)
                print("  🗑 Deleted Fabric Purchase: \(pId)")
            } catch {
                print("  ⚠️ Failed to delete Fabric Purchase: \(error.localizedDescription)")
            }
        }
        
        if let fmId = fabricMaterialId {
            do {
                _ = try await api.archiveMaterial(id: fmId)
                print("  📂 Archived Fabric Material: \(fmId)")
            } catch {
                print("  ⚠️ Failed to archive Fabric Material: \(error.localizedDescription)")
            }
        }
    }
}
