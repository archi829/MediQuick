-- =========================
-- 🧩 BLOCK 1: DATA POPULATION
-- =========================

-- 1️⃣ CUSTOMERS
INSERT INTO Customer (first_name, last_name, email, address_street, address_city, address_state, address_pincode, latitude, longitude)
VALUES
('Aarav', 'Sharma', 'aarav@gmail.com', '22 MG Road', 'Mumbai', 'Maharashtra', '400001', 19.0760, 72.8777),
('Priya', 'Mehta', 'priya@gmail.com', '101 Indiranagar', 'Bengaluru', 'Karnataka', '560038', 12.9716, 77.5946),
('Rahul', 'Verma', 'rahulv@gmail.com', '55 Gariahat', 'Kolkata', 'West Bengal', '700019', 22.5726, 88.3639);

-- 2️⃣ CUSTOMER PHONES
INSERT INTO Customer_Phone VALUES
(1, '9876543210'), (1, '9822221111'),
(2, '9900002233'),
(3, '9811122233');

-- 3️⃣ PHARMACIES
INSERT INTO Pharmacy (license_no, pharm_name, contact_phone, address_street, address_city, address_state, address_pincode, latitude, longitude)
VALUES
('LIC1001', 'MedLife Mumbai', '9123456789', 'Colaba Causeway', 'Mumbai', 'Maharashtra', '400005', 18.9218, 72.8330),
('LIC1002', 'HealthPlus Bengaluru', '9012345678', 'Koramangala 5th Block', 'Bengaluru', 'Karnataka', '560095', 12.9352, 77.6245),
('LIC1003', 'WellCare Kolkata', '9333344444', 'Salt Lake Sector 5', 'Kolkata', 'West Bengal', '700091', 22.5790, 88.4273);

-- 4️⃣ MEDICINES
INSERT INTO Medicine (med_name, type, description, unit, unit_size, prescription_required)
VALUES
('Paracetamol', 'Tablet', 'Pain and fever reducer', 'strip', '10 tablets', FALSE),
('Amoxicillin', 'Capsule', 'Antibiotic - bacterial infections', 'strip', '10 capsules', TRUE),
('Cetirizine', 'Tablet', 'Anti-allergic medication', 'strip', '10 tablets', FALSE),
('Insulin', 'Injection', 'Diabetes treatment', 'vial', '10ml', TRUE),
('Vitamin C', 'Tablet', 'Immunity booster', 'strip', '10 tablets', FALSE);

-- 5️⃣ MEDICINE SUBSTITUTE (recursive)
INSERT INTO Medicine_Substitute VALUES
(1, 3), (2, 4), (3, 1);

-- 6️⃣ AVAILABLE STOCK
INSERT INTO Available_Stock (pharmacy_id, med_id, current_stock, price)
VALUES
(1, 1, 50, 20.00),   -- Paracetamol in Mumbai
(1, 2, 5, 120.00),    -- Amoxicillin - edge case low stock
(1, 3, 25, 18.00),

(2, 1, 40, 22.00),
(2, 4, 10, 300.00),
(2, 5, 20, 50.00),

(3, 1, 30, 19.00),
(3, 2, 4, 110.00),    -- will trigger low-stock alert after deduction
(3, 5, 10, 45.00);

-- 7️⃣ DOCTORS
INSERT INTO Doctor (doc_name, contact_phone)
VALUES
('Dr. Suresh Iyer', '9898989898'),
('Dr. Ritu Bansal', '9876500011');

-- 8️⃣ DELIVERY AGENTS
INSERT INTO Delivery_Agent (agent_name, phone, current_lat, current_lng, status)
VALUES
('Ramesh Kumar', '9001112222', 19.08, 72.87, 'Available'),
('Sita Das', '9123344556', 12.97, 77.59, 'Available'),
('Karan Joshi', '9330093300', 22.57, 88.36, 'Offline');

-- 9️⃣ CARTS
INSERT INTO Cart (cust_id, payment_status)
VALUES
(1, 'Paid'),   -- Aarav - fully paid
(2, 'Pending'),-- Priya - unpaid (to show error)
(3, 'Paid');   -- Rahul - paid

-- 🔟 CART ITEMS
INSERT INTO Cart_Item (cart_id, med_id, quantity) VALUES
(1, 1, 2),  -- Paracetamol
(1, 2, 1),  -- Amoxicillin (needs prescription)
(1, 5, 3),  -- Vitamin C
(2, 1, 1),
(2, 4, 2),
(3, 4, 1),  -- Insulin (needs prescription)
(3, 5, 2);

-- ==========================================================
-- 🔐 USER ACCOUNTS AND MYSQL USERS WITH ROLES
-- ==========================================================
-- Note: MySQL roles must be created first (see 2_roles.sql)

-- 1️⃣ CUSTOMER USERS (3 customers)
-- Create User table entries
INSERT INTO User (username, password, role, linked_id) VALUES
('cust1@gmail.com', 'cust1', 'Customer', 1),
('cust2@gmail.com', 'cust2', 'Customer', 2),
('cust3@gmail.com', 'cust3', 'Customer', 3);

-- Create MySQL users with customer_role (using short format: role_id)
-- MySQL username limit is 32 characters, so we use: cust1, cust2, etc.
CREATE USER IF NOT EXISTS 'cust1'@'localhost' IDENTIFIED BY 'cust1';
GRANT 'customer_role'@'localhost' TO 'cust1'@'localhost';
SET DEFAULT ROLE 'customer_role'@'localhost' TO 'cust1'@'localhost';

CREATE USER IF NOT EXISTS 'cust2'@'localhost' IDENTIFIED BY 'cust2';
GRANT 'customer_role'@'localhost' TO 'cust2'@'localhost';
SET DEFAULT ROLE 'customer_role'@'localhost' TO 'cust2'@'localhost';

CREATE USER IF NOT EXISTS 'cust3'@'localhost' IDENTIFIED BY 'cust3';
GRANT 'customer_role'@'localhost' TO 'cust3'@'localhost';
SET DEFAULT ROLE 'customer_role'@'localhost' TO 'cust3'@'localhost';

-- 2️⃣ DOCTOR USERS (2 doctors)
-- Create User table entries
INSERT INTO User (username, password, role, linked_id) VALUES
('doc1@gmail.com', 'doc1', 'Doctor', 1),
('doc2@gmail.com', 'doc2', 'Doctor', 2);

-- Create MySQL users with doctor_role (using short format: role_id)
CREATE USER IF NOT EXISTS 'doc1'@'localhost' IDENTIFIED BY 'doc1';
GRANT 'doctor_role'@'localhost' TO 'doc1'@'localhost';
SET DEFAULT ROLE 'doctor_role'@'localhost' TO 'doc1'@'localhost';

CREATE USER IF NOT EXISTS 'doc2'@'localhost' IDENTIFIED BY 'doc2';
GRANT 'doctor_role'@'localhost' TO 'doc2'@'localhost';
SET DEFAULT ROLE 'doctor_role'@'localhost' TO 'doc2'@'localhost';

-- 3️⃣ PHARMACY USERS (3 pharmacies)
-- Create User table entries
INSERT INTO User (username, password, role, linked_id) VALUES
('pharm1@gmail.com', 'pharm1', 'Pharmacy', 1),
('pharm2@gmail.com', 'pharm2', 'Pharmacy', 2),
('pharm3@gmail.com', 'pharm3', 'Pharmacy', 3);

-- Create MySQL users with pharmacy_role (using short format: role_id)
CREATE USER IF NOT EXISTS 'pharm1'@'localhost' IDENTIFIED BY 'pharm1';
GRANT 'pharmacy_role'@'localhost' TO 'pharm1'@'localhost';
SET DEFAULT ROLE 'pharmacy_role'@'localhost' TO 'pharm1'@'localhost';

CREATE USER IF NOT EXISTS 'pharm2'@'localhost' IDENTIFIED BY 'pharm2';
GRANT 'pharmacy_role'@'localhost' TO 'pharm2'@'localhost';
SET DEFAULT ROLE 'pharmacy_role'@'localhost' TO 'pharm2'@'localhost';

CREATE USER IF NOT EXISTS 'pharm3'@'localhost' IDENTIFIED BY 'pharm3';
GRANT 'pharmacy_role'@'localhost' TO 'pharm3'@'localhost';
SET DEFAULT ROLE 'pharmacy_role'@'localhost' TO 'pharm3'@'localhost';

-- 4️⃣ DELIVERY AGENT USERS (3 agents)
-- Create User table entries
INSERT INTO User (username, password, role, linked_id) VALUES
('agent1@gmail.com', 'agent1', 'Agent', 1),
('agent2@gmail.com', 'agent2', 'Agent', 2),
('agent3@gmail.com', 'agent3', 'Agent', 3);

-- Create MySQL users with agent_role (using short format: role_id)
CREATE USER IF NOT EXISTS 'agent1'@'localhost' IDENTIFIED BY 'agent1';
GRANT 'agent_role'@'localhost' TO 'agent1'@'localhost';
SET DEFAULT ROLE 'agent_role'@'localhost' TO 'agent1'@'localhost';

CREATE USER IF NOT EXISTS 'agent2'@'localhost' IDENTIFIED BY 'agent2';
GRANT 'agent_role'@'localhost' TO 'agent2'@'localhost';
SET DEFAULT ROLE 'agent_role'@'localhost' TO 'agent2'@'localhost';

CREATE USER IF NOT EXISTS 'agent3'@'localhost' IDENTIFIED BY 'agent3';
GRANT 'agent_role'@'localhost' TO 'agent3'@'localhost';
SET DEFAULT ROLE 'agent_role'@'localhost' TO 'agent3'@'localhost';

-- Flush privileges to apply all changes
FLUSH PRIVILEGES;


