CREATE TABLE order_events (
    id          INTEGER PRIMARY KEY,
    order_id    TEXT NOT NULL REFERENCES orders (id),
    status      TEXT NOT NULL,
    occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
