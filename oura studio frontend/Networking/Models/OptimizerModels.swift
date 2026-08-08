import Foundation

enum OptimizerStrategy: String, Codable, CaseIterable {
    case maxQty = "max_qty"
    case minWaste = "min_waste"
    case maxProfit = "max_profit"

    var displayName: String {
        switch self {
        case .maxQty:    return "Max Qty"
        case .minWaste:  return "Waste Minimum"
        case .maxProfit: return "Max Profit"
        }
    }
}

struct OptimizerCandidate: Codable {
    let productSizeId: UUID
    let patternSpecId: UUID
    let minQty: Int?

    enum CodingKeys: String, CodingKey {
        case productSizeId = "product_size_id"
        case patternSpecId = "pattern_spec_id"
        case minQty = "min_qty"
    }
}

struct SuggestOptimizerRequest: Codable {
    let materialPurchaseId: UUID
    let candidates: [OptimizerCandidate]

    enum CodingKeys: String, CodingKey {
        case materialPurchaseId = "material_purchase_id"
        case candidates
    }
}

struct OptimizerLayoutItem: Codable, Identifiable, Hashable {
    let id: UUID
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let patternSpecId: UUID
    let orientation: String
    let qtySuggested: Int
    let fabricLengthUsedCm: Double
    let costPerPiece: Double

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case patternSpecId = "pattern_spec_id"
        case orientation
        case qtySuggested = "qty_suggested"
        case fabricLengthUsedCm = "fabric_length_used_cm"
        case costPerPiece = "cost_per_piece"
    }
}

struct OptimizerLayout: Codable, Identifiable {
    let id: UUID
    let strategy: OptimizerStrategy
    let wastePct: Double
    let items: [OptimizerLayoutItem]
    let totalQty: Int
    let estimatedProfit: Double?

    enum CodingKeys: String, CodingKey {
        case id, strategy
        case wastePct = "waste_pct"
        case items
        case totalQty = "total_qty"
        case estimatedProfit = "estimated_profit"
    }
}

struct SuggestOptimizerResponse: Codable {
    let layouts: [OptimizerLayout]
}

// MARK: - Raw backend response (suggest endpoint omits id, product_name, size_label, total_qty)

struct BackendOptimizerLayoutItem: Codable {
    let productSizeId: UUID
    let patternSpecId: UUID
    let orientation: String
    let qtySuggested: Int
    let fabricLengthUsedCm: Double
    let costPerPiece: Double

    enum CodingKeys: String, CodingKey {
        case productSizeId    = "product_size_id"
        case patternSpecId    = "pattern_spec_id"
        case orientation
        case qtySuggested     = "qty_suggested"
        case fabricLengthUsedCm = "fabric_length_used_cm"
        case costPerPiece     = "cost_per_piece"
    }
}

struct BackendOptimizerLayout: Codable {
    let strategy: OptimizerStrategy
    let wastePct: Double
    let items: [BackendOptimizerLayoutItem]

    enum CodingKeys: String, CodingKey {
        case strategy
        case wastePct = "waste_pct"
        case items
    }
}

struct BackendSuggestOptimizerResponse: Codable {
    let layouts: [BackendOptimizerLayout]
}

// POST /cutting-optimizer/layouts only returns the new ID, not a full CuttingLayout
struct BackendCreateLayoutResponse: Codable {
    let cuttingLayoutId: UUID

    enum CodingKeys: String, CodingKey {
        case cuttingLayoutId = "cutting_layout_id"
    }
}

struct CreateLayoutRequest: Codable {
    let materialPurchaseId: UUID
    let strategy: String
    let items: [CreateLayoutItemInput]

    enum CodingKeys: String, CodingKey {
        case materialPurchaseId = "material_purchase_id"
        case strategy, items
    }

    struct CreateLayoutItemInput: Codable {
        let productSizeId: UUID
        let patternSpecId: UUID
        let orientation: String
        let qtySuggested: Int
        let fabricLengthUsedCm: Double
        let costPerPiece: Double

        enum CodingKeys: String, CodingKey {
            case productSizeId = "product_size_id"
            case patternSpecId = "pattern_spec_id"
            case orientation
            case qtySuggested = "qty_suggested"
            case fabricLengthUsedCm = "fabric_length_used_cm"
            case costPerPiece = "cost_per_piece"
        }
    }
}

struct CuttingLayout: Codable, Identifiable {
    let id: UUID
    let materialPurchaseId: UUID
    let materialName: String
    let strategy: String?
    let status: String
    let wastePct: Double?
    let totalFabricCost: Double
    let createdAt: Date
    let items: [OptimizerLayoutItem]

    enum CodingKeys: String, CodingKey {
        case id
        case materialPurchaseId = "material_purchase_id"
        case materialName = "material_name"
        case strategy
        case status
        case wastePct = "waste_pct"
        case totalFabricCost = "total_fabric_cost"
        case createdAt = "created_at"
        case items
    }
}
