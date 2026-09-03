SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.email,
    COUNT(o.id) AS total_orders,
    SUM(o.total) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE c.status = 'active'
  AND (o.status = 'paid' OR o.status IS NULL)
  AND o.deleted_at IS NULL
GROUP BY c.id, c.name, c.email
HAVING total_spent > 500
ORDER BY total_spent DESC;