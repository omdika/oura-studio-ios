import Foundation

struct PatternFabric: Codable, Identifiable {
    let id: UUID
    let materialId: UUID
    let materialName: String
    let cutLengthCm: Double   // Panjang potongan
    let cutWidthCm: Double    // Lebar potongan
    let rotationAllowed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case materialId      = "material_id"
        case materialName    = "material_name"
        case cutLengthCm     = "cut_length_cm"
        case cutWidthCm      = "cut_width_cm"
        case rotationAllowed = "rotation_allowed"
    }
}

struct PatternSpec: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    let productName: String
    let productSku: String
    let sizeLabel: String
    let fabrics: [PatternFabric]
    let estLaborMinutes: Double
    let isActive: Bool
    let effectiveFrom: Date
    let effectiveTo: Date?
    let components: [PatternComponent]
    let usedInBatchCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId   = "product_size_id"
        case productName     = "product_name"
        case productSku      = "product_sku"
        case sizeLabel       = "size_label"
        case fabrics
        case estLaborMinutes = "est_labor_minutes"
        case isActive        = "is_active"
        case effectiveFrom   = "effective_from"
        case effectiveTo     = "effective_to"
        case components
        case usedInBatchCount = "used_in_batch_count"
    }

    // Computed convenience props
    var fabricMaterialName: String {
        fabrics.isEmpty ? "Tanpa Kain" : fabrics.map { $0.materialName }.joined(separator: " + ")
    }
    var fabricMaterialId: UUID?   { fabrics.first?.materialId }
    var cutLengthCm: Double       { fabrics.first?.cutLengthCm ?? 0 }
    var cutWidthCm: Double        { fabrics.first?.cutWidthCm  ?? 0 }
    var rotationAllowed: Bool     { fabrics.first?.rotationAllowed ?? true }

    var canDelete: Bool       { usedInBatchCount == 0 }
    var isInPlaceEdit: Bool   { usedInBatchCount == 0 }
}

struct PatternComponent: Codable, Identifiable, Hashable {
    let id: UUID
    let patternSpecId: UUID
    let materialId: UUID
    let materialName: String
    let qtyPerUnit: Double

    enum CodingKeys: String, CodingKey {
        case id
        case patternSpecId = "pattern_spec_id"
        case materialId    = "material_id"
        case materialName  = "material_name"
        case qtyPerUnit    = "qty_per_unit"
    }
}

// MARK: - Raw backend response (flat format, enriched client-side in APIService)

struct BackendPatternSpec: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    let fabricMaterialId: UUID
    let cutWidthCm: Double
    let cutHeightCm: Double
    let rotationAllowed: Bool
    let estLaborMinutes: Double
    let isActive: Bool
    let effectiveFrom: Date
    let effectiveTo: Date?
    let components: [BackendPatternComponent]

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId    = "product_size_id"
        case fabricMaterialId = "fabric_material_id"
        case cutWidthCm       = "cut_width_cm"
        case cutHeightCm      = "cut_height_cm"
        case rotationAllowed  = "rotation_allowed"
        case estLaborMinutes  = "est_labor_minutes"
        case isActive         = "is_active"
        case effectiveFrom    = "effective_from"
        case effectiveTo      = "effective_to"
        case components
    }
}

struct BackendPatternComponent: Codable, Identifiable {
    let id: UUID
    let materialId: UUID
    let qtyPerUnit: Double

    enum CodingKeys: String, CodingKey {
        case id
        case materialId = "material_id"
        case qtyPerUnit = "qty_per_unit"
    }
}

// Frontend model — supports multi-fabric input from UI
struct CreatePatternSpecRequest: Codable {
    let productSizeId: UUID
    let fabrics: [FabricInput]   // may be empty — fabric is optional
    let estLaborMinutes: Double
    let components: [ComponentInput]

    enum CodingKeys: String, CodingKey {
        case productSizeId   = "product_size_id"
        case fabrics
        case estLaborMinutes = "est_labor_minutes"
        case components
    }

    struct FabricInput: Codable {
        let materialId: UUID
        let cutLengthCm: Double  // height in backend terms
        let cutWidthCm: Double
        let rotationAllowed: Bool

        enum CodingKeys: String, CodingKey {
            case materialId      = "material_id"
            case cutLengthCm     = "cut_length_cm"
            case cutWidthCm      = "cut_width_cm"
            case rotationAllowed = "rotation_allowed"
        }
    }

    struct ComponentInput: Codable {
        let materialId: UUID
        let qtyPerUnit: Double

        enum CodingKeys: String, CodingKey {
            case materialId = "material_id"
            case qtyPerUnit = "qty_per_unit"
        }
    }
}

// Backend wire format — flat fields, one fabric per spec
// Backend uses cut_height_cm for what the UI calls cut_length_cm (the long dimension)
struct BackendCreatePatternSpecRequest: Encodable {
    let productSizeId: UUID
    let fabricMaterialId: UUID
    let cutWidthCm: Double
    let cutHeightCm: Double
    let rotationAllowed: Bool
    let estLaborMinutes: Double
    let components: [CreatePatternSpecRequest.ComponentInput]

    enum CodingKeys: String, CodingKey {
        case productSizeId      = "product_size_id"
        case fabricMaterialId   = "fabric_material_id"
        case cutWidthCm         = "cut_width_cm"
        case cutHeightCm        = "cut_height_cm"
        case rotationAllowed    = "rotation_allowed"
        case estLaborMinutes    = "est_labor_minutes"
        case components
    }
}
