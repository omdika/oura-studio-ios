import Foundation

struct SalesReportPoint: Codable, Identifiable {
    let period: String
    let totalRevenue: Double
    let totalProfit: Double
    let orderCount: Int

    var id: String { period }

    enum CodingKeys: String, CodingKey {
        case period = "date"
        case totalRevenue
        case totalProfit
        case orderCount
    }
}

struct SalesReport: Codable {
    let points: [SalesReportPoint]
    let totalRevenue: Double
    let totalProfit: Double
}

struct SalesByProductItem: Codable, Identifiable {
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let fabricVariantName: String?
    let qtySold: Int
    let revenue: Double
    let profit: Double

    var id: UUID { productSizeId }

    var displayLabel: String {
        guard let fabric = fabricVariantName else { return "\(productName) · \(sizeLabel)" }
        return "\(productName) · \(sizeLabel) · \(fabric)"
    }

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case fabricVariantName = "fabric_variant_name"
        case qtySold = "qty_sold"
        case revenue
        case profit
    }
}

struct MarginRankingItem: Codable, Identifiable {
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let fabricVariantName: String?
    let hpp: Double
    let sellingPrice: Double
    let marginPct: Double

    var id: UUID { productSizeId }

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case fabricVariantName = "fabric_variant_name"
        case hpp = "hpp_total"
        case sellingPrice = "selling_price"
        case marginPct = "margin_pct"
    }
}

struct StockCardEntry: Codable, Identifiable {
    let id: UUID
    let changeQty: Int
    let reason: String
    let refType: String?
    let unitHppSnapshot: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case changeQty = "change_qty"
        case reason
        case refType = "ref_type"
        case unitHppSnapshot = "unit_hpp_snapshot"
        case createdAt = "created_at"
    }

    var reasonDisplay: String {
        switch reason {
        case "production": return "Produksi"
        case "sale":       return "Penjualan"
        case "adjustment": return "Penyesuaian"
        case "damage":     return "Kerusakan"
        case "return":     return "Retur"
        default:           return reason.capitalized
        }
    }
}

struct StockCard: Codable {
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let currentQty: Int
    let entries: [StockCardEntry]

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case currentQty = "current_qty"
        case entries
    }
}

struct WasteByMaterial: Codable, Identifiable {
    let materialId: UUID
    let materialName: String
    let avgWastePct: Double
    let totalWasteAreaCm2: Double

    var id: UUID { materialId }

    enum CodingKeys: String, CodingKey {
        case materialId = "material_id"
        case materialName = "material_name"
        case avgWastePct = "avg_waste_pct"
        case totalWasteAreaCm2 = "total_waste_area_cm2"
    }
}

struct LowStockAlert: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let currentStockQty: Int
    let reorderMinQty: Double

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case currentStockQty = "current_stock_qty"
        case reorderMinQty = "reorder_min_qty"
    }
}

struct DashboardSummary: Codable {
    let todayRevenue: Double
    let todayProfit: Double
    let todayOrderCount: Int
    let todayUnitsSold: Int
    // Backend may omit month-level stats — treated as optional until implemented
    let monthRevenue: Double?
    let monthOrders: Int?
    let monthUnitsSold: Int?
    let monthBatchesConfirmed: Int?
    let avgMarginPct: Double?
    let lowStockAlerts: [LowStockAlert]

    enum CodingKeys: String, CodingKey {
        case todayRevenue = "today_revenue"
        case todayProfit = "today_profit"
        case todayOrderCount = "today_order_count"
        case todayUnitsSold = "today_units_sold"
        case monthRevenue = "month_revenue"
        case monthOrders = "month_orders"
        case monthUnitsSold = "month_units_sold"
        case monthBatchesConfirmed = "month_batches_confirmed"
        case avgMarginPct = "avg_margin_pct"
        case lowStockAlerts = "low_stock_alerts"
    }
}
