/* 1) CUSTOMER */
CREATE TABLE Customer (
  cust_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE,
  address_street VARCHAR(150),
  address_city VARCHAR(50),
  address_state VARCHAR(50),
  address_pincode CHAR(6),
  latitude DECIMAL(10,6),
  longitude DECIMAL(10,6),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* 2) CUSTOMER_PHONE (multivalued attribute) */
CREATE TABLE Customer_Phone (
  cust_id INT NOT NULL,
  phone VARCHAR(15) NOT NULL,
  PRIMARY KEY (cust_id, phone),
  FOREIGN KEY (cust_id) REFERENCES Customer(cust_id) ON DELETE CASCADE ON UPDATE CASCADE
);

/* 3) PHARMACY */
CREATE TABLE Pharmacy (
  pharmacy_id INT AUTO_INCREMENT PRIMARY KEY,
  license_no VARCHAR(50) UNIQUE,
  pharm_name VARCHAR(100) NOT NULL,
  contact_phone VARCHAR(15),
  address_street VARCHAR(150),
  address_city VARCHAR(50),
  address_state VARCHAR(50),
  address_pincode CHAR(6),
  latitude DECIMAL(10,6),
  longitude DECIMAL(10,6),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* 4) MEDICINE */
CREATE TABLE Medicine (
  med_id INT AUTO_INCREMENT PRIMARY KEY,
  med_name VARCHAR(150) NOT NULL,
  type VARCHAR(50),
  description TEXT,
  unit VARCHAR(20),
  unit_size VARCHAR(20),
  prescription_required BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (med_name)
);

/* 5) DOCTOR */
CREATE TABLE Doctor (
  doc_id INT AUTO_INCREMENT PRIMARY KEY,
  doc_name VARCHAR(100) NOT NULL,
  contact_phone VARCHAR(15),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* 6) DELIVERY_AGENT */
CREATE TABLE Delivery_Agent (
  agent_id INT AUTO_INCREMENT PRIMARY KEY,
  agent_name VARCHAR(100) NOT NULL,
  phone VARCHAR(15),
  current_lat DECIMAL(10,6),
  current_lng DECIMAL(10,6),
  last_seen_at TIMESTAMP NULL,
  status ENUM('Available','Busy','Offline') NOT NULL DEFAULT 'Offline'
);

/* 7) AVAILABLE_STOCK (associative) */
CREATE TABLE Available_Stock (
  pharmacy_id INT NOT NULL,
  med_id INT NOT NULL,
  current_stock INT NOT NULL DEFAULT 0,
  price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (pharmacy_id, med_id),
  FOREIGN KEY (pharmacy_id) REFERENCES Pharmacy(pharmacy_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (med_id) REFERENCES Medicine(med_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (current_stock >= 0),
  CHECK (price >= 0)
);


/* 8) CART */
CREATE TABLE Cart (
  cart_id INT AUTO_INCREMENT PRIMARY KEY,
  cust_id INT NOT NULL,
  cart_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  requires_prescription BOOLEAN DEFAULT FALSE,  -- auto-calculated from items  
  prescription_status ENUM('Not Uploaded','To Be Verified','Verified','Rejected') DEFAULT 'Not Uploaded',
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  payment_status ENUM('Pending','Paid') DEFAULT 'Pending',
  FOREIGN KEY (cust_id) REFERENCES Customer(cust_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (total_amount >= 0)
);

/* 9) CART_ITEM (Associative Entity) */
CREATE TABLE Cart_Item (
  cart_id INT NOT NULL,
  med_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  assigned_pharmacy_id INT NULL,      -- for internal processng, we won't ask customer
  PRIMARY KEY (cart_id, med_id),
  FOREIGN KEY (cart_id) REFERENCES Cart(cart_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (med_id) REFERENCES Medicine(med_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CHECK (quantity >= 0)
);

/* 10) USER (auth) */
CREATE TABLE `User` (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(80) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  role ENUM('Customer','Pharmacy','Doctor','Agent') NOT NULL,
  linked_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* 11) ORDERS (parent for Sub_Order, Prescription, Order_Medicine) */
CREATE TABLE Orders (
  order_id INT AUTO_INCREMENT PRIMARY KEY,
  cust_id INT NOT NULL,
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  final_status ENUM('Processing','Partially Delivered','Delivered','Cancelled') DEFAULT 'Processing',
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  FOREIGN KEY (cust_id) REFERENCES Customer(cust_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (total_amount >= 0)
);


/* 12) SUB_ORDER (weak entity) */
CREATE TABLE Sub_Order (
  order_id INT NOT NULL,
  sub_order_id INT NOT NULL,
  pharmacy_id INT NOT NULL,
  agent_id INT NULL,
  sub_total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  status ENUM('Processing','Assigned','Shipped','Delivered','Cancelled') NOT NULL DEFAULT 'Processing',
  pickup_lat DECIMAL(10,6),
  pickup_lng DECIMAL(10,6),
  drop_lat DECIMAL(10,6),
  drop_lng DECIMAL(10,6),
  PRIMARY KEY (order_id, sub_order_id),
  FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (pharmacy_id) REFERENCES Pharmacy(pharmacy_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (agent_id) REFERENCES Delivery_Agent(agent_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CHECK (sub_total >= 0)
);

/* 13) ORDER_MEDICINE (ternary resolution) */
CREATE TABLE Order_Medicine (
   order_item_id INT AUTO_INCREMENT PRIMARY KEY,  -- unique row identifier
   order_id INT NOT NULL,
   sub_order_id INT NULL,                         -- only used if split
   med_id INT NOT NULL,
   quantity INT NOT NULL DEFAULT 1,
   price_at_order DECIMAL(10,2) NOT NULL DEFAULT 0.00,
   dosage_instructions VARCHAR(255),

   FOREIGN KEY (order_id) REFERENCES Orders(order_id)
      ON DELETE CASCADE ON UPDATE CASCADE,

   FOREIGN KEY (med_id) REFERENCES Medicine(med_id)
      ON DELETE RESTRICT ON UPDATE CASCADE,

   CHECK (quantity > 0),
   CHECK (price_at_order >= 0)
);


/* Composite FK from Order_Medicine to Sub_Order */
ALTER TABLE Order_Medicine
  ADD CONSTRAINT fk_ordermedicine_suborder
  FOREIGN KEY (order_id, sub_order_id)
  REFERENCES Sub_Order(order_id, sub_order_id)
  ON DELETE CASCADE ON UPDATE CASCADE;


/* 14) PRESCRIPTION */
CREATE TABLE Prescription (
  presc_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  cust_id INT NOT NULL,
  file_path VARCHAR(255) UNIQUE NOT NULL,
  assigned_doc_id INT NULL,
  issued_date DATE,
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status ENUM('To Be Verified','Verified','Rejected') DEFAULT 'To Be Verified',
  verified_at TIMESTAMP NULL,
  FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (cust_id) REFERENCES Customer(cust_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (assigned_doc_id) REFERENCES Doctor(doc_id) ON DELETE SET NULL ON UPDATE CASCADE
);
-- executed till here

/* 15) MEDICINE_SUBSTITUTE (recursive M:N) */
CREATE TABLE Medicine_Substitute (
  med_id INT NOT NULL,
  substitute_med_id INT NOT NULL,
  PRIMARY KEY (med_id, substitute_med_id),
  FOREIGN KEY (med_id) REFERENCES Medicine(med_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (substitute_med_id) REFERENCES Medicine(med_id) ON DELETE CASCADE ON UPDATE CASCADE
);

/* 16) Low_Stock_Alert (helper for low-stock trigger) */
CREATE TABLE Low_Stock_Alert (
  alert_id INT AUTO_INCREMENT PRIMARY KEY,
  pharmacy_id INT NOT NULL,
  med_id INT NOT NULL,
  stock_level INT NOT NULL,
  alert_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pharmacy_id) REFERENCES Pharmacy(pharmacy_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (med_id) REFERENCES Medicine(med_id) ON DELETE CASCADE ON UPDATE CASCADE
);

/* 17) SubOrder_Audit (helper for audit trigger) */
CREATE TABLE SubOrder_Audit (
  audit_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  sub_order_id INT NOT NULL,
  old_status VARCHAR(50),
  new_status VARCHAR(50),
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id, sub_order_id) REFERENCES Sub_Order(order_id, sub_order_id) ON DELETE CASCADE ON UPDATE CASCADE
);

/* 18) Useful Indexes */
CREATE INDEX idx_available_stock_med ON Available_Stock(med_id);
CREATE INDEX idx_orders_cust ON Orders(cust_id);
CREATE INDEX idx_suborder_pharm ON Sub_Order(pharmacy_id);
CREATE INDEX idx_ordermedicine_med ON Order_Medicine(med_id);

