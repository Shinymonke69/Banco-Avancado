-- Listar apenas clientes ativos
CREATE OR REPLACE VIEW active_customers AS
SELECT
  id,
  name,
  phone
FROM `customers`
WHERE status = 'active';
