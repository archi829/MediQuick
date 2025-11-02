-- 1. Create an 'admin' user for your Flask App
-- RECOMMENDED: Update your app.py to use this user instead of 'root'
CREATE USER 'admin_user'@'localhost' IDENTIFIED BY 'adminpass123';
GRANT ALL PRIVILEGES ON mediquick.* TO 'admin_user'@'localhost';

-- 2. Create a 'Doctor' user (Req 2)
CREATE USER 'doc_user'@'localhost' IDENTIFIED BY 'docpass123';
-- Grant minimal permissions
GRANT SELECT ON mediquick.Prescription TO 'doc_user'@'localhost';
GRANT SELECT ON mediquick.Customer TO 'doc_user'@'localhost';
-- Grant permission to UPDATE only the verification columns [cite: 54]
GRANT UPDATE(status, assigned_doc_id, verified_at) ON mediquick.Prescription TO 'doc_user'@'localhost';

-- 3. Create a 'Pharmacy' user (Req 2)
CREATE USER 'pharm_user'@'localhost' IDENTIFIED BY 'pharmpass123';
-- Grant permissions for stock and order management
GRANT SELECT, UPDATE ON mediquick.Available_Stock TO 'pharm_user'@'localhost'; 
GRANT SELECT, UPDATE(status) ON mediquick.Sub_Order TO 'pharm_user'@'localhost';
GRANT SELECT ON mediquick.Order_Medicine TO 'pharm_user'@'localhost';

-- 4. Create a 'Delivery Agent' user (Req 2)
CREATE USER 'agent_user'@'localhost' IDENTIFIED BY 'agentpass123'; 
-- Grant permissions to view their orders and update status/location
GRANT SELECT, UPDATE(status) ON mediquick.Sub_Order TO 'agent_user'@'localhost'; 
GRANT SELECT, UPDATE(status, current_lat, current_lng) ON mediquick.Delivery_Agent TO 'agent_user'@'localhost'; 

FLUSH PRIVILEGES;