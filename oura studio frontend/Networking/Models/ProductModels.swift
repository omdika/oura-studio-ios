import Foundation

struct Product: Codable, Identifiable, Hashable {
    let id: UUID
    let sku: String
    let name: String
    let isArchived: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sku, name
        case isArchived = "is_archived"
        case createdAt = "created_at"
    }
}

struct ProductSize: Codable, Identifiable, Hashable {
    let id: UUID
    let productId: UUID
    let sizeLabel: String
    let reorderMinQty: Double?
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case sizeLabel = "size_label"
        case reorderMinQty = "reorder_min_qty"
        case isArchived = "is_archived"
    }
}

// Matches the flat list response from GET /products/{sku}/sizes
struct ProductSizeBasic: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let sizeLabel: String
    let fabricVariantName: String?
    let reorderMinQty: Double?
    let sellingPrice: Double?
    let isArchived: Bool
    let currentStockQty: Int
    let productionStockQty: Int?
    let manualStockQty: Int?
    let latestHppBreakdown: HPPBreakdown?
    let marginPct: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case productId           = "product_id"
        case sizeLabel           = "size_label"
        case fabricVariantName   = "fabric_variant_name"
        case reorderMinQty       = "reorder_min_qty"
        case sellingPrice        = "selling_price"
        case isArchived          = "is_archived"
        case currentStockQty     = "current_stock_qty"
        case productionStockQty  = "production_stock_qty"
        case manualStockQty      = "manual_stock_qty"
        case latestHppBreakdown  = "latest_hpp_breakdown"
        case marginPct           = "margin_pct"
    }
}

struct HPPLineItem: Codable {
    let name: String
    let cost: Double
}

struct HPPBreakdown: Codable {
    let fabric: Double
    let fabricItems: [HPPLineItem]
    let pooledMaterial: Double
    let hardware: Double
    let hardwareItems: [HPPLineItem]
    let labor: Double
    let overhead: Double
    let total: Double

    enum CodingKeys: String, CodingKey {
        case fabric
        case fabricItems    = "fabric_items"
        case pooledMaterial = "pooled_material"
        case hardware
        case hardwareItems  = "hardware_items"
        case labor, overhead, total
    }

    init(fabric: Double, fabricItems: [HPPLineItem] = [], pooledMaterial: Double,
         hardware: Double, hardwareItems: [HPPLineItem] = [],
         labor: Double, overhead: Double, total: Double) {
        self.fabric = fabric; self.fabricItems = fabricItems
        self.pooledMaterial = pooledMaterial
        self.hardware = hardware; self.hardwareItems = hardwareItems
        self.labor = labor; self.overhead = overhead; self.total = total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fabric         = try c.decode(Double.self, forKey: .fabric)
        fabricItems    = (try? c.decodeIfPresent([HPPLineItem].self, forKey: .fabricItems)) ?? []
        pooledMaterial = try c.decode(Double.self, forKey: .pooledMaterial)
        hardware       = try c.decode(Double.self, forKey: .hardware)
        hardwareItems  = (try? c.decodeIfPresent([HPPLineItem].self, forKey: .hardwareItems)) ?? []
        labor          = try c.decode(Double.self, forKey: .labor)
        overhead       = try c.decode(Double.self, forKey: .overhead)
        total          = try c.decode(Double.self, forKey: .total)
    }
}

struct ProductSizeDetail: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let productSku: String
    let productName: String
    let sizeLabel: String
    let fabricVariantName: String?
    let reorderMinQty: Double?
    let isArchived: Bool
    let currentStockQty: Int
    // Stock breakdown by source — production = from confirmBatch; manual = from adjustStock
    let productionStockQty: Int
    let manualStockQty: Int
    let latestHppBreakdown: HPPBreakdown?
    let sellingPrice: Double?
    let marginPct: Double?
    // Manual HPP fields — filled when product bypasses batch production flow
    var manualHppFabric: Double?
    var manualHppPooled: Double?
    var manualHppHardware: Double?
    var manualHppLabor: Double?
    var manualHppOverhead: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case productSku = "product_sku"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case fabricVariantName = "fabric_variant_name"
        case reorderMinQty = "reorder_min_qty"
        case isArchived = "is_archived"
        case currentStockQty = "current_stock_qty"
        case productionStockQty = "production_stock_qty"
        case manualStockQty = "manual_stock_qty"
        case latestHppBreakdown = "latest_hpp_breakdown"
        case sellingPrice = "selling_price"
        case marginPct = "margin_pct"
        case manualHppFabric   = "manual_hpp_fabric"
        case manualHppPooled   = "manual_hpp_pooled"
        case manualHppHardware = "manual_hpp_hardware"
        case manualHppLabor    = "manual_hpp_labor"
        case manualHppOverhead = "manual_hpp_overhead"
    }

    var displayLabel: String {
        guard let fabric = fabricVariantName else { return sizeLabel }
        return "\(sizeLabel) · \(fabric)"
    }

    var isLowStock: Bool {
        guard let min = reorderMinQty else { return false }
        return Double(currentStockQty) < min
    }

    var markupPct: Double? {
        guard let margin = marginPct else { return nil }
        guard margin < 1.0 else { return nil }
        return margin / (1 - margin)
    }

    var manualHppBreakdown: HPPBreakdown? {
        let total = (manualHppFabric ?? 0) + (manualHppPooled ?? 0)
                  + (manualHppHardware ?? 0) + (manualHppLabor ?? 0) + (manualHppOverhead ?? 0)
        guard total > 0 else { return nil }
        return HPPBreakdown(fabric: manualHppFabric ?? 0,
                            pooledMaterial: manualHppPooled ?? 0,
                            hardware: manualHppHardware ?? 0,
                            labor: manualHppLabor ?? 0,
                            overhead: manualHppOverhead ?? 0,
                            total: total)
    }

    // Batch HPP first, manual HPP as fallback
    var effectiveHppBreakdown: HPPBreakdown? {
        latestHppBreakdown ?? manualHppBreakdown
    }
}

struct PriceAdvisorRequest: Codable {
    let targetMarginPct: Double
    let marketplaceFeePct: Double?
    let promoAllocationPct: Double?

    enum CodingKeys: String, CodingKey {
        case targetMarginPct = "target_margin_pct"
        case marketplaceFeePct = "marketplace_fee_pct"
        case promoAllocationPct = "promo_allocation_pct"
    }
}

struct PriceAdvisorResponse: Codable {
    let suggestedPrice: Double
    let resultingMarginPct: Double
    let resultingMarkupPct: Double

    enum CodingKeys: String, CodingKey {
        case suggestedPrice = "suggested_price"
        case resultingMarginPct = "resulting_margin_pct"
        case resultingMarkupPct = "resulting_markup_pct"
    }
}

struct PatchProductSizeRequest: Codable {
    let sellingPrice: Double?
    let reorderMinQty: Double?
    let isArchived: Bool?
    let manualHppFabric: Double?
    let manualHppPooled: Double?
    let manualHppHardware: Double?
    let manualHppLabor: Double?
    let manualHppOverhead: Double?

    init(sellingPrice: Double? = nil, reorderMinQty: Double? = nil, isArchived: Bool? = nil,
         manualHppFabric: Double? = nil, manualHppPooled: Double? = nil,
         manualHppHardware: Double? = nil, manualHppLabor: Double? = nil,
         manualHppOverhead: Double? = nil) {
        self.sellingPrice = sellingPrice
        self.reorderMinQty = reorderMinQty
        self.isArchived = isArchived
        self.manualHppFabric   = manualHppFabric
        self.manualHppPooled   = manualHppPooled
        self.manualHppHardware = manualHppHardware
        self.manualHppLabor    = manualHppLabor
        self.manualHppOverhead = manualHppOverhead
    }

    enum CodingKeys: String, CodingKey {
        case sellingPrice      = "selling_price"
        case reorderMinQty     = "reorder_min_qty"
        case isArchived        = "is_archived"
        case manualHppFabric   = "manual_hpp_fabric"
        case manualHppPooled   = "manual_hpp_pooled"
        case manualHppHardware = "manual_hpp_hardware"
        case manualHppLabor    = "manual_hpp_labor"
        case manualHppOverhead = "manual_hpp_overhead"
    }
}

struct CreateProductRequest: Codable {
    let name: String
    let sku: String?
}

struct PatchProductRequest: Codable {
    let name: String
}

// Used for soft-archiving a product — backend requires name alongside is_archived
struct ArchiveProductRequest: Encodable {
    let name: String
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isArchived = "is_archived"
    }
}

struct CreateProductSizeRequest: Codable {
    let sizeLabel: String
    let fabricVariantName: String?
    let reorderMinQty: Double?

    enum CodingKeys: String, CodingKey {
        case sizeLabel = "size_label"
        case fabricVariantName = "fabric_variant_name"
        case reorderMinQty = "reorder_min_qty"
    }
}

struct StockAdjustmentRequest: Codable {
    let productSizeId: UUID
    let changeQty: Int
    let reason: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case changeQty = "change_qty"
        case reason
        case note
    }
}

struct StockAdjustmentLedgerEntry: Codable {
    let id: UUID
    let productSizeId: UUID
    let changeQty: Int
    let reason: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId = "product_size_id"
        case changeQty = "change_qty"
        case reason
        case createdAt = "created_at"
    }
}
