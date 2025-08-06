-- Simple DDL for testing the app database connection
-- Run this after connecting: psql -h 127.0.0.1 -p 15432 -U app -d app -W

-- Simple users table
CREATE TABLE IF NOT EXISTS test_users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Simple products table
CREATE TABLE IF NOT EXISTS test_products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO test_users (name, email) VALUES
('Alice Johnson', 'alice@test.com'),
('Bob Wilson', 'bob@test.com'),
('Charlie Brown', 'charlie@test.com')
ON CONFLICT (email) DO NOTHING;

INSERT INTO test_products (name, price, description) VALUES
('Widget A', 10.99, 'A useful widget'),
('Gadget B', 25.50, 'An amazing gadget'),
('Tool C', 15.75, 'A handy tool')
ON CONFLICT DO NOTHING;

-- Test queries
SELECT 'Testing connection...' as message;
SELECT COUNT(*) as user_count FROM test_users;
SELECT COUNT(*) as product_count FROM test_products;

-- Show all data
SELECT * FROM test_users;
SELECT * FROM test_products;

