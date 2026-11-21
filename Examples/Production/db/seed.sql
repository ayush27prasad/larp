INSERT INTO customers (id, email, full_name) VALUES
    ('cus_demo', 'demo@orderly.example', 'Dana Demo'),
    ('cus_8821', 'priya@example.com', 'Priya Raman'),
    ('cus_9134', 'leo@example.com', 'Léo Martin');

INSERT INTO products (sku, name, unit_price_cents) VALUES
    ('MUG-01', 'Stoneware mug', 1800),
    ('TEE-02', 'Organic cotton tee', 2900),
    ('CAP-03', 'Canvas cap', 2200),
    ('BAG-04', 'Market tote', 3500);

INSERT INTO stock (sku, on_hand) VALUES
    ('MUG-01', 120), ('TEE-02', 40), ('CAP-03', 0), ('BAG-04', 15);

INSERT INTO addresses (customer_id, line1, city, postcode) VALUES
    ('cus_demo', '1 Infinite Loop', 'Cupertino', '95014'),
    ('cus_8821', '500 Market St', 'San Francisco', '94105');

INSERT INTO orders (id, customer_id, status, total_cents, coupon_code, shipping_address_id) VALUES
    ('ord_a1b2c3', 'cus_demo', 'PAID', 4387, NULL, 1),
    ('ord_d4e5f6', 'cus_demo', 'SHIPPED', 3131, 'WELCOME10', 1),
    ('ord_778899', 'cus_8821', 'CANCELLED', 2875, NULL, 2),
    ('ord_aa0011', 'cus_9134', 'PENDING', 6156, 'VIP20', NULL);

INSERT INTO line_items (order_id, sku, quantity, unit_price_cents) VALUES
    ('ord_a1b2c3', 'MUG-01', 2, 1800),
    ('ord_d4e5f6', 'TEE-02', 1, 2900),
    ('ord_778899', 'CAP-03', 1, 2200),
    ('ord_aa0011', 'BAG-04', 2, 3500);

INSERT INTO payments (charge_id, order_id, amount_cents, status) VALUES
    ('ch_1001', 'ord_a1b2c3', 4387, 'SUCCEEDED'),
    ('ch_1002', 'ord_d4e5f6', 3131, 'SUCCEEDED');

INSERT INTO order_events (order_id, status) VALUES
    ('ord_a1b2c3', 'PENDING'), ('ord_a1b2c3', 'RESERVED'), ('ord_a1b2c3', 'PAID'),
    ('ord_d4e5f6', 'PAID'), ('ord_d4e5f6', 'SHIPPED'),
    ('ord_778899', 'PENDING'), ('ord_778899', 'CANCELLED');
