package com.orderly.app

// Mirrors proto/orders/v1/orders.proto.
enum class OrderStatus { PENDING, RESERVED, PAID, SHIPPED, CANCELLED }

data class LineItem(val sku: String, val quantity: Int, val unitPriceCents: Long)

data class Order(
    val id: String,
    val customerId: String,
    val items: List<LineItem>,
    val status: OrderStatus,
    val totalCents: Long,
) {
    val formattedTotal: String
        get() = "$%d.%02d".format(totalCents / 100, totalCents % 100)
}
