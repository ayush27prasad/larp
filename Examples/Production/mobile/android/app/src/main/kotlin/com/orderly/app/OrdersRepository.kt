package com.orderly.app

import java.net.URL
import org.json.JSONArray

class OrdersRepository(private val baseUrl: String = "http://10.0.2.2:8080") {

    fun ordersFor(customerId: String): List<Order> {
        val json = URL("$baseUrl/orders?customer_id=$customerId").readText()
        val array = JSONArray(json)
        return (0 until array.length()).map { index ->
            val o = array.getJSONObject(index)
            val items = o.getJSONArray("items")
            Order(
                id = o.getString("id"),
                customerId = o.getString("customer_id"),
                items = (0 until items.length()).map { i ->
                    val item = items.getJSONObject(i)
                    LineItem(item.getString("sku"), item.getInt("quantity"), item.getLong("unit_price_cents"))
                },
                status = OrderStatus.valueOf(o.getString("status")),
                totalCents = o.getLong("total_cents"),
            )
        }
    }
}
