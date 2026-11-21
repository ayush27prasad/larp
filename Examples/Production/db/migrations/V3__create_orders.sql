CREATE TABLE orders (
    id           TEXT PRIMARY KEY,
    customer_id  TEXT NOT NULL REFERENCES customers (id),
    status       TEXT NOT NULL DEFAULT 'PENDING',
    total_cents  INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
