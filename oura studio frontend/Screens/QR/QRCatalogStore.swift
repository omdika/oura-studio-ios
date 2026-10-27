import Foundation

final class QRCatalogStore {
    static let shared = QRCatalogStore()
    
    struct Snapshot {
        let products: [Product]
        let sizesByProduct: [UUID: [ProductSizeDetail]]
        let fetchedAt: Date
    }
    
    private var _snapshot: Snapshot?
    var snapshot: Snapshot? { _snapshot }
    var ttl: TimeInterval = 60
    
    func isValid() -> Bool {
        guard let s = _snapshot else { return false }
        return Date().timeIntervalSince(s.fetchedAt) < ttl
    }
    
    func store(products: [Product], sizesByProduct: [UUID: [ProductSizeDetail]]) {
        _snapshot = Snapshot(products: products, sizesByProduct: sizesByProduct, fetchedAt: Date())
    }
    
    func invalidate() {
        _snapshot = nil
    }
}
