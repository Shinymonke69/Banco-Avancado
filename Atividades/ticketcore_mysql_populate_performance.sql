-- ==============================================================================
-- PROJETO TICKETCORE - ETAPA 04: DESEMPENHO E OTIMIZAÇÃO
-- Arquivo: ticketcore_mysql_populate_performance.sql
-- Descrição: Procedure para gerar massa de dados volumosa (20.000 pedidos)
-- ==============================================================================

USE ticket_core;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_generate_bulk_orders$$
CREATE PROCEDURE sp_generate_bulk_orders(IN p_total INT)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_cust_id BIGINT;
    DECLARE v_esp_id BIGINT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_created DATETIME;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_order_id BIGINT;
    DECLARE v_rand_status INT;
    DECLARE v_rand_days INT;
    DECLARE v_rand_sec INT;

    SET autocommit = 0;
    SET unique_checks = 0;
    SET foreign_key_checks = 0;

    WHILE v_i <= p_total DO
        SET v_cust_id = 1 + (v_i % 4);
        SET v_esp_id = 1 + (v_i % 5);
        
        IF v_esp_id = 1 THEN SET v_price = 500.00;
        ELSEIF v_esp_id = 2 THEN SET v_price = 600.00;
        ELSEIF v_esp_id = 3 THEN SET v_price = 350.00;
        ELSEIF v_esp_id = 4 THEN SET v_price = 800.00;
        ELSE SET v_price = 150.00;
        END IF;

        SET v_rand_status = v_i % 10;
        IF v_rand_status < 7 THEN
            SET v_status = 'confirmed';
        ELSEIF v_rand_status < 9 THEN
            SET v_status = 'pending';
        ELSE
            SET v_status = 'cancelled';
        END IF;

        SET v_rand_days = v_i % 60;
        SET v_rand_sec = (v_i * 37) % 86400;
        SET v_created = DATE_SUB('2026-11-01 12:00:00', INTERVAL v_rand_days DAY) + INTERVAL v_rand_sec SECOND;

        INSERT INTO orders (customer_id, order_number, status, subtotal, discount, total, expires_at, created_at, updated_at)
        VALUES (
            v_cust_id, 
            CONCAT('BULK-', v_i, '-', FLOOR(RAND() * 1000000)),
            v_status,
            v_price,
            0.00,
            v_price,
            DATE_ADD(v_created, INTERVAL 30 MINUTE),
            v_created,
            v_created
        );
        SET v_order_id = LAST_INSERT_ID();

        INSERT INTO order_items (order_id, event_sector_price_id, quantity, unit_price, discount, total, created_at)
        VALUES (v_order_id, v_esp_id, 1, v_price, 0.00, v_price, v_created);

        IF (v_i % 1000) = 0 THEN
            COMMIT;
        END IF;

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
    SET foreign_key_checks = 1;
    SET unique_checks = 1;
    SET autocommit = 1;
END$$

DELIMITER ;

CALL sp_generate_bulk_orders(20000);
