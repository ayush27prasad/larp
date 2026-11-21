import os

import httpx

from .models import Order

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://localhost:8081")
PAYMENTS_URL = os.environ.get("PAYMENTS_URL", "http://localhost:8082")


class ReservationFailed(Exception):
    pass


class ChargeFailed(Exception):
    pass


async def reserve_stock(order: Order) -> None:
    payload = {"order_id": order.id, "items": [i.model_dump() for i in order.items]}
    async with httpx.AsyncClient() as client:
        response = await client.post(f"{INVENTORY_URL}/reservations", json=payload)
    if response.status_code != 201:
        raise ReservationFailed(response.text)


async def release_stock(order: Order) -> None:
    async with httpx.AsyncClient() as client:
        await client.delete(f"{INVENTORY_URL}/reservations/{order.id}")


async def charge(order: Order) -> str:
    payload = {"order_id": order.id, "amount_cents": order.total_cents}
    async with httpx.AsyncClient() as client:
        response = await client.post(f"{PAYMENTS_URL}/charges", json=payload)
    if response.status_code != 201:
        raise ChargeFailed(response.text)
    return response.json()["charge_id"]
