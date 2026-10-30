// ==============================================================================
// PROJETO TICKETCORE - ETAPA 04: DESEMPENHO E OTIMIZAÇÃO
// Arquivo: ticketcore_mongodb_populate_performance.js
// Descrição: Inserção de 20.000 documentos na coleção orders do MongoDB
// ==============================================================================

const dbName = "ticket_core";
const ticketDb = db.getSiblingDB(dbName);

const customers = [
  { id: ObjectId("670db0000000000000000001"), name: "Carlos Eduardo Silva", email: "carlos.silva@email.com", document: "12345678901" },
  { id: ObjectId("670db0000000000000000002"), name: "Mariana Souza Santos", email: "mariana.souza@email.com", document: "98765432100" },
  { id: ObjectId("670db0000000000000000003"), name: "Rafael Gomes Lima", email: "rafael.gomes@email.com", document: "45678912344" },
  { id: ObjectId("670db0000000000000000004"), name: "Beatriz Alves Ramos", email: "beatriz.alves@email.com", document: "78912345600" }
];

const eventsData = [
  { event_id: ObjectId("670db2000000000000000001"), event_name: "Show Rock Legends Tour", sector_id: 1, sector_name: "Pista Premium", sector_price_id: 1, lot_name: "1º Lote - Pista Premium", price: 500.00 },
  { event_id: ObjectId("670db2000000000000000001"), event_name: "Show Rock Legends Tour", sector_id: 1, sector_name: "Pista Premium", sector_price_id: 2, lot_name: "2º Lote - Pista Premium", price: 600.00 },
  { event_id: ObjectId("670db2000000000000000001"), event_name: "Show Rock Legends Tour", sector_id: 2, sector_name: "Cadeira Inferior", sector_price_id: 3, lot_name: "1º Lote - Cadeira Inferior", price: 350.00 },
  { event_id: ObjectId("670db2000000000000000002"), event_name: "Final da Supercopa 2026", sector_id: 3, sector_name: "Maracanã Mais", sector_price_id: 4, lot_name: "1º Lote - Maracanã Mais", price: 800.00 },
  { event_id: ObjectId("670db2000000000000000002"), event_name: "Final da Supercopa 2026", sector_id: 4, sector_name: "Arquibancada Geral", sector_price_id: 5, lot_name: "1º Lote - Arquibancada Geral", price: 150.00 }
];

const totalDocs = 20000;
const batchSize = 2000;
let batch = [];
const baseDate = new Date("2026-11-01T12:00:00Z").getTime();

print("Iniciando geração de 20.000 pedidos no MongoDB...");

for (let i = 1; i <= totalDocs; i++) {
  const cust = customers[(i % 4)];
  const itemData = eventsData[(i % 5)];
  
  const randStatus = i % 10;
  let status = "confirmed";
  if (randStatus >= 7 && randStatus < 9) {
    status = "pending";
  } else if (randStatus >= 9) {
    status = "cancelled";
  }

  const daysOffset = (i % 60) * 86400000;
  const secOffset = ((i * 37) % 86400) * 1000;
  const createdAt = new Date(baseDate - daysOffset + secOffset);
  const expiresAt = new Date(createdAt.getTime() + 1800000);

  batch.push({
    order_number: "BULK-M-" + i + "-" + Math.floor(Math.random() * 1000000),
    customer: cust,
    status: status,
    subtotal: itemData.price,
    discount: 0.0,
    total: itemData.price,
    expires_at: expiresAt,
    items: [
      {
        order_item_id: i,
        event_id: itemData.event_id,
        event_name: itemData.event_name,
        sector_id: itemData.sector_id,
        sector_name: itemData.sector_name,
        sector_price_id: itemData.sector_price_id,
        lot_name: itemData.lot_name,
        quantity: 1,
        unit_price: itemData.price,
        discount: 0.0,
        total: itemData.price
      }
    ],
    created_at: createdAt,
    updated_at: createdAt
  });

  if (batch.length === batchSize) {
    ticketDb.orders.insertMany(batch);
    batch = [];
  }
}

if (batch.length > 0) {
  ticketDb.orders.insertMany(batch);
}

print("Concluído! Total de documentos em orders: " + ticketDb.orders.countDocuments());

