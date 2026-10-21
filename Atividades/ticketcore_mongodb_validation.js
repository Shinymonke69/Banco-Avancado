// ==============================================================================
// PROJETO TICKETCORE - ETAPA 02: INTEGRIDADE E VALIDAÇÃO
// Arquivo: ticketcore_mongodb_validation.js
// Descrição: Configuração completa de $jsonSchema validators e Unique Indexes
// ==============================================================================

const dbName = "ticket_core";
const ticketDb = db.getSiblingDB(dbName);

// ------------------------------------------------------------------------------
// 1. Coleção: customers
// Validação: campos obrigatórios, formato de status, e índices únicos
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "customers",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "email", "document", "status", "created_at"],
      properties: {
        name: {
          bsonType: "string",
          description: "Nome completo do comprador é obrigatório"
        },
        email: {
          bsonType: "string",
          pattern: "^.+@.+\\..+$",
          description: "Formato de e-mail válido obrigatório"
        },
        document: {
          bsonType: "string",
          description: "Documento de identificação obrigatório"
        },
        status: {
          enum: ["active", "inactive", "blocked"],
          description: "Status deve ser apenas active, inactive ou blocked"
        },
        created_at: {
          bsonType: "date"
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

ticketDb.customers.createIndex({ email: 1 }, { unique: true });
ticketDb.customers.createIndex({ document: 1 }, { unique: true });

// ------------------------------------------------------------------------------
// 2. Coleção: venues
// Validação: capacidade física deve ser maior que 0
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "venues",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "address", "city", "state", "capacity", "status"],
      properties: {
        name: { bsonType: "string" },
        capacity: {
          bsonType: ["int", "long", "double"],
          minimum: 1,
          description: "A capacidade do local deve ser estritamente positiva (> 0)"
        },
        status: {
          enum: ["active", "inactive"]
        },
        sectors: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["id", "name", "capacity"],
            properties: {
              id: { bsonType: ["int", "long"] },
              name: { bsonType: "string" },
              capacity: {
                bsonType: ["int", "long", "double"],
                minimum: 1,
                description: "A capacidade de cada setor deve ser positiva (> 0)"
              }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// ------------------------------------------------------------------------------
// 3. Coleção: events
// Validação: status restrito, lotes comerciais com quantidades >= 0 e preços >= 0
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "events",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["venue_id", "name", "starts_at", "ends_at", "status"],
      properties: {
        venue_id: { bsonType: "objectId" },
        name: { bsonType: "string" },
        status: {
          enum: ["draft", "published", "cancelled", "finished"],
          description: "Status do evento deve ser draft, published, cancelled ou finished"
        },
        sector_prices: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["id", "name", "price", "total_quantity", "available_quantity", "status"],
            properties: {
              price: {
                bsonType: ["double", "int", "long", "decimal"],
                minimum: 0,
                description: "Preço do lote não pode ser negativo"
              },
              total_quantity: {
                bsonType: ["int", "long"],
                minimum: 0,
                description: "Quantidade total não pode ser negativa"
              },
              available_quantity: {
                bsonType: ["int", "long"],
                minimum: 0,
                description: "Quantidade disponível não pode ser negativa"
              },
              status: {
                enum: ["scheduled", "active", "sold_out", "closed"]
              }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// ------------------------------------------------------------------------------
// 4. Coleção: orders
// Validação: order_number único, status restrito, totais >= 0, itens com quantidade >= 1
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "orders",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["order_number", "customer", "status", "total", "items"],
      properties: {
        order_number: { bsonType: "string" },
        status: {
          enum: ["pending", "confirmed", "cancelled", "expired"],
          description: "Status deve ser pending, confirmed, cancelled ou expired"
        },
        total: {
          bsonType: ["double", "int", "long", "decimal"],
          minimum: 0,
          description: "Total do pedido não pode ser negativo"
        },
        items: {
          bsonType: "array",
          minItems: 1,
          description: "Um pedido precisa ter no mínimo 1 item",
          items: {
            bsonType: "object",
            required: ["event_id", "quantity", "unit_price"],
            properties: {
              quantity: {
                bsonType: ["int", "long"],
                minimum: 1,
                description: "A quantidade de ingressos deve ser de no mínimo 1"
              },
              unit_price: {
                bsonType: ["double", "int", "long", "decimal"],
                minimum: 0,
                description: "O preço unitário não pode ser negativo"
              }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

ticketDb.orders.createIndex({ order_number: 1 }, { unique: true });

// ------------------------------------------------------------------------------
// 5. Coleção: tickets
// Validação: ticket_code único, status válido e check_ins com resultado restrito
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "tickets",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ticket_code", "order_id", "status", "issued_at"],
      properties: {
        ticket_code: { bsonType: "string" },
        order_id: { bsonType: "objectId" },
        status: {
          enum: ["issued", "used", "cancelled", "refunded"],
          description: "Status do ingresso deve ser issued, used, cancelled ou refunded"
        },
        check_ins: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["gate", "operator_id", "result", "checked_in_at"],
            properties: {
              result: {
                enum: ["accepted", "rejected"],
                description: "Resultado de check-in deve ser accepted ou rejected"
              }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

ticketDb.tickets.createIndex({ ticket_code: 1 }, { unique: true });

// ------------------------------------------------------------------------------
// 6. Coleção: payments
// Validação: idempotency_key único, valor > 0, status restrito
// ------------------------------------------------------------------------------
ticketDb.runCommand({
  collMod: "payments",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["order_id", "idempotency_key", "method", "amount", "status"],
      properties: {
        order_id: { bsonType: "objectId" },
        idempotency_key: { bsonType: "string" },
        amount: {
          bsonType: ["double", "int", "long", "decimal"],
          minimum: 0.01,
          description: "Valor do pagamento deve ser maior que 0"
        },
        status: {
          enum: ["pending", "approved", "rejected", "cancelled", "refunded"],
          description: "Status deve ser pending, approved, rejected, cancelled ou refunded"
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

ticketDb.payments.createIndex({ idempotency_key: 1 }, { unique: true });

print(">>> [MongoDB] Schemas de validação e índices únicos aplicados com sucesso no ticket_core!");
