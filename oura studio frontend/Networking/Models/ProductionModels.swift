import Foundation

struct ProductionBatch: Codable, Identifiable {
    let id: UUID
    let cuttingLayoutId: UUID?
    let cuttingLayoutStrategy: String?
    let materialName: String?
    let producedAt: Date
    let status: String
    let notes: String?
    var items: [ProductionBatchItem]

    enum CodingKeys: String, CodingKey {
        case id
        case cuttingLayoutId = "cutting_layout_id"
        case cuttingLayoutStrategy = "cutting_layout_strategy"
        case materialName = "material_name"
        case producedAt = "produced_at"
        case status, notes, items
    }

    var isDraft: Bool { status == "draft" }
    var isConfirmed: Bool { status == "confirmed" }

    // "Scrunchie - Satin Putih" — product + material with dash separator
    var batchLabel: String {
        guard !items.isEmpty else { return "Batch Kosong" }
        let productNames = Array(Set(items.map { $0.productName })).sorted().joined(separator: ", ")
        if let mat = materialName { return "\(productNames) - \(mat)" }
        return productNames
    }

    // "M 8pcs, L 3pcs" — sizes with qty as subtitle
    var batchSizeDetail: String {
        items.sorted { $0.sizeLabel < $1.sizeLabel }
             .map { "\($0.sizeLabel) \($0.qtyActual)pcs" }
             .joined(separator: ", ")
    }

    var draftLabel: String { batchLabel }
}

struct ProductionBatchItem: Codable, Identifiable {
    let id: UUID
    let productionBatchId: UUID
    let productSizeId: UUID
    let productName: String
    let sizeLabel: String
    let patternSpecId: UUID
    var qtyActual: Int
    let qtySuggested: Int?
    let hppFabric: Double
    let hppPooledMaterial: Double
    let hppHardware: Double
    let hppLabor: Double
    let hppOverhead: Double
    let hppTotal: Double

    enum CodingKeys: String, CodingKey {
        case id
        case productionBatchId = "production_batch_id"
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        case patternSpecId = "pattern_spec_id"
        case qtyActual = "qty_actual"
        case qtySuggested = "qty_suggested"
        case hppFabric = "hpp_fabric"
        case hppPooledMaterial = "hpp_pooled_material"
        case hppHardware = "hpp_hardware"
        case hppLabor = "hpp_labor"
        case hppOverhead = "hpp_overhead"
        case hppTotal = "hpp_total"
    }
}

struct UpdateBatchItemRequest: Codable {
    let qtyActual: Int

    enum CodingKeys: String, CodingKey {
        case qtyActual = "qty_actual"
    }
}

struct CreateProductionBatchRequest: Codable {
    let cuttingLayoutId: UUID?

    enum CodingKeys: String, CodingKey {
        case cuttingLayoutId = "cutting_layout_id"
    }
}

// MARK: - Raw backend format (items lack product_name, size_label, production_batch_id)

struct BackendProductionBatchItem: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    let patternSpecId: UUID
    let qtyActual: Int
    let qtySuggested: Int?
    // fabricCostPerPiece is available even in draft; hpp_* fields are only non-zero after confirmation
    let fabricCostPerPiece: Double
    let hppFabric: Double
    let hppPooledMaterial: Double
    let hppHardware: Double
    let hppLabor: Double
    let hppOverhead: Double
    let hppTotal: Double

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId      = "product_size_id"
        case patternSpecId      = "pattern_spec_id"
        case qtyActual          = "qty_actual"
        case qtySuggested       = "qty_suggested"
        case fabricCostPerPiece = "fabric_cost_per_piece"
        case hppFabric          = "hpp_fabric"
        case hppPooledMaterial  = "hpp_pooled_material"
        case hppHardware        = "hpp_hardware"
        case hppLabor           = "hpp_labor"
        case hppOverhead        = "hpp_overhead"
        case hppTotal           = "hpp_total"
    }
}

struct BackendProductionBatch: Codable, Identifiable {
    let id: UUID
    let cuttingLayoutId: UUID?
    let cuttingLayoutStrategy: String?
    let materialName: String?
    let producedAt: Date
    let status: String
    let notes: String?
    let items: [BackendProductionBatchItem]

    enum CodingKeys: String, CodingKey {
        case id
        case cuttingLayoutId       = "cutting_layout_id"
        case cuttingLayoutStrategy = "cutting_layout_strategy"
        case materialName          = "material_name"
        case producedAt            = "produced_at"
        case status, notes, items
    }
}
