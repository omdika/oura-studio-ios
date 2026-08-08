import Foundation

struct Supplier: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

struct CreateSupplierRequest: Codable {
    let name: String
}

struct PatchSupplierRequest: Codable {
    let name: String
}
