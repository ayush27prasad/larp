import { useEffect, useState } from "react";
import { listOrders } from "../api/client";
import type { Order } from "../types";
import { OrderRow } from "./OrderRow";

export function OrderList({ customerId }: { customerId: string }) {
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listOrders(customerId).then(setOrders).catch((e: Error) => setError(e.message));
  }, [customerId]);

  if (error) return <p className="error">{error}</p>;
  if (orders === null) return <p>Loading…</p>;
  if (orders.length === 0) return <p>No orders yet.</p>;

  return (
    <table className="orders">
      <thead>
        <tr><th>Order</th><th>Items</th><th>Status</th><th>Total</th></tr>
      </thead>
      <tbody>
        {orders.map((order) => <OrderRow key={order.id} order={order} />)}
      </tbody>
    </table>
  );
}
