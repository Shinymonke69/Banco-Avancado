CREATE OR REPLACE VIEW customers_orders_summary AS
SELECT
    c.id,
    c.name,
    COUNT(o.id) AS orders,
    SUM(o.total) AS total_spent,
    AVG(o.total) AS average_ticket
FROM customers AS c
JOIN orders AS o
    ON c.id = o.customer_id
WHERE
    o.status = "paid" 
GROUP BY
    c.id,
    c.name;
