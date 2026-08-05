CREATE TABLE IF NOT EXISTS carts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cart_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cart_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

DROP PROCEDURE IF EXISTS Checkout_Process;

DELIMITER $$

CREATE PROCEDURE Checkout_Process(IN p_customer_id BIGINT UNSIGNED)
BEGIN
    DECLARE v_order_id BIGINT UNSIGNED;
    DECLARE v_cart_id BIGINT UNSIGNED;
    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT id INTO v_cart_id FROM carts WHERE customer_id = p_customer_id AND status = 'active' LIMIT 1;
    
    IF v_cart_id IS NOT NULL THEN
        START TRANSACTION;
        
        INSERT INTO orders (customer_id, status, paid_at, created_at, updated_at, total) 
        VALUES (p_customer_id, 'closed', NOW(), NOW(), NOW(), 0);
        
        SET v_order_id = LAST_INSERT_ID();
        
        INSERT INTO order_items (order_id, product_id, product_name, product_price, quantity, created_at, updated_at)
        SELECT 
            v_order_id, 
            ci.product_id, 
            p.name, 
            p.price, 
            ci.quantity, 
            NOW(), 
            NOW()
        FROM cart_items ci
        JOIN products p ON ci.product_id = p.id
        WHERE ci.cart_id = v_cart_id;
        
        UPDATE products p
        JOIN cart_items ci ON p.id = ci.product_id
        SET p.stock = p.stock - ci.quantity
        WHERE ci.cart_id = v_cart_id;
        
        SELECT COALESCE(SUM(product_price * quantity), 0) INTO v_total 
        FROM order_items 
        WHERE order_id = v_order_id;
        
        UPDATE orders 
        SET total = v_total
        WHERE id = v_order_id;
        
        UPDATE carts SET status = 'inativo' WHERE id = v_cart_id;
        
        DELETE FROM cart_items WHERE cart_id = v_cart_id;
        
        COMMIT;
    END IF;
    
END $$

DELIMITER ;