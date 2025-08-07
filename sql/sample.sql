-- Simple DDL for testing the app database connection
-- Run this after connecting: kubectl exec cluster-example-1 -it -- psql -U postgres

-- Simple users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (name, email) VALUES
('Alice Johnson', 'alice@test.com'),
('Bob Wilson', 'bob@test.com'),
('Charlie Brown', 'charlie@test.com'),
('David Smith', 'david@test.com'),
('Eva Green', 'eva@test.com'),
('Frank Lee', 'frank@test.com'),
('Grace Kim', 'grace@test.com'),
('Henry Ford', 'henry@test.com'),
('Ivy Chen', 'ivy@test.com'),
('Jack Black', 'jack@test.com'),
('Karen White', 'karen@test.com'),
('Liam Young', 'liam@test.com'),
('Mona Patel', 'mona@test.com'),
('SATO Naoki', 'naoki@test.com'),
('TANAKA Yuki', 'yuki@test.com'),
('SUZUKI Haruka', 'haruka@test.com'),
('YAMAMOTO Kenta', 'kenta@test.com'),
('KOBAYASHI Sakura', 'sakura@test.com'),
('NAKAMURA Taro', 'taro@test.com'),
('WATANABE Emi', 'emi@test.com'),
('TAKAHASHI Ryo', 'ryo@test.com'),
('MATSUMOTO Aya', 'aya@test.com'),
('FUJITA Shota', 'shota@test.com')
ON CONFLICT (email) DO NOTHING;

-- Test queries
SELECT 'Testing connection...' as message;
SELECT COUNT(*) as user_count FROM users;

-- Show all data
SELECT * FROM users;

