from enum import Enum

from pydantic import BaseModel, Field


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    RESERVED = "RESERVED"
    PAID = "PAID"
    SHIPPED = "SHIPPED"
    CANCELLED = "CANCELLED"


class LineItem(BaseModel):
    sku: str
    quantity: int = Field(gt=0)
    unit_price_cents: int = Field(ge=0)


class Order(BaseModel):
    id: str
    customer_id: str
    items: list[LineItem]
    status: OrderStatus = OrderStatus.PENDING
    total_cents: int = 0


class CreateOrderRequest(BaseModel):
    customer_id: str
    items: list[LineItem]
    coupon_code: str | None = None
