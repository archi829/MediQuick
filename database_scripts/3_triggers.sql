-- TRIGGERS

/* T1) Medicine_Substitute: prevent self-substitution 
======================================================*/
DELIMITER $$
CREATE TRIGGER trg_check_medicine_substitute
BEFORE INSERT ON Medicine_Substitute
FOR EACH ROW
BEGIN
    IF NEW.med_id = NEW.substitute_med_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'med_id cannot equal substitute_med_id';
    END IF;
END$$
DELIMITER ;

/* T2) Available_Stock: low stock alert using function 
======================================================*/
DROP TRIGGER IF EXISTS trg_low_stock_alert;
DELIMITER $$
CREATE TRIGGER trg_low_stock_alert
AFTER UPDATE ON Available_Stock
FOR EACH ROW
BEGIN
    -- Use NEW.current_stock directly instead of calling function
    IF NEW.current_stock < 5 THEN
        INSERT INTO Low_Stock_Alert(pharmacy_id, med_id, stock_level, alert_time)
        VALUES (NEW.pharmacy_id, NEW.med_id, NEW.current_stock, NOW());
    END IF;
END$$
DELIMITER ;

/* T3) cart_item_after_insert: Automatically update Cart totals and prescription flag when Cart_Item table changes.
==========================================================*/
DELIMITER $$
CREATE TRIGGER trg_cart_item_after_insert
AFTER INSERT ON Cart_Item
FOR EACH ROW
BEGIN
    UPDATE Cart
    SET
        total_amount = fn_get_cart_total(NEW.cart_id),
        requires_prescription = fn_is_prescription_required(NEW.cart_id)
    WHERE cart_id = NEW.cart_id;
END$$
DELIMITER ;

/* T4) cart_item_after_update 
=============================*/
DELIMITER $$
CREATE TRIGGER trg_cart_item_after_update
AFTER UPDATE ON Cart_Item
FOR EACH ROW
BEGIN
    UPDATE Cart
    SET
        total_amount = fn_get_cart_total(NEW.cart_id),
        requires_prescription = fn_is_prescription_required(NEW.cart_id)
    WHERE cart_id = NEW.cart_id;
END$$
DELIMITER ;

/* T5) cart_item_after_delete 
=============================*/
DELIMITER $$
CREATE TRIGGER trg_cart_item_after_delete
AFTER DELETE ON Cart_Item
FOR EACH ROW
BEGIN
    UPDATE Cart
    SET
        total_amount = fn_get_cart_total(OLD.cart_id),
        requires_prescription = fn_is_prescription_required(OLD.cart_id)
    WHERE cart_id = OLD.cart_id;
END$$
DELIMITER ;












