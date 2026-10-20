-- ==============================================================================
-- PROJETO TICKETCORE - ETAPA 01: FUNDAÇÃO
-- Arquivo: ticketcore_mysql_schema.sql
-- Descrição: Criação das tabelas relacionais com PKs, FKs, restrições e índices.
-- ==============================================================================

USE ticket_core;

-- Desabilitar temporariamente checagem de chaves estrangeiras para limpeza ordenada
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS check_ins;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS event_sector_prices;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS venues;
DROP TABLE IF EXISTS customers;

SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------------------------
-- 1. TABELA: customers (Compradores)
-- ------------------------------------------------------------------------------
CREATE TABLE customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL,
    document VARCHAR(20) NOT NULL,
    phone VARCHAR(25) NULL,
    status ENUM('active', 'inactive', 'blocked') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT uq_customers_document UNIQUE (document)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 2. TABELA: venues (Locais dos eventos)
-- ------------------------------------------------------------------------------
CREATE TABLE venues (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    capacity INT UNSIGNED NOT NULL,
    status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_venues_capacity CHECK (capacity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 3. TABELA: events (Eventos)
-- ------------------------------------------------------------------------------
CREATE TABLE events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    sales_starts_at DATETIME NOT NULL,
    sales_ends_at DATETIME NOT NULL,
    status ENUM('draft', 'published', 'cancelled', 'finished') NOT NULL DEFAULT 'draft',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_events_venue FOREIGN KEY (venue_id) REFERENCES venues(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_events_dates CHECK (ends_at >= starts_at),
    CONSTRAINT chk_events_sales_dates CHECK (sales_ends_at >= sales_starts_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_events_status_dates ON events (status, starts_at);

-- ------------------------------------------------------------------------------
-- 4. TABELA: sectors (Setores dos locais)
-- ------------------------------------------------------------------------------
CREATE TABLE sectors (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    capacity INT UNSIGNED NOT NULL,
    status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sectors_venue FOREIGN KEY (venue_id) REFERENCES venues(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_sectors_capacity CHECK (capacity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 5. TABELA: event_sector_prices (Lotes e disponibilidade)
-- ------------------------------------------------------------------------------
CREATE TABLE event_sector_prices (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT UNSIGNED NOT NULL,
    sector_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL, -- Ex: '1º Lote Meia', '1º Lote Inteira'
    price DECIMAL(10,2) NOT NULL,
    total_quantity INT UNSIGNED NOT NULL,
    available_quantity INT UNSIGNED NOT NULL,
    sales_starts_at DATETIME NOT NULL,
    sales_ends_at DATETIME NOT NULL,
    status ENUM('scheduled', 'active', 'sold_out', 'closed') NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_esp_event FOREIGN KEY (event_id) REFERENCES events(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_esp_sector FOREIGN KEY (sector_id) REFERENCES sectors(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_esp_price CHECK (price >= 0),
    CONSTRAINT chk_esp_quantity CHECK (available_quantity <= total_quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_esp_lookup ON event_sector_prices (event_id, sector_id, status);

-- ------------------------------------------------------------------------------
-- 6. TABELA: orders (Pedidos)
-- ------------------------------------------------------------------------------
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_number VARCHAR(36) NOT NULL, -- UUID ou código único do pedido
    status ENUM('pending', 'confirmed', 'cancelled', 'expired') NOT NULL DEFAULT 'pending',
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    discount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    expires_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_orders_order_number UNIQUE (order_number),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_orders_totals CHECK (total >= 0 AND discount >= 0 AND subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_orders_customer ON orders (customer_id, status);

-- ------------------------------------------------------------------------------
-- 7. TABELA: order_items (Itens do pedido)
-- ------------------------------------------------------------------------------
CREATE TABLE order_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    event_sector_price_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL, -- Congela o preço histórico pago
    discount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_items_esp FOREIGN KEY (event_sector_price_id) REFERENCES event_sector_prices(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_items_quantity CHECK (quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 8. TABELA: tickets (Ingressos individuais)
-- ------------------------------------------------------------------------------
CREATE TABLE tickets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_item_id BIGINT UNSIGNED NOT NULL,
    ticket_code VARCHAR(50) NOT NULL, -- Código de barras / hash QR code único
    holder_name VARCHAR(150) NULL,
    holder_document VARCHAR(20) NULL,
    status ENUM('issued', 'used', 'cancelled', 'refunded') NOT NULL DEFAULT 'issued',
    issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_tickets_code UNIQUE (ticket_code),
    CONSTRAINT fk_tickets_order_item FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_tickets_status ON tickets (status);

-- ------------------------------------------------------------------------------
-- 9. TABELA: payments (Pagamentos do pedido)
-- ------------------------------------------------------------------------------
CREATE TABLE payments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    transaction_reference VARCHAR(100) NULL,
    idempotency_key VARCHAR(100) NOT NULL, -- Previne cobrança/notificação duplicada
    method VARCHAR(30) NOT NULL, -- 'credit_card', 'pix', 'boleto'
    amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'cancelled', 'refunded') NOT NULL DEFAULT 'pending',
    paid_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_payments_idempotency UNIQUE (idempotency_key),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_payments_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 10. TABELA: check_ins (Controle de acesso / validação na catraca)
-- ------------------------------------------------------------------------------
CREATE TABLE check_ins (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL,
    gate VARCHAR(50) NOT NULL, -- Portão A, Catraca 3, etc.
    operator_id VARCHAR(50) NOT NULL,
    result ENUM('accepted', 'rejected') NOT NULL,
    reason VARCHAR(100) NULL, -- Ex: 'already_used', 'ticket_cancelled'
    checked_in_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_checkins_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_checkins_ticket ON check_ins (ticket_id, checked_in_at);

-- ------------------------------------------------------------------------------
-- 11. TABELA: refunds (Reembolsos)
-- ------------------------------------------------------------------------------
CREATE TABLE refunds (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payment_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'completed') NOT NULL DEFAULT 'pending',
    provider_reference VARCHAR(100) NULL,
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_refunds_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 12. TABELA: audit_logs (Auditoria do sistema)
-- ------------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL, -- Ex: 'event_sector_prices', 'orders'
    entity_id BIGINT UNSIGNED NOT NULL,
    operation ENUM('insert', 'update', 'delete') NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    actor_id VARCHAR(50) NOT NULL, -- ID do usuário ou serviço
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_audit_entity ON audit_logs (entity_type, entity_id);
