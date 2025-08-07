-- Simple DDL for testing the app database connection
-- Run this after connecting: kubectl exec example1-1 -it -- psql -U postgres

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

-- ==== USER PERMISSIONS QUERIES ====

-- 1. List all users with their basic attributes
SELECT 
    usename as username,
    usesuper as is_superuser,
    usecreatedb as can_create_db,
    usecreatererole as can_create_role,
    userepl as can_replicate,
    usebypassrls as can_bypass_rls,
    passwd as has_password,
    valuntil as password_expires
FROM pg_user
ORDER BY usename;

-- 2. Check all table privileges for all users
SELECT 
    grantee as username,
    table_schema,
    table_name,
    privilege_type,
    is_grantable,
    grantor
FROM information_schema.table_privileges 
WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
ORDER BY grantee, table_schema, table_name, privilege_type;

-- 3. Check schema privileges for all users
SELECT 
    grantee as username,
    schema_name,
    privilege_type,
    is_grantable,
    grantor
FROM information_schema.schema_privileges 
WHERE schema_name NOT IN ('information_schema', 'pg_catalog')
ORDER BY grantee, schema_name, privilege_type;

-- 4. Check database privileges for all users
SELECT 
    datacl as database_privileges,
    datname as database_name
FROM pg_database 
WHERE datname = current_database();

-- 5. Check role memberships (which users belong to which roles)
SELECT 
    member.rolname as member_user,
    role.rolname as role_name,
    grantor.rolname as granted_by,
    admin_option
FROM pg_auth_members am
JOIN pg_roles role ON role.oid = am.roleid
JOIN pg_roles member ON member.oid = am.member
JOIN pg_roles grantor ON grantor.oid = am.grantor
ORDER BY member_user, role_name;

-- 6. Check effective permissions on all tables for each user
SELECT 
    u.usename as username,
    t.schemaname,
    t.tablename,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'SELECT') as can_select,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'INSERT') as can_insert,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'UPDATE') as can_update,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'DELETE') as can_delete,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'TRUNCATE') as can_truncate,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'REFERENCES') as can_reference,
    has_table_privilege(u.usename, t.schemaname||'.'||t.tablename, 'TRIGGER') as can_trigger
FROM pg_user u
CROSS JOIN pg_tables t 
WHERE t.schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY username, schemaname, tablename;

-- 7. Summary view: Users and their key permissions
SELECT 
    u.usename as username,
    u.usesuper as is_superuser,
    COUNT(DISTINCT tp.table_name) as tables_with_privileges,
    STRING_AGG(DISTINCT tp.privilege_type, ', ') as table_privileges,
    STRING_AGG(DISTINCT sp.privilege_type, ', ') as schema_privileges
FROM pg_user u
LEFT JOIN information_schema.table_privileges tp ON tp.grantee = u.usename 
    AND tp.table_schema NOT IN ('information_schema', 'pg_catalog')
LEFT JOIN information_schema.schema_privileges sp ON sp.grantee = u.usename
    AND sp.schema_name NOT IN ('information_schema', 'pg_catalog')
GROUP BY u.usename, u.usesuper
ORDER BY u.usename;

ALTER USER app WITH SUPERUSER;