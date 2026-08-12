-- atividade 1

DELIMITER $$

CREATE FUNCTION calculate_item_total(
    product_price DECIMAL(10,2),
    quantity INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN product_price * quantity;
END $$

DELIMITER ;


SELECT
    oi.id AS item_id,
    p.name AS product_name,
    oi.product_price AS price,
    oi.quantity,
    calculate_item_total(oi.product_price, oi.quantity) AS total
FROM order_items oi
JOIN products p
    ON p.id = oi.product_id;

-- atividade 2

DELIMITER //

CREATE FUNCTION customer_level(
    total_spent DECIMAL(10,2)
)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    IF total_spent < 500 THEN
        RETURN 'Bronze';
    ELSEIF total_spent <= 2000 THEN
        RETURN 'Prata';
    ELSE
        RETURN 'Ouro';
    END IF;
END //

DELIMITER ;


SELECT
    c.id AS customer_id,
    c.name AS customer_name,
    SUM(o.total) AS total_spent,
    customer_level(SUM(o.total)) AS classification
FROM customers c
JOIN orders o
    ON o.customer_id = c.id
WHERE o.status = 'paid'
GROUP BY c.id, c.name;


-- atividade 3

DELIMITER //

CREATE FUNCTION calculate_order_discount(
    order_value DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    IF order_value < 200 THEN
        RETURN 0;
    ELSEIF order_value < 500 THEN
        RETURN order_value * 0.05;
    ELSEIF order_value < 1000 THEN
        RETURN order_value * 0.10;
    ELSE
        RETURN order_value * 0.15;
    END IF;
END //

DELIMITER ;


SELECT
    id AS order_id,
    total AS order_value,
    calculate_order_discount(total) AS discount
FROM orders
WHERE status = 'paid';

-- atividade 4

DELIMITER $$

CREATE FUNCTION order_items_quantity(
    p_order_id BIGINT UNSIGNED
)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_quantity BIGINT UNSIGNED;

    SELECT COALESCE(SUM(quantity), 0)
      INTO v_quantity
      FROM order_items
     WHERE order_id = p_order_id;

    RETURN v_quantity;
END$$

DELIMITER ;

SELECT
    o.id,
    o.total,
    order_items_quantity(o.id) AS items_quantity
FROM orders AS o;


-- atividade 5

DELIMITER $$

CREATE FUNCTION customer_total_spent(
    p_customer_id BIGINT UNSIGNED
)
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10, 2);

    SELECT COALESCE(SUM(total), 0.00)
      INTO v_total
      FROM orders
     WHERE customer_id = p_customer_id
       AND status = 'paid';

    RETURN v_total;
END$$

DELIMITER ;

SELECT
    c.id,
    c.name,
    customer_total_spent(c.id) AS total_spent
FROM customers AS c;