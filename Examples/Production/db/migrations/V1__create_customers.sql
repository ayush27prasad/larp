CREATE TABLE customers (
    id          TEXT PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    full_name   TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
