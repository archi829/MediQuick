-- =====================================================================
-- ⚙️ SETUP: MAKE SCRIPT REPEATABLE (v2)
-- =====================================================================
-- This block resets the database to a clean state before testing.
SET SQL_SAFE_UPDATES = 0;

-- 1. Clear all transactional data
DELETE FROM Order_Medicine;
DELETE FROM Sub_Order;
DELETE FROM Orders;
DELETE FROM Cart_Item;
DELETE FROM Low_Stock_Alert;
DELETE FROM Medicine_Substitute;

-- 2. Reset cart totals (since items are deleted, triggers won't fire)
UPDATE Cart SET total_amount = 0.00, requires_prescription = 0;

-- 3. Reset stock to original values from '2 populating-block1.sql'
--    This is the corrected block:
UPDATE Available_Stock
SET current_stock = CASE 
    WHEN pharmacy_id = 1 AND med_id = 1 THEN 50 -- P1, Med 1
    WHEN pharmacy_id = 1 AND med_id = 2 THEN 5  -- P1, Med 2
    WHEN pharmacy_id = 2 AND med_id = 1 THEN 40 -- P2, Med 1 (for Test 6 re-assign)
    WHEN pharmacy_id = 3 AND med_id = 1 THEN 30 -- P3, Med 1 (THE MISSING LINE)
    ELSE current_stock
END
WHERE med_id IN (1, 2);


SET SQL_SAFE_UPDATES = 1;
-- =====================================================================


-- =====================================================================
-- NOTE: This test script assumes the database has been populated with
-- data from 3_data_population.sql, including User accounts:
-- - Customers: cust1@gmail.com, cust2@gmail.com, cust3@gmail.com (passwords: cust1, cust2, cust3)
-- - Doctors: doc1@gmail.com, doc2@gmail.com (passwords: doc1, doc2)
-- - Pharmacies: pharm1@gmail.com, pharm2@gmail.com, pharm3@gmail.com (passwords: pharm1, pharm2, pharm3)
-- - Agents: agent1@gmail.com, agent2@gmail.com, agent3@gmail.com (passwords: agent1, agent2, agent3)
-- =====================================================================

-- =====================================
-- Test 1: trg_check_medicine_substitute (UNCHANGED)
-- =====================================
-- Attempt self-substitution (should fail)
-- Expected: Error "med_id cannot equal substitute_med_id"
INSERT INTO Medicine_Substitute (med_id, substitute_med_id) VALUES (1, 1);

-- Insert a valid substitution (should succeed)
INSERT INTO Medicine_Substitute (med_id, substitute_med_id) VALUES (2, 3);

-- Verify insertion
SELECT * FROM Medicine_Substitute WHERE med_id = 2 AND substitute_med_id = 3;


-- =====================================
-- Test 2: trg_low_stock_alert (UNCHANGED)
-- =====================================
-- Step 1: Update stock below threshold to trigger alert
UPDATE Available_Stock
SET current_stock = 3
WHERE pharmacy_id = 1 AND med_id = 1;

-- Step 2: Check that alert was created
SELECT * FROM Low_Stock_Alert
WHERE pharmacy_id = 1 AND med_id = 1;

-- Reset stock for next test
UPDATE Available_Stock SET current_stock = 50 WHERE pharmacy_id = 1 AND med_id = 1;


-- =====================================
-- Test 3: Core Logic (sp_add_cart_item, Triggers, fn_get_cart_total)
-- =====================================
-- This tests the real-time assignment and pricing logic.

-- Customer 1 (Aarav) is in Mumbai (19.0760, 72.8777).
-- Pharmacy 1 (MedLife) is in Mumbai (18.9218, 72.8330) and is closest.

-- Step 1: Add Med 1 (Paracetamol) to Cart 1.
-- sp_add_cart_item will call sp_assign_single_cart_item.
-- Closest pharmacy with Med 1 is P1. Price = 20.00.
-- Trigger fires. Total = 2 * 20.00 = 40.00. Prescription = 0.
CALL sp_add_cart_item(1, 1, 2);

-- Verify Step 1:
SELECT total_amount, requires_prescription FROM Cart WHERE cart_id = 1;
SELECT * FROM Cart_Item WHERE cart_id = 1; -- Check assigned_pharmacy_id = 1

-- Step 2: Add Med 2 (Amoxicillin) to Cart 1.
-- Closest pharmacy with Med 2 is P1. Price = 120.00.
-- Trigger fires. fn_get_cart_total now sums BOTH items:
-- (2 * 20.00) + (1 * 120.00) = 40.00 + 120.00 = 160.00
-- Prescription = 1 (because Med 2 requires it).
CALL sp_add_cart_item(1, 2, 1);

-- Verify Step 2:
-- EXPECTED: 160.00, 1 (TRUE)
SELECT total_amount, requires_prescription FROM Cart WHERE cart_id = 1;
SELECT * FROM Cart_Item WHERE cart_id = 1; -- Both items assigned to P1


-- =====================================
-- Test 4: fn_check_medicine_availability (UNCHANGED)
-- =====================================
-- Check stock of Med 1 at P1 (should be 50 from reset)
select fn_check_medicine_availability(1,1); 

-- =====================================
-- Test 5: sp_process_cart_to_order_modular (Successful Order)
-- =====================================
-- This is a self-contained "happy path" test.
-- We'll use Cart 1 (Aarav, Mumbai), which is 'Paid'.
-- Pharmacy 1 (Mumbai) is closest.

-- Step 1: Add items to Cart 1.
-- P1 Price for Med 1 = 20.00
-- P1 Price for Med 2 = 120.00
CALL sp_add_cart_item(1, 1, 2); -- Qty 2, Assigns P1. Total = 40.00
CALL sp_add_cart_item(1, 2, 1); -- Qty 1, Assigns P1. Total = 40.00 + 120.00 = 160.00

-- Verify cart state before processing
SELECT * FROM Cart WHERE cart_id = 1; -- Expected Total: 160.00
SELECT * FROM Cart_Item WHERE cart_id = 1; -- Both items assigned to P1

-- Step 2: Process the order.
-- sp_validate_cart_stock will run, find all items are in stock,
-- and do nothing. The order will be created with total 160.00.
CALL sp_process_cart_to_order_modular(1);

-- Step 3: Verify the order was created correctly
SELECT * FROM Orders WHERE cust_id = 1 AND total_amount = 160.00;
SELECT * FROM Sub_Order WHERE pharmacy_id = 1;
SELECT * FROM Order_Medicine;

-- Step 4: Verify stock was deducted
-- P1 Med 1: 50 - 2 = 48
-- P1 Med 2: 5 - 1 = 4
SELECT * FROM Available_Stock WHERE pharmacy_id = 1 AND med_id IN (1, 2);

-- Step 5: Verify cart was cleared
SELECT * FROM Cart_Item WHERE cart_id = 1; -- Should be empty
SELECT * FROM Cart WHERE cart_id = 1; -- Should show 0.00, 0


-- =====================================
-- Test 6: sp_validate_cart_stock (Re-assignment Success Test)
-- =====================================
-- We simulate a "race condition" where the *first* pharmacy runs out,
-- but the procedure *finds a new pharmacy* and fixes the cart.

-- Step 1: Add item to Cart 3 (Rahul, Kolkata), which is 'Paid'.
-- Closest pharmacy with Med 1 is P3 (Kolkata). Stock=30, Price=19.00
CALL sp_add_cart_item(3, 1, 5); -- Qty 5 is fine
SELECT * FROM Cart WHERE cart_id = 3; -- Expected Total = 5 * 19.00 = 95.00
SELECT * FROM Cart_Item WHERE cart_id = 3; -- Assigned to P3

-- Step 2: Simulate stock running out at P3.
UPDATE Available_Stock SET current_stock = 2 WHERE pharmacy_id = 3 AND med_id = 1;

-- Step 3: Attempt to process the order.
CALL sp_process_cart_to_order_modular(3);

-- == VERIFICATION FOR TEST 6 ==
-- sp_validate_cart_stock should have run:
-- 1. Found Qty 5 > Stock 2 at P3.
-- 2. Searched for a new pharmacy.
-- 3. Found P2 (Bengaluru, Stock=40, Price=22.00) as the next-best.
-- 4. Re-assigned the item to P2.
-- 5. Recalculated the cart total: 5 * 22.00 = 110.00
-- 6. The main procedure continued and created the order with this NEW total.

-- Verify the order was created with the *new* total
SELECT * FROM Orders WHERE cust_id = 3 AND total_amount = 110.00;

-- Verify the sub-order was created for P2 (the new pharmacy)
SELECT * FROM Sub_Order WHERE pharmacy_id = 2;

-- Verify P3's stock was NOT touched (still 2)
SELECT * FROM Available_Stock WHERE pharmacy_id = 3 AND med_id = 1;

-- Verify P2's stock WAS deducted (40 - 5 = 35)
SELECT * FROM Available_Stock WHERE pharmacy_id = 2 AND med_id = 1;

-- Verify cart was cleared
SELECT * FROM Cart WHERE cart_id = 3; -- Should show 0.00


-- =====================================
-- Test 7: sp_validate_cart_stock (Total Failure Test)
-- =====================================
-- We simulate a "race condition" where the item is
-- out of stock EVERYWHERE.

-- Step 1: Add an item to Cart 1 (Aarav, 'Paid').
-- (Cart 1 was cleared by Test 5, so it's fresh)
-- Closest pharmacy with Med 1 is P1. Stock=48, Price=20.00
CALL sp_add_cart_item(1, 1, 10); -- Request 10 units
SELECT * FROM Cart WHERE cart_id = 1; -- Total = 10 * 20.00 = 200.00

-- Step 2: Simulate stock running out EVERYWHERE for Med 1
SET SQL_SAFE_UPDATES = 0;
UPDATE Available_Stock SET current_stock = 5 WHERE med_id = 1; -- Set all to 5
SET SQL_SAFE_UPDATES = 1;
SELECT * FROM Available_Stock WHERE med_id = 1; -- Verify all stock is 5

-- Step 3: Attempt to process the order.
-- sp_validate_cart_stock will run:
-- 1. Find Qty 10 > Stock 5 at P1.
-- 2. Try to re-assign to P2... Qty 10 > Stock 5. Fail.
-- 3. Try to re-assign to P3... Qty 10 > Stock 5. Fail.
-- 4. Throw the final error.
--
-- EXPECTED: Error "Error: "Paracetamol" is out of stock..."
CALL sp_process_cart_to_order_modular(1);

-- == VERIFICATION FOR TEST 7 ==
-- Since the call failed, the cart should NOT have been cleared,
-- and no order should have been created.
SELECT * FROM Orders WHERE cust_id = 1 AND total_amount = 200.00; -- 0 rows
SELECT * FROM Cart_Item WHERE cart_id = 1; -- 1 row (item still there)
SELECT * FROM Cart WHERE cart_id = 1; -- Total still 200.00


-- =====================================
-- Test 8: sp_assign_delivery_agent
-- =====================================
-- This test assumes Test 5 or Test 6 was successful and created a Sub_Order.
-- Let's find a sub_order_id that was created.
SET @sub_order_id = (SELECT sub_order_id FROM Sub_Order LIMIT 1);
SET @agent_id = (SELECT agent_id FROM Delivery_Agent WHERE status = 'Available' LIMIT 1);

-- Step 1: Verify agent and sub-order are unassigned
SELECT * FROM Delivery_Agent WHERE agent_id = @agent_id;
SELECT * FROM Sub_Order WHERE sub_order_id = @sub_order_id;

-- Step 2: Assign the agent
SET SQL_SAFE_UPDATES = 0;
CALL sp_assign_delivery_agent(@sub_order_id);
SET SQL_SAFE_UPDATES = 1;

-- Step 3: Verify agent is 'Busy' and sub-order is 'Assigned'
SELECT * FROM Delivery_Agent WHERE agent_id = @agent_id;
SELECT * FROM Sub_Order WHERE sub_order_id = @sub_order_id;

-- =====================================================================
-- Test 9: sp_verify_prescription (Doctor Functionality)
-- =====================================================================
-- This test relies on Test 5 having created an order for cust_id = 1.
-- We will manually insert a prescription for that order to test the
-- doctor's verification procedure.

-- Step 1: Setup - Insert a prescription to be verified.
-- (We assume Test 5 ran, creating an order for cust_id = 1)
SET @order_id_for_presc = (SELECT order_id FROM Orders WHERE cust_id = 1 LIMIT 1);
SET @cust_id_for_presc = 1;

INSERT INTO Prescription (order_id, cust_id, file_path, status)
VALUES (@order_id_for_presc, @cust_id_for_presc, '/uploads/presc_1.pdf', 'To Be Verified');

SET @test_presc_id = LAST_INSERT_ID();

-- Verify initial state
SELECT * FROM Prescription WHERE presc_id = @test_presc_id;
-- EXPECTED: status = 'To Be Verified', assigned_doc_id = NULL

-- Step 2: Test successful verification
-- We use doc_id = 1 (Dr. Suresh Iyer from data population)
-- Login credentials: username='doc1@gmail.com', password='doc1'
CALL sp_verify_prescription(@test_presc_id, 1, 'Verified');

-- Verify update
SELECT * FROM Prescription WHERE presc_id = @test_presc_id;
-- EXPECTED: status = 'Verified', assigned_doc_id = 1, verified_at is NOT NULL

-- Step 3: Test that a re-verification fails (procedure only updates 'To Be Verified')
-- Attempt to change status from 'Verified' to 'Rejected'
-- We use doc_id = 2 (Dr. Ritu Bansal from data population)
-- Login credentials: username='doc2@gmail.com', password='doc2'
CALL sp_verify_prescription(@test_presc_id, 2, 'Rejected');

-- Verify no change
SELECT * FROM Prescription WHERE presc_id = @test_presc_id;
-- EXPECTED: status = 'Verified', assigned_doc_id = 1 (no change)


-- Step 4: Test successful rejection
-- Setup
INSERT INTO Prescription (order_id, cust_id, file_path, status)
VALUES (@order_id_for_presc, @cust_id_for_presc, '/uploads/presc_2.pdf', 'To Be Verified');

SET @test_presc_id_2 = LAST_INSERT_ID();

-- Call procedure with 'Rejected'
CALL sp_verify_prescription(@test_presc_id_2, 2, 'Rejected');

-- Verify update
SELECT * FROM Prescription WHERE presc_id = @test_presc_id_2;
-- EXPECTED: status = 'Rejected', assigned_doc_id = 2, verified_at is NOT NULL

-- =====================================================================
