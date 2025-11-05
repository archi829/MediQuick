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

-- ========================
--   P6) Doctor verifies prescription 
-- ========================
DELIMITER $$
CREATE PROCEDURE sp_verify_prescription(
    IN p_presc_id INT,
    IN p_doc_id INT,
    IN p_new_status ENUM('Verified', 'Rejected')
)
BEGIN
    UPDATE Prescription
    SET
        status = p_new_status,
        assigned_doc_id = p_doc_id, -- Assign the doctor who verified it [cite: 34]
        verified_at = CURRENT_TIMESTAMP
    WHERE
        presc_id = p_presc_id
        AND status = 'To Be Verified'; -- Only update unverified ones [cite: 37]
    
    SELECT ROW_COUNT() AS rows_updated;
END$$
DELIMITER ;



-- =========================
-- P7) Update Payment Status
--     Called after front-end "Pay" button is clicked.
-- =========================
DELIMITER $$
CREATE PROCEDURE sp_update_payment_status(IN p_cust_id INT)
BEGIN
    -- Find the active cart for the customer and set status to Paid
    UPDATE Cart
    SET payment_status = 'Paid'
    WHERE cust_id = p_cust_id; 
    
    -- NOTE: The calling API must handle the success/error reporting.
    -- This procedure assumes the cart exists.
END$$
DELIMITER ;




-- =========================
--   P8) Admin Assign Agent (Admin View Wrapper)
--       This procedure handles the (order_id, sub_order_id) compound key
--       and calls the core assignment logic.
-- =======================
DELIMITER $$
CREATE PROCEDURE sp_admin_assign_agent(
    IN p_order_id INT,
    IN p_sub_order_id INT
)
BEGIN
    -- This procedure acts as a wrapper for the existing logic, 
    -- primarily to facilitate front-end/API calls using the composite key.
    
    -- Check if the sub-order exists and is in the 'Processing' status
    DECLARE v_current_status ENUM('Processing','Assigned','Shipped','Delivered','Cancelled');
    
    SELECT status INTO v_current_status
    FROM Sub_Order
    WHERE order_id = p_order_id AND sub_order_id = p_sub_order_id;
    
    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sub-Order not found.';
    END IF;
    
--    IF v_current_status != 'Processing' THEN
--        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = CONCAT('Cannot assign agent. Sub-Order is already in status: ', v_current_status);
--    END IF;
    
    -- Call the core assignment logic which finds an available agent
    -- NOTE: Your existing core procedure is sp_assign_delivery_agent(IN p_sub_order_id INT)
    -- We pass the sub_order_id. We need to ensure the existing procedure logic works for the sub_order_id in isolation.
    
    -- *** This is the critical step ***
    CALL sp_assign_delivery_agent(p_sub_order_id);
    
    -- Check if the assignment was successful by looking up the new status
    SELECT status INTO v_current_status
    FROM Sub_Order
    WHERE order_id = p_order_id AND sub_order_id = p_sub_order_id;
    
    IF v_current_status = 'Assigned' THEN
        SELECT CONCAT('Successfully assigned agent to Sub-Order #', p_sub_order_id) AS message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available delivery agents or order not ready for assignment.';
    END IF;

END$$
DELIMITER ;








-- DUMMY CODE: Must be added to 6_procedures.sql for system function
DELIMITER $$
CREATE PROCEDURE sp_complete_delivery(IN p_order_id INT, IN p_sub_order_id INT)
BEGIN
    DECLARE v_agent_id INT;

    -- 1. Get the agent assigned to the sub-order
    SELECT agent_id INTO v_agent_id
    FROM Sub_Order
    WHERE order_id = p_order_id AND sub_order_id = p_sub_order_id;

    -- 2. Mark the Sub-Order as Delivered
    UPDATE Sub_Order
    SET status = 'Delivered'
    WHERE order_id = p_order_id AND sub_order_id = p_sub_order_id;

    -- 3. Update the agent's status from 'Busy' to 'Available'
    IF v_agent_id IS NOT NULL THEN
        UPDATE Delivery_Agent
        SET status = 'Available'
        WHERE agent_id = v_agent_id;
    END IF;
    
    -- (A trigger would typically update the parent Orders table status here)
END$$
DELIMITER ;