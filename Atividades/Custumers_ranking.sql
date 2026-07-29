CREATE OR REPLACE VIEW customers_ranking_30d AS
SELECT
    c.id,
    c.name,
    SUM(o.total) AS total
FROM orders AS o
JOIN customers AS c
    ON c.id = o.customer_id
WHERE
    o.paid_at IS NOT NULL
    AND o.paid_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY
    c.id,
    c.name
ORDER BY
    total DESC,
    c.name ASC;
