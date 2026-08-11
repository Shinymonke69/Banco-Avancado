CREATE TABLE IF NOT EXISTS daily_sales_summary (
    summary_date DATE PRIMARY KEY,
    total_orders INT DEFAULT 0,
    total_sales DECIMAL(15,2) DEFAULT 0.00,
    average_ticket DECIMAL(15,2) DEFAULT 0.00,
    best_selling_product VARCHAR(255),
    top_customer VARCHAR(255),
    new_customers_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS generate_daily_sales_summary;

DELIMITER $$

CREATE PROCEDURE generate_daily_sales_summary(IN p_date DATE)
BEGIN
    DECLARE v_total_orders INT DEFAULT 0;
    DECLARE v_total_sales DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_average_ticket DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_best_selling_product VARCHAR(255) DEFAULT NULL;
    DECLARE v_top_customer VARCHAR(255) DEFAULT NULL;
    DECLARE v_new_customers_count INT DEFAULT 0;

    
    SELECT 
        COUNT(id), 
        COALESCE(SUM(total), 0), 
        COALESCE(AVG(total), 0)
    INTO 
        v_total_orders, 
        v_total_sales, 
        v_average_ticket
    FROM orders
    WHERE DATE(paid_at) = p_date AND status = 'paid';

   
    SELECT p.name 
    INTO v_best_selling_product
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN products p ON oi.product_id = p.id
    WHERE DATE(o.paid_at) = p_date AND o.status = 'paid'
    GROUP BY p.id, p.name
    ORDER BY SUM(oi.quantity) DESC
    LIMIT 1;

    
    SELECT c.name 
    INTO v_top_customer
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    WHERE DATE(o.paid_at) = p_date AND o.status = 'paid'
    GROUP BY c.id, c.name
    ORDER BY SUM(o.total) DESC
    LIMIT 1;

    
    SELECT COUNT(id)
    INTO v_new_customers_count
    FROM customers
    WHERE DATE(created_at) = p_date;

    
    INSERT INTO daily_sales_summary (
        summary_date, 
        total_orders, 
        total_sales, 
        average_ticket, 
        best_selling_product, 
        top_customer, 
        new_customers_count
    ) VALUES (
        p_date,
        v_total_orders,
        v_total_sales,
        v_average_ticket,
        v_best_selling_product,
        v_top_customer,
        v_new_customers_count
    )
    ON DUPLICATE KEY UPDATE 
        total_orders = VALUES(total_orders),
        total_sales = VALUES(total_sales),
        average_ticket = VALUES(average_ticket),
        best_selling_product = VALUES(best_selling_product),
        top_customer = VALUES(top_customer),
        new_customers_count = VALUES(new_customers_count);

END $$

DELIMITER ;
