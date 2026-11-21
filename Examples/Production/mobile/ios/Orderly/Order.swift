import Foundation

// Mirrors proto/orders/v1/orders.proto.
enum OrderStatus: String, Codable {
    case pending = "PENDING"
    case reserved = "RESERVED"
    case paid = "PAID"
    case shipped = "SHIPPED"
    case cancelled = "CANCELLED"
}

struct LineItem: Codable, Hashable {
    let sku: String
    let quantity: Int
    let unitPriceCents: Int
}

struct Order: Codable, Identifiable, Hashable {
    let id: String
    let customerId: String
    let items: [LineItem]
    let status: OrderStatus
    let totalCents: Int

    var formattedTotal: String {
        (Double(totalCents) / 100).formatted(.currency(code: "USD"))
    }
}
