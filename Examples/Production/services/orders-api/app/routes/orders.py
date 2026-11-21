from fastapi import APIRouter, HTTPException

from ..clients import ChargeFailed, ReservationFailed, charge, release_stock, reserve_stock
from ..models import CreateOrderRequest, Order, OrderStatus
from ..pricing import calculate_total
from ..repository import OrderRepository

router = APIRouter(prefix="/orders")
repository = OrderRepository()


@router.post("", status_code=201)
async def create_order(request: CreateOrderRequest) -> Order:
    order = repository.add(
        Order(
            id="",
            customer_id=request.customer_id,
            items=request.items,
            total_cents=calculate_total(request.items, request.coupon_code),
        )
    )

    try:
        await reserve_stock(order)
        repository.set_status(order.id, OrderStatus.RESERVED)
        await charge(order)
    except ReservationFailed:
        return repository.set_status(order.id, OrderStatus.CANCELLED)
    except ChargeFailed:
        await release_stock(order)
        return repository.set_status(order.id, OrderStatus.CANCELLED)

    return repository.set_status(order.id, OrderStatus.PAID)


@router.get("/{order_id}")
async def get_order(order_id: str) -> Order:
    order = repository.get(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    return order


@router.get("")
async def list_orders(customer_id: str) -> list[Order]:
    return repository.for_customer(customer_id)
