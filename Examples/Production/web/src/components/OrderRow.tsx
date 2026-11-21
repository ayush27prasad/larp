import type { Order } from "../types";

export function formatCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

const STATUS_LABEL: Record<Order["status"], string> = {
  PENDING: "Pending",
  RESERVED: "Reserved",
  PAID: "Paid",
  SHIPPED: "Shipped",
  CANCELLED: "Cancelled",
};

export function OrderRow({ order }: { order: Order }) {
  const itemCount = order.items.reduce((sum, item) => sum + item.quantity, 0);
  return (
    <tr className={`order-row status-${order.status.toLowerCase()}`}>
      <td>{order.id}</td>
      <td>{itemCount} items</td>
      <td>{STATUS_LABEL[order.status]}</td>
      <td className="amount">{formatCents(order.total_cents)}</td>
    </tr>
  );
}
