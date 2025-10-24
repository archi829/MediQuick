x-- Functions
-- fn 1 : cart total
-- ========================
-- ❗️ REPLACE Function 1 ❗️
-- (fn_get_cart_total)
-- ========================
DELIMITER $$
CREATE FUNCTION fn_get_cart_total(p_cart_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(12,2);
    
    -- This logic now calculates the total based on ASSIGNED pharmacies
    SELECT COALESCE(SUM(ci.quantity * s.price), 0)
    INTO total
    FROM Cart_Item ci
     JOIN Available_Stock s 
       ON ci.med_id = s.med_id
       AND ci.assigned_pharmacy_id = s.pharmacy_id -- The Key Change
    WHERE ci.cart_id = p_cart_id;

    RETURN total;
END$$
DELIMITER ;



DELIMITER $$
-- check med aval in tht pharmacy 
CREATE FUNCTION fn_check_medicine_availability(p_med_id INT, p_pharmacy_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE stock_count INT;

    SELECT IFNULL(current_stock, 0)
    INTO stock_count
    FROM Available_Stock
    WHERE med_id = p_med_id
      AND pharmacy_id = p_pharmacy_id
    LIMIT 1;

    RETURN stock_count;
END $$

DELIMITER ;

-- ==============================
-- Funtions for sp_process_cart_to_order_modular
-- ==============================
-- Simple absolute distance function
DELIMITER $$
CREATE FUNCTION fn_simple_distance(
    lat1 DECIMAL(10,6),
    lng1 DECIMAL(10,6),
    lat2 DECIMAL(10,6),
    lng2 DECIMAL(10,6)
) RETURNS DECIMAL(12,6) DETERMINISTIC
BEGIN
    RETURN ABS(lat1 - lat2) + ABS(lng1 - lng2);
END$$
DELIMITER ;


DELIMITER $$
CREATE FUNCTION fn_check_payment_status(p_cart_id INT) RETURNS ENUM('Pending','Paid') DETERMINISTIC
BEGIN
    DECLARE paid_status ENUM('Pending','Paid');
    SELECT payment_status INTO paid_status
    FROM Cart
    WHERE cart_id = p_cart_id;
    RETURN paid_status;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION fn_create_sub_orders(p_cart_id INT, p_order_id INT) RETURNS BOOLEAN DETERMINISTIC
BEGIN
    INSERT INTO Sub_Order(order_id, sub_order_id, pharmacy_id, sub_total, status)
    SELECT
        p_order_id,
        ROW_NUMBER() OVER (ORDER BY assigned_pharmacy_id) AS sub_order_id,
        assigned_pharmacy_id,
        0,
        'Processing'
    FROM Cart_Item
    WHERE cart_id = p_cart_id
    GROUP BY assigned_pharmacy_id;

    RETURN TRUE;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION fn_insert_order_medicines(p_cart_id INT, p_order_id INT) RETURNS BOOLEAN DETERMINISTIC
BEGIN
    INSERT INTO Order_Medicine(order_id, sub_order_id, med_id, quantity, price_at_order)
    SELECT
        p_order_id,
        so.sub_order_id,
        ci.med_id,
        ci.quantity,
        av.price
    FROM Cart_Item ci
    JOIN Sub_Order so ON ci.assigned_pharmacy_id = so.pharmacy_id AND so.order_id = p_order_id
    JOIN Available_Stock av ON av.med_id = ci.med_id AND av.pharmacy_id = ci.assigned_pharmacy_id
    WHERE ci.cart_id = p_cart_id;

    UPDATE Available_Stock av
    JOIN Cart_Item ci ON av.med_id = ci.med_id AND av.pharmacy_id = ci.assigned_pharmacy_id
    SET av.current_stock = av.current_stock - ci.quantity
    WHERE ci.cart_id = p_cart_id;

    UPDATE Sub_Order so
    JOIN (
        SELECT sub_order_id, SUM(quantity * price_at_order) AS total
        FROM Order_Medicine
        WHERE order_id = p_order_id
        GROUP BY sub_order_id
    ) t ON so.sub_order_id = t.sub_order_id
    SET so.sub_total = t.total
    WHERE so.order_id = p_order_id;

    RETURN TRUE;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION fn_clear_cart(p_cart_id INT) RETURNS BOOLEAN DETERMINISTIC
BEGIN
    DELETE FROM Cart_Item WHERE cart_id = p_cart_id;
    UPDATE Cart
    SET total_amount = 0, requires_prescription = FALSE
    WHERE cart_id = p_cart_id;

    RETURN TRUE;
END$$
DELIMITER ;

-- ==============================
-- Function to check if cart needs a prescription
-- ==============================
DELIMITER $$
CREATE FUNCTION fn_is_prescription_required(p_cart_id INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE v_requires_prescription BOOLEAN;
    
    SELECT EXISTS(
        SELECT 1
        FROM Cart_Item ci
        JOIN Medicine m ON ci.med_id = m.med_id
        WHERE ci.cart_id = p_cart_id
          AND m.prescription_required = TRUE
    )
    INTO v_requires_prescription;
    
    RETURN v_requires_prescription;
END$$
DELIMITER ;