-- ==============================================================================
-- PROJETO TICKETCORE - ETAPA 01: FUNDAÇÃO
-- Arquivo: ticketcore_mysql_seeds.sql
-- Descrição: Carga de dados iniciais coerentes para demonstrar o fluxo completo
-- ==============================================================================

USE ticket_core;

-- 1. Inserir Compradores (customers)
INSERT INTO customers (id, name, email, document, phone, status) VALUES
(1, 'Carlos Eduardo Silva', 'carlos.silva@email.com', '12345678901', '11988887777', 'active'),
(2, 'Mariana Souza Santos', 'mariana.souza@email.com', '98765432100', '21977776666', 'active'),
(3, 'Rafael Gomes Lima', 'rafael.gomes@email.com', '45678912344', '31966665555', 'active');

-- 2. Inserir Locais (venues)
INSERT INTO venues (id, name, address, city, state, capacity, status) VALUES
(1, 'Allianz Parque', 'Av. Francisco Matarazzo, 1705 - Água Branca', 'São Paulo', 'SP', 45000, 'active'),
(2, 'Maracanã', 'Av. Pres. Castelo Branco, Portão 3', 'Rio de Janeiro', 'RJ', 78000, 'active');

-- 3. Inserir Setores dos locais (sectors)
INSERT INTO sectors (id, venue_id, name, description, capacity, status) VALUES
(1, 1, 'Pista Premium', 'Área frontal próxima ao palco', 10000, 'active'),
(2, 1, 'Cadeira Inferior', 'Assentos numerados no primeiro nível', 20000, 'active'),
(3, 2, 'Maracanã Mais', 'Área vip com buffet e visão central', 5000, 'active');

-- 4. Inserir Eventos (events)
INSERT INTO events (id, venue_id, name, description, starts_at, ends_at, sales_starts_at, sales_ends_at, status) VALUES
(1, 1, 'Show Rock Legends Tour', 'Apresentação exclusiva da turnê mundial de rock', '2026-11-20 20:00:00', '2026-11-20 23:30:00', '2026-09-01 10:00:00', '2026-11-20 18:00:00', 'published'),
(2, 2, 'Final da Supercopa 2026', 'Decisão em jogo único', '2026-12-05 16:00:00', '2026-12-05 18:30:00', '2026-10-01 09:00:00', '2026-12-05 14:00:00', 'published');

-- 5. Inserir Lotes e Preços (event_sector_prices)
-- Regra de negócio: lote 1 esgotado, lote 2 em andamento
INSERT INTO event_sector_prices (id, event_id, sector_id, name, price, total_quantity, available_quantity, sales_starts_at, sales_ends_at, status) VALUES
(1, 1, 1, '1º Lote - Pista Premium', 500.00, 100, 0, '2026-09-01 10:00:00', '2026-09-15 23:59:59', 'sold_out'),
(2, 1, 1, '2º Lote - Pista Premium', 600.00, 200, 198, '2026-09-16 00:00:00', '2026-11-20 18:00:00', 'active'),
(3, 1, 2, '1º Lote - Cadeira Inferior', 350.00, 300, 299, '2026-09-01 10:00:00', '2026-11-20 18:00:00', 'active');

-- 6. Inserir Pedido (orders) - Carlos comprou 2 ingressos da Pista Premium (Lote 2)
INSERT INTO orders (id, customer_id, order_number, status, subtotal, discount, total, expires_at, created_at) VALUES
(1, 1, 'ORD-2026-0001', 'confirmed', 1200.00, 0.00, 1200.00, '2026-10-14 20:30:00', '2026-10-14 20:00:00');

-- 7. Inserir Itens do Pedido (order_items)
INSERT INTO order_items (id, order_id, event_sector_price_id, quantity, unit_price, discount, total) VALUES
(1, 1, 2, 2, 600.00, 0.00, 1200.00);

-- 8. Inserir Ingressos Individuais (tickets) - 1 item com quantidade 2 origina 2 tickets únicos
INSERT INTO tickets (id, order_item_id, ticket_code, holder_name, holder_document, status, issued_at) VALUES
(1, 1, 'TCK-RL-0001-A9F', 'Carlos Eduardo Silva', '12345678901', 'used', '2026-10-14 20:05:00'),
(2, 1, 'TCK-RL-0002-B7X', 'Camila Silva', '23456789012', 'issued', '2026-10-14 20:05:00');

-- 9. Inserir Pagamento (payments) com chave de idempotência
INSERT INTO payments (id, order_id, transaction_reference, idempotency_key, method, amount, status, paid_at) VALUES
(1, 1, 'TX-GATEWAY-998811', 'IDEMP-20261014-0001-CC', 'credit_card', 1200.00, 'approved', '2026-10-14 20:03:00');

-- 10. Inserir Tentativas de Check-in (check_ins)
-- O ingresso 1 entrou com sucesso. O mesmo ingresso tenta entrar de novo e é rejeitado!
INSERT INTO check_ins (id, ticket_id, gate, operator_id, result, reason, checked_in_at) VALUES
(1, 1, 'Portão B - Catraca 1', 'OP-ROBERTO-04', 'accepted', NULL, '2026-11-20 19:15:00'),
(2, 1, 'Portão B - Catraca 2', 'OP-MARCELA-02', 'rejected', 'already_used', '2026-11-20 19:22:00');

-- 11. Inserir Auditoria (audit_logs)
INSERT INTO audit_logs (id, entity_type, entity_id, operation, old_values, new_values, actor_id, created_at) VALUES
(1, 'event_sector_prices', 2, 'update', JSON_OBJECT('available_quantity', 200), JSON_OBJECT('available_quantity', 198), 'checkout-service', '2026-10-14 20:00:00');
