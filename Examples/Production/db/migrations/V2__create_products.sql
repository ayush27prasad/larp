CREATE TABLE products (
    sku              TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0)
);
