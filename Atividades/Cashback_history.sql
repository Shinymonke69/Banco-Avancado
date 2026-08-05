CREATE TABLE cashback_history (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_id BIGINT UNSIGNED NOT NULL,
    purchase_amount DECIMAL(10, 2) NOT NULL,
    cashback_percentage DECIMAL(5, 2) NOT NULL,
    cashback_amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT cashback_history_order_unique
        UNIQUE (order_id),

    CONSTRAINT cashback_history_customer_id_foreign
        FOREIGN KEY (customer_id)
        REFERENCES customers (id),

    CONSTRAINT cashback_history_order_id_foreign
        FOREIGN KEY (order_id)
        REFERENCES orders (id)
);

DROP PROCEDURE IF EXISTS apply_order_cashback;

DELIMITER $$

CREATE PROCEDURE apply_order_cashback(IN p_order_id BIGINT UNSIGNED)
BEGIN
    DECLARE v_customer_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_purchase_amount DECIMAL(10, 2) DEFAULT 0.00;
    DECLARE v_order_status VARCHAR(25);
    DECLARE v_paid_at TIMESTAMP DEFAULT NULL;
    DECLARE v_percentage DECIMAL(5, 2);
    DECLARE v_cashback_amount DECIMAL(10, 2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT customer_id, total, status, paid_at
      INTO v_customer_id, v_purchase_amount, v_order_status, v_paid_at
      FROM orders
     WHERE id = p_order_id
       AND deleted_at IS NULL
     FOR UPDATE;

    IF v_customer_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pedido nao encontrado.';
    END IF;

    IF v_order_status <> 'paid' OR v_paid_at IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O pedido ainda nao foi pago.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cashback_history
        WHERE order_id = p_order_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O cashback deste pedido ja foi aplicado.';
    END IF;

    SET v_percentage = CASE
        WHEN v_purchase_amount <= 100.00 THEN 2.00
        WHEN v_purchase_amount <= 500.00 THEN 5.00
        ELSE 10.00
    END;

    SET v_cashback_amount = ROUND(
        v_purchase_amount * (v_percentage / 100),
        2
    );

    UPDATE customers
       SET cashback_balance = cashback_balance + v_cashback_amount,
           updated_at = CURRENT_TIMESTAMP
     WHERE id = v_customer_id;

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cliente do pedido nao encontrado.';
    END IF;

    INSERT INTO cashback_history (
        customer_id,
        order_id,
        purchase_amount,
        cashback_percentage,
        cashback_amount,
        created_at
    ) VALUES (
        v_customer_id,
        p_order_id,
        v_purchase_amount,
        v_percentage,
        v_cashback_amount,
        CURRENT_TIMESTAMP
    );

    COMMIT;

    SELECT
        p_order_id AS order_id,
        v_customer_id AS customer_id,
        v_purchase_amount AS purchase_amount,
        v_percentage AS cashback_percentage,
        v_cashback_amount AS cashback_amount;
END$$

DELIMITER ;