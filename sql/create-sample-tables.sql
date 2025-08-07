-- Sample tables for CNPG backup/restore testing
-- This will create database activity and generate WAL files

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'active'
);
COMMENT ON TABLE users IS 'User management table';
COMMENT ON COLUMN users.name IS 'Full name of the user';
COMMENT ON COLUMN users.email IS 'Unique email address';

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),
    in_stock BOOLEAN DEFAULT true
);
COMMENT ON TABLE products IS 'Product catalog table';
COMMENT ON COLUMN products.name IS 'Product name';
COMMENT ON COLUMN products.price IS 'Product price in USD';

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    FOREIGN KEY (user_id) REFERENCES users(id)
);
COMMENT ON TABLE orders IS 'Customer orders table';
COMMENT ON COLUMN orders.user_id IS 'Reference to users table';

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id INT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
COMMENT ON TABLE order_items IS 'Individual items within orders';

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id INT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);
COMMENT ON TABLE categories IS 'Product categories with hierarchy support';

-- Insert sample data into users
INSERT INTO users (name, email, status) VALUES
('Alice Johnson', 'alice@example.com', 'active'),
('Bob Wilson', 'bob@example.com', 'active'),
('Charlie Brown', 'charlie@example.com', 'active'),
('Diana Prince', 'diana@example.com', 'active'),
('Eva Green', 'eva@example.com', 'inactive'),
('Frank Castle', 'frank@example.com', 'active'),
('Grace Hopper', 'grace@example.com', 'active'),
('Henry Ford', 'henry@example.com', 'active'),
('Ivy Chen', 'ivy@example.com', 'active'),
('Jack Black', 'jack@example.com', 'active')
ON CONFLICT (email) DO NOTHING;

-- Insert sample data into categories
INSERT INTO categories (name, description) VALUES
('Electronics', 'Electronic devices and gadgets'),
('Computers', 'Computers and computer accessories'),
('Smartphones', 'Mobile phones and accessories'),
('Books', 'Physical and digital books'),
('Clothing', 'Apparel and fashion items'),
('Home & Garden', 'Home improvement and gardening'),
('Sports', 'Sports equipment and gear'),
('Toys', 'Toys and games for all ages')
ON CONFLICT (name) DO NOTHING;

-- Insert sample data into products
INSERT INTO products (name, description, price, category, in_stock) VALUES
('MacBook Pro 16"', 'High-performance laptop for professionals', 2499.00, 'Computers', true),
('iPhone 15 Pro', 'Latest smartphone with advanced camera', 999.00, 'Smartphones', true),
('Dell XPS 13', 'Ultrabook with excellent display', 1299.00, 'Computers', true),
('Samsung Galaxy S24', 'Android flagship smartphone', 899.00, 'Smartphones', true),
('iPad Air', 'Versatile tablet for work and play', 599.00, 'Electronics', true),
('AirPods Pro', 'Wireless earbuds with noise cancellation', 249.00, 'Electronics', true),
('The PostgreSQL Book', 'Comprehensive guide to PostgreSQL', 49.99, 'Books', true),
('Running Shoes', 'Comfortable shoes for daily running', 129.99, 'Sports', true),
('Coffee Maker', 'Automatic drip coffee maker', 89.99, 'Home & Garden', true),
('Gaming Mouse', 'High-precision gaming mouse', 79.99, 'Computers', true)
ON CONFLICT DO NOTHING;

-- Insert sample orders (this will create more database activity)
WITH user_ids AS (
    SELECT id FROM users LIMIT 5
),
product_data AS (
    SELECT id, price FROM products LIMIT 8
)
INSERT INTO orders (user_id, total_amount, status)
SELECT 
    u.id,
    ROUND((RANDOM() * 1000 + 100)::numeric, 2),
    CASE 
        WHEN RANDOM() < 0.7 THEN 'completed'
        WHEN RANDOM() < 0.9 THEN 'pending'
        ELSE 'cancelled'
    END
FROM user_ids u
CROSS JOIN generate_series(1, 3) -- Each user gets 3 orders
ON CONFLICT DO NOTHING;

-- Insert order items
WITH order_data AS (
    SELECT id FROM orders
),
product_data AS (
    SELECT id, price FROM products
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    o.id,
    p.id,
    (RANDOM() * 3 + 1)::int,
    p.price
FROM order_data o
CROSS JOIN (
    SELECT id, price FROM product_data ORDER BY RANDOM() LIMIT 2
) p
ON CONFLICT DO NOTHING;

-- Create some indexes to generate more activity
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_create_time ON orders(create_time);

-- Generate some additional activity with updates
UPDATE products 
SET price = price * 1.1 
WHERE category = 'Electronics';

UPDATE users 
SET status = 'premium' 
WHERE id IN (SELECT id FROM users ORDER BY RANDOM() LIMIT 3);

-- Create a view for reporting
CREATE OR REPLACE VIEW order_summary AS
SELECT 
    u.name as customer_name,
    u.email,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_spent,
    MAX(o.create_time) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.name, u.email
ORDER BY total_spent DESC;

-- Show final statistics
SELECT 'Users' as table_name, COUNT(*) as record_count FROM users
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL
SELECT 'Categories', COUNT(*) FROM categories
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items', COUNT(*) FROM order_items;

-- Show some sample data
SELECT 'Sample data created successfully!' as message;
SELECT * FROM order_summary LIMIT 5;
