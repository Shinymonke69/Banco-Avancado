// ==============================================================================
// PROJETO TICKETCORE - ETAPA 01: FUNDAÇÃO
// Arquivo: ticketcore_mongodb_setup.js
// Descrição: Criação das coleções, validações de schema e índices no MongoDB
// ==============================================================================

const dbName = "ticket_core";
const ticketDb = db.getSiblingDB(dbName);

// ------------------------------------------------------------------------------
// 1. Coleção: customers
// Valida unicidade de email e document com índices únicos
// ------------------------------------------------------------------------------
ticketDb.createCollection("customers", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "email", "document", "status", "created_at"],
      properties: {
        name: { bsonType: "string" },
        email: { bsonType: "string" },
        document: { bsonType: "string" },
        phone: { bsonType: ["string", "null"] },
        status: { enum: ["active", "inactive", "blocked"] },
        created_at: { bsonType: "date" },
        updated_at: { bsonType: "date" }
      }
    }
  }
});
ticketDb.customers.createIndex({ email: 1 }, { unique: true });
ticketDb.customers.createIndex({ document: 1 }, { unique: true });

// ------------------------------------------------------------------------------
// 2. Coleção: venues (Incorpora setores)
// Padrão de Modelagem: Embed Sectors dentro de Venues (1:poucos)
// ------------------------------------------------------------------------------
ticketDb.createCollection("venues");
ticketDb.venues.createIndex({ name: 1 });

// ------------------------------------------------------------------------------
// 3. Coleção: events (Incorpora preços e lotes - event_sector_prices)
// Justificativa: Agilidade de consulta para a página do evento e disponibilidade
// ------------------------------------------------------------------------------
ticketDb.createCollection("events");
ticketDb.events.createIndex({ status: 1, starts_at: 1 });
ticketDb.events.createIndex({ venue_id: 1 });

// ------------------------------------------------------------------------------
// 4. Coleção: orders (Incorpora order_items e snapshot do comprador)
// Justificativa: Atomicidade do pedido e preservação histórica dos valores
// ------------------------------------------------------------------------------
ticketDb.createCollection("orders");
ticketDb.orders.createIndex({ order_number: 1 }, { unique: true });
ticketDb.orders.createIndex({ "customer.id": 1, status: 1 });

// ------------------------------------------------------------------------------
// 5. Coleção: tickets (Ingressos individuais separados por catraca e concorrência)
// Justificativa: Validação rápida e isolada na portaria com histórico de check_ins
// ------------------------------------------------------------------------------
ticketDb.createCollection("tickets");
ticketDb.tickets.createIndex({ ticket_code: 1 }, { unique: true });
ticketDb.tickets.createIndex({ order_id: 1 });
ticketDb.tickets.createIndex({ status: 1 });

// ------------------------------------------------------------------------------
// 6. Coleção: payments (Coleção separada para auditoria fiscal e idempotência)
// Justificativa: Idempotência garantida por índice único no gateway
// ------------------------------------------------------------------------------
ticketDb.createCollection("payments");
ticketDb.payments.createIndex({ idempotency_key: 1 }, { unique: true });
ticketDb.payments.createIndex({ order_id: 1 });

// ------------------------------------------------------------------------------
// 7. Coleção: audit_logs
// ------------------------------------------------------------------------------
ticketDb.createCollection("audit_logs");
ticketDb.audit_logs.createIndex({ entity_type: 1, entity_id: 1 });

// ==============================================================================
// CARGA DE DADOS INICIAIS (SEEDS COERENTES COM O CENÁRIO MYSQL)
// ==============================================================================

// Inserir Customers
ticketDb.customers.insertMany([
  {
    _id: ObjectId("670db0000000000000000001"),
    mysql_id: 1,
    name: "Carlos Eduardo Silva",
    email: "carlos.silva@email.com",
    document: "12345678901",
    phone: "11988887777",
    status: "active",
    created_at: new Date("2026-09-01T10:00:00Z"),
    updated_at: new Date("2026-09-01T10:00:00Z")
  },
  {
    _id: ObjectId("670db0000000000000000002"),
    mysql_id: 2,
    name: "Mariana Souza Santos",
    email: "mariana.souza@email.com",
    document: "98765432100",
    phone: "21977776666",
    status: "active",
    created_at: new Date("2026-09-05T14:30:00Z"),
    updated_at: new Date("2026-09-05T14:30:00Z")
  }
]);

// Inserir Venues com Setores incorporados
ticketDb.venues.insertMany([
  {
    _id: ObjectId("670db1000000000000000001"),
    mysql_id: 1,
    name: "Allianz Parque",
    address: "Av. Francisco Matarazzo, 1705 - Água Branca",
    city: "São Paulo",
    state: "SP",
    capacity: 45000,
    status: "active",
    sectors: [
      { id: 1, name: "Pista Premium", description: "Área frontal", capacity: 10000 },
      { id: 2, name: "Cadeira Inferior", description: "Assentos primeiro nível", capacity: 20000 }
    ],
    created_at: new Date("2026-08-01T10:00:00Z")
  }
]);

// Inserir Events com Lotes comerciais incorporados
ticketDb.events.insertMany([
  {
    _id: ObjectId("670db2000000000000000001"),
    mysql_id: 1,
    venue_id: ObjectId("670db1000000000000000001"),
    venue_name: "Allianz Parque",
    name: "Show Rock Legends Tour",
    description: "Apresentação exclusiva da turnê mundial de rock",
    starts_at: new Date("2026-11-20T20:00:00Z"),
    ends_at: new Date("2026-11-20T23:30:00Z"),
    sales_starts_at: new Date("2026-09-01T10:00:00Z"),
    sales_ends_at: new Date("2026-11-20T18:00:00Z"),
    status: "published",
    sector_prices: [
      {
        id: 1,
        sector_id: 1,
        sector_name: "Pista Premium",
        name: "1º Lote - Pista Premium",
        price: 500.00,
        total_quantity: 100,
        available_quantity: 0,
        status: "sold_out"
      },
      {
        id: 2,
        sector_id: 1,
        sector_name: "Pista Premium",
        name: "2º Lote - Pista Premium",
        price: 600.00,
        total_quantity: 200,
        available_quantity: 198,
        status: "active"
      }
    ],
    created_at: new Date("2026-08-15T09:00:00Z")
  }
]);

// Inserir Orders (com itens incorporados)
ticketDb.orders.insertMany([
  {
    _id: ObjectId("670db3000000000000000001"),
    mysql_id: 1,
    order_number: "ORD-2026-0001",
    customer: {
      id: ObjectId("670db0000000000000000001"),
      name: "Carlos Eduardo Silva",
      email: "carlos.silva@email.com",
      document: "12345678901"
    },
    status: "confirmed",
    subtotal: 1200.00,
    discount: 0.00,
    total: 1200.00,
    items: [
      {
        order_item_id: 1,
        event_id: ObjectId("670db2000000000000000001"),
        event_name: "Show Rock Legends Tour",
        sector_price_id: 2,
        sector_name: "Pista Premium",
        lot_name: "2º Lote - Pista Premium",
        quantity: 2,
        unit_price: 600.00,
        discount: 0.00,
        total: 1200.00
      }
    ],
    created_at: new Date("2026-10-14T20:00:00Z"),
    updated_at: new Date("2026-10-14T20:05:00Z")
  }
]);

// Inserir Tickets com histórico de check-ins embutido
ticketDb.tickets.insertMany([
  {
    _id: ObjectId("670db4000000000000000001"),
    mysql_id: 1,
    ticket_code: "TCK-RL-0001-A9F",
    order_id: ObjectId("670db3000000000000000001"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_name: "Pista Premium",
    holder_name: "Carlos Eduardo Silva",
    holder_document: "12345678901",
    status: "used",
    issued_at: new Date("2026-10-14T20:05:00Z"),
    check_ins: [
      {
        gate: "Portão B - Catraca 1",
        operator_id: "OP-ROBERTO-04",
        result: "accepted",
        reason: null,
        checked_in_at: new Date("2026-11-20T19:15:00Z")
      },
      {
        gate: "Portão B - Catraca 2",
        operator_id: "OP-MARCELA-02",
        result: "rejected",
        reason: "already_used",
        checked_in_at: new Date("2026-11-20T19:22:00Z")
      }
    ]
  },
  {
    _id: ObjectId("670db4000000000000000002"),
    mysql_id: 2,
    ticket_code: "TCK-RL-0002-B7X",
    order_id: ObjectId("670db3000000000000000001"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_name: "Pista Premium",
    holder_name: "Camila Silva",
    holder_document: "23456789012",
    status: "issued",
    issued_at: new Date("2026-10-14T20:05:00Z"),
    check_ins: []
  }
]);

// Inserir Pagamento com idempotência
ticketDb.payments.insertMany([
  {
    _id: ObjectId("670db5000000000000000001"),
    mysql_id: 1,
    order_id: ObjectId("670db3000000000000000001"),
    transaction_reference: "TX-GATEWAY-998811",
    idempotency_key: "IDEMP-20261014-0001-CC",
    method: "credit_card",
    amount: 1200.00,
    status: "approved",
    paid_at: new Date("2026-10-14T20:03:00Z"),
    created_at: new Date("2026-10-14T20:00:00Z")
  }
]);

// Inserir Auditoria com valores anteriores e novos estruturados nativamente
ticketDb.audit_logs.insertMany([
  {
    _id: ObjectId("670db6000000000000000001"),
    entity_type: "event_sector_prices",
    entity_id: 2,
    operation: "update",
    old_values: { available_quantity: 200 },
    new_values: { available_quantity: 198 },
    actor_id: "checkout-service",
    created_at: new Date("2026-10-14T20:00:00Z")
  }
]);
