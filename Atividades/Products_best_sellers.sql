CREATE OR REPLACE VIEW products_best_sellers_24h AS
SELECT
    p.id,
    p.name,
    SUM(oi.quantity) AS quantity
FROM order_items AS oi
JOIN orders AS o
    ON o.id = oi.order_id
JOIN products AS p
    ON p.id = oi.product_id
WHERE
    o.paid_at IS NOT NULL
    AND o.paid_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY
    p.id,
    p.name
ORDER BY
    quantity DESC,
    p.name ASC;

SELECT *
FROM products_best_sellers_24h;