import Foundation

// Mock data lives here — all IDs are stable so views can cross-reference correctly
@MainActor
class MockAPIService {
    static let shared = MockAPIService()

    // MARK: - Stable mock IDs
    let ownerEmail = "owner@ourastudio.id"

    // Material IDs
    let matSatinId        = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!
    let matWaffleId       = UUID(uuidString: "11111111-0000-0000-0000-000000000002")!
    let matBrokat1Id      = UUID(uuidString: "11111111-0000-0000-0000-000000000003")!
    let matBenang1Id      = UUID(uuidString: "11111111-0000-0000-0000-000000000004")!
    let matBenang2Id      = UUID(uuidString: "11111111-0000-0000-0000-000000000005")!
    let matRingId         = UUID(uuidString: "11111111-0000-0000-0000-000000000006")!
    let matSnapId         = UUID(uuidString: "11111111-0000-0000-0000-000000000007")!
    let matElasticId      = UUID(uuidString: "11111111-0000-0000-0000-000000000008")!
    // Additional materials for pagination demo
    let matToyoboId       = UUID(uuidString: "11111111-0000-0000-0000-000000000009")!
    let matSatinSilkId    = UUID(uuidString: "11111111-0000-0000-0000-000000000010")!
    let matWafflePinkId   = UUID(uuidString: "11111111-0000-0000-0000-000000000011")!
    let matKatunId        = UUID(uuidString: "11111111-0000-0000-0000-000000000012")!
    let matLinenId        = UUID(uuidString: "11111111-0000-0000-0000-000000000013")!
    let matBenangMerahId  = UUID(uuidString: "11111111-0000-0000-0000-000000000014")!
    let matKancingId      = UUID(uuidString: "11111111-0000-0000-0000-000000000015")!
    let matSilkPutihId    = UUID(uuidString: "11111111-0000-0000-0000-000000000016")!

    // Supplier IDs
    let sup1Id = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
    let sup2Id = UUID(uuidString: "22222222-0000-0000-0000-000000000002")!
    let sup3Id = UUID(uuidString: "22222222-0000-0000-0000-000000000003")!

    // Purchase IDs
    let pur1Id = UUID(uuidString: "33333333-0000-0000-0000-000000000001")!
    let pur2Id = UUID(uuidString: "33333333-0000-0000-0000-000000000002")!
    let pur3Id = UUID(uuidString: "33333333-0000-0000-0000-000000000003")!
    let pur4Id = UUID(uuidString: "33333333-0000-0000-0000-000000000004")!

    // Product IDs
    let prodScrunchieId = UUID(uuidString: "44444444-0000-0000-0000-000000000001")!
    let prodIkatId      = UUID(uuidString: "44444444-0000-0000-0000-000000000002")!
    let prodPouchId     = UUID(uuidString: "44444444-0000-0000-0000-000000000003")!
    let prodHairClipId  = UUID(uuidString: "44444444-0000-0000-0000-000000000004")!

    // ProductSize IDs
    let sizeScrunS   = UUID(uuidString: "55555555-0000-0000-0000-000000000001")!
    let sizeScrunM   = UUID(uuidString: "55555555-0000-0000-0000-000000000002")!
    let sizeScrunL   = UUID(uuidString: "55555555-0000-0000-0000-000000000003")!
    let sizeIkatM    = UUID(uuidString: "55555555-0000-0000-0000-000000000004")!
    let sizeIkatL    = UUID(uuidString: "55555555-0000-0000-0000-000000000005")!
    let sizeScrunXS  = UUID(uuidString: "55555555-0000-0000-0000-000000000006")!
    let sizeScrunXL  = UUID(uuidString: "55555555-0000-0000-0000-000000000007")!
    let sizePouchS   = UUID(uuidString: "55555555-0000-0000-0000-000000000008")!
    let sizePouchM   = UUID(uuidString: "55555555-0000-0000-0000-000000000009")!
    let sizePouchL   = UUID(uuidString: "55555555-0000-0000-0000-000000000010")!
    let sizeHairS    = UUID(uuidString: "55555555-0000-0000-0000-000000000011")!
    let sizeHairM    = UUID(uuidString: "55555555-0000-0000-0000-000000000012")!

    // PatternSpec IDs
    let specScrunM_Satin      = UUID(uuidString: "66666666-0000-0000-0000-000000000001")!
    let specScrunM_Waffle     = UUID(uuidString: "66666666-0000-0000-0000-000000000002")!
    let specScrunS_Satin      = UUID(uuidString: "66666666-0000-0000-0000-000000000003")!
    let specIkatM_Brokat      = UUID(uuidString: "66666666-0000-0000-0000-000000000004")!
    let specScrunL_SilkPutih  = UUID(uuidString: "66666666-0000-0000-0000-000000000005")!

    // Cutting layout IDs
    let layout1Id = UUID(uuidString: "77777777-0000-0000-0000-000000000001")!

    // Production batch IDs
    let batch1Id = UUID(uuidString: "88888888-0000-0000-0000-000000000001")!

    // Sales IDs
    let sale1Id = UUID(uuidString: "99999999-0000-0000-0000-000000000001")!
    let sale2Id = UUID(uuidString: "99999999-0000-0000-0000-000000000002")!
    let sale3Id = UUID(uuidString: "99999999-0000-0000-0000-000000000003")!

    private func ago(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    // Internal mutable state so create/patch operations feel live
    private var _materials: [Material] = []
    private var _suppliers: [Supplier] = []
    private var _purchases: [UUID: [MaterialPurchase]] = [:]
    private var _materialUsage: [UUID: [MaterialUsageEntry]] = [:]
    private var _products: [Product] = []
    private var _productSizes: [String: [ProductSizeDetail]] = [:]  // keyed by sku
    private var _patternSpecs: [PatternSpec] = []
    private var _cuttingLayouts: [CuttingLayout] = []
    private var _productionBatches: [ProductionBatch] = []
    private var _salesOrders: [SalesOrder] = []
    private var _settings: [SettingItem] = []
    private var _ledgerEntries: [StockAdjustmentLedgerEntry] = []

    init() { seedData() }

    private func seedData() {
        _suppliers = [
            Supplier(id: sup1Id, name: "Toko Kain Abadi", createdAt: ago(days: 30)),
        ]

        // matSatinId     → Satin Pelangi  (200 cm lebar)
        // matWaffleId    → Waffle Merah   (150 cm lebar)
        // matSilkPutihId → Silk Putih     (200 cm lebar, tanpa resep, tanpa stok)
        _materials = [
            Material(id: matSatinId, name: "Satin Pelangi", category: .fabric,
                     costClass: "direct_precise", purchaseUnit: "meter", usageUnit: "cm",
                     fabricWidthCm: 200, currentAvgCost: 450, reorderMinQty: 50,
                     isArchived: false, createdAt: ago(days: 10), updatedAt: ago(days: 1)),
            Material(id: matWaffleId, name: "Waffle Merah", category: .fabric,
                     costClass: "direct_precise", purchaseUnit: "meter", usageUnit: "cm",
                     fabricWidthCm: 150, currentAvgCost: 320, reorderMinQty: 30,
                     isArchived: false, createdAt: ago(days: 8), updatedAt: ago(days: 2)),
            Material(id: matSilkPutihId, name: "Silk Putih", category: .fabric,
                     costClass: "direct_precise", purchaseUnit: "meter", usageUnit: "cm",
                     fabricWidthCm: 200, currentAvgCost: 550, reorderMinQty: nil,
                     isArchived: false, createdAt: ago(days: 5), updatedAt: ago(days: 5)),
        ]

        // pur1: Waffle Merah 150×100 cm  pur2: Satin Pelangi 200×100 cm  pur3: Silk Putih 200×100 cm
        _purchases = [
            matWaffleId: [
                MaterialPurchase(id: pur1Id, materialId: matWaffleId, widthCm: 150, lengthCm: 100,
                                 qty: nil, packageLabel: nil, totalCost: 32_000,
                                 supplierId: sup1Id, supplierName: "Toko Kain Abadi",
                                 purchasedAt: ago(days: 2), remainingLengthCm: 100,
                                 createdAt: ago(days: 2)),
            ],
            matSatinId: [
                MaterialPurchase(id: pur2Id, materialId: matSatinId, widthCm: 200, lengthCm: 100,
                                 qty: nil, packageLabel: nil, totalCost: 45_000,
                                 supplierId: sup1Id, supplierName: "Toko Kain Abadi",
                                 purchasedAt: ago(days: 1), remainingLengthCm: 100,
                                 createdAt: ago(days: 1)),
            ],
            matSilkPutihId: [
                MaterialPurchase(id: pur3Id, materialId: matSilkPutihId, widthCm: 200, lengthCm: 100,
                                 qty: nil, packageLabel: nil, totalCost: 55_000,
                                 supplierId: sup1Id, supplierName: "Toko Kain Abadi",
                                 purchasedAt: ago(days: 5), remainingLengthCm: 100,
                                 createdAt: ago(days: 5)),
            ],
        ]

        _products = [
            Product(id: prodScrunchieId, sku: "SCRUNCHIE", name: "Scrunchie",
                    isArchived: false, createdAt: ago(days: 14)),
        ]

        // sizeScrunM  → M · Satin Pelangi
        // sizeScrunXS → M · Waffle Merah
        // sizeScrunL  → L · Satin Pelangi
        // sizeScrunS  → L · Waffle Merah
        // sizeScrunXL → L · Silk Putih
        _productSizes = [
            "SCRUNCHIE": [
                ProductSizeDetail(id: sizeScrunM, productId: prodScrunchieId, productSku: "SCRUNCHIE",
                                  productName: "Scrunchie", sizeLabel: "M", fabricVariantName: "Satin Pelangi",
                                  reorderMinQty: 20, isArchived: false, currentStockQty: 10,
                                  productionStockQty: 0, manualStockQty: 10,
                                  latestHppBreakdown: HPPBreakdown(fabric: 3_400, pooledMaterial: 350, hardware: 120, labor: 2_800, overhead: 600, total: 7_270),
                                  sellingPrice: 22_000, marginPct: 0.67),
                ProductSizeDetail(id: sizeScrunXS, productId: prodScrunchieId, productSku: "SCRUNCHIE",
                                  productName: "Scrunchie", sizeLabel: "M", fabricVariantName: "Waffle Merah",
                                  reorderMinQty: 20, isArchived: false, currentStockQty: 5,
                                  productionStockQty: 0, manualStockQty: 5,
                                  latestHppBreakdown: HPPBreakdown(fabric: 2_900, pooledMaterial: 300, hardware: 100, labor: 2_800, overhead: 550, total: 6_650),
                                  sellingPrice: 20_000, marginPct: 0.67),
                ProductSizeDetail(id: sizeScrunL, productId: prodScrunchieId, productSku: "SCRUNCHIE",
                                  productName: "Scrunchie", sizeLabel: "L", fabricVariantName: "Satin Pelangi",
                                  reorderMinQty: 15, isArchived: false, currentStockQty: 12,
                                  productionStockQty: 0, manualStockQty: 12,
                                  latestHppBreakdown: HPPBreakdown(fabric: 4_200, pooledMaterial: 400, hardware: 150, labor: 3_360, overhead: 700, total: 8_810),
                                  sellingPrice: 25_000, marginPct: 0.65),
                ProductSizeDetail(id: sizeScrunS, productId: prodScrunchieId, productSku: "SCRUNCHIE",
                                  productName: "Scrunchie", sizeLabel: "L", fabricVariantName: "Waffle Merah",
                                  reorderMinQty: 10, isArchived: false, currentStockQty: 8,
                                  productionStockQty: 8, manualStockQty: 0,
                                  latestHppBreakdown: HPPBreakdown(fabric: 3_600, pooledMaterial: 350, hardware: 130, labor: 3_360, overhead: 650, total: 8_090),
                                  sellingPrice: 24_000, marginPct: 0.66),
                ProductSizeDetail(id: sizeScrunXL, productId: prodScrunchieId, productSku: "SCRUNCHIE",
                                  productName: "Scrunchie", sizeLabel: "L", fabricVariantName: "Silk Putih",
                                  reorderMinQty: 10, isArchived: false, currentStockQty: 0,
                                  productionStockQty: 0, manualStockQty: 0,
                                  latestHppBreakdown: HPPBreakdown(fabric: 5_100, pooledMaterial: 400, hardware: 150, labor: 3_360, overhead: 700, total: 9_710),
                                  sellingPrice: 26_000, marginPct: 0.63),
            ],
        ]

        // Resep: 1 spec per (size · fabric) — tiap spec 1 kain
        // specScrunM_Satin     → M · Satin Pelangi : potongan 90×20 cm
        // specScrunM_Waffle    → M · Waffle Merah  : potongan 80×18 cm
        // specScrunS_Satin     → L · Satin Pelangi : potongan 100×22 cm
        // specIkatM_Brokat     → L · Waffle Merah  : potongan 90×21 cm
        // specScrunL_SilkPutih → L · Silk Putih    : potongan 80×18 cm
        _patternSpecs = [
            PatternSpec(id: specScrunM_Satin, productSizeId: sizeScrunM, productName: "Scrunchie",
                        productSku: "SCRUNCHIE", sizeLabel: "M",
                        fabrics: [PatternFabric(id: UUID(), materialId: matSatinId, materialName: "Satin Pelangi",
                                                fabricFamily: "Satin", cutLengthCm: 90, cutWidthCm: 20, rotationAllowed: true)],
                        estLaborMinutes: 10, isActive: true,
                        effectiveFrom: ago(days: 7), effectiveTo: nil,
                        components: [], usedInBatchCount: 0),
            PatternSpec(id: specScrunM_Waffle, productSizeId: sizeScrunXS, productName: "Scrunchie",
                        productSku: "SCRUNCHIE", sizeLabel: "M",
                        fabrics: [PatternFabric(id: UUID(), materialId: matWaffleId, materialName: "Waffle Merah",
                                                fabricFamily: "Waffle", cutLengthCm: 80, cutWidthCm: 18, rotationAllowed: true)],
                        estLaborMinutes: 10, isActive: true,
                        effectiveFrom: ago(days: 7), effectiveTo: nil,
                        components: [], usedInBatchCount: 0),
            PatternSpec(id: specScrunS_Satin, productSizeId: sizeScrunL, productName: "Scrunchie",
                        productSku: "SCRUNCHIE", sizeLabel: "L",
                        fabrics: [PatternFabric(id: UUID(), materialId: matSatinId, materialName: "Satin Pelangi",
                                                fabricFamily: "Satin", cutLengthCm: 100, cutWidthCm: 22, rotationAllowed: true)],
                        estLaborMinutes: 12, isActive: true,
                        effectiveFrom: ago(days: 7), effectiveTo: nil,
                        components: [], usedInBatchCount: 0),
            PatternSpec(id: specIkatM_Brokat, productSizeId: sizeScrunS, productName: "Scrunchie",
                        productSku: "SCRUNCHIE", sizeLabel: "L",
                        fabrics: [PatternFabric(id: UUID(), materialId: matWaffleId, materialName: "Waffle Merah",
                                                fabricFamily: "Waffle", cutLengthCm: 90, cutWidthCm: 21, rotationAllowed: true)],
                        estLaborMinutes: 12, isActive: true,
                        effectiveFrom: ago(days: 7), effectiveTo: nil,
                        components: [], usedInBatchCount: 0),
            PatternSpec(id: specScrunL_SilkPutih, productSizeId: sizeScrunXL, productName: "Scrunchie",
                        productSku: "SCRUNCHIE", sizeLabel: "L",
                        fabrics: [PatternFabric(id: UUID(), materialId: matSilkPutihId, materialName: "Silk Putih",
                                                fabricFamily: nil, cutLengthCm: 80, cutWidthCm: 18, rotationAllowed: true)],
                        estLaborMinutes: 12, isActive: true,
                        effectiveFrom: ago(days: 3), effectiveTo: nil,
                        components: [], usedInBatchCount: 0),
        ]

        _salesOrders = seedSalesOrders()

        _settings = [
            SettingItem(key: "labor_rate_per_minute", value: 50, updatedAt: ago(days: 30)),
            SettingItem(key: "default_overhead_per_unit", value: 300, updatedAt: ago(days: 30)),
            SettingItem(key: "pooled_material_rate:thread", value: 500, updatedAt: ago(days: 30)),
            SettingItem(key: "pooled_material_rate:packaging", value: 200, updatedAt: ago(days: 30)),
        ]

        _ledgerEntries = [
            StockAdjustmentLedgerEntry(id: UUID(), productSizeId: sizeScrunM, changeQty: 10, reason: "initial", createdAt: ago(days: 3)),
            StockAdjustmentLedgerEntry(id: UUID(), productSizeId: sizeScrunXS, changeQty: 5, reason: "initial", createdAt: ago(days: 2)),
            StockAdjustmentLedgerEntry(id: UUID(), productSizeId: sizeScrunL, changeQty: 12, reason: "initial", createdAt: ago(days: 1)),
            StockAdjustmentLedgerEntry(id: UUID(), productSizeId: sizeScrunS, changeQty: 8, reason: "production", createdAt: Date()),
        ]
    }

    private func seedSalesOrders() -> [SalesOrder] {
        typealias RawItem = (UUID, String, String, Int, Double, Double)
        func makeOrder(_ id: UUID, _ inv: String, _ daysAgo: Int, _ rawItems: [RawItem]) -> SalesOrder {
            let items = rawItems.map { (sizeId, name, label, qty, price, hpp) in
                SalesOrderItem(id: UUID(), productSizeId: sizeId,
                               salesOrderId: id, productName: name, sizeLabel: label,
                               qty: qty, unitPrice: price, discount: 0,
                               unitHppSnapshot: hpp, lineProfit: (price - hpp) * Double(qty))
            }
            let rev = items.reduce(0.0) { $0 + $1.lineRevenue }
            let prf = items.reduce(0.0) { $0 + $1.lineProfit }
            return SalesOrder(id: id, invoiceNo: inv, customerName: nil, paymentMethod: "cash",
                              marketplaceFeePct: 0, status: "paid", soldAt: ago(days: daysAgo),
                              items: items, totalRevenue: rev, totalProfit: prf)
        }
        return [
            makeOrder(sale1Id, "INV-2026-001", 0,  [(sizeScrunM, "Scrunchie", "M · Satin Pelangi", 3, 22000, 12000)]),
            makeOrder(sale2Id, "INV-2026-002", 1,  [(sizeScrunL, "Scrunchie", "L · Satin Pelangi", 2, 25000, 13000),
                                                     (sizeScrunXS, "Scrunchie", "M · Waffle Merah", 1, 20000, 11000)]),
            makeOrder(sale3Id, "INV-2026-003", 2,  [(sizeScrunS, "Scrunchie", "L · Waffle Merah", 4, 24000, 12000)]),
            makeOrder(UUID(),  "INV-2026-004", 3,  [(sizeScrunXL, "Scrunchie", "L · Silk Putih",   2, 26000, 14000)]),
            makeOrder(UUID(),  "INV-2026-005", 4,  [(sizeScrunM,  "Scrunchie", "M · Satin Pelangi", 5, 22000, 12000),
                                                     (sizeScrunXS, "Scrunchie", "M · Waffle Merah",  2, 20000, 11000)]),
            makeOrder(UUID(),  "INV-2026-006", 6,  [(sizeScrunL,  "Scrunchie", "L · Satin Pelangi",  1, 25000, 13000)]),
            makeOrder(UUID(),  "INV-2026-007", 7,  [(sizeScrunM,  "Scrunchie", "M · Satin Pelangi", 6, 22000, 12000)]),
            makeOrder(UUID(),  "INV-2026-008", 9,  [(sizeScrunS,  "Scrunchie", "L · Waffle Merah",  3, 24000, 12000),
                                                     (sizeScrunXL, "Scrunchie", "L · Silk Putih",   2, 26000, 14000)]),
            makeOrder(UUID(),  "INV-2026-009", 11, [(sizeScrunXS, "Scrunchie", "M · Waffle Merah",  4, 20000, 11000)]),
            makeOrder(UUID(),  "INV-2026-010", 12, [(sizeScrunM,  "Scrunchie", "M · Satin Pelangi", 3, 22000, 12000)]),
            makeOrder(UUID(),  "INV-2026-011", 14, [(sizeScrunL,  "Scrunchie", "L · Satin Pelangi",  2, 25000, 13000),
                                                     (sizeScrunS,  "Scrunchie", "L · Waffle Merah",  3, 24000, 12000)]),
            makeOrder(UUID(),  "INV-2026-012", 16, [(sizeScrunXL, "Scrunchie", "L · Silk Putih",   1, 26000, 14000)]),
            makeOrder(UUID(),  "INV-2026-013", 18, [(sizeScrunM,  "Scrunchie", "M · Satin Pelangi", 7, 22000, 12000)]),
            makeOrder(UUID(),  "INV-2026-014", 21, [(sizeScrunXS, "Scrunchie", "M · Waffle Merah",  3, 20000, 11000),
                                                     (sizeScrunL,  "Scrunchie", "L · Satin Pelangi",  1, 25000, 13000)]),
            makeOrder(UUID(),  "INV-2026-015", 24, [(sizeScrunS,  "Scrunchie", "L · Waffle Merah",  5, 24000, 12000)]),
            makeOrder(UUID(),  "INV-2026-016", 27, [(sizeScrunM,  "Scrunchie", "M · Satin Pelangi", 4, 22000, 12000)]),
            makeOrder(UUID(),  "INV-2026-017", 30, [(sizeScrunXL, "Scrunchie", "L · Silk Putih",   3, 26000, 14000),
                                                     (sizeScrunXS, "Scrunchie", "M · Waffle Merah",  2, 20000, 11000)]),
        ]
    }

    // Simulate network delay
    private func delay() async {
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
    }

    // MARK: - Auth

    func loginWithGoogle(idToken: String?) async throws -> LoginResponse {
        await delay()
        let expiry = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        return LoginResponse(accessToken: "mock-jwt-google-\(UUID())", expiresAt: expiry)
    }

    // MARK: - Materials

    func getMaterials(search: String?) async throws -> [Material] {
        await delay()
        var result = _materials.filter { !$0.isArchived }
        if let q = search?.lowercased(), !q.isEmpty {
            result = result.filter { $0.name.lowercased().contains(q) }
        }
        return result.map { annotateStock($0) }
    }

    private func annotateStock(_ mat: Material) -> Material {
        var m = mat
        let purchases = _purchases[mat.id] ?? []
        switch mat.category {
        case .fabric:
            m.currentTotalQty = purchases.compactMap { $0.remainingLengthCm }.reduce(0, +) / 100.0
        default:
            m.currentTotalQty = purchases.compactMap { $0.qty }.reduce(0, +)
        }
        return m
    }

    func getMaterial(id: UUID) async throws -> Material {
        await delay()
        guard let m = _materials.first(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Material tidak ditemukan")
        }
        return m
    }

    func createMaterial(_ req: CreateMaterialRequest) async throws -> Material {
        await delay()
        guard let cat = MaterialCategory(rawValue: req.category) else {
            throw APIError.serverError(400, "Kategori tidak valid")
        }
        let m = Material(id: UUID(), name: req.name, category: cat,
                         costClass: req.costClass, purchaseUnit: req.purchaseUnit,
                         usageUnit: req.usageUnit, fabricWidthCm: req.fabricWidthCm,
                         currentAvgCost: 0, reorderMinQty: nil,
                         isArchived: false, createdAt: Date(), updatedAt: Date())
        _materials.append(m)
        _purchases[m.id] = []
        return m
    }

    func patchMaterial(id: UUID, _ req: PatchMaterialRequest) async throws -> Material {
        await delay()
        guard let idx = _materials.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Material tidak ditemukan")
        }
        let old = _materials[idx]
        let updated = Material(id: old.id,
                               name: req.name ?? old.name,
                               category: old.category,
                               costClass: old.costClass,
                               purchaseUnit: old.purchaseUnit,
                               usageUnit: old.usageUnit,
                               fabricWidthCm: req.fabricWidthCm ?? old.fabricWidthCm,
                               currentAvgCost: old.currentAvgCost,
                               reorderMinQty: req.reorderMinQty ?? old.reorderMinQty,
                               isArchived: req.isArchived ?? old.isArchived,
                               createdAt: old.createdAt,
                               updatedAt: Date())
        _materials[idx] = updated
        return updated
    }

    func getPurchases(materialId: UUID) async throws -> [MaterialPurchase] {
        await delay()
        return (_purchases[materialId] ?? []).sorted { $0.purchasedAt > $1.purchasedAt }
    }

    func createPurchase(materialId: UUID, _ req: CreatePurchaseRequest) async throws -> MaterialPurchase {
        await delay()
        guard _materials.contains(where: { $0.id == materialId }) else {
            throw APIError.serverError(404, "Material tidak ditemukan")
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let purchasedAt = dateFormatter.date(from: req.purchasedAt) ?? Date()
        let p = MaterialPurchase(id: UUID(), materialId: materialId,
                                 widthCm: req.widthCm, lengthCm: req.lengthCm,
                                 qty: req.qty, packageLabel: req.packageLabel,
                                 totalCost: req.totalCost,
                                 supplierId: req.supplierId,
                                 supplierName: req.supplierName,
                                 purchasedAt: purchasedAt,
                                 remainingLengthCm: req.lengthCm,
                                 createdAt: Date())
        if _purchases[materialId] == nil { _purchases[materialId] = [] }
        _purchases[materialId]!.insert(p, at: 0)
        recalcAvgCost(materialId: materialId)
        return p
    }

    func patchPurchase(materialId: UUID, purchaseId: UUID, _ req: PatchPurchaseRequest) async throws -> MaterialPurchase {
        await delay()
        guard var list = _purchases[materialId],
              let idx = list.firstIndex(where: { $0.id == purchaseId }) else {
            throw APIError.serverError(404, "Pembelian tidak ditemukan")
        }
        let old = list[idx]
        if old.isConsumed && (req.widthCm != nil || req.lengthCm != nil || req.qty != nil) {
            throw APIError.conflict("Pembelian ini sudah dipakai di produksi — dimensi tidak bisa diubah")
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let purchasedAt = req.purchasedAt.flatMap { dateFormatter.date(from: $0) } ?? old.purchasedAt
        let updated = MaterialPurchase(id: old.id, materialId: old.materialId,
                                       widthCm: req.widthCm ?? old.widthCm,
                                       lengthCm: req.lengthCm ?? old.lengthCm,
                                       qty: req.qty ?? old.qty,
                                       packageLabel: old.packageLabel,
                                       totalCost: req.totalCost ?? old.totalCost,
                                       supplierId: req.supplierId ?? old.supplierId,
                                       supplierName: req.supplierName ?? old.supplierName,
                                       purchasedAt: purchasedAt,
                                       remainingLengthCm: old.remainingLengthCm,
                                       createdAt: old.createdAt)
        list[idx] = updated
        _purchases[materialId] = list
        recalcAvgCost(materialId: materialId)
        return updated
    }

    func deletePurchase(materialId: UUID, purchaseId: UUID) async throws {
        await delay()
        guard var list = _purchases[materialId],
              let idx = list.firstIndex(where: { $0.id == purchaseId }) else {
            throw APIError.serverError(404, "Pembelian tidak ditemukan")
        }
        let purchase = list[idx]
        if purchase.isConsumed {
            throw APIError.conflict("Tidak bisa menghapus pembelian yang sudah dipakai di produksi")
        }
        list.remove(at: idx)
        _purchases[materialId] = list
        recalcAvgCost(materialId: materialId)
    }

    private func recalcAvgCost(materialId: UUID) {
        let purchases = _purchases[materialId] ?? []
        guard let idx = _materials.firstIndex(where: { $0.id == materialId }) else { return }
        let totalCost = purchases.reduce(0.0) { $0 + $1.totalCost }
        let totalQty = purchases.reduce(0.0) { $0 + ($1.lengthCm ?? $1.qty ?? 1) }
        let avg = totalQty > 0 ? totalCost / totalQty : 0
        let old = _materials[idx]
        _materials[idx] = Material(id: old.id, name: old.name, category: old.category,
                                   costClass: old.costClass, purchaseUnit: old.purchaseUnit,
                                   usageUnit: old.usageUnit, fabricWidthCm: old.fabricWidthCm,
                                   currentAvgCost: avg, reorderMinQty: old.reorderMinQty,
                                   isArchived: old.isArchived, createdAt: old.createdAt,
                                   updatedAt: Date())
    }

    // MARK: - Suppliers

    func getSuppliers(search: String?) async throws -> [Supplier] {
        await delay()
        if let q = search?.lowercased(), !q.isEmpty {
            return _suppliers.filter { $0.name.lowercased().contains(q) }
        }
        return _suppliers
    }

    func createSupplier(name: String) async throws -> Supplier {
        await delay()
        if let existing = _suppliers.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing
        }
        let s = Supplier(id: UUID(), name: name, createdAt: Date())
        _suppliers.append(s)
        return s
    }

    // MARK: - Products

    func getProducts() async throws -> [Product] {
        await delay()
        return _products.filter { !$0.isArchived }
    }

    func createProduct(name: String, sku: String? = nil) async throws -> Product {
        await delay()
        let computedSku = (sku ?? name.uppercased().replacingOccurrences(of: " ", with: "-"))
        guard !_products.contains(where: { $0.sku == computedSku }) else {
            throw APIError.conflict("SKU sudah dipakai")
        }
        let p = Product(id: UUID(), sku: computedSku, name: name, isArchived: false, createdAt: Date())
        _products.append(p)
        _productSizes[computedSku] = []
        return p
    }

    func getProductSizes(sku: String) async throws -> [ProductSizeDetail] {
        await delay()
        return (_productSizes[sku] ?? []).filter { !$0.isArchived }
    }

    func getAllProductSizes() async throws -> [ProductSizeDetail] {
        await delay()
        return _productSizes.values.flatMap { $0 }.filter { !$0.isArchived }
    }

    func getProductSizeById(id: UUID) async throws -> ProductSizeDetail {
        await delay()
        let all = _productSizes.values.flatMap { $0 }
        guard let found = all.first(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Product size tidak ditemukan")
        }
        return found
    }

    func getStockLedger(from: Date, to: Date) async throws -> [StockAdjustmentLedgerEntry] {
        await delay()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: from)
        let endOfDay = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: to) ?? to)
        
        return _ledgerEntries.filter { entry in
            entry.createdAt >= startOfDay && entry.createdAt < endOfDay
        }
    }

    func patchProduct(sku: String, name: String) async throws -> Product {
        await delay()
        guard let idx = _products.firstIndex(where: { $0.sku == sku }) else {
            throw APIError.serverError(404, "Produk tidak ditemukan")
        }
        let old = _products[idx]
        let updated = Product(id: old.id, sku: old.sku, name: name, isArchived: old.isArchived, createdAt: old.createdAt)
        _products[idx] = updated
        if var sizes = _productSizes[sku] {
            sizes = sizes.map { s in
                ProductSizeDetail(id: s.id, productId: s.productId, productSku: s.productSku,
                                  productName: name, sizeLabel: s.sizeLabel,
                                  fabricVariantName: s.fabricVariantName,
                                  reorderMinQty: s.reorderMinQty, isArchived: s.isArchived,
                                  currentStockQty: s.currentStockQty,
                                  productionStockQty: s.productionStockQty, manualStockQty: s.manualStockQty,
                                  latestHppBreakdown: s.latestHppBreakdown,
                                  sellingPrice: s.sellingPrice, marginPct: s.marginPct)
            }
            _productSizes[sku] = sizes
        }
        return updated
    }

    func archiveProduct(sku: String) async throws {
        await delay()
        guard let idx = _products.firstIndex(where: { $0.sku == sku }) else {
            throw APIError.serverError(404, "Produk tidak ditemukan")
        }
        let old = _products[idx]
        _products[idx] = Product(id: old.id, sku: old.sku, name: old.name, isArchived: true, createdAt: old.createdAt)
    }

    func archiveProductSize(sku: String, sizeId: UUID) async throws {
        await delay()
        guard var sizes = _productSizes[sku],
              let idx = sizes.firstIndex(where: { $0.id == sizeId }) else {
            throw APIError.serverError(404, "Ukuran tidak ditemukan")
        }
        let old = sizes[idx]
        sizes[idx] = ProductSizeDetail(id: old.id, productId: old.productId, productSku: old.productSku,
                                       productName: old.productName, sizeLabel: old.sizeLabel,
                                       fabricVariantName: old.fabricVariantName,
                                       reorderMinQty: old.reorderMinQty, isArchived: true,
                                       currentStockQty: old.currentStockQty,
                                       productionStockQty: old.productionStockQty, manualStockQty: old.manualStockQty,
                                       latestHppBreakdown: old.latestHppBreakdown,
                                       sellingPrice: old.sellingPrice, marginPct: old.marginPct)
        _productSizes[sku] = sizes
    }

    func createProductSize(sku: String, sizeLabel: String, fabricVariantName: String? = nil, reorderMinQty: Double? = nil) async throws -> ProductSizeDetail {
        await delay()
        guard let product = _products.first(where: { $0.sku == sku }) else {
            throw APIError.serverError(404, "Produk tidak ditemukan")
        }
        guard !(_productSizes[sku] ?? []).contains(where: { $0.sizeLabel == sizeLabel && $0.fabricVariantName == fabricVariantName }) else {
            throw APIError.conflict("Ukuran dengan jenis kain ini sudah ada")
        }
        let detail = ProductSizeDetail(id: UUID(), productId: product.id, productSku: sku,
                                       productName: product.name, sizeLabel: sizeLabel,
                                       fabricVariantName: fabricVariantName,
                                       reorderMinQty: reorderMinQty, isArchived: false,
                                       currentStockQty: 0,
                                       productionStockQty: 0, manualStockQty: 0,
                                       latestHppBreakdown: nil,
                                       sellingPrice: nil, marginPct: nil)
        if _productSizes[sku] == nil { _productSizes[sku] = [] }
        _productSizes[sku]!.append(detail)
        return detail
    }

    func patchProductSize(sku: String, sizeId: UUID, _ req: PatchProductSizeRequest) async throws -> ProductSizeDetail {
        await delay()
        guard var list = _productSizes[sku],
              let idx = list.firstIndex(where: { $0.id == sizeId }) else {
            throw APIError.serverError(404, "Ukuran tidak ditemukan")
        }
        let old = list[idx]
        let price = req.sellingPrice ?? old.sellingPrice
        let hpp = old.latestHppBreakdown?.total
        let margin: Double? = (price != nil && hpp != nil && price! > 0) ? (price! - hpp!) / price! : old.marginPct
        let updated = ProductSizeDetail(id: old.id, productId: old.productId, productSku: sku,
                                        productName: old.productName, sizeLabel: old.sizeLabel,
                                        fabricVariantName: old.fabricVariantName,
                                        reorderMinQty: req.reorderMinQty ?? old.reorderMinQty,
                                        isArchived: old.isArchived,
                                        currentStockQty: old.currentStockQty,
                                        productionStockQty: old.productionStockQty, manualStockQty: old.manualStockQty,
                                        latestHppBreakdown: old.latestHppBreakdown,
                                        sellingPrice: price,
                                        marginPct: margin)
        list[idx] = updated
        _productSizes[sku] = list
        return updated
    }

    func getPriceAdvisor(sku: String, sizeId: UUID, _ req: PriceAdvisorRequest) async throws -> PriceAdvisorResponse {
        await delay()
        guard let list = _productSizes[sku],
              let detail = list.first(where: { $0.id == sizeId }),
              let hpp = detail.latestHppBreakdown?.total else {
            throw APIError.serverError(400, "HPP belum tersedia untuk ukuran ini")
        }
        let denom = 1 - req.targetMarginPct - (req.marketplaceFeePct ?? 0) - (req.promoAllocationPct ?? 0)
        guard denom > 0 else { throw APIError.serverError(400, "Margin terlalu besar") }
        let rawPrice = hpp / denom
        let suggested = ceil(rawPrice / 500) * 500
        let margin = (suggested - hpp) / suggested
        let markup = (suggested - hpp) / hpp
        return PriceAdvisorResponse(suggestedPrice: suggested, resultingMarginPct: margin, resultingMarkupPct: markup)
    }

    // MARK: - Pattern Specs

    func getPatternSpecs(productId: UUID?, size: String?, fabricMaterialId: UUID?) async throws -> [PatternSpec] {
        await delay()
        return _patternSpecs.filter { spec in
            if spec.isActive == false { return false }
            if let pid = productId { guard _productSizes.values.flatMap({ $0 }).contains(where: { $0.id == spec.productSizeId && $0.productId == pid }) else { return false } }
            if let s = size { guard spec.sizeLabel == s else { return false } }
            if let fid = fabricMaterialId { guard spec.fabrics.contains(where: { $0.materialId == fid }) else { return false } }
            return true
        }
    }

    func createOrUpdatePatternSpec(_ req: CreatePatternSpecRequest) async throws -> PatternSpec {
        await delay()
        let sizeDetail = _productSizes.values.flatMap({ $0 }).first(where: { $0.id == req.productSizeId })
        let productName = sizeDetail?.productName ?? "Unknown"
        let productSku  = sizeDetail?.productSku  ?? ""
        let sizeLabel   = sizeDetail?.sizeLabel   ?? ""

        let fabricObjects = req.fabrics.map { f in
            let mat = _materials.first(where: { $0.id == f.materialId })
            return PatternFabric(id: UUID(), materialId: f.materialId,
                                 materialName: mat?.name ?? "Unknown",
                                 fabricFamily: mat?.fabricFamily,
                                 cutLengthCm: f.cutLengthCm, cutWidthCm: f.cutWidthCm,
                                 rotationAllowed: f.rotationAllowed)
        }
        let comps = req.components.map { c in
            PatternComponent(id: UUID(), patternSpecId: UUID(),
                             materialId: c.materialId,
                             materialName: _materials.first(where: { $0.id == c.materialId })?.name ?? "Unknown",
                             qtyPerUnit: c.qtyPerUnit)
        }

        // One active spec per (productSizeId, fabricMaterialId) — multiple fabrics may coexist for the same size
        let firstFabricId = req.fabrics.first?.materialId
        if let idx = _patternSpecs.firstIndex(where: {
            $0.productSizeId == req.productSizeId &&
            $0.isActive &&
            $0.fabrics.first?.materialId == firstFabricId
        }) {
            let existing = _patternSpecs[idx]
            if existing.usedInBatchCount == 0 {
                let updated = PatternSpec(id: existing.id, productSizeId: req.productSizeId,
                                          productName: productName, productSku: productSku,
                                          sizeLabel: sizeLabel, fabrics: fabricObjects,
                                          estLaborMinutes: req.estLaborMinutes, isActive: true,
                                          effectiveFrom: existing.effectiveFrom, effectiveTo: nil,
                                          components: comps, usedInBatchCount: 0)
                _patternSpecs[idx] = updated
                return updated
            } else {
                let deactivated = PatternSpec(id: existing.id, productSizeId: existing.productSizeId,
                                              productName: existing.productName, productSku: existing.productSku,
                                              sizeLabel: existing.sizeLabel, fabrics: existing.fabrics,
                                              estLaborMinutes: existing.estLaborMinutes, isActive: false,
                                              effectiveFrom: existing.effectiveFrom, effectiveTo: Date(),
                                              components: existing.components, usedInBatchCount: existing.usedInBatchCount)
                _patternSpecs[idx] = deactivated
            }
        }

        let newSpec = PatternSpec(id: UUID(), productSizeId: req.productSizeId,
                                   productName: productName, productSku: productSku,
                                   sizeLabel: sizeLabel, fabrics: fabricObjects,
                                   estLaborMinutes: req.estLaborMinutes, isActive: true,
                                   effectiveFrom: Date(), effectiveTo: nil,
                                   components: comps, usedInBatchCount: 0)
        _patternSpecs.append(newSpec)
        return newSpec
    }

    func deletePatternSpec(id: UUID) async throws {
        await delay()
        guard let idx = _patternSpecs.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Resep tidak ditemukan")
        }
        if _patternSpecs[idx].usedInBatchCount > 0 {
            throw APIError.conflict("Resep ini sudah dipakai di produksi dan tidak bisa dihapus")
        }
        _patternSpecs.remove(at: idx)
    }

    func getPatternSpecsForSize(productSku: String, sizeLabel: String) async throws -> [PatternSpec] {
        await delay()
        return _patternSpecs.filter { $0.isActive && $0.productSku == productSku && $0.sizeLabel == sizeLabel }
    }

    // MARK: - Optimizer

    func suggestLayouts(_ req: SuggestOptimizerRequest) async throws -> [OptimizerLayout] {
        await delay()
        guard let purchase = _purchases.values.flatMap({ $0 }).first(where: { $0.id == req.materialPurchaseId }),
              let width = purchase.widthCm, let length = purchase.remainingLengthCm else {
            throw APIError.serverError(400, "Pembelian tidak ditemukan atau sudah habis")
        }

        // Pre-compute orientation + minimum-rows per candidate.
        // Stores BOTH primary and alternative orientations so the allocation phase can fall back
        // when the primary's rowHeight doesn't fit in the space left after reserving for others.
        struct CandInfo {
            let candidate: OptimizerCandidate
            let spec: PatternSpec
            // Primary orientation: maximises total pieces on the full roll
            let cols: Int
            let rowHeight: Double
            let orientation: String
            let minRows: Int
            // Alternative orientation (the other rotation)
            let altCols: Int
            let altRowHeight: Double
            let altOrientation: String
            let altMinRows: Int
            // Smallest fabric length needed to satisfy minQty using whichever orientation is more compact.
            // Used for future-reservation so a tall primary rowHeight doesn't over-claim the budget.
            let bestMinLen: Double
        }
        // Use fabric dimensions matching this roll's material (for multi-fabric products)
        let rollMaterialId = purchase.materialId

        let candInfos: [CandInfo] = req.candidates.compactMap { candidate in
            guard let spec = _patternSpecs.first(where: { $0.id == candidate.patternSpecId }) else { return nil }
            let matchedFabric = spec.fabrics.first(where: { $0.materialId == rollMaterialId })
                ?? spec.fabrics.first
            let cutW = matchedFabric?.cutWidthCm ?? 0
            let cutL = matchedFabric?.cutLengthCm ?? 0
            let rotAllowed = matchedFabric?.rotationAllowed ?? false
            let normalCols = cutW > 0 ? Int(width / cutW) : 0
            let normalRows = normalCols > 0 && cutL > 0 ? Int(length / cutL) : 0
            let rotCols = rotAllowed && cutL > 0 ? Int(width / cutL) : 0
            let rotRows = rotCols > 0 ? Int(length / cutW) : 0
            // At least one orientation must fit ≥1 piece on the full roll
            guard normalCols * normalRows > 0 || rotCols * rotRows > 0 else { return nil }
            let minQty = candidate.minQty ?? 0
            let normalMinRows = normalCols > 0 && minQty > 0 ? Int(ceil(Double(minQty) / Double(normalCols))) : 0
            let rotMinRows    = rotCols    > 0 && minQty > 0 ? Int(ceil(Double(minQty) / Double(rotCols)))    : 0
            let normalMinLen: Double = normalCols > 0 ? Double(normalMinRows) * cutL : .infinity
            let rotMinLen:    Double = rotCols    > 0 ? Double(rotMinRows)    * cutW : .infinity
            let bestMinLen = min(normalMinLen, rotMinLen)
            // Primary = orientation that yields more pieces on the full roll
            let useRotated = (rotCols * rotRows) > (normalCols * normalRows)
            let cols      = useRotated ? rotCols       : normalCols
            let rowH      = useRotated ? cutW          : cutL
            let orient    = useRotated ? "rotated"     : "normal"
            let minR      = useRotated ? rotMinRows    : normalMinRows
            let altCols   = useRotated ? normalCols    : rotCols
            let altRowH   = useRotated ? cutL          : cutW
            let altOrient = useRotated ? "normal"      : "rotated"
            let altMinR   = useRotated ? normalMinRows : rotMinRows
            return CandInfo(candidate: candidate, spec: spec,
                            cols: cols, rowHeight: rowH, orientation: orient, minRows: minR,
                            altCols: altCols, altRowHeight: altRowH, altOrientation: altOrient, altMinRows: altMinR,
                            bestMinLen: bestMinLen == .infinity ? 0 : bestMinLen)
        }

        var layouts: [OptimizerLayout] = []

        for (si, strategy) in ([OptimizerStrategy.minWaste, .maxQty, .maxProfit]).enumerated() {
            var remainingLength = length
            var items: [OptimizerLayoutItem] = []
            var totalQty = 0

            for (idx, info) in candInfos.enumerated() {
                // Use bestMinLen (not minRows×rowHeight) so a candidate with a tall primary
                // orientation doesn't over-consume the reservation budget for other candidates.
                let futureMinLength = candInfos[(idx + 1)...].reduce(0.0) { $0 + $1.bestMinLen }
                let availableForThis = max(0.0, remainingLength - futureMinLength)

                // Try primary orientation; if it doesn't fit, try the alternative
                var usedCols    = info.cols
                var usedRowH    = info.rowHeight
                var usedOrient  = info.orientation
                var usedMinRows = info.minRows
                var maxRowsForThis = Int(availableForThis / usedRowH)
                if maxRowsForThis == 0, info.altCols > 0 {
                    let altMax = Int(availableForThis / info.altRowHeight)
                    if altMax > 0 {
                        usedCols       = info.altCols
                        usedRowH       = info.altRowHeight
                        usedOrient     = info.altOrientation
                        usedMinRows    = info.altMinRows
                        maxRowsForThis = altMax
                    }
                }
                guard maxRowsForThis > 0 else { continue }

                // Guarantee minimum; any extra rows depend on strategy
                let minRowsSatisfied = min(usedMinRows, maxRowsForThis)
                let naturalExtraRows = maxRowsForThis - minRowsSatisfied
                let extraRows = si == 2
                    ? Int(Double(naturalExtraRows) * 0.9)   // max profit: hold back 10%
                    : naturalExtraRows                       // min waste & max qty: use all

                let finalRows = minRowsSatisfied + extraRows
                guard finalRows > 0 else { continue }

                let lengthUsed = Double(finalRows) * usedRowH
                guard lengthUsed <= remainingLength else { continue }

                let qty = usedCols * finalRows
                let costPerUnit = (purchase.totalCost / length) * usedRowH / Double(usedCols)
                items.append(OptimizerLayoutItem(id: UUID(),
                                                 productSizeId: info.candidate.productSizeId,
                                                 productName: info.spec.productName,
                                                 sizeLabel: info.spec.sizeLabel,
                                                 patternSpecId: info.candidate.patternSpecId,
                                                 orientation: usedOrient, qtySuggested: qty,
                                                 fabricLengthUsedCm: lengthUsed, costPerPiece: costPerUnit))
                remainingLength -= lengthUsed
                totalQty += qty
            }

            let wastePct = length > 0 ? remainingLength / length : 0
            layouts.append(OptimizerLayout(id: UUID(), strategy: strategy, wastePct: wastePct,
                                           items: items, totalQty: totalQty, estimatedProfit: nil))
        }

        return layouts
    }

    func createLayout(_ req: CreateLayoutRequest) async throws -> CuttingLayout {
        await delay()
        let purchase = _purchases.values.flatMap({ $0 }).first(where: { $0.id == req.materialPurchaseId })
        let materialName = purchase.flatMap { p in _materials.first(where: { $0.id == p.materialId }) }?.name ?? "Kain"

        let totalUsed = req.items.reduce(0.0) { $0 + $1.fabricLengthUsedCm }
        let totalLength = purchase?.remainingLengthCm ?? totalUsed
        let wastePct = totalLength > 0 ? max(0.0, (totalLength - totalUsed) / totalLength) : 0.0
        let totalFabricCost = req.items.reduce(0.0) { $0 + $1.costPerPiece * Double($1.qtySuggested) }

        let layoutItems = req.items.map { item -> OptimizerLayoutItem in
            let sizeDetail = _productSizes.values.flatMap({ $0 }).first(where: { $0.id == item.productSizeId })
            return OptimizerLayoutItem(id: UUID(),
                                       productSizeId: item.productSizeId,
                                       productName: sizeDetail?.productName ?? "",
                                       sizeLabel: sizeDetail?.sizeLabel ?? "",
                                       patternSpecId: item.patternSpecId,
                                       orientation: item.orientation,
                                       qtySuggested: item.qtySuggested,
                                       fabricLengthUsedCm: item.fabricLengthUsedCm,
                                       costPerPiece: item.costPerPiece)
        }

        let layout = CuttingLayout(id: UUID(),
                                   materialPurchaseId: req.materialPurchaseId,
                                   materialName: materialName,
                                   strategy: req.strategy,
                                   status: "suggested",
                                   wastePct: wastePct,
                                   totalFabricCost: totalFabricCost,
                                   createdAt: Date(),
                                   items: layoutItems)
        _cuttingLayouts.append(layout)
        return layout
    }

    func discardLayout(id: UUID) async throws {
        await delay()
    }

    // MARK: - Production

    func createProductionBatch(cuttingLayoutIds: [UUID] = []) async throws -> ProductionBatch {
        await delay()
        let batchId = UUID()
        var batchItems: [ProductionBatchItem] = []
        var strategyName: String? = nil
        var materialName: String? = nil

        if !cuttingLayoutIds.isEmpty {
            let laborRate       = _settings.first(where: { $0.key == "labor_rate_per_minute" })?.value ?? 50
            let overheadPerUnit = _settings.first(where: { $0.key == "default_overhead_per_unit" })?.value ?? 300
            let pooledThread    = _settings.first(where: { $0.key == "pooled_material_rate:thread" })?.value ?? 500

            // Collect per-productSizeId entries from all layouts:
            // each entry records (specId, qty, costPerPiece, productName, sizeLabel)
            var sizeEntries: [UUID: [(specId: UUID, qty: Int, cost: Double, name: String, size: String)]] = [:]

            for layoutId in cuttingLayoutIds {
                guard let layout = _cuttingLayouts.first(where: { $0.id == layoutId }) else { continue }
                if strategyName == nil {
                    strategyName = layout.strategy.flatMap { OptimizerStrategy(rawValue: $0)?.displayName }
                    materialName = layout.materialName
                }
                for item in layout.items {
                    let entry = (specId: item.patternSpecId,
                                 qty: item.qtySuggested,
                                 cost: item.costPerPiece,
                                 name: item.productName,
                                 size: item.sizeLabel)
                    sizeEntries[item.productSizeId, default: []].append(entry)
                }
            }

            // Aggregate: bottleneck qty (MIN), fabric HPP (SUM across layouts)
            for (sizeId, entries) in sizeEntries {
                guard let first = entries.first else { continue }
                let spec        = _patternSpecs.first(where: { $0.id == first.specId })
                let bottleneck  = entries.map(\.qty).min() ?? 0
                let fabricCost  = entries.map(\.cost).reduce(0, +)
                let hppLabor    = (spec?.estLaborMinutes ?? 0) * laborRate
                let hppHardware = spec?.components.reduce(0.0) { sum, comp in
                    let cost = _materials.first(where: { $0.id == comp.materialId })?.currentAvgCost ?? 0
                    return sum + cost * comp.qtyPerUnit
                } ?? 0
                let latestHpp   = _productSizes.values.flatMap { $0 }
                    .first(where: { $0.id == sizeId })?.latestHppBreakdown
                batchItems.append(ProductionBatchItem(
                    id: UUID(), productionBatchId: batchId,
                    productSizeId: sizeId,
                    productName: first.name, sizeLabel: first.size,
                    patternSpecId: first.specId,
                    qtyActual: bottleneck, qtySuggested: bottleneck,
                    hppFabric: fabricCost,
                    hppPooledMaterial: pooledThread, hppHardware: hppHardware,
                    hppLabor: hppLabor, hppOverhead: overheadPerUnit,
                    hppTotal: fabricCost + pooledThread + hppHardware + hppLabor + overheadPerUnit,
                    latestHppBreakdown: latestHpp
                ))
            }
        }
        // manual batch (no layout) → empty items, user sets qty manually

        let batch = ProductionBatch(id: batchId, cuttingLayoutIds: cuttingLayoutIds,
                                    cuttingLayoutStrategy: strategyName, materialName: materialName,
                                    producedAt: Date(), status: "draft", notes: nil, items: batchItems)
        _productionBatches.append(batch)
        return batch
    }

    func updateBatchItem(batchId: UUID, itemId: UUID, qtyActual: Int) async throws -> ProductionBatchItem {
        await delay()
        guard let bIdx = _productionBatches.firstIndex(where: { $0.id == batchId }) else {
            throw APIError.serverError(404, "Batch tidak ditemukan")
        }
        guard let iIdx = _productionBatches[bIdx].items.firstIndex(where: { $0.id == itemId }) else {
            throw APIError.serverError(404, "Item tidak ditemukan")
        }
        _productionBatches[bIdx].items[iIdx].qtyActual = qtyActual
        return _productionBatches[bIdx].items[iIdx]
    }

    func confirmBatch(id: UUID) async throws {
        await delay()
        guard let idx = _productionBatches.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Batch tidak ditemukan")
        }
        let old = _productionBatches[idx]
        let confirmed = ProductionBatch(id: old.id, cuttingLayoutIds: old.cuttingLayoutIds,
                                        cuttingLayoutStrategy: old.cuttingLayoutStrategy,
                                        materialName: old.materialName,
                                        producedAt: old.producedAt, status: "confirmed",
                                        notes: old.notes, items: old.items)
        _productionBatches[idx] = confirmed

        // Add produced qty to stock and update HPP per product size
        for item in old.items {
            for sku in _productSizes.keys {
                guard var sizes = _productSizes[sku],
                      let sIdx = sizes.firstIndex(where: { $0.id == item.productSizeId }) else { continue }
                let s = sizes[sIdx]
                sizes[sIdx] = ProductSizeDetail(id: s.id, productId: s.productId,
                                                productSku: s.productSku, productName: s.productName,
                                                sizeLabel: s.sizeLabel, fabricVariantName: s.fabricVariantName,
                                                reorderMinQty: s.reorderMinQty,
                                                isArchived: s.isArchived,
                                                currentStockQty: s.currentStockQty + item.qtyActual,
                                                productionStockQty: s.productionStockQty + item.qtyActual,
                                                manualStockQty: s.manualStockQty,
                                                latestHppBreakdown: HPPBreakdown(fabric: item.hppFabric,
                                                    pooledMaterial: item.hppPooledMaterial,
                                                    hardware: item.hppHardware, labor: item.hppLabor,
                                                    overhead: item.hppOverhead, total: item.hppTotal),
                                                sellingPrice: s.sellingPrice, marginPct: s.marginPct)
                _productSizes[sku] = sizes
                
                _ledgerEntries.append(StockAdjustmentLedgerEntry(
                    id: UUID(),
                    productSizeId: s.id,
                    changeQty: item.qtyActual,
                    reason: "production",
                    createdAt: Date()
                ))
                break
            }
        }

        // Reduce remainingLengthCm on the purchase used by this layout
        if let layoutId = old.cuttingLayoutId,
           let layout = _cuttingLayouts.first(where: { $0.id == layoutId }) {
            let totalUsed = layout.items.reduce(0.0) { $0 + $1.fabricLengthUsedCm }
            for matId in _purchases.keys {
                guard var list = _purchases[matId],
                      let pIdx = list.firstIndex(where: { $0.id == layout.materialPurchaseId }) else { continue }
                let p = list[pIdx]
                let newRemaining = max(0.0, (p.remainingLengthCm ?? 0) - totalUsed)
                list[pIdx] = MaterialPurchase(id: p.id, materialId: p.materialId,
                                              widthCm: p.widthCm, lengthCm: p.lengthCm,
                                              qty: p.qty, packageLabel: p.packageLabel,
                                              totalCost: p.totalCost, supplierId: p.supplierId,
                                              supplierName: p.supplierName, purchasedAt: p.purchasedAt,
                                              remainingLengthCm: newRemaining, createdAt: p.createdAt)
                _purchases[matId] = list
                break
            }
        }

    }

    func getProductionBatch(id: UUID) async throws -> ProductionBatch {
        await delay()
        guard let batch = _productionBatches.first(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Batch tidak ditemukan")
        }
        return batch
    }

    func getProductionBatches(status: String? = nil) async throws -> [ProductionBatch] {
        await delay()
        if let status {
            return _productionBatches.filter { $0.status == status }.sorted { $0.producedAt > $1.producedAt }
        }
        return _productionBatches.sorted { $0.producedAt > $1.producedAt }
    }

    func deleteProductionBatch(id: UUID) async throws {
        await delay()
        guard let batch = _productionBatches.first(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Batch tidak ditemukan")
        }
        guard batch.isDraft else {
            throw APIError.serverError(409, "Batch yang sudah dikonfirmasi tidak bisa dihapus")
        }
        _productionBatches.removeAll { $0.id == id }
    }

    // MARK: - Stock adjustment (manual / stok awal)

    func adjustStock(sku: String, sizeId: UUID, qty: Int, reason: String, note: String?) async throws -> ProductSizeDetail {
        await delay()
        guard var list = _productSizes[sku],
              let idx = list.firstIndex(where: { $0.id == sizeId }) else {
            throw APIError.serverError(404, "Ukuran tidak ditemukan")
        }
        guard qty != 0 else {
            return list[idx]
        }
        let old = list[idx]
        let newCurrentStock = old.currentStockQty + qty
        guard newCurrentStock >= 0 else {
            throw APIError.serverError(400, "Stok tidak boleh kurang dari 0")
        }
        let newManualStock = max(0, old.manualStockQty + qty)
        let updated = ProductSizeDetail(id: old.id, productId: old.productId, productSku: old.productSku,
                                        productName: old.productName, sizeLabel: old.sizeLabel,
                                        fabricVariantName: old.fabricVariantName,
                                        reorderMinQty: old.reorderMinQty, isArchived: old.isArchived,
                                        currentStockQty: newCurrentStock,
                                        productionStockQty: old.productionStockQty,
                                        manualStockQty: newManualStock,
                                        latestHppBreakdown: old.latestHppBreakdown,
                                        sellingPrice: old.sellingPrice, marginPct: old.marginPct)
        list[idx] = updated
        _productSizes[sku] = list
        
        _ledgerEntries.append(StockAdjustmentLedgerEntry(
            id: UUID(),
            productSizeId: sizeId,
            changeQty: qty,
            reason: reason,
            createdAt: Date()
        ))
        
        return updated
    }

    // Creates product stock from existing bahan: adds manualStockQty and deducts fabric from purchases
    func addStockFromBahan(sku: String, sizeId: UUID, qty: Int, specId: UUID) async throws -> ProductSizeDetail {
        await delay()
        guard qty > 0 else { throw APIError.serverError(400, "Jumlah harus lebih dari 0") }
        guard var sizeList = _productSizes[sku],
              let sIdx = sizeList.firstIndex(where: { $0.id == sizeId }) else {
            throw APIError.serverError(404, "Ukuran tidak ditemukan")
        }
        guard let spec = _patternSpecs.first(where: { $0.id == specId }) else {
            throw APIError.serverError(404, "Resep tidak ditemukan")
        }
        let variantFabricName = sizeList[sIdx].fabricVariantName
        let fabric: PatternFabric
        if let variantName = variantFabricName,
           let matched = spec.fabrics.first(where: { f in
               _materials.first(where: { $0.id == f.materialId })?.name == variantName
           }) {
            fabric = matched
        } else if let first = spec.fabrics.first {
            fabric = first
        } else {
            throw APIError.serverError(404, "Resep tidak memiliki data kain")
        }
        let materialId   = fabric.materialId
        let cutL         = fabric.cutLengthCm
        let cutW         = fabric.cutWidthCm
        let rotAllowed   = fabric.rotationAllowed
        // Determine orientation from first available purchase width
        let purchaseWidth = (_purchases[materialId] ?? [])
            .first(where: { ($0.remainingLengthCm ?? 0) > 0 })?.widthCm ?? 150.0
        let normalCols = Int(purchaseWidth / cutW)
        let rotCols    = rotAllowed ? Int(purchaseWidth / cutL) : 0
        let finalCols  = max(max(normalCols, rotCols), 1)
        let finalRowH  = (rotCols > normalCols && rotCols > 0) ? cutW : cutL
        let rowsNeeded = Int(ceil(Double(qty) / Double(finalCols)))
        let totalFabricNeeded = Double(rowsNeeded) * finalRowH
        var fabricNeeded = totalFabricNeeded
        // FIFO deduction across purchases
        if var purchases = _purchases[materialId] {
            for i in 0..<purchases.count {
                guard fabricNeeded > 0 else { break }
                guard let remLen = purchases[i].remainingLengthCm, remLen > 0 else { continue }
                let deduct = min(remLen, fabricNeeded)
                let p = purchases[i]
                purchases[i] = MaterialPurchase(id: p.id, materialId: p.materialId,
                                                widthCm: p.widthCm, lengthCm: p.lengthCm,
                                                qty: p.qty, packageLabel: p.packageLabel,
                                                totalCost: p.totalCost, supplierId: p.supplierId,
                                                supplierName: p.supplierName, purchasedAt: p.purchasedAt,
                                                remainingLengthCm: max(0, remLen - deduct),
                                                createdAt: p.createdAt)
                fabricNeeded -= deduct
            }
            _purchases[materialId] = purchases
        }
        // Log usage entry for Pergerakan Stok display
        let old = sizeList[sIdx]
        var usageLog = _materialUsage[materialId] ?? []
        usageLog.append(MaterialUsageEntry(
            id: UUID(),
            materialId: materialId,
            deductedCm: totalFabricNeeded,
            description: "\(old.productName) · \(old.sizeLabel)\(old.fabricVariantName.map { " · \($0)" } ?? "") (\(qty) pcs, dari resep)",
            date: Date(),
            productSku: old.productSku
        ))
        _materialUsage[materialId] = usageLog
        let updated = ProductSizeDetail(id: old.id, productId: old.productId, productSku: old.productSku,
                                        productName: old.productName, sizeLabel: old.sizeLabel,
                                        fabricVariantName: old.fabricVariantName,
                                        reorderMinQty: old.reorderMinQty, isArchived: old.isArchived,
                                        currentStockQty: old.currentStockQty + qty,
                                        productionStockQty: old.productionStockQty,
                                        manualStockQty: old.manualStockQty + qty,
                                        latestHppBreakdown: old.latestHppBreakdown,
                                        sellingPrice: old.sellingPrice, marginPct: old.marginPct)
        sizeList[sIdx] = updated
        _productSizes[sku] = sizeList
        
        _ledgerEntries.append(StockAdjustmentLedgerEntry(
            id: UUID(),
            productSizeId: sizeId,
            changeQty: qty,
            reason: "initial",
            createdAt: Date()
        ))
        
        return updated
    }

    // Adds product stock and deducts fabric using manually-specified cutting dimensions (no spec required)
    func addStockManual(sku: String, sizeId: UUID, qty: Int, materialId: UUID, cutWidthCm: Double, cutLengthCm: Double) async throws -> ProductSizeDetail {
        await delay()
        guard qty > 0 else { throw APIError.serverError(400, "Jumlah harus lebih dari 0") }
        guard var sizeList = _productSizes[sku],
              let sIdx = sizeList.firstIndex(where: { $0.id == sizeId }) else {
            throw APIError.serverError(404, "Ukuran tidak ditemukan")
        }
        let old = sizeList[sIdx]
        let purchaseWidth = (_purchases[materialId] ?? [])
            .first(where: { ($0.remainingLengthCm ?? 0) > 0 })?.widthCm ?? 150.0
        let cols = max(Int(purchaseWidth / cutWidthCm), 1)
        let rowsNeeded = Int(ceil(Double(qty) / Double(cols)))
        let totalFabricNeeded = Double(rowsNeeded) * cutLengthCm
        var fabricNeeded = totalFabricNeeded
        if var purchases = _purchases[materialId] {
            for i in 0..<purchases.count {
                guard fabricNeeded > 0 else { break }
                guard let remLen = purchases[i].remainingLengthCm, remLen > 0 else { continue }
                let deduct = min(remLen, fabricNeeded)
                let p = purchases[i]
                purchases[i] = MaterialPurchase(id: p.id, materialId: p.materialId,
                                                widthCm: p.widthCm, lengthCm: p.lengthCm,
                                                qty: p.qty, packageLabel: p.packageLabel,
                                                totalCost: p.totalCost, supplierId: p.supplierId,
                                                supplierName: p.supplierName, purchasedAt: p.purchasedAt,
                                                remainingLengthCm: max(0, remLen - deduct),
                                                createdAt: p.createdAt)
                fabricNeeded -= deduct
            }
            _purchases[materialId] = purchases
        }
        // Always log the usage event regardless of whether purchases existed
        let actualDeducted = totalFabricNeeded - max(0, fabricNeeded)
        var usageLog = _materialUsage[materialId] ?? []
        usageLog.append(MaterialUsageEntry(
            id: UUID(),
            materialId: materialId,
            deductedCm: totalFabricNeeded,
            description: "\(old.productName) · \(old.sizeLabel)\(old.fabricVariantName.map { " · \($0)" } ?? "") (\(qty) pcs)",
            date: Date(),
            productSku: old.productSku
        ))
        _ = actualDeducted  // captured for future use; logged amount is planned usage
        _materialUsage[materialId] = usageLog
        let updated = ProductSizeDetail(id: old.id, productId: old.productId, productSku: old.productSku,
                                        productName: old.productName, sizeLabel: old.sizeLabel,
                                        fabricVariantName: old.fabricVariantName,
                                        reorderMinQty: old.reorderMinQty, isArchived: old.isArchived,
                                        currentStockQty: old.currentStockQty + qty,
                                        productionStockQty: old.productionStockQty,
                                        manualStockQty: old.manualStockQty + qty,
                                        latestHppBreakdown: old.latestHppBreakdown,
                                        sellingPrice: old.sellingPrice, marginPct: old.marginPct)
        sizeList[sIdx] = updated
        _productSizes[sku] = sizeList
        
        _ledgerEntries.append(StockAdjustmentLedgerEntry(
            id: UUID(),
            productSizeId: sizeId,
            changeQty: qty,
            reason: "initial",
            createdAt: Date()
        ))
        
        return updated
    }

    func getMaterialUsage(materialId: UUID) async throws -> [MaterialUsageEntry] {
        await delay()
        return (_materialUsage[materialId] ?? []).sorted { $0.date > $1.date }
    }

    func getFabricFamilies() async throws -> [String] {
        await delay()
        let families = _materials.compactMap { $0.fabricFamily }
        return Array(Set(families)).sorted()
    }

    // MARK: - Sales

    func getSalesOrders() async throws -> [SalesOrder] {
        await delay()
        return _salesOrders.sorted { $0.soldAt > $1.soldAt }
    }

    func getSalesOrder(id: UUID) async throws -> SalesOrder {
        await delay()
        guard let o = _salesOrders.first(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Order tidak ditemukan")
        }
        return o
    }

    func createSalesOrder(_ req: CreateSalesOrderRequest) async throws -> SalesOrder {
        await delay()
        let invoiceNo = "INV-2026-\(String(format: "%03d", _salesOrders.count + 1))"
        let items = req.items.map { item in
            let sizeDetail = _productSizes.values.flatMap({ $0 }).first(where: { $0.id == item.productSizeId })
            let hpp = sizeDetail?.latestHppBreakdown?.total ?? 0
            let effectivePrice = item.unitPrice - (item.discount ?? 0)
            let profit = (effectivePrice - hpp) * Double(item.qty)
            return SalesOrderItem(id: UUID(), productSizeId: item.productSizeId,
                                  salesOrderId: UUID(),
                                  productName: sizeDetail?.productName,
                                  sizeLabel: sizeDetail?.sizeLabel,
                                  qty: item.qty, unitPrice: item.unitPrice,
                                  discount: item.discount ?? 0,
                                  unitHppSnapshot: hpp, lineProfit: profit)
        }
        let total = items.reduce(0.0) { $0 + ($1.unitPrice - $1.discount) * Double($1.qty) }
        let profit = items.reduce(0.0) { $0 + $1.lineProfit }
        let order = SalesOrder(id: UUID(), invoiceNo: invoiceNo,
                               customerName: req.customerName,
                               paymentMethod: req.paymentMethod,
                               marketplaceFeePct: req.marketplaceFeePct ?? 0,
                               status: "unpaid", soldAt: Date(),
                               items: items, totalRevenue: total, totalProfit: profit)
        _salesOrders.insert(order, at: 0)
        return order
    }

    func markSalesOrderPaid(id: UUID) async throws -> SalesOrder {
        await delay()
        guard let idx = _salesOrders.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Order tidak ditemukan")
        }
        let old = _salesOrders[idx]
        let updated = SalesOrder(id: old.id, invoiceNo: old.invoiceNo, customerName: old.customerName,
                                 paymentMethod: old.paymentMethod, marketplaceFeePct: old.marketplaceFeePct,
                                 status: "paid", soldAt: old.soldAt, items: old.items,
                                 totalRevenue: old.totalRevenue, totalProfit: old.totalProfit)
        _salesOrders[idx] = updated
        return updated
    }

    func cancelSalesOrder(id: UUID, reason: String? = nil) async throws -> SalesOrder {
        await delay()
        guard let idx = _salesOrders.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Order tidak ditemukan")
        }
        let old = _salesOrders[idx]

        // Restore finished-goods stock for each cancelled item
        for item in old.items {
            for sku in _productSizes.keys {
                guard let sizeIdx = _productSizes[sku]?.firstIndex(where: { $0.id == item.productSizeId }) else { continue }
                let d = _productSizes[sku]![sizeIdx]
                _productSizes[sku]![sizeIdx] = ProductSizeDetail(
                    id: d.id, productId: d.productId, productSku: d.productSku,
                    productName: d.productName, sizeLabel: d.sizeLabel,
                    fabricVariantName: d.fabricVariantName,
                    reorderMinQty: d.reorderMinQty, isArchived: d.isArchived,
                    currentStockQty: d.currentStockQty + item.qty,
                    productionStockQty: d.productionStockQty, manualStockQty: d.manualStockQty,
                    latestHppBreakdown: d.latestHppBreakdown,
                    sellingPrice: d.sellingPrice, marginPct: d.marginPct)
                break
            }
        }

        let updated = SalesOrder(id: old.id, invoiceNo: old.invoiceNo, customerName: old.customerName,
                                 paymentMethod: old.paymentMethod, marketplaceFeePct: old.marketplaceFeePct,
                                 status: "cancelled", soldAt: old.soldAt, items: old.items,
                                 totalRevenue: old.totalRevenue, totalProfit: old.totalProfit)
        _salesOrders[idx] = updated
        return updated
    }

    func updateSalesOrder(id: UUID, customerName: String?, paymentMethod: String) async throws -> SalesOrder {
        await delay()
        guard let idx = _salesOrders.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Order tidak ditemukan")
        }
        let old = _salesOrders[idx]
        let updated = SalesOrder(id: old.id, invoiceNo: old.invoiceNo, customerName: customerName,
                                 paymentMethod: paymentMethod, marketplaceFeePct: old.marketplaceFeePct,
                                 status: old.status, soldAt: old.soldAt, items: old.items,
                                 totalRevenue: old.totalRevenue, totalProfit: old.totalProfit)
        _salesOrders[idx] = updated
        return updated
    }

    func deleteSalesOrder(id: UUID) async throws {
        await delay()
        guard let idx = _salesOrders.firstIndex(where: { $0.id == id }) else {
            throw APIError.serverError(404, "Order tidak ditemukan")
        }
        let old = _salesOrders[idx]
        if !old.isCancelled {
            for item in old.items {
                for sku in _productSizes.keys {
                    guard let sizeIdx = _productSizes[sku]?.firstIndex(where: { $0.id == item.productSizeId }) else { continue }
                    let d = _productSizes[sku]![sizeIdx]
                    _productSizes[sku]![sizeIdx] = ProductSizeDetail(
                        id: d.id, productId: d.productId, productSku: d.productSku,
                        productName: d.productName, sizeLabel: d.sizeLabel,
                        fabricVariantName: d.fabricVariantName,
                        reorderMinQty: d.reorderMinQty, isArchived: d.isArchived,
                        currentStockQty: d.currentStockQty + item.qty,
                        productionStockQty: d.productionStockQty, manualStockQty: d.manualStockQty,
                        latestHppBreakdown: d.latestHppBreakdown,
                        sellingPrice: d.sellingPrice, marginPct: d.marginPct)
                    break
                }
            }
        }
        _salesOrders.remove(at: idx)
    }

    // MARK: - Reports

    func getDashboard() async throws -> DashboardSummary {
        await delay()
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let todayOrders = _salesOrders.filter { cal.isDateInToday($0.soldAt) }
        let monthOrders = _salesOrders.filter { $0.soldAt >= startOfMonth }
        let todayRevenue = todayOrders.reduce(0.0) { $0 + $1.displayRevenue }
        let todayProfit = todayOrders.reduce(0.0) { $0 + $1.displayProfit }
        let todayUnits = todayOrders.flatMap { $0.items }.reduce(0) { $0 + $1.qty }
        let monthRevenue = monthOrders.reduce(0.0) { $0 + $1.displayRevenue }
        let monthUnits = monthOrders.flatMap { $0.items }.reduce(0) { $0 + $1.qty }
        let allSizes = _productSizes.values.flatMap { $0 }
        let avgMargin = allSizes.compactMap { $0.marginPct }.reduce(0.0, +) / Double(max(1, allSizes.compactMap { $0.marginPct }.count))
        let alerts = try await getLowStock()
        return DashboardSummary(todayRevenue: todayRevenue, todayProfit: todayProfit,
                                todayOrderCount: todayOrders.count, todayUnitsSold: todayUnits,
                                monthRevenue: monthRevenue, monthOrders: monthOrders.count,
                                monthUnitsSold: monthUnits, monthBatchesConfirmed: 1,
                                avgMarginPct: avgMargin, lowStockAlerts: alerts)
    }

    func getSalesReport(from: Date, to: Date, groupBy: String) async throws -> SalesReport {
        await delay()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "dd MMM"

        let startDay = cal.startOfDay(for: from)
        let endDay   = cal.startOfDay(for: to)
        let totalDays = max(0, cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0)

        // Aggregate real orders by calendar day
        var revenueByDay: [Date: Double] = [:]
        var profitByDay:  [Date: Double] = [:]
        var countByDay:   [Date: Int]    = [:]
        var unitsByDay:   [Date: Int]    = [:]
        for order in _salesOrders where order.status != "cancelled" {
            let day = cal.startOfDay(for: order.soldAt)
            guard day >= startDay && day <= endDay else { continue }
            revenueByDay[day, default: 0] += order.displayRevenue
            profitByDay[day,  default: 0] += order.displayProfit
            countByDay[day,   default: 0] += 1
            let totalQty = order.items.reduce(0) { $0 + $1.qty }
            unitsByDay[day, default: 0] += totalQty
        }

        var points: [SalesReportPoint] = []
        for i in 0...totalDays {
            guard let d = cal.date(byAdding: .day, value: i, to: startDay) else { continue }
            let rev   = revenueByDay[d] ?? 0
            let prf   = profitByDay[d]  ?? 0
            let count = countByDay[d]   ?? 0
            let units = unitsByDay[d]   ?? 0
            guard rev > 0 || count > 0 else { continue }
            points.append(SalesReportPoint(period: fmt.string(from: d),
                                           totalRevenue: rev, totalProfit: prf, orderCount: count, unitsSold: units))
        }

        let total  = points.reduce(0.0) { $0 + $1.totalRevenue }
        let profit = points.reduce(0.0) { $0 + $1.totalProfit }
        return SalesReport(points: points, totalRevenue: total, totalProfit: profit)
    }

    func getSalesByProduct(from: Date, to: Date) async throws -> [SalesByProductItem] {
        await delay()
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: from)
        let endDay   = cal.startOfDay(for: to)

        var buckets: [UUID: (qty: Int, revenue: Double, profit: Double)] = [:]
        for order in _salesOrders where order.status != "cancelled" {
            let day = cal.startOfDay(for: order.soldAt)
            guard day >= startDay && day <= endDay else { continue }
            for item in order.items {
                var b = buckets[item.productSizeId] ?? (0, 0, 0)
                b.qty += item.qty
                b.revenue += item.lineRevenue
                b.profit += item.lineProfit
                buckets[item.productSizeId] = b
            }
        }

        let sizeMap = Dictionary(uniqueKeysWithValues: _productSizes.values.flatMap { $0 }.map { ($0.id, $0) })
        return buckets.map { productSizeId, val -> SalesByProductItem in
            let detail = sizeMap[productSizeId]
            return SalesByProductItem(productSizeId: productSizeId,
                                      productName: detail?.productName ?? "Produk",
                                      sizeLabel: detail?.sizeLabel ?? "-",
                                      fabricVariantName: detail?.fabricVariantName,
                                      qtySold: val.qty, revenue: val.revenue, profit: val.profit,
                                      currentStockQty: detail?.currentStockQty ?? 0)
        }.sorted { $0.revenue > $1.revenue }
    }

    func getMarginRanking() async throws -> [MarginRankingItem] {
        await delay()
        return _productSizes.values.flatMap({ $0 }).compactMap { detail -> MarginRankingItem? in
            guard let hpp = detail.latestHppBreakdown?.total,
                  let price = detail.sellingPrice,
                  let margin = detail.marginPct else { return nil }
            return MarginRankingItem(productSizeId: detail.id,
                                     productName: detail.productName, sizeLabel: detail.sizeLabel,
                                     fabricVariantName: detail.fabricVariantName,
                                     hpp: hpp, sellingPrice: price, marginPct: margin)
        }.sorted { $0.marginPct > $1.marginPct }
    }

    func getStockCard(productSizeId: UUID) async throws -> StockCard {
        await delay()
        let detail = _productSizes.values.flatMap({ $0 }).first(where: { $0.id == productSizeId })
        let entries = (0..<8).map { i -> StockCardEntry in
            let reasons = ["production", "sale", "sale", "production", "sale"]
            let reason = reasons[i % reasons.count]
            return StockCardEntry(id: UUID(), changeQty: reason == "production" ? Int.random(in: 20...50) : -Int.random(in: 1...5),
                                  reason: reason, refType: nil, unitHppSnapshot: detail?.latestHppBreakdown?.total,
                                  createdAt: ago(days: i * 3))
        }
        return StockCard(productSizeId: productSizeId,
                         productName: detail?.productName ?? "",
                         sizeLabel: detail?.sizeLabel ?? "",
                         currentQty: detail?.currentStockQty ?? 0,
                         entries: entries)
    }

    func getWasteByMaterial(from: Date, to: Date) async throws -> [WasteByMaterial] {
        await delay()
        return _materials.filter { $0.category == .fabric }.map { mat in
            WasteByMaterial(materialId: mat.id, materialName: mat.name,
                            avgWastePct: Double.random(in: 8...25),
                            totalWasteAreaCm2: Double.random(in: 500...5000))
        }
    }

    func getLowStock() async throws -> [LowStockAlert] {
        await delay()
        return _productSizes.values.flatMap({ $0 }).compactMap { detail -> LowStockAlert? in
            guard let min = detail.reorderMinQty,
                  Double(detail.currentStockQty) < min else { return nil }
            return LowStockAlert(productSizeId: detail.id,
                                 productName: detail.productName, sizeLabel: detail.sizeLabel,
                                 currentStockQty: detail.currentStockQty, reorderMinQty: min)
        }
    }

    // MARK: - Settings

    func getSettings() async throws -> [SettingItem] {
        await delay()
        return _settings
    }

    func patchSetting(key: String, value: Double) async throws -> SettingItem {
        await delay()
        if let idx = _settings.firstIndex(where: { $0.key == key }) {
            let updated = SettingItem(key: key, value: value, updatedAt: Date())
            _settings[idx] = updated
            return updated
        }
        let new = SettingItem(key: key, value: value, updatedAt: Date())
        _settings.append(new)
        return new
    }
}


