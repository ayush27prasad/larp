// Mirrors proto/orders/v1/orders.proto.

export type OrderStatus = "PENDING" | "RESERVED" | "PAID" | "SHIPPED" | "CANCELLED";

export interface LineItem {
  sku: string;
  quantity: number;
  unit_price_cents: number;
}

export interface Order {
  id: string;
  customer_id: string;
  items: LineItem[];
  status: OrderStatus;
  total_cents: number;
}
