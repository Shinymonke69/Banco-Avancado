// ==============================================================================
// PROJETO TICKETCORE - ETAPA 03: CONSULTAS E AGREGAÇÕES
// Arquivo: ticketcore_mongodb_seeds_03.js
// Descrição: Carga de dados no MongoDB idêntica à massa lógica do MySQL
// ==============================================================================

const dbName = "ticket_core";
const ticketDb = db.getSiblingDB(dbName);

// 1. Limpar coleções para sincronizar com a massa nova
ticketDb.orders.deleteMany({});
ticketDb.tickets.deleteMany({});
ticketDb.payments.deleteMany({});
ticketDb.events.deleteMany({});
ticketDb.venues.deleteMany({});
ticketDb.customers.deleteMany({});

// 2. Customers
ticketDb.customers.insertMany([
  {
    _id: ObjectId("670db0000000000000000001"),
    mysql_id: 1,
    name: "Carlos Eduardo Silva",
    email: "carlos.silva@email.com",
    document: "12345678901",
    phone: "11988887777",
    status: "active",
    created_at: new Date("2026-09-01T10:00:00Z")
  },
  {
    _id: ObjectId("670db0000000000000000002"),
    mysql_id: 2,
    name: "Mariana Souza Santos",
    email: "mariana.souza@email.com",
    document: "98765432100",
    phone: "21977776666",
    status: "active",
    created_at: new Date("2026-09-05T14:30:00Z")
  },
  {
    _id: ObjectId("670db0000000000000000003"),
    mysql_id: 3,
    name: "Rafael Gomes Lima",
    email: "rafael.gomes@email.com",
    document: "45678912344",
    phone: "31966665555",
    status: "active",
    created_at: new Date("2026-09-10T09:15:00Z")
  },
  {
    _id: ObjectId("670db0000000000000000004"),
    mysql_id: 4,
    name: "Beatriz Alves Ramos",
    email: "beatriz.alves@email.com",
    document: "78912345600",
    phone: "41955554444",
    status: "active",
    created_at: new Date("2026-10-01T12:00:00Z")
  }
]);

// 3. Venues com setores embutidos
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
      { id: 1, name: "Pista Premium", capacity: 10000 },
      { id: 2, name: "Cadeira Inferior", capacity: 20000 }
    ]
  },
  {
    _id: ObjectId("670db1000000000000000002"),
    mysql_id: 2,
    name: "Maracanã",
    address: "Av. Pres. Castelo Branco, Portão 3",
    city: "Rio de Janeiro",
    state: "RJ",
    capacity: 78000,
    status: "active",
    sectors: [
      { id: 3, name: "Maracanã Mais", capacity: 5000 },
      { id: 4, name: "Arquibancada Geral", capacity: 40000 }
    ]
  }
]);

// 4. Events com Lotes comerciais embutidos
ticketDb.events.insertMany([
  {
    _id: ObjectId("670db2000000000000000001"),
    mysql_id: 1,
    venue_id: ObjectId("670db1000000000000000001"),
    venue_name: "Allianz Parque",
    name: "Show Rock Legends Tour",
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
        available_quantity: 195,
        status: "active"
      },
      {
        id: 3,
        sector_id: 2,
        sector_name: "Cadeira Inferior",
        name: "1º Lote - Cadeira Inferior",
        price: 350.00,
        total_quantity: 300,
        available_quantity: 296,
        status: "active"
      }
    ]
  },
  {
    _id: ObjectId("670db2000000000000000002"),
    mysql_id: 2,
    venue_id: ObjectId("670db1000000000000000002"),
    venue_name: "Maracanã",
    name: "Final da Supercopa 2026",
    starts_at: new Date("2026-12-05T16:00:00Z"),
    ends_at: new Date("2026-12-05T18:30:00Z"),
    sales_starts_at: new Date("2026-10-01T09:00:00Z"),
    sales_ends_at: new Date("2026-12-05T14:00:00Z"),
    status: "published",
    sector_prices: [
      {
        id: 4,
        sector_id: 3,
        sector_name: "Maracanã Mais",
        name: "1º Lote - Maracanã Mais",
        price: 800.00,
        total_quantity: 50,
        available_quantity: 48,
        status: "active"
      },
      {
        id: 5,
        sector_id: 4,
        sector_name: "Arquibancada Geral",
        name: "1º Lote - Arquibancada Geral",
        price: 150.00,
        total_quantity: 500,
        available_quantity: 490,
        status: "active"
      }
    ]
  }
]);

// 5. Orders (6 pedidos: 4 confirmados e 2 pendentes)
ticketDb.orders.insertMany([
  // Pedido 1: Carlos (Confirmado)
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
        sector_id: 1,
        sector_name: "Pista Premium",
        sector_price_id: 2,
        lot_name: "2º Lote - Pista Premium",
        quantity: 2,
        unit_price: 600.00,
        total: 1200.00
      }
    ],
    created_at: new Date("2026-10-14T20:00:00Z"),
    updated_at: new Date("2026-10-14T20:03:00Z")
  },
  // Pedido 2: Carlos (Confirmado)
  {
    _id: ObjectId("670db3000000000000000002"),
    mysql_id: 2,
    order_number: "ORD-2026-0002",
    customer: {
      id: ObjectId("670db0000000000000000001"),
      name: "Carlos Eduardo Silva",
      email: "carlos.silva@email.com",
      document: "12345678901"
    },
    status: "confirmed",
    subtotal: 600.00,
    discount: 0.00,
    total: 600.00,
    items: [
      {
        order_item_id: 2,
        event_id: ObjectId("670db2000000000000000001"),
        event_name: "Show Rock Legends Tour",
        sector_id: 1,
        sector_name: "Pista Premium",
        sector_price_id: 2,
        lot_name: "2º Lote - Pista Premium",
        quantity: 1,
        unit_price: 600.00,
        total: 600.00
      }
    ],
    created_at: new Date("2026-10-15T15:00:00Z"),
    updated_at: new Date("2026-10-15T15:02:00Z")
  },
  // Pedido 3: Mariana (Confirmada)
  {
    _id: ObjectId("670db3000000000000000003"),
    mysql_id: 3,
    order_number: "ORD-2026-0003",
    customer: {
      id: ObjectId("670db0000000000000000002"),
      name: "Mariana Souza Santos",
      email: "mariana.souza@email.com",
      document: "98765432100"
    },
    status: "confirmed",
    subtotal: 1400.00,
    discount: 0.00,
    total: 1400.00,
    items: [
      {
        order_item_id: 3,
        event_id: ObjectId("670db2000000000000000001"),
        event_name: "Show Rock Legends Tour",
        sector_id: 2,
        sector_name: "Cadeira Inferior",
        sector_price_id: 3,
        lot_name: "1º Lote - Cadeira Inferior",
        quantity: 4,
        unit_price: 350.00,
        total: 1400.00
      }
    ],
    created_at: new Date("2026-10-16T11:00:00Z"),
    updated_at: new Date("2026-10-16T11:05:00Z")
  },
  // Pedido 4: Rafael (Confirmado)
  {
    _id: ObjectId("670db3000000000000000004"),
    mysql_id: 4,
    order_number: "ORD-2026-0004",
    customer: {
      id: ObjectId("670db0000000000000000003"),
      name: "Rafael Gomes Lima",
      email: "rafael.gomes@email.com",
      document: "45678912344"
    },
    status: "confirmed",
    subtotal: 1600.00,
    discount: 0.00,
    total: 1600.00,
    items: [
      {
        order_item_id: 4,
        event_id: ObjectId("670db2000000000000000002"),
        event_name: "Final da Supercopa 2026",
        sector_id: 3,
        sector_name: "Maracanã Mais",
        sector_price_id: 4,
        lot_name: "1º Lote - Maracanã Mais",
        quantity: 2,
        unit_price: 800.00,
        total: 1600.00
      }
    ],
    created_at: new Date("2026-10-17T14:00:00Z"),
    updated_at: new Date("2026-10-17T14:04:00Z")
  },
  // Pedido 5: Beatriz (PENDENTE)
  {
    _id: ObjectId("670db3000000000000000005"),
    mysql_id: 5,
    order_number: "ORD-2026-0005",
    customer: {
      id: ObjectId("670db0000000000000000004"),
      name: "Beatriz Alves Ramos",
      email: "beatriz.alves@email.com",
      document: "78912345600"
    },
    status: "pending",
    subtotal: 1200.00,
    discount: 0.00,
    total: 1200.00,
    items: [
      {
        order_item_id: 5,
        event_id: ObjectId("670db2000000000000000001"),
        event_name: "Show Rock Legends Tour",
        sector_id: 1,
        sector_name: "Pista Premium",
        sector_price_id: 2,
        lot_name: "2º Lote - Pista Premium",
        quantity: 2,
        unit_price: 600.00,
        total: 1200.00
      }
    ],
    created_at: new Date("2026-10-21T19:30:00Z"),
    updated_at: new Date("2026-10-21T19:30:00Z")
  },
  // Pedido 6: Rafael (PENDENTE)
  {
    _id: ObjectId("670db3000000000000000006"),
    mysql_id: 6,
    order_number: "ORD-2026-0006",
    customer: {
      id: ObjectId("670db0000000000000000003"),
      name: "Rafael Gomes Lima",
      email: "rafael.gomes@email.com",
      document: "45678912344"
    },
    status: "pending",
    subtotal: 1500.00,
    discount: 0.00,
    total: 1500.00,
    items: [
      {
        order_item_id: 6,
        event_id: ObjectId("670db2000000000000000002"),
        event_name: "Final da Supercopa 2026",
        sector_id: 4,
        sector_name: "Arquibancada Geral",
        sector_price_id: 5,
        lot_name: "1º Lote - Arquibancada Geral",
        quantity: 10,
        unit_price: 150.00,
        total: 1500.00
      }
    ],
    created_at: new Date("2026-10-21T19:45:00Z"),
    updated_at: new Date("2026-10-21T19:45:00Z")
  }
]);

// 6. Tickets individuais emitidos para os pedidos confirmados
ticketDb.tickets.insertMany([
  {
    _id: ObjectId("670db4000000000000000001"),
    ticket_code: "TCK-RL-0001-A9F",
    order_id: ObjectId("670db3000000000000000001"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 1,
    sector_name: "Pista Premium",
    holder_name: "Carlos Eduardo Silva",
    holder_document: "12345678901",
    status: "used",
    issued_at: new Date("2026-10-14T20:05:00Z"),
    check_ins: [{ gate: "Portão B - Catraca 1", operator_id: "OP-01", result: "accepted", reason: null, checked_in_at: new Date("2026-11-20T19:15:00Z") }]
  },
  {
    _id: ObjectId("670db4000000000000000002"),
    ticket_code: "TCK-RL-0002-B7X",
    order_id: ObjectId("670db3000000000000000001"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 1,
    sector_name: "Pista Premium",
    holder_name: "Camila Silva",
    holder_document: "23456789012",
    status: "issued",
    issued_at: new Date("2026-10-14T20:05:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000003"),
    ticket_code: "TCK-RL-0003-C3Z",
    order_id: ObjectId("670db3000000000000000002"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 1,
    sector_name: "Pista Premium",
    holder_name: "Carlos Eduardo Silva",
    holder_document: "12345678901",
    status: "issued",
    issued_at: new Date("2026-10-15T15:03:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000004"),
    ticket_code: "TCK-RL-0004-D1A",
    order_id: ObjectId("670db3000000000000000003"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 2,
    sector_name: "Cadeira Inferior",
    holder_name: "Mariana Souza Santos",
    holder_document: "98765432100",
    status: "issued",
    issued_at: new Date("2026-10-16T11:06:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000005"),
    ticket_code: "TCK-RL-0005-D2B",
    order_id: ObjectId("670db3000000000000000003"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 2,
    sector_name: "Cadeira Inferior",
    holder_name: "Lucas Souza",
    holder_document: "98765432101",
    status: "issued",
    issued_at: new Date("2026-10-16T11:06:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000006"),
    ticket_code: "TCK-RL-0006-D3C",
    order_id: ObjectId("670db3000000000000000003"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 2,
    sector_name: "Cadeira Inferior",
    holder_name: "Felipe Santos",
    holder_document: "98765432102",
    status: "issued",
    issued_at: new Date("2026-10-16T11:06:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000007"),
    ticket_code: "TCK-RL-0007-D4D",
    order_id: ObjectId("670db3000000000000000003"),
    event_id: ObjectId("670db2000000000000000001"),
    sector_id: 2,
    sector_name: "Cadeira Inferior",
    holder_name: "Juliana Ramos",
    holder_document: "98765432103",
    status: "issued",
    issued_at: new Date("2026-10-16T11:06:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000008"),
    ticket_code: "TCK-SC-0001-E1",
    order_id: ObjectId("670db3000000000000000004"),
    event_id: ObjectId("670db2000000000000000002"),
    sector_id: 3,
    sector_name: "Maracanã Mais",
    holder_name: "Rafael Gomes Lima",
    holder_document: "45678912344",
    status: "issued",
    issued_at: new Date("2026-10-17T14:05:00Z"),
    check_ins: []
  },
  {
    _id: ObjectId("670db4000000000000000009"),
    ticket_code: "TCK-SC-0002-E2",
    order_id: ObjectId("670db3000000000000000004"),
    event_id: ObjectId("670db2000000000000000002"),
    sector_id: 3,
    sector_name: "Maracanã Mais",
    holder_name: "Bruno Lima",
    holder_document: "45678912345",
    status: "issued",
    issued_at: new Date("2026-10-17T14:05:00Z"),
    check_ins: []
  }
]);

print(">>> [MongoDB] Carga de dados enriquecida para a etapa 03 concluída com sucesso!");
