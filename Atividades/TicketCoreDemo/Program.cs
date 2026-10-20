using System;
using System.Data;
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
            Console.WriteLine("=================================================================");
            Console.WriteLine("    TICKETCORE - ETAPA 01: FUNDAÇÃO (C# / .NET)");
            Console.WriteLine("    Demonstração de Integração: MySQL (Relacional) e MongoDB (NoSQL)");
            Console.WriteLine("=================================================================\n");

            // 1. Testar e consultar MySQL
            await ConsultarFluxoMySQL();

            Console.WriteLine("\n-----------------------------------------------------------------\n");

            // 2. Testar e consultar MongoDB
            await ConsultarFluxoMongoDB();

            Console.WriteLine("\n=================================================================");
            Console.WriteLine("    Execução concluída com sucesso em ambos os bancos!");
            Console.WriteLine("=================================================================");
        }

        /// <summary>
        /// Consulta no MySQL: Une tabelas normalizadas através de JOINs (orders -> customers -> tickets)
        /// </summary>
        static async Task ConsultarFluxoMySQL()
        {
            Console.WriteLine(">>> [1/2] Executando Fluxo Básico de Consulta no MySQL (Porta 33206)...");

            // String de conexão para o MySQL rodando no Docker local
            string mysqlConnStr = "Server=localhost;Port=33206;Database=ticket_core;User ID=ecommerce_usr;Password=ecommercepwd;";

            try
            {
                await using var conn = new MySqlConnection(mysqlConnStr);
                await conn.OpenAsync();
                Console.WriteLine("    [OK] Conectado ao MySQL com sucesso!");

                string query = @"
                    SELECT 
                        o.order_number,
                        c.name AS customer_name,
                        c.email AS customer_email,
                        e.name AS event_name,
                        esp.name AS lot_name,
                        t.ticket_code,
                        t.holder_name,
                        t.status AS ticket_status,
                        p.amount AS paid_amount,
                        p.status AS payment_status
                    FROM orders o
                    INNER JOIN customers c ON o.customer_id = c.id
                    INNER JOIN order_items oi ON oi.order_id = o.id
                    INNER JOIN event_sector_prices esp ON oi.event_sector_price_id = esp.id
                    INNER JOIN events e ON esp.event_id = e.id
                    INNER JOIN tickets t ON t.order_item_id = oi.id
                    LEFT JOIN payments p ON p.order_id = o.id
                    WHERE o.order_number = @orderNumber;";

                await using var cmd = new MySqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@orderNumber", "ORD-2026-0001");

                await using var reader = await cmd.ExecuteReaderAsync();

                Console.WriteLine("\n    Resultado do Pedido Normalizado (MySQL):");
                while (await reader.ReadAsync())
                {
                    Console.WriteLine($"    - Pedido: {reader["order_number"]} | Cliente: {reader["customer_name"]}");
                    Console.WriteLine($"      Evento: {reader["event_name"]} | Lote: {reader["lot_name"]}");
                    Console.WriteLine($"      Ingresso Emitido: {reader["ticket_code"]} (Titular: {reader["holder_name"]}) -> Status: {reader["ticket_status"]}");
                    Console.WriteLine($"      Pagamento: R$ {reader["paid_amount"]} ({reader["payment_status"]})");
                    Console.WriteLine("      -----------------------------------------------------------");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"    [ERRO] Falha ao consultar MySQL: {ex.Message}");
            }
        }

        /// <summary>
        /// Consulta no MongoDB: Consulta documento agregador com itens embutidos e busca ingressos
        /// </summary>
        static async Task ConsultarFluxoMongoDB()
        {
            Console.WriteLine(">>> [2/2] Executando Fluxo Básico de Consulta no MongoDB (Porta 27917)...");

            // String de conexão para o MongoDB rodando no Docker local
            string mongoConnStr = "mongodb://advbd:advbd1234@localhost:27917/?authSource=admin";

            try
            {
                var client = new MongoClient(mongoConnStr);
                var database = client.GetDatabase("ticket_core");
                Console.WriteLine("    [OK] Conectado ao MongoDB com sucesso!");

                var ordersCollection = database.GetCollection<BsonDocument>("orders");
                var ticketsCollection = database.GetCollection<BsonDocument>("tickets");

                // Buscar o pedido pelo código público
                var filterOrder = Builders<BsonDocument>.Filter.Eq("order_number", "ORD-2026-0001");
                var order = await ordersCollection.Find(filterOrder).FirstOrDefaultAsync();

                if (order != null)
                {
                    Console.WriteLine("\n    Documento do Pedido (MongoDB - Estrutura Incorporada):");
                    Console.WriteLine($"    - Pedido ID: {order["_id"]}");
                    Console.WriteLine($"    - Número: {order["order_number"]}");
                    Console.WriteLine($"    - Cliente Embutido: {order["customer"]["name"]} ({order["customer"]["email"]})");
                    Console.WriteLine($"    - Valor Total: R$ {order["total"]}");
                    
                    var items = order["items"].AsBsonArray;
                    Console.WriteLine($"    - Quantidade de Linhas de Itens Embutidos: {items.Count}");
                    foreach (var item in items)
                    {
                        Console.WriteLine($"      * Evento: {item["event_name"]} | Lote: {item["lot_name"]} | Qtd: {item["quantity"]}x R$ {item["unit_price"]}");
                    }

                    // Buscar ingressos vinculados ao pedido na coleção separada
                    var filterTickets = Builders<BsonDocument>.Filter.Eq("order_id", order["_id"]);
                    var tickets = await ticketsCollection.Find(filterTickets).ToListAsync();

                    Console.WriteLine("\n    Ingressos Vinculados (Coleção 'tickets' com Check-ins embutidos):");
                    foreach (var t in tickets)
                    {
                        Console.WriteLine($"      * Ingresso: {t["ticket_code"]} | Titular: {t["holder_name"]} | Status: {t["status"]}");
                        var checkIns = t["check_ins"].AsBsonArray;
                        if (checkIns.Count > 0)
                        {
                            Console.WriteLine($"        Tentativas de Catraca ({checkIns.Count}):");
                            foreach (var chk in checkIns)
                            {
                                Console.WriteLine($"          - {chk["gate"]} | Resultado: {chk["result"]} (Motivo: {chk["reason"]})");
                            }
                        }
                    }
                }
                else
                {
                    Console.WriteLine("    [AVISO] Pedido não encontrado no MongoDB.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"    [ERRO] Falha ao consultar MongoDB: {ex.Message}");
            }
        }
    }
}
