-- Procedures 

-- ========================
--   P1)Finds and assigns the best pharmacy for one item.
-- ==============================
DELIMITER $$
CREATE PROCEDURE sp_assign_single_cart_item(IN p_cart_id INT, IN p_med_id INT)
BEGIN
    -- Find customer location from cart
    DECLARE v_cust_lat DECIMAL(10,6);
    DECLARE v_cust_lng DECIMAL(10,6);
    DECLARE v_quantity INT;
    
    SELECT c.latitude, c.longitude, ci.quantity
    INTO v_cust_lat, v_cust_lng, v_quantity
    FROM Cart ca
    JOIN Customer c ON ca.cust_id = c.cust_id
    JOIN Cart_Item ci ON ca.cart_id = ci.cart_id
    WHERE ca.cart_id = p_cart_id AND ci.med_id = p_med_id
    LIMIT 1;

    -- Update the Cart_Item row with the best pharmacy
    UPDATE Cart_Item ci
    JOIN (
        -- This subquery finds the single best pharmacy
        SELECT 
            a.pharmacy_id,
            fn_simple_distance(v_cust_lat, v_cust_lng, p.latitude, p.longitude) AS dist
        FROM Available_Stock a
        JOIN Pharmacy p ON p.pharmacy_id = a.pharmacy_id
        WHERE a.med_id = p_med_id
          AND a.current_stock >= v_quantity
        ORDER BY dist ASC -- Order by distance
        LIMIT 1 -- Pick the closest one
    ) best_ph
    SET ci.assigned_pharmacy_id = best_ph.pharmacy_id
    WHERE ci.cart_id = p_cart_id AND ci.med_id = p_med_id;

    -- This procedure does NOT call sp_validate_cart_stock
END$$
DELIMITER ;

-- ========================
-- P2) Add item to cart (no total update, trigger handles it)
-- ========================
DELIMITER $$
CREATE PROCEDURE sp_add_cart_item(IN p_cart_id INT, IN p_med_id INT, IN p_qty INT)
BEGIN
    -- Step 1: Add or update the item quantity
    INSERT INTO Cart_Item(cart_id, med_id, quantity)
    VALUES (p_cart_id, p_med_id, p_qty)
    ON DUPLICATE KEY UPDATE quantity = quantity + p_qty;
    
    -- Step 2: Assign the best pharmacy for this item
    CALL sp_assign_single_cart_item(p_cart_id, p_med_id);
    
    -- This procedure does NOT call sp_validate_cart_stock
    -- The trigger will fire and update the total, that's all.
END$$
DELIMITER ;

-- ========================
--   P3) Checks if all items in the cart are still in stock at their assigned pharmacies before finalizing the order.
-- ========================

DELIMITER $$
CREATE PROCEDURE sp_validate_cart_stock(
    IN p_cart_id INT,
    IN p_cust_lat DECIMAL(10,6), -- (NEW PARAMETER)
    IN p_cust_lng DECIMAL(10,6)  -- (NEW PARAMETER)
)
BEGIN
    -- == 1. DECLARE VARIABLES ==
    DECLARE v_rows_updated INT DEFAULT 0;
    DECLARE v_failed_med_name VARCHAR(150) DEFAULT NULL;
    DECLARE v_error_message VARCHAR(512); 

    -- == 2. ATTEMPT TO FIX THE CART ==
    WITH
    BadItems AS (
        SELECT 
            ci.med_id, 
            ci.quantity, 
            ci.assigned_pharmacy_id
        FROM Cart_Item ci
        JOIN Available_Stock av 
            ON ci.med_id = av.med_id 
            AND ci.assigned_pharmacy_id = av.pharmacy_id
        -- (FIX) We no longer JOIN Cart or Customer here
        WHERE ci.cart_id = p_cart_id
          AND ci.quantity > av.current_stock
    ),
    RankedNewPharmacies AS (
        SELECT
            bi.med_id,
            a.pharmacy_id AS new_pharmacy_id,
            -- (FIX) Use the new parameters
            ROW_NUMBER() OVER(
                PARTITION BY bi.med_id 
                ORDER BY fn_simple_distance(p_cust_lat, p_cust_lng, p.latitude, p.longitude) ASC
            ) as rnk
        FROM BadItems bi
        JOIN Available_Stock a ON bi.med_id = a.med_id
        JOIN Pharmacy p ON a.pharmacy_id = p.pharmacy_id
        WHERE 
            a.current_stock >= bi.quantity
            AND a.pharmacy_id != bi.assigned_pharmacy_id
    )
    
    UPDATE Cart_Item ci
    JOIN RankedNewPharmacies rnp 
        ON ci.med_id = rnp.med_id AND ci.cart_id = p_cart_id
    SET 
        ci.assigned_pharmacy_id = rnp.new_pharmacy_id
    WHERE 
        rnp.rnk = 1;

    -- This UPDATE on Cart_Item fires the trigger.
    -- The trigger updates Cart.
    -- This is now SAFE because *this* procedure did NOT read from Cart.

    SET v_rows_updated = ROW_COUNT();

    -- == 3. CHECK FOR *UNFIXABLE* ITEMS ==
    SELECT 
        m.med_name
    INTO 
        v_failed_med_name
    FROM Cart_Item ci
    JOIN Available_Stock av 
        ON ci.med_id = av.med_id 
        AND ci.assigned_pharmacy_id = av.pharmacy_id
    JOIN Medicine m ON ci.med_id = m.med_id
    WHERE ci.cart_id = p_cart_id
      AND ci.quantity > av.current_stock
    LIMIT 1;

    -- == 4. SIGNAL ERROR (IF NEEDED) ==
    IF v_failed_med_name IS NOT NULL THEN
        SET v_error_message = CONCAT('Error: "', v_failed_med_name, 
                                     '" is out of stock at all nearby pharmacies. Please remove it from your cart to proceed to payment.');
                                     
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = v_error_message;
            
    END IF;
    
END$$

DELIMITER ;

-- ========================
--   Procedure 4
-- ========================
DELIMITER $$
CREATE PROCEDURE sp_process_cart_to_order_modular(IN p_cart_id INT)
BEGIN
    DECLARE v_cust_id INT;
    DECLARE paid_status ENUM('Pending','Paid');
    DECLARE v_final_total DECIMAL(12,2);
    DECLARE new_order_id INT;
    
    -- (NEW) Variables for customer location
    DECLARE v_cust_lat DECIMAL(10,6);
    DECLARE v_cust_lng DECIMAL(10,6);

    -- Step 1: Check payment status
    SELECT fn_check_payment_status(p_cart_id) INTO paid_status;

    IF paid_status != 'Paid' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment not completed for this cart.';
    END IF;

    -- Step 2: Get customer info AND location
    SELECT 
        ca.cust_id, 
        ca.total_amount,
        c.latitude,
        c.longitude
    INTO 
        v_cust_id, 
        v_final_total,
        v_cust_lat,
        v_cust_lng
    FROM Cart ca
    JOIN Customer c ON ca.cust_id = c.cust_id
    WHERE ca.cart_id = p_cart_id;
    
    -- Step 3: VALIDATE STOCK
    -- (FIX) Pass the location data in as parameters
    CALL sp_validate_cart_stock(p_cart_id, v_cust_lat, v_cust_lng);

    -- Step 4: Re-fetch the total, in case validation changed it.
    SELECT total_amount INTO v_final_total
    FROM Cart
    WHERE cart_id = p_cart_id;

    -- Step 5: Create a new order with the CORRECT total
    INSERT INTO Orders(cust_id, total_amount)
    VALUES (v_cust_id, v_final_total);

    SET new_order_id = LAST_INSERT_ID();

    -- Step 6: Create sub-orders
    SELECT fn_create_sub_orders(p_cart_id, new_order_id);

    -- Step 7: Insert medicines into Order_Medicine
    SELECT fn_insert_order_medicines(p_cart_id, new_order_id);

    -- Step 8: Clear the cart
    SELECT fn_clear_cart(p_cart_id);

    -- Step 9: Display summary
    SELECT 
        o.order_id,
        o.cust_id,
        o.total_amount AS order_total,
        'Order processed successfully!' AS message
    FROM Orders o
    WHERE o.order_id = new_order_id;
END$$

DELIMITER ;

-- ========================
--   P5) Assign delivery agent (uses fn_check_medicine_availability)
-- ========================
DELIMITER $$
CREATE PROCEDURE sp_assign_delivery_agent(IN p_sub_order_id INT)
BEGIN
    DECLARE assigned_agent INT;

    SELECT da.agent_id INTO assigned_agent
    FROM Delivery_Agent da
    JOIN Sub_Order so ON so.sub_order_id = p_sub_order_id
    JOIN Order_Medicine om ON om.order_id = so.order_id
    WHERE da.status = 'Available' AND fn_check_medicine_availability(om.med_id, so.pharmacy_id) > 0
    LIMIT 1;

    IF assigned_agent IS NOT NULL THEN
        UPDATE Sub_Order
        SET agent_id = assigned_agent,
            status = 'Assigned'
        WHERE sub_order_id = p_sub_order_id;

        UPDATE Delivery_Agent
        SET status = 'Busy'
        WHERE agent_id = assigned_agent;
    END IF;
END$$
DELIMITER ;

