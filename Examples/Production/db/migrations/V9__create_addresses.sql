CREATE TABLE addresses (
    id           INTEGER PRIMARY KEY,
    customer_id  TEXT NOT NULL REFERENCES customers (id),
    line1        TEXT NOT NULL,
    city         TEXT NOT NULL,
    postcode     TEXT NOT NULL,
    country      TEXT NOT NULL DEFAULT 'US'
);
