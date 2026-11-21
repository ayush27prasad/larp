"""Turns line items into a total. Every amount is in integer cents."""

from .models import LineItem

TAX_RATE = 0.08
FREE_SHIPPING_THRESHOLD_CENTS = 5_000
SHIPPING_CENTS = 499

COUPONS = {"WELCOME10": 10, "VIP20": 20}


def subtotal(items: list[LineItem]) -> int:
    return sum(item.unit_price_cents * item.quantity for item in items)


def bulk_discount_percent(items: list[LineItem]) -> int:
    """Mirrors the bulk_discounts rules in config/feature-flags.json."""
    quantity = sum(item.quantity for item in items)
    if quantity >= 50:
        return 10
    if quantity >= 10:
        return 5
    return 0


def discount(items: list[LineItem], coupon_code: str | None) -> int:
    percent = max(bulk_discount_percent(items), COUPONS.get(coupon_code or "", 0))
    return subtotal(items) * percent // 100


def shipping(discounted_cents: int) -> int:
    return 0 if discounted_cents >= FREE_SHIPPING_THRESHOLD_CENTS else SHIPPING_CENTS


def calculate_total(items: list[LineItem], coupon_code: str | None = None) -> int:
    discounted = subtotal(items) - discount(items, coupon_code)
    tax = round(discounted * TAX_RATE)
    return discounted + tax + shipping(discounted)
