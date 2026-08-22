import Foundation

struct PatternFabric: Codable, Identifiable {
    let id: UUID
    let materialId: UUID
    let materialName: String
    let fabricFamily: String?
    let cutLengthCm: Double   // Panjang potongan
    let cutWidthCm: Double    // Lebar potongan
    let rotationAllowed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case materialId      = "material_id"
        case materialName    = "material_name"
        case fabricFamily    = "fabric_family"
        case cutLengthCm     = "cut_height_cm"
        case cutWidthCm      = "cut_width_cm"
        case rotationAllowed = "rotation_allowed"
    }
}

/// Mirrors backend `estimate_fabric_cost_per_piece_from_rate` (app/services/cutting_optimizer.py) --
/// the same per-piece nesting estimate the cutting optimizer and `get_hpp_for_sale`'s PatternSpec
/// fallback tier use. Picks whichever allowed orientation packs more pieces across a hypothetical
/// roll of `fabricWidthCm` (the material's typical/default width), which minimizes cost per piece;
/// falls back to one full row per piece (no nesting) when `fabricWidthCm` is unknown or neither
/// orientation fits at least one piece across the width.
///
/// Client-side estimates that skip this (e.g. `cutLengthCm * costPerCm` with no division by how
/// many pieces fit across the roll's width) overstate fabric cost by roughly that pieces-per-row
/// factor -- this is what keeps the "estimasi resep" HPP shown on the product page consistent with
/// what Optimasi Resep would actually compute for the same spec.
func estimatedFabricCostPerPiece(
    cutWidthCm: Double,
    cutHeightCm: Double,
    rotationAllowed: Bool,
    fabricWidthCm: Double?,
    costPerCm: Double
) -> Double {
    guard costPerCm > 0 else { return 0 }
    guard let fabricWidthCm, fabricWidthCm > 0 else { return costPerCm * cutHeightCm }

    var feasibleCosts: [Double] = []
    if cutWidthCm > 0 {
        let normalPiecesPerRow = Int(fabricWidthCm / cutWidthCm)
        if normalPiecesPerRow > 0 && cutHeightCm > 0 {
            feasibleCosts.append(costPerCm * cutHeightCm / Double(normalPiecesPerRow))
        }
    }
    if rotationAllowed, cutHeightCm > 0 {
        let rotatedPiecesPerRow = Int(fabricWidthCm / cutHeightCm)
        if rotatedPiecesPerRow > 0 && cutWidthCm > 0 {
            feasibleCosts.append(costPerCm * cutWidthCm / Double(rotatedPiecesPerRow))
        }
    }
    return feasibleCosts.min() ?? (costPerCm * cutHeightCm)
}

/// Picks a roll width for `estimatedFabricCostPerPiece`'s nesting calc, preferring the actual
/// `width_cm` of a real purchase over `material.fabric_width_cm` (a separate, optional "typical
/// width" hint that's frequently left unset). When it's unset, `estimatedFabricCostPerPiece`
/// silently falls back to "one piece per row" -- a confirmed ~100x inflation in a real case (see
/// backend `get_hpp_for_sale` docstring) -- whereas a purchase's width_cm is always recorded (it's
/// a required field for fabric purchases). Among purchases with stock left, picks the one with the
/// most remaining length, since that's the roll most likely to actually get cut next; falls back to
/// any purchase's width, then to `fallback` (typically `material.fabricWidthCm`) if there are none.
func representativeFabricWidthCm(purchases: [MaterialPurchase], fallback: Double?) -> Double? {
    let withStock = purchases.filter { ($0.widthCm ?? 0) > 0 && ($0.remainingLengthCm ?? 0) > 0 }
    if let mostStock = withStock.max(by: { ($0.remainingLengthCm ?? 0) < ($1.remainingLengthCm ?? 0) }) {
        return mostStock.widthCm
    }
    if let anyWithWidth = purchases.first(where: { ($0.widthCm ?? 0) > 0 }) {
        return anyWithWidth.widthCm
    }
    return fallback
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

// MARK: - Raw backend response (v2.15+: fabrics via join table)

struct BackendPatternFabric: Codable {
    let id: UUID
    let materialId: UUID
    let materialName: String
    let cutWidthCm: Double
    let cutHeightCm: Double  // backend "height" = UI "panjang/length"
    let rotationAllowed: Bool
    let fabricLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case materialId      = "material_id"
        case materialName    = "material_name"
        case cutWidthCm      = "cut_width_cm"
        case cutHeightCm     = "cut_height_cm"
        case rotationAllowed = "rotation_allowed"
        case fabricLabel     = "fabric_label"
    }
}

struct BackendPatternSpec: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    let fabrics: [BackendPatternFabric]
    let estLaborMinutes: Double
    let isActive: Bool
    let effectiveFrom: Date
    let effectiveTo: Date?
    let components: [BackendPatternComponent]
    let usedInBatchCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId    = "product_size_id"
        case fabrics
        case estLaborMinutes  = "est_labor_minutes"
        case isActive         = "is_active"
        case effectiveFrom    = "effective_from"
        case effectiveTo      = "effective_to"
        case components
        case usedInBatchCount = "used_in_batch_count"
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

// Backend wire format — v2.15+: fabrics array replaces flat fields
struct BackendCreatePatternSpecRequest: Encodable {
    let productSizeId: UUID
    let fabrics: [FabricLayerRequest]
    let estLaborMinutes: Double
    let components: [CreatePatternSpecRequest.ComponentInput]

    struct FabricLayerRequest: Encodable {
        let materialId: UUID
        let cutWidthCm: Double
        let cutHeightCm: Double  // backend "height" = UI "panjang/length"
        let rotationAllowed: Bool
        let fabricLabel: String?

        enum CodingKeys: String, CodingKey {
            case materialId      = "material_id"
            case cutWidthCm      = "cut_width_cm"
            case cutHeightCm     = "cut_height_cm"
            case rotationAllowed = "rotation_allowed"
            case fabricLabel     = "fabric_label"
        }
    }

    enum CodingKeys: String, CodingKey {
        case productSizeId   = "product_size_id"
        case fabrics
        case estLaborMinutes = "est_labor_minutes"
        case components
    }
}
