import Foundation

struct SettingItem: Codable, Identifiable {
    var id: String { key }
    let key: String
    let value: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case key, value
        case updatedAt = "updated_at"
    }

    var displayName: String {
        switch key {
        case "labor_rate_per_minute":       return "Tarif Tenaga Kerja (Rp/menit)"
        case "default_overhead_per_unit":   return "Overhead per Unit (Rp)"
        case "pooled_material_rate:thread": return "Biaya Benang per Unit (Rp)"
        case "pooled_material_rate:packaging": return "Biaya Packaging per Unit (Rp)"
        default: return key
        }
    }

    var category: String {
        if key.hasPrefix("pooled_material_rate") { return "Bahan Pooled" }
        if key == "labor_rate_per_minute" { return "Tenaga Kerja" }
        return "Overhead"
    }
}

struct PatchSettingRequest: Codable {
    let key: String
    let value: Double
}
