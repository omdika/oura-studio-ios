import Foundation

// MARK: - Stock Opname Session

struct StockOpnameSession: Codable, Identifiable, Hashable {
    let id: UUID
    let status: String
    let startedAt: Date
    let completedAt: Date?
    let note: String?
    let totalVarianceValue: Double
    let itemCount: Int
    let createdAt: Date
    var items: [StockOpnameItem]?

    enum CodingKeys: String, CodingKey {
        case id, status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case note
        case totalVarianceValue = "total_variance_value"
        case itemCount = "item_count"
        case createdAt = "created_at"
        case items
    }

    var statusLabel: String {
        switch status {
        case "completed": return "Selesai"
        case "cancelled": return "Dibatalkan"
        case "in_progress": return "Sedang Berlangsung"
        default: return "Draft"
        }
    }
}

// MARK: - Stock Opname Item

struct StockOpnameItem: Codable, Identifiable, Hashable {
    let id: UUID
    let sessionId: UUID
    let productSizeId: UUID
    let scannedQty: Double
    let systemStockQtySnapshot: Double
    let varianceQty: Double
    let note: String?
    let createdAt: Date

    // Enrichment (diisi oleh backend di endpoint detail)
    let productSku: String?
    let productName: String?
    let sizeLabel: String?
    let fabricVariantName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case productSizeId = "product_size_id"
        case scannedQty = "scanned_qty"
        case systemStockQtySnapshot = "system_stock_qty_snapshot"
        case varianceQty = "variance_qty"
        case note
        case createdAt = "created_at"
        case productSku = "product_sku"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case fabricVariantName = "fabric_variant_name"
    }

    var displayLabel: String {
        guard let fabric = fabricVariantName, !fabric.isEmpty else { return sizeLabel ?? "-" }
        return "\(sizeLabel ?? "-") · \(fabric)"
    }
}

// MARK: - Request / Response bodies

struct CreateStockOpnameSessionRequest: Codable {
    let note: String?
}

struct AddStockOpnameItemRequest: Codable {
    let productSizeId: UUID
    let scannedQty: Double?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case scannedQty = "scanned_qty"
        case note
    }
}

struct UpdateStockOpnameItemRequest: Codable {
    let scannedQty: Double?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case scannedQty = "scanned_qty"
        case note
    }
}

struct CompleteStockOpnameResponse: Codable {
    let sessionId: UUID
    let status: String
    let completedAt: Date
    let totalVarianceValue: Double
    let adjustmentsWritten: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case completedAt = "completed_at"
        case totalVarianceValue = "total_variance_value"
        case adjustmentsWritten = "adjustments_written"
    }
}
