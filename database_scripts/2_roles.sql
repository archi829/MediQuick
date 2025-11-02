-- ==========================================================
-- MySQL ROLES CREATION AND PERMISSIONS
-- ==========================================================
-- This script creates roles for different user types in the MediQuick system
-- MySQL 8.0+ supports roles
-- Note: If using MySQL < 8.0, roles are not supported and you'll need to grant permissions directly to users

-- 1. Create Admin Role (Full access to all tables)
CREATE ROLE IF NOT EXISTS 'admin_role'@'localhost';
GRANT ALL PRIVILEGES ON mediquick.* TO 'admin_role'@'localhost';

-- 2. Create Customer Role (Limited access for customers)
CREATE ROLE IF NOT EXISTS 'customer_role'@'localhost';
-- Customers can view their own data
GRANT SELECT ON mediquick.Customer TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Cart TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Cart_Item TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Orders TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Sub_Order TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Order_Medicine TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Medicine TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Available_Stock TO 'customer_role'@'localhost';
GRANT SELECT ON mediquick.Pharmacy TO 'customer_role'@'localhost';
-- Customers can insert/update their own carts and orders
GRANT INSERT, UPDATE ON mediquick.Cart TO 'customer_role'@'localhost';
GRANT INSERT, UPDATE, DELETE ON mediquick.Cart_Item TO 'customer_role'@'localhost';
GRANT INSERT ON mediquick.Prescription TO 'customer_role'@'localhost';
GRANT INSERT ON mediquick.Orders TO 'customer_role'@'localhost';
GRANT INSERT ON mediquick.Order_Medicine TO 'customer_role'@'localhost';

-- 3. Create Doctor Role (Prescription verification permissions)
CREATE ROLE IF NOT EXISTS 'doctor_role'@'localhost';
-- Doctors can view prescriptions and customer info
GRANT SELECT ON mediquick.Prescription TO 'doctor_role'@'localhost';
GRANT SELECT ON mediquick.Customer TO 'doctor_role'@'localhost';
GRANT SELECT ON mediquick.Orders TO 'doctor_role'@'localhost';
-- Doctors can update prescription verification status only
GRANT UPDATE(status, assigned_doc_id, verified_at) ON mediquick.Prescription TO 'doctor_role'@'localhost';
GRANT INSERT(assigned_doc_id, verified_at) ON mediquick.Prescription TO 'doctor_role'@'localhost';

-- 4. Create Pharmacy Role (Stock and order management)
CREATE ROLE IF NOT EXISTS 'pharmacy_role'@'localhost';
-- Pharmacies can view stock, orders, and related data
GRANT SELECT ON mediquick.Available_Stock TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Sub_Order TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Orders TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Order_Medicine TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Customer TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Medicine TO 'pharmacy_role'@'localhost';
GRANT SELECT ON mediquick.Pharmacy TO 'pharmacy_role'@'localhost';
-- Pharmacies can manage their stock
GRANT INSERT, UPDATE, DELETE ON mediquick.Available_Stock TO 'pharmacy_role'@'localhost';
-- Pharmacies can update order status
GRANT UPDATE(status) ON mediquick.Sub_Order TO 'pharmacy_role'@'localhost';

-- 5. Create Delivery Agent Role (Delivery management)
CREATE ROLE IF NOT EXISTS 'agent_role'@'localhost';
-- Agents can view their assigned deliveries
GRANT SELECT ON mediquick.Sub_Order TO 'agent_role'@'localhost';
GRANT SELECT ON mediquick.Orders TO 'agent_role'@'localhost';
GRANT SELECT ON mediquick.Customer TO 'agent_role'@'localhost';
GRANT SELECT ON mediquick.Pharmacy TO 'agent_role'@'localhost';
GRANT SELECT ON mediquick.Delivery_Agent TO 'agent_role'@'localhost';
-- Agents can update delivery status
GRANT UPDATE(status) ON mediquick.Sub_Order TO 'agent_role'@'localhost';
-- Agents can update their own location and status
GRANT UPDATE(status, current_lat, current_lng, last_seen_at) ON mediquick.Delivery_Agent TO 'agent_role'@'localhost';

-- ==========================================================
-- CREATE DEFAULT ADMIN USER (for Flask app connection)
-- ==========================================================
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'adminpass123';
GRANT 'admin_role'@'localhost' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'admin_role'@'localhost' TO 'admin_user'@'localhost';

-- ==========================================================
-- FLUSH PRIVILEGES
-- ==========================================================
FLUSH PRIVILEGES;
