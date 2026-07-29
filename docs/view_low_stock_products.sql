-- Listar apenas produtos com estoque inferior a 30
CREATE OR REPLACE VIEW low_stock_products AS
SELECT
  *
FROM `products`
WHERE stock < 30
WITH CHECK OPTION;

INSERT INTO low_stock_products (
  name,
  description,
  image,
  stock,
  price,
  created_at,
  updated_at
) VALUES (
  'Product A Low Stock',
  'Desc of Product A',
  'debug-image',
  10,
  100,
  now(),
  now()
);