import Foundation

enum MaterialCategory: String, Codable, CaseIterable, Hashable {
    case fabric = "fabric"
    case thread = "thread"
    case hardware = "hardware"
    case packaging = "packaging"

    var displayName: String {
        switch self {
        case .fabric:    return "Kain"
        case .thread:    return "Benang (pooled)"
        case .hardware:  return "Hardware"
        case .packaging: return "Packaging"
        }
    }

    var defaultPurchaseUnit: String {
        switch self {
        case .fabric:    return "meter"
        case .thread:    return "roll"
        case .hardware:  return "pcs"
        case .packaging: return "pack"
        }
    }

    var defaultUsageUnit: String {
        switch self {
        case .fabric:    return "cm"
        case .thread:    return "cm2"
        case .hardware:  return "pcs"
        case .packaging: return "pcs"
        }
    }

    var defaultCostClass: String {
        switch self {
        case .fabric:    return "direct_precise"
        case .hardware:  return "direct_precise"
        case .thread:    return "direct_pooled"
        case .packaging: return "direct_pooled"
        }
    }
}

enum StockStatus {
    case ok, low, critical

    var color: String {
        switch self {
        case .ok:       return "green"
        case .low:      return "orange"
        case .critical: return "red"
        }
    }

    var label: String {
        switch self {
        case .ok:       return "Aman"
        case .low:      return "Menipis"
        case .critical: return "Rendah"
        }
    }
}

struct Material: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: MaterialCategory
    let costClass: String
    let purchaseUnit: String
    let usageUnit: String
    let fabricWidthCm: Double?
    let currentAvgCost: Double
    let reorderMinQty: Double?
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    // Server-computed aggregate; nil means not loaded yet
    var currentTotalQty: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case costClass = "cost_class"
        case purchaseUnit = "purchase_unit"
        case usageUnit = "usage_unit"
        case fabricWidthCm = "fabric_width_cm"
        case currentAvgCost = "current_avg_cost"
        case reorderMinQty = "reorder_min_qty"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case currentTotalQty = "current_total_qty"
    }

    func stockStatus(currentStock: Double) -> StockStatus {
        guard let min = reorderMinQty else { return .ok }
        if currentStock <= 0 { return .critical }
        if currentStock < min { return .low }
        return .ok
    }
}

struct MaterialPurchase: Codable, Identifiable {
    let id: UUID
    let materialId: UUID
    let widthCm: Double?
    let lengthCm: Double?
    let qty: Double?
    let packageLabel: String?
    let totalCost: Double
    let supplierId: UUID?
    let supplierName: String?
    let purchasedAt: Date
    let remainingLengthCm: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case materialId = "material_id"
        case widthCm = "width_cm"
        case lengthCm = "length_cm"
        case qty
        case packageLabel = "package_label"
        case totalCost = "total_cost"
        case supplierId = "supplier_id"
        case supplierName = "supplier_name"
        case purchasedAt = "purchased_at"
        case remainingLengthCm = "remaining_length_cm"
        case createdAt = "created_at"
    }

    var isConsumed: Bool {
        if let remaining = remainingLengthCm, let length = lengthCm {
            return remaining < length
        }
        return false
    }

    var isFullyConsumed: Bool {
        if let remaining = remainingLengthCm { return remaining <= 0 }
        return false
    }

    var isPartiallyConsumed: Bool { isConsumed && !isFullyConsumed }

    var unitCost: Double {
        if let length = lengthCm, let width = widthCm, length > 0, width > 0 {
            return totalCost / length
        }
        if let q = qty, q > 0 {
            return totalCost / q
        }
        return totalCost
    }
}

struct MaterialUsageEntry: Identifiable {
    let id: UUID
    let materialId: UUID
    let deductedCm: Double
    let description: String
    let date: Date
    var productSku: String? = nil
}

struct CreateMaterialRequest: Codable {
    let name: String
    let category: String
    let costClass: String
    let purchaseUnit: String
    let usageUnit: String
    let fabricWidthCm: Double?

    enum CodingKeys: String, CodingKey {
        case name, category
        case costClass = "cost_class"
        case purchaseUnit = "purchase_unit"
        case usageUnit = "usage_unit"
        case fabricWidthCm = "fabric_width_cm"
    }
}

struct PatchMaterialRequest: Codable {
    let name: String?
    let reorderMinQty: Double?
    let isArchived: Bool?
    let fabricWidthCm: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case reorderMinQty = "reorder_min_qty"
        case isArchived = "is_archived"
        case fabricWidthCm = "fabric_width_cm"
    }
}

struct CreatePurchaseRequest: Codable {
    let widthCm: Double?
    let lengthCm: Double?
    let qty: Double?
    let packageLabel: String?
    let totalCost: Double
    let supplierId: UUID?
    let supplierName: String?
    let purchasedAt: String

    enum CodingKeys: String, CodingKey {
        case widthCm = "width_cm"
        case lengthCm = "length_cm"
        case qty
        case packageLabel = "package_label"
        case totalCost = "total_cost"
        case supplierId = "supplier_id"
        case supplierName = "supplier_name"
        case purchasedAt = "purchased_at"
    }
}

struct PatchPurchaseRequest: Codable {
    let widthCm: Double?
    let lengthCm: Double?
    let qty: Double?
    let totalCost: Double?
    let supplierId: UUID?
    let supplierName: String?
    let purchasedAt: String?

    enum CodingKeys: String, CodingKey {
        case widthCm = "width_cm"
        case lengthCm = "length_cm"
        case qty
        case totalCost = "total_cost"
        case supplierId = "supplier_id"
        case supplierName = "supplier_name"
        case purchasedAt = "purchased_at"
    }
}
