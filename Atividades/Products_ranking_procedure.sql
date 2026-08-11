DROP PROCEDURE IF EXISTS generate_products_ranking;

DELIMITER $$

CREATE PROCEDURE generate_products_ranking(
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_limit INT,
    IN p_category_id BIGINT UNSIGNED -- Desafio: Filtro opcional por categoria (NULL para buscar em todas as categorias)
)
BEGIN
    SELECT 
        p.name AS Produto,
        SUM(oi.quantity) AS Qtde_Vendida,
        SUM(oi.product_price * oi.quantity) AS Faturamento
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN products p ON oi.product_id = p.id
    WHERE 
        DATE(o.paid_at) BETWEEN p_start_date AND p_end_date
        AND o.status = 'paid'
        -- Filtro opcional: Se p_category_id for nulo, ignora o filtro. Se tiver valor, busca somente daquela categoria
        AND (p_category_id IS NULL OR p.category_id = p_category_id)
    GROUP BY 
        p.id, 
        p.name
    ORDER BY 
        Qtde_Vendida DESC, 
        Faturamento DESC
    LIMIT p_limit;

END $$

DELIMITER ;
