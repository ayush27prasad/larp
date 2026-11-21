CREATE TABLE payments (
    charge_id     TEXT PRIMARY KEY,
    order_id      TEXT NOT NULL UNIQUE REFERENCES orders (id),
    amount_cents  INTEGER NOT NULL,
    status        TEXT NOT NULL,
    created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
