const ticketDb = db.getSiblingDB("ticket_core");

ticketDb.events.updateOne(
  { mysql_id: 1 },
  { $pull: { sector_prices: { id: 99 } } }
);

ticketDb.events.updateOne(
  { mysql_id: 1 },
  { 
    $push: { 
      sector_prices: { 
        id: 99, 
        sector_id: 1, 
        sector_name: "Pista Premium", 
        name: "Lote Concorrencia 10 Ingressos", 
        price: 100.0, 
        total_quantity: 10, 
        available_quantity: 10, 
        status: "active" 
      } 
    } 
  }
);

print("Lote 99 criado com sucesso no MongoDB com 10 ingressos disponíveis!");

