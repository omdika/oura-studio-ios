import Foundation

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "cash"
    case transfer = "transfer"
    case qris = "qris"
    case marketplace = "marketplace"

    var displayName: String {
        switch self {
        case .cash:        return "Cash"
        case .transfer:    return "Transfer"
        case .qris:        return "QRIS"
        case .marketplace: return "Marketplace"
        }
    }
}

struct SalesOrder: Codable, Identifiable {
    let id: UUID
    let invoiceNo: String
    let customerName: String?
    let paymentMethod: String?
    let marketplaceFeePct: Double
    let status: String
    let soldAt: Date
    let items: [SalesOrderItem]
    // Backend may omit these — fall back to computing from items
    let totalRevenue: Double?
    let totalProfit: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceNo = "invoice_no"
        case customerName = "customer_name"
        case paymentMethod = "payment_method"
        case marketplaceFeePct = "marketplace_fee_pct"
        case status
        case soldAt = "sold_at"
        case items
        case totalRevenue = "total_revenue"
        case totalProfit = "total_profit"
    }

    var isCancelled: Bool { status == "cancelled" }
    var isPaid: Bool { status == "paid" }

    var displayRevenue: Double { totalRevenue ?? items.reduce(0) { $0 + $1.lineRevenue } }
    var displayProfit: Double { totalProfit ?? items.reduce(0) { $0 + $1.lineProfit } }
}

struct SalesOrderItem: Codable, Identifiable {
    let id: UUID
    let productSizeId: UUID
    // SalesOrderItemOut (backend) does include product_name/size_label directly -- these were
    // previously left out of CodingKeys under a stale "backend omits these" assumption, so they
    // always decoded to nil and every item silently showed "Produk · -" regardless of what sold.
    var salesOrderId: UUID? = nil
    var productName: String? = nil
    var sizeLabel: String? = nil
    let qty: Int
    let unitPrice: Double
    let discount: Double
    let unitHppSnapshot: Double
    let lineProfit: Double

    enum CodingKeys: String, CodingKey {
        case id
        case productSizeId = "product_size_id"
        case productName = "product_name"
        case sizeLabel = "size_label"
        // salesOrderId intentionally omitted -- redundant with the order that already owns this item
        case qty
        case unitPrice = "unit_price"
        case discount
        case unitHppSnapshot = "unit_hpp_snapshot"
        case lineProfit = "line_profit"
    }

    var effectivePrice: Double { unitPrice - discount }
    var lineRevenue: Double { effectivePrice * Double(qty) }
}

struct CreateSalesOrderRequest: Codable {
    let customerName: String?
    let paymentMethod: String
    let marketplaceFeePct: Double?
    let items: [ItemInput]

    enum CodingKeys: String, CodingKey {
        case customerName = "customer_name"
        case paymentMethod = "payment_method"
        case marketplaceFeePct = "marketplace_fee_pct"
        case items
    }

    struct ItemInput: Codable {
        let productSizeId: UUID
        let qty: Int
        let unitPrice: Double
        let discount: Double?

        enum CodingKeys: String, CodingKey {
            case productSizeId = "product_size_id"
            case qty
            case unitPrice = "unit_price"
            case discount
        }
    }
}

struct CancelSalesOrderRequest: Codable {
    let reason: String?
}
