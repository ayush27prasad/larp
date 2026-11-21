CREATE TABLE line_items (
    order_id          TEXT NOT NULL REFERENCES orders (id),
    sku               TEXT NOT NULL REFERENCES products (sku),
    quantity          INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_cents  INTEGER NOT NULL,
    PRIMARY KEY (order_id, sku)
);
