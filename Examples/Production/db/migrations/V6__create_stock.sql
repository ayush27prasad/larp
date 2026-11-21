CREATE TABLE stock (
    sku      TEXT PRIMARY KEY REFERENCES products (sku),
    on_hand  INTEGER NOT NULL DEFAULT 0
);
