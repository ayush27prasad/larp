import type { LineItem, Order } from "../types";

const BASE_URL = import.meta.env.VITE_ORDERS_API ?? "http://localhost:8080";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!response.ok) {
    throw new Error(`${init?.method ?? "GET"} ${path} failed: ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export function listOrders(customerId: string): Promise<Order[]> {
  return request(`/orders?customer_id=${encodeURIComponent(customerId)}`);
}

export function createOrder(customerId: string, items: LineItem[], couponCode?: string): Promise<Order> {
  return request("/orders", {
    method: "POST",
    body: JSON.stringify({ customer_id: customerId, items, coupon_code: couponCode }),
  });
}
