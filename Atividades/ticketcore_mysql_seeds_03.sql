-- ==============================================================================
-- PROJETO TICKETCORE - ETAPA 03: CONSULTAS E AGREGAÇÕES
-- Arquivo: ticketcore_mysql_seeds_03.sql
-- Descrição: Carga de dados enriquecida para cobrir perfeitamente as 5 perguntas de gestão
-- ==============================================================================

USE ticket_core;

-- Garantir clientes
INSERT INTO customers (id, name, email, document, phone, status) VALUES
(1, 'Carlos Eduardo Silva', 'carlos.silva@email.com', '12345678901', '11988887777', 'active'),
(2, 'Mariana Souza Santos', 'mariana.souza@email.com', '98765432100', '21977776666', 'active'),
(3, 'Rafael Gomes Lima', 'rafael.gomes@email.com', '45678912344', '31966665555', 'active'),
(4, 'Beatriz Alves Ramos', 'beatriz.alves@email.com', '78912345600', '41955554444', 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name), status=VALUES(status);

-- Garantir locais (venues)
INSERT INTO venues (id, name, address, city, state, capacity, status) VALUES
(1, 'Allianz Parque', 'Av. Francisco Matarazzo, 1705 - Água Branca', 'São Paulo', 'SP', 45000, 'active'),
(2, 'Maracanã', 'Av. Pres. Castelo Branco, Portão 3', 'Rio de Janeiro', 'RJ', 78000, 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Garantir setores (sectors)
INSERT INTO sectors (id, venue_id, name, description, capacity, status) VALUES
(1, 1, 'Pista Premium', 'Área frontal próxima ao palco', 10000, 'active'),
(2, 1, 'Cadeira Inferior', 'Assentos numerados no primeiro nível', 20000, 'active'),
(3, 2, 'Maracanã Mais', 'Área vip com buffet e visão central', 5000, 'active'),
(4, 2, 'Arquibancada Geral', 'Setor popular central', 40000, 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Garantir eventos (events)
INSERT INTO events (id, venue_id, name, description, starts_at, ends_at, sales_starts_at, sales_ends_at, status) VALUES
(1, 1, 'Show Rock Legends Tour', 'Apresentação turnê mundial de rock', '2026-11-20 20:00:00', '2026-11-20 23:30:00', '2026-09-01 10:00:00', '2026-11-20 18:00:00', 'published'),
(2, 2, 'Final da Supercopa 2026', 'Decisão em jogo único', '2026-12-05 16:00:00', '2026-12-05 18:30:00', '2026-10-01 09:00:00', '2026-12-05 14:00:00', 'published')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Garantir lotes e disponibilidade (event_sector_prices)
-- Evento 1:
-- Lote 1 Pista Premium (total 100, disp 0, sold 100) -> 500.00
-- Lote 2 Pista Premium (total 200, disp 195, sold 5) -> 600.00
-- Lote 3 Cadeira Inferior (total 300, disp 296, sold 4) -> 350.00
-- Evento 2:
-- Lote 4 Maracanã Mais (total 50, disp 48, sold 2) -> 800.00
-- Lote 5 Arquibancada Geral (total 500, disp 490, sold 10) -> 150.00
INSERT INTO event_sector_prices (id, event_id, sector_id, name, price, total_quantity, available_quantity, sales_starts_at, sales_ends_at, status) VALUES
(1, 1, 1, '1º Lote - Pista Premium', 500.00, 100, 0, '2026-09-01 10:00:00', '2026-09-15 23:59:59', 'sold_out'),
(2, 1, 1, '2º Lote - Pista Premium', 600.00, 200, 195, '2026-09-16 00:00:00', '2026-11-20 18:00:00', 'active'),
(3, 1, 2, '1º Lote - Cadeira Inferior', 350.00, 300, 296, '2026-09-01 10:00:00', '2026-11-20 18:00:00', 'active'),
(4, 2, 3, '1º Lote - Maracanã Mais', 800.00, 50, 48, '2026-10-01 09:00:00', '2026-12-05 14:00:00', 'active'),
(5, 2, 4, '1º Lote - Arquibancada Geral', 150.00, 500, 490, '2026-10-01 09:00:00', '2026-12-05 14:00:00', 'active')
ON DUPLICATE KEY UPDATE price=VALUES(price), total_quantity=VALUES(total_quantity), available_quantity=VALUES(available_quantity), status=VALUES(status);

-- Limpar pedidos e itens antigos de teste para garantir massa consistente e idêntica
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE check_ins;
TRUNCATE TABLE tickets;
TRUNCATE TABLE payments;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
SET FOREIGN_KEY_CHECKS = 1;

-- Pedidos Coerentes:
-- Pedido 1: Carlos (Confirmado / Pago) -> 2 ingressos Pista Premium (Lote 2) = R$ 1200.00 [Show Rock]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(1, 1, 'ORD-2026-0001', 'confirmed', 1200.00, 0.00, 1200.00, '2026-10-14 20:30:00', '2026-10-14 20:00:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(1, 1, 2, 2, 600.00, 0.00, 1200.00);
INSERT INTO payments (id, order_id, transaction_reference, idempotency_key, method, amount, status, paid_at) VALUES
(1, 1, 'TX-GATEWAY-001', 'IDEMP-20261014-0001', 'credit_card', 1200.00, 'approved', '2026-10-14 20:03:00');
INSERT INTO tickets (id, order_item_id, ticket_code, holder_name, holder_document, status, issued_at) VALUES
(1, 1, 'TCK-RL-0001-A9F', 'Carlos Eduardo Silva', '12345678901', 'used', '2026-10-14 20:05:00'),
(2, 1, 'TCK-RL-0002-B7X', 'Camila Silva', '23456789012', 'issued', '2026-10-14 20:05:00');

-- Pedido 2: Carlos (Confirmado / Pago) -> 1 ingresso Pista Premium (Lote 2) = R$ 600.00 [Show Rock]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(2, 1, 'ORD-2026-0002', 'confirmed', 600.00, 0.00, 600.00, '2026-10-15 15:30:00', '2026-10-15 15:00:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(2, 2, 2, 1, 600.00, 0.00, 600.00);
INSERT INTO payments (id, order_id, transaction_reference, idempotency_key, method, amount, status, paid_at) VALUES
(2, 2, 'TX-GATEWAY-002', 'IDEMP-20261015-0002', 'pix', 600.00, 'approved', '2026-10-15 15:02:00');
INSERT INTO tickets (id, order_item_id, ticket_code, holder_name, holder_document, status, issued_at) VALUES
(3, 2, 'TCK-RL-0003-C3Z', 'Carlos Eduardo Silva', '12345678901', 'issued', '2026-10-15 15:03:00');

-- Pedido 3: Mariana (Confirmada / Paga) -> 4 ingressos Cadeira Inferior (Lote 3) = R$ 1400.00 [Show Rock]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(3, 2, 'ORD-2026-0003', 'confirmed', 1400.00, 0.00, 1400.00, '2026-10-16 11:30:00', '2026-10-16 11:00:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(3, 3, 3, 4, 350.00, 0.00, 1400.00);
INSERT INTO payments (id, order_id, transaction_reference, idempotency_key, method, amount, status, paid_at) VALUES
(3, 3, 'TX-GATEWAY-003', 'IDEMP-20261016-0003', 'credit_card', 1400.00, 'approved', '2026-10-16 11:05:00');
INSERT INTO tickets (id, order_item_id, ticket_code, holder_name, holder_document, status, issued_at) VALUES
(4, 3, 'TCK-RL-0004-D1A', 'Mariana Souza Santos', '98765432100', 'issued', '2026-10-16 11:06:00'),
(5, 3, 'TCK-RL-0005-D2B', 'Lucas Souza', '98765432101', 'issued', '2026-10-16 11:06:00'),
(6, 3, 'TCK-RL-0006-D3C', 'Felipe Santos', '98765432102', 'issued', '2026-10-16 11:06:00'),
(7, 3, 'TCK-RL-0007-D4D', 'Juliana Ramos', '98765432103', 'issued', '2026-10-16 11:06:00');

-- Pedido 4: Rafael (Confirmado / Pago) -> 2 ingressos Maracanã Mais (Lote 4) = R$ 1600.00 [Supercopa]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(4, 3, 'ORD-2026-0004', 'confirmed', 1600.00, 0.00, 1600.00, '2026-10-17 14:30:00', '2026-10-17 14:00:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(4, 4, 4, 2, 800.00, 0.00, 1600.00);
INSERT INTO payments (id, order_id, transaction_reference, idempotency_key, method, amount, status, paid_at) VALUES
(4, 4, 'TX-GATEWAY-004', 'IDEMP-20261017-0004', 'credit_card', 1600.00, 'approved', '2026-10-17 14:04:00');
INSERT INTO tickets (id, order_item_id, ticket_code, holder_name, holder_document, status, issued_at) VALUES
(8, 4, 'TCK-SC-0001-E1', 'Rafael Gomes Lima', '45678912344', 'issued', '2026-10-17 14:05:00'),
(9, 4, 'TCK-SC-0002-E2', 'Bruno Lima', '45678912345', 'issued', '2026-10-17 14:05:00');

-- Pedido 5: Beatriz (PENDENTE de pagamento) -> 2 ingressos Pista Premium (Lote 2) = R$ 1200.00 [Show Rock]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(5, 4, 'ORD-2026-0005', 'pending', 1200.00, 0.00, 1200.00, '2026-10-21 21:00:00', '2026-10-21 19:30:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(5, 5, 2, 2, 600.00, 0.00, 1200.00);
-- Sem pagamento e sem tickets emitidos pois está pendente!

-- Pedido 6: Rafael (PENDENTE de pagamento) -> 10 ingressos Arquibancada Geral (Lote 5) = R$ 1500.00 [Supercopa]
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(6, 3, 'ORD-2026-0006', 'pending', 1500.00, 0.00, 1500.00, '2026-10-21 21:15:00', '2026-10-21 19:45:00');
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(6, 6, 5, 10, 150.00, 0.00, 1500.00);
