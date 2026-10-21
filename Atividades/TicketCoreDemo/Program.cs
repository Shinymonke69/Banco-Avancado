using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MySqlConnector;
using MongoDB.Bson;
using MongoDB.Driver;

namespace TicketCoreDemo
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;
            Console.WriteLine("==================================================================================");
            Console.WriteLine("    TICKETCORE - ETAPA 03: CONSULTAS E AGREGAÇÕES ANALÍTICAS (C# / .NET)");
            Console.WriteLine("    Execução das 5 Perguntas de Negócio no MySQL e MongoDB");
            Console.WriteLine("==================================================================================\n");

            string mysqlConnStr = "Server=localhost;Port=33206;Database=ticket_core;User ID=ecommerce_usr;Password=ecommercepwd;";
            string mongoConnStr = "mongodb://advbd:advbd1234@localhost:27917/?authSource=admin";

            await using var mySqlConn = new MySqlConnection(mysqlConnStr);
            await mySqlConn.OpenAsync();

            var mongoClient = new MongoClient(mongoConnStr);
            var mongoDb = mongoClient.GetDatabase("ticket_core");

            // 1. Faturamento por evento e período
            await Consulta1_Faturamento(mySqlConn, mongoDb);

            // 2. Ingressos vendidos e disponíveis por setor
            await Consulta2_Setores(mySqlConn, mongoDb);

            // 3. Eventos com maior volume de vendas
            await Consulta3_VolumeVendas(mySqlConn, mongoDb);

            // 4. Pedidos pendentes de pagamento
            await Consulta4_PedidosPendentes(mySqlConn, mongoDb);

            // 5. Compradores com mais compras ou maior valor acumulado
            await Consulta5_MelhoresCompradores(mySqlConn, mongoDb);

            Console.WriteLine("\n==================================================================================");
            Console.WriteLine("    Execução das 5 Consultas Concluída com Sucesso em Ambos os Bancos!");
            Console.WriteLine("==================================================================================");
        }

        // -----------------------------------------------------------------------------------------
        // 1. Faturamento por evento e período
        // -----------------------------------------------------------------------------------------
        static async Task Consulta1_Faturamento(MySqlConnection sqlConn, IMongoDatabase mongoDb)
        {
            Console.WriteLine("\n>>> [CONSULTA 1] FATURAMENTO POR EVENTO E PERÍODO (OUTUBRO/2026)");

            // MySQL
            string sql = @"
                SELECT 
                    e.name AS evento,
                    DATE_FORMAT(o.created_at, '%Y-%m') AS periodo,
                    COUNT(DISTINCT o.id) AS total_pedidos,
                    SUM(oi.quantity) AS ingressos_vendidos,
                    SUM(oi.total) AS faturamento_total
                FROM events e
                JOIN event_sector_prices esp ON esp.event_id = e.id
                JOIN order_items oi ON oi.event_sector_price_id = esp.id
                JOIN orders o ON o.id = oi.order_id
                WHERE o.status = 'confirmed' 
                  AND o.created_at BETWEEN '2026-10-01 00:00:00' AND '2026-10-31 23:59:59'
                GROUP BY e.id, e.name, DATE_FORMAT(o.created_at, '%Y-%m')
                ORDER BY faturamento_total DESC;";

            Console.WriteLine("  [MySQL]:");
            await using (var cmd = new MySqlCommand(sql, sqlConn))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    Evento: {reader["evento"]} | Mês: {reader["periodo"]} | Pedidos: {reader["total_pedidos"]} | Ingressos: {reader["ingressos_vendidos"]} | Faturamento: R$ {Convert.ToDecimal(reader["faturamento_total"]):N2}");
                }
            }

            // MongoDB Aggregation Pipeline
            Console.WriteLine("  [MongoDB - Aggregation Pipeline]:");
            var pipeline = new BsonDocument[]
            {
                new BsonDocument("$match", new BsonDocument {
                    { "status", "confirmed" },
                    { "created_at", new BsonDocument {
                        { "$gte", new DateTime(2026, 10, 1, 0, 0, 0, DateTimeKind.Utc) },
                        { "$lte", new DateTime(2026, 10, 31, 23, 59, 59, DateTimeKind.Utc) }
                    }}
                }),
                new BsonDocument("$unwind", "$items"),
                new BsonDocument("$group", new BsonDocument {
                    { "_id", new BsonDocument {
                        { "event_name", "$items.event_name" },
                        { "periodo", new BsonDocument("$dateToString", new BsonDocument { { "format", "%Y-%m" }, { "date", "$created_at" } }) }
                    }},
                    { "pedidos", new BsonDocument("$addToSet", "$order_number") },
                    { "ingressos_vendidos", new BsonDocument("$sum", "$items.quantity") },
                    { "faturamento_total", new BsonDocument("$sum", "$items.total") }
                }),
                new BsonDocument("$project", new BsonDocument {
                    { "evento", "$_id.event_name" },
                    { "periodo", "$_id.periodo" },
                    { "total_pedidos", new BsonDocument("$size", "$pedidos") },
                    { "ingressos_vendidos", 1 },
                    { "faturamento_total", 1 }
                }),
                new BsonDocument("$sort", new BsonDocument("faturamento_total", -1))
            };

            var mongoResults = await mongoDb.GetCollection<BsonDocument>("orders").Aggregate<BsonDocument>(pipeline).ToListAsync();
            foreach (var doc in mongoResults)
            {
                Console.WriteLine($"    Evento: {doc["evento"]} | Mês: {doc["periodo"]} | Pedidos: {doc["total_pedidos"]} | Ingressos: {doc["ingressos_vendidos"]} | Faturamento: R$ {Convert.ToDecimal(doc["faturamento_total"]):N2}");
            }
        }

        // -----------------------------------------------------------------------------------------
        // 2. Ingressos vendidos e disponíveis por setor
        // -----------------------------------------------------------------------------------------
        static async Task Consulta2_Setores(MySqlConnection sqlConn, IMongoDatabase mongoDb)
        {
            Console.WriteLine("\n>>> [CONSULTA 2] INGRESSOS VENDIDOS E DISPONÍVEIS POR SETOR");

            // MySQL: Agrupando por evento e setor calculando disponibilidade e vendidos a partir dos lotes (event_sector_prices)
            string sql = @"
                SELECT 
                    e.name AS evento,
                    s.name AS setor,
                    s.capacity AS capacidade_setor,
                    SUM(esp.total_quantity - esp.available_quantity) AS vendidos,
                    SUM(esp.available_quantity) AS disponiveis
                FROM sectors s
                JOIN venues v ON s.venue_id = v.id
                JOIN event_sector_prices esp ON esp.sector_id = s.id
                JOIN events e ON esp.event_id = e.id
                GROUP BY e.id, e.name, s.id, s.name, s.capacity
                ORDER BY e.name, s.name;";

            Console.WriteLine("  [MySQL]:");
            await using (var cmd = new MySqlCommand(sql, sqlConn))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    Evento: {reader["evento"]} | Setor: {reader["setor"]} | Cap: {reader["capacidade_setor"]} | Vendidos: {reader["vendidos"]} | Disponíveis: {reader["disponiveis"]}");
                }
            }

            // MongoDB: Pipeline claro e direto navegando pelos lotes do evento
            Console.WriteLine("  [MongoDB - Aggregation Pipeline]:");
            var pipeline = new BsonDocument[]
            {
                new BsonDocument("$unwind", "$sector_prices"),
                new BsonDocument("$group", new BsonDocument {
                    { "_id", new BsonDocument {
                        { "evento", "$name" },
                        { "setor", "$sector_prices.sector_name" }
                    }},
                    { "disponiveis", new BsonDocument("$sum", "$sector_prices.available_quantity") },
                    { "total_lote", new BsonDocument("$sum", "$sector_prices.total_quantity") }
                }),
                new BsonDocument("$project", new BsonDocument {
                    { "evento", "$_id.evento" },
                    { "setor", "$_id.setor" },
                    { "disponiveis", 1 },
                    { "vendidos", new BsonDocument("$subtract", new BsonArray { "$total_lote", "$disponiveis" }) }
                }),
                new BsonDocument("$sort", new BsonDocument { { "evento", 1 }, { "setor", 1 } })
            };

            var mongoResults = await mongoDb.GetCollection<BsonDocument>("events").Aggregate<BsonDocument>(pipeline).ToListAsync();
            foreach (var doc in mongoResults)
            {
                Console.WriteLine($"    Evento: {doc["evento"]} | Setor: {doc["setor"]} | Vendidos: {doc["vendidos"]} | Disponíveis: {doc["disponiveis"]}");
            }
        }

        // -----------------------------------------------------------------------------------------
        // 3. Eventos com maior volume de vendas
        // -----------------------------------------------------------------------------------------
        static async Task Consulta3_VolumeVendas(MySqlConnection sqlConn, IMongoDatabase mongoDb)
        {
            Console.WriteLine("\n>>> [CONSULTA 3] EVENTOS COM MAIOR VOLUME DE VENDAS (RANKING)");

            // MySQL
            string sql = @"
                SELECT 
                    e.name AS evento,
                    COUNT(DISTINCT o.id) AS qtd_pedidos,
                    SUM(oi.quantity) AS ingressos_vendidos,
                    SUM(oi.total) AS faturamento_total
                FROM events e
                JOIN event_sector_prices esp ON esp.event_id = e.id
                JOIN order_items oi ON oi.event_sector_price_id = esp.id
                JOIN orders o ON o.id = oi.order_id
                WHERE o.status = 'confirmed'
                GROUP BY e.id, e.name
                ORDER BY ingressos_vendidos DESC, faturamento_total DESC;";

            Console.WriteLine("  [MySQL]:");
            await using (var cmd = new MySqlCommand(sql, sqlConn))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                int rank = 1;
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    #{rank++} {reader["evento"]} -> Ingressos Vendidos: {reader["ingressos_vendidos"]} | Pedidos: {reader["qtd_pedidos"]} | Total: R$ {Convert.ToDecimal(reader["faturamento_total"]):N2}");
                }
            }

            // MongoDB
            Console.WriteLine("  [MongoDB - Aggregation Pipeline]:");
            var pipeline = new BsonDocument[]
            {
                new BsonDocument("$match", new BsonDocument("status", "confirmed")),
                new BsonDocument("$unwind", "$items"),
                new BsonDocument("$group", new BsonDocument {
                    { "_id", "$items.event_name" },
                    { "pedidos", new BsonDocument("$addToSet", "$order_number") },
                    { "ingressos_vendidos", new BsonDocument("$sum", "$items.quantity") },
                    { "faturamento_total", new BsonDocument("$sum", "$items.total") }
                }),
                new BsonDocument("$project", new BsonDocument {
                    { "evento", "$_id" },
                    { "qtd_pedidos", new BsonDocument("$size", "$pedidos") },
                    { "ingressos_vendidos", 1 },
                    { "faturamento_total", 1 }
                }),
                new BsonDocument("$sort", new BsonDocument { { "ingressos_vendidos", -1 }, { "faturamento_total", -1 } })
            };

            var mongoResults = await mongoDb.GetCollection<BsonDocument>("orders").Aggregate<BsonDocument>(pipeline).ToListAsync();
            int mRank = 1;
            foreach (var doc in mongoResults)
            {
                Console.WriteLine($"    #{mRank++} {doc["evento"]} -> Ingressos Vendidos: {doc["ingressos_vendidos"]} | Pedidos: {doc["qtd_pedidos"]} | Total: R$ {Convert.ToDecimal(doc["faturamento_total"]):N2}");
            }
        }

        // -----------------------------------------------------------------------------------------
        // 4. Pedidos pendentes de pagamento
        // -----------------------------------------------------------------------------------------
        static async Task Consulta4_PedidosPendentes(MySqlConnection sqlConn, IMongoDatabase mongoDb)
        {
            Console.WriteLine("\n>>> [CONSULTA 4] PEDIDOS PENDENTES DE PAGAMENTO (FILA DE EXPIRAÇÃO)");

            // MySQL
            string sql = @"
                SELECT 
                    o.order_number,
                    c.name AS comprador,
                    c.email,
                    o.total,
                    o.created_at,
                    o.expires_at,
                    TIMESTAMPDIFF(MINUTE, NOW(), o.expires_at) AS minutos_restantes
                FROM orders o
                JOIN customers c ON o.customer_id = c.id
                WHERE o.status = 'pending'
                ORDER BY o.expires_at ASC;";

            Console.WriteLine("  [MySQL]:");
            await using (var cmd = new MySqlCommand(sql, sqlConn))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    Pedido: {reader["order_number"]} | Cliente: {reader["comprador"]} ({reader["email"]}) | Valor: R$ {Convert.ToDecimal(reader["total"]):N2} | Expira em: {reader["expires_at"]}");
                }
            }

            // MongoDB
            Console.WriteLine("  [MongoDB - Find Query]:");
            var filter = Builders<BsonDocument>.Filter.Eq("status", "pending");
            var sort = Builders<BsonDocument>.Sort.Ascending("created_at");
            var mongoResults = await mongoDb.GetCollection<BsonDocument>("orders").Find(filter).Sort(sort).ToListAsync();

            foreach (var doc in mongoResults)
            {
                Console.WriteLine($"    Pedido: {doc["order_number"]} | Cliente: {doc["customer"]["name"]} ({doc["customer"]["email"]}) | Valor: R$ {Convert.ToDecimal(doc["total"]):N2} | Criado em: {doc["created_at"]}");
            }
        }

        // -----------------------------------------------------------------------------------------
        // 5. Compradores com mais compras ou maior valor acumulado
        // -----------------------------------------------------------------------------------------
        static async Task Consulta5_MelhoresCompradores(MySqlConnection sqlConn, IMongoDatabase mongoDb)
        {
            Console.WriteLine("\n>>> [CONSULTA 5] TOP COMPRADORES (QUANTIDADE DE COMPRAS E VALOR ACUMULADO)");

            // MySQL
            string sql = @"
                SELECT 
                    c.name AS comprador,
                    c.email,
                    COUNT(o.id) AS total_pedidos,
                    SUM(o.total) AS total_gasto,
                    AVG(o.total) AS ticket_medio,
                    MAX(o.created_at) AS ultima_compra
                FROM customers c
                JOIN orders o ON o.customer_id = c.id
                WHERE o.status = 'confirmed'
                GROUP BY c.id, c.name, c.email
                ORDER BY total_gasto DESC, total_pedidos DESC;";

            Console.WriteLine("  [MySQL]:");
            await using (var cmd = new MySqlCommand(sql, sqlConn))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                int rank = 1;
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    #{rank++} {reader["comprador"]} | Compras: {reader["total_pedidos"]} | Total: R$ {Convert.ToDecimal(reader["total_gasto"]):N2} | Ticket Médio: R$ {Convert.ToDecimal(reader["ticket_medio"]):N2}");
                }
            }

            // MongoDB
            Console.WriteLine("  [MongoDB - Aggregation Pipeline]:");
            var pipeline = new BsonDocument[]
            {
                new BsonDocument("$match", new BsonDocument("status", "confirmed")),
                new BsonDocument("$group", new BsonDocument {
                    { "_id", "$customer.id" },
                    { "comprador", new BsonDocument("$first", "$customer.name") },
                    { "email", new BsonDocument("$first", "$customer.email") },
                    { "total_pedidos", new BsonDocument("$sum", 1) },
                    { "total_gasto", new BsonDocument("$sum", "$total") },
                    { "ticket_medio", new BsonDocument("$avg", "$total") }
                }),
                new BsonDocument("$sort", new BsonDocument { { "total_gasto", -1 }, { "total_pedidos", -1 } })
            };

            var mongoResults = await mongoDb.GetCollection<BsonDocument>("orders").Aggregate<BsonDocument>(pipeline).ToListAsync();
            int mRank = 1;
            foreach (var doc in mongoResults)
            {
                Console.WriteLine($"    #{mRank++} {doc["comprador"]} | Compras: {doc["total_pedidos"]} | Total: R$ {Convert.ToDecimal(doc["total_gasto"]):N2} | Ticket Médio: R$ {Convert.ToDecimal(doc["ticket_medio"]):N2}");
            }
        }
    }
}
