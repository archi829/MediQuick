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


