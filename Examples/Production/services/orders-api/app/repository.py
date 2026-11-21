import uuid

from .models import Order, OrderStatus


class OrderRepository:
    """In-memory for now; the Postgres version lands with migration V12."""

    def __init__(self) -> None:
        self._orders: dict[str, Order] = {}

    def add(self, order: Order) -> Order:
        if not order.id:
            order.id = f"ord_{uuid.uuid4().hex[:12]}"
        self._orders[order.id] = order
        return order

    def get(self, order_id: str) -> Order | None:
        return self._orders.get(order_id)

    def for_customer(self, customer_id: str) -> list[Order]:
        return [o for o in self._orders.values() if o.customer_id == customer_id]

    def set_status(self, order_id: str, status: OrderStatus) -> Order:
        order = self._orders[order_id]
        order.status = status
        return order
