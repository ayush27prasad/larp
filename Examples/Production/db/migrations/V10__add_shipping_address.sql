ALTER TABLE orders ADD COLUMN shipping_address_id INTEGER REFERENCES addresses (id);
