-- SQLite can't add a CHECK to an existing table; Postgres runs the ALTER.
CREATE VIEW orders_by_status AS
    SELECT status, COUNT(*) AS order_count, SUM(total_cents) AS revenue_cents
    FROM orders
    GROUP BY status;
