from app.models import LineItem
from app.pricing import calculate_total, discount, shipping, subtotal


def items(*pairs: tuple[int, int]) -> list[LineItem]:
    return [LineItem(sku=f"SKU-{i}", quantity=q, unit_price_cents=p) for i, (q, p) in enumerate(pairs)]


def test_subtotal_multiplies_quantity_by_price():
    assert subtotal(items((2, 1_000), (1, 250))) == 2_250


def test_bulk_discount_applies_from_ten_items():
    assert discount(items((10, 100)), None) == 50


def test_coupon_beats_smaller_bulk_discount():
    assert discount(items((10, 100)), "VIP20") == 200


def test_free_shipping_over_threshold():
    assert shipping(5_000) == 0
    assert shipping(4_999) == 499


def test_total_includes_tax_and_shipping():
    assert calculate_total(items((1, 1_000))) == 1_000 + 80 + 499
