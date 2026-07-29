CREATE OR REPLACE VIEW orders_paid_on_current_month AS
SELECT
    id,
    paid_at,
    total
FROM orders
WHERE
    paid_at IS NOT NULL
    AND paid_at >= DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
    AND paid_at < DATE_ADD(
        DATE_FORMAT(CURRENT_DATE, '%Y-%m-01'),
        INTERVAL 1 MONTH
    );
