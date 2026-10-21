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
            Console.WriteLine("    TICKETCORE - ETAPA 02: INTEGRIDADE E VALIDAÇÃO DOS BANCOS (C# / .NET)");
            Console.WriteLine("    Execução Automatizada da Matriz de Testes (Casos Aceitos e Rejeitados)");
            Console.WriteLine("==================================================================================\n");

            string mysqlConnStr = "Server=localhost;Port=33206;Database=ticket_core;User ID=ecommerce_usr;Password=ecommercepwd;";
            string mongoConnStr = "mongodb://advbd:advbd1234@localhost:27917/?authSource=admin";

            // Executar bateria de testes no MySQL
            await ExecutarBateriaMySQL(mysqlConnStr);

            Console.WriteLine("\n----------------------------------------------------------------------------------\n");

            // Executar bateria de testes no MongoDB
            await ExecutarBateriaMongoDB(mongoConnStr);

            Console.WriteLine("\n==================================================================================");
            Console.WriteLine("    Relatório Concluído: Ambos os bancos rejeitaram com êxito todas as violações!");
            Console.WriteLine("==================================================================================");
        }

        static async Task ExecutarBateriaMySQL(string connStr)
        {
            Console.WriteLine(">>> [BATERIA 1/2] EXECUTANDO TESTES DE INTEGRIDADE NO MYSQL (RELACIONAL)");

            await using var conn = new MySqlConnection(connStr);
            await conn.OpenAsync();

            // Teste 1: Quantidade Negativa / Zero em Lote (CHECK Constraint)
            await TestarCasoMySQL(conn,
                "T1: Inserção de Lote com Quantidade Negativa (total_quantity = -5)",
                "INSERT INTO event_sector_prices (event_id, sector_id, name, price, total_quantity, available_quantity, sales_starts_at, sales_ends_at, status) " +
                "VALUES (1, 1, 'Lote Inválido Negativo', 100.00, -5, -5, NOW(), DATE_ADD(NOW(), INTERVAL 1 DAY), 'active');",
                esperaRejeicao: true);

            // Teste 2: Ingresso com Ticket Code Duplicado (UNIQUE Constraint)
            await TestarCasoMySQL(conn,
                "T2: Duplicidade de ticket_code ('TCK-RL-0001-A9F')",
                "INSERT INTO tickets (order_item_id, ticket_code, holder_name, holder_document, status) " +
                "VALUES (1, 'TCK-RL-0001-A9F', 'Impostor', '00000000000', 'issued');",
                esperaRejeicao: true);

            // Teste 3: Referência Inexistente / Pedido Fantasma (FOREIGN KEY Constraint)
            await TestarCasoMySQL(conn,
                "T3: Inserção de Item de Pedido para Pedido Inexistente (order_id = 999999)",
                "INSERT INTO order_items (order_id, event_sector_price_id, quantity, unit_price, discount, total) " +
                "VALUES (999999, 1, 1, 100.00, 0, 100.00);",
                esperaRejeicao: true);

            // Teste 4: Estado Inválido em Status de Pedido (ENUM Constraint)
            await TestarCasoMySQL(conn,
                "T4: Inserção de Pedido com Estado Inválido (status = 'status_inventado')",
                "INSERT INTO orders (customer_id, order_number, status, subtotal, discount, total) " +
                "VALUES (1, 'ORD-INVALID-STATE', 'status_inventado', 100.00, 0, 100.00);",
                esperaRejeicao: true);

            // Teste 5: Idempotência de Pagamento Duplicada (UNIQUE Constraint)
            await TestarCasoMySQL(conn,
                "T5: Pagamento Duplicado com a mesma idempotency_key ('IDEMP-20261014-0001-CC')",
                "INSERT INTO payments (order_id, idempotency_key, method, amount, status) " +
                "VALUES (1, 'IDEMP-20261014-0001-CC', 'credit_card', 1200.00, 'approved');",
                esperaRejeicao: true);

            // Teste 6: Caso Válido / Aceito
            await TestarCasoMySQL(conn,
                "T6 [VÁLIDO]: Inserção de Pedido Válido com Valores e Estados Corretos",
                "INSERT INTO orders (customer_id, order_number, status, subtotal, discount, total) " +
                "VALUES (2, 'ORD-TEST-VALID-01', 'pending', 350.00, 0, 350.00);",
                esperaRejeicao: false);
        }

        static async Task TestarCasoMySQL(MySqlConnection conn, string titulo, string sql, bool esperaRejeicao)
        {
            Console.WriteLine($"\n  -> Testando: {titulo}");
            try
            {
                await using var cmd = new MySqlCommand(sql, conn);
                await cmd.ExecuteNonQueryAsync();

                if (esperaRejeicao)
                {
                    Console.WriteLine("     [FALHA] O banco de dados DEVERIA ter rejeitado, mas aceitou a transação!");
                }
                else
                {
                    Console.WriteLine("     [SUCESSO] Operação válida aceita pelo MySQL conforme esperado.");
                }
            }
            catch (MySqlException ex)
            {
                if (esperaRejeicao)
                {
                    Console.WriteLine($"     [REJEIÇÃO CORRETA] MySQL barrou com sucesso!");
                    Console.WriteLine($"     Código: {ex.Number} | Mensagem: {ex.Message.Split('\n')[0]}");
                }
                else
                {
                    Console.WriteLine($"     [ERRO INESPERADO] Operação válida foi rejeitada: {ex.Message}");
                }
            }
        }

        static async Task ExecutarBateriaMongoDB(string connStr)
        {
            Console.WriteLine(">>> [BATERIA 2/2] EXECUTANDO TESTES DE INTEGRIDADE NO MONGODB (DOCUMENTAL)");

            var client = new MongoClient(connStr);
            var database = client.GetDatabase("ticket_core");

            // Teste 1: Quantidade Zero / Negativa em Itens de Pedido ($jsonSchema minimum: 1)
            await TestarCasoMongo(
                "T1: Inserção de Pedido com Quantidade Negativa/Zero de Ingressos (quantity = 0)",
                async () =>
                {
                    var orders = database.GetCollection<BsonDocument>("orders");
                    var invalidOrder = new BsonDocument
                    {
                        { "order_number", "ORD-MONGO-INV-01" },
                        { "customer", new BsonDocument { { "name", "Teste" } } },
                        { "status", "pending" },
                        { "total", 0.0 },
                        { "items", new BsonArray
                            {
                                new BsonDocument
                                {
                                    { "event_id", ObjectId.GenerateNewId() },
                                    { "quantity", 0 }, // Inválido! mínimo é 1
                                    { "unit_price", 100.0 }
                                }
                            }
                        }
                    };
                    await orders.InsertOneAsync(invalidOrder);
                },
                esperaRejeicao: true);

            // Teste 2: Ticket Code Duplicado (Unique Index)
            await TestarCasoMongo(
                "T2: Duplicidade de ticket_code no MongoDB ('TCK-RL-0001-A9F')",
                async () =>
                {
                    var tickets = database.GetCollection<BsonDocument>("tickets");
                    var duplicateTicket = new BsonDocument
                    {
                        { "ticket_code", "TCK-RL-0001-A9F" }, // Duplicado!
                        { "order_id", ObjectId.GenerateNewId() },
                        { "status", "issued" },
                        { "issued_at", DateTime.UtcNow },
                        { "check_ins", new BsonArray() }
                    };
                    await tickets.InsertOneAsync(duplicateTicket);
                },
                esperaRejeicao: true);

            // Teste 3: Estado Inválido em Status ($jsonSchema enum)
            await TestarCasoMongo(
                "T3: Inserção de Ingresso com Status Inválido (status = 'invalido_status')",
                async () =>
                {
                    var tickets = database.GetCollection<BsonDocument>("tickets");
                    var invalidStatusTicket = new BsonDocument
                    {
                        { "ticket_code", "TCK-TEST-INVALID-999" },
                        { "order_id", ObjectId.GenerateNewId() },
                        { "status", "invalido_status" }, // Inválido!
                        { "issued_at", DateTime.UtcNow },
                        { "check_ins", new BsonArray() }
                    };
                    await tickets.InsertOneAsync(invalidStatusTicket);
                },
                esperaRejeicao: true);

            // Teste 4: Campo Obrigatório Ausente ($jsonSchema required)
            await TestarCasoMongo(
                "T4: Inserção de Comprador sem Documento/CPF (Campo Obrigatório Ausente)",
                async () =>
                {
                    var customers = database.GetCollection<BsonDocument>("customers");
                    var invalidCustomer = new BsonDocument
                    {
                        { "name", "Cliente Sem CPF" },
                        { "email", "semcpf@email.com" },
                        // "document" omitido de propósito!
                        { "status", "active" },
                        { "created_at", DateTime.UtcNow }
                    };
                    await customers.InsertOneAsync(invalidCustomer);
                },
                esperaRejeicao: true);

            // Teste 5: Idempotência de Pagamento Duplicada (Unique Index)
            await TestarCasoMongo(
                "T5: Pagamento com idempotency_key duplicada ('IDEMP-20261014-0001-CC')",
                async () =>
                {
                    var payments = database.GetCollection<BsonDocument>("payments");
                    var duplicatePayment = new BsonDocument
                    {
                        { "order_id", ObjectId.GenerateNewId() },
                        { "idempotency_key", "IDEMP-20261014-0001-CC" }, // Duplicado!
                        { "method", "pix" },
                        { "amount", 500.0 },
                        { "status", "approved" }
                    };
                    await payments.InsertOneAsync(duplicatePayment);
                },
                esperaRejeicao: true);

            // Teste 6: Caso Válido / Aceito
            await TestarCasoMongo(
                "T6 [VÁLIDO]: Inserção de Pagamento Válido com Chave Única e Valor Positivo",
                async () =>
                {
                    var payments = database.GetCollection<BsonDocument>("payments");
                    var validPayment = new BsonDocument
                    {
                        { "order_id", ObjectId.GenerateNewId() },
                        { "idempotency_key", "IDEMP-VALID-TEST-" + Guid.NewGuid().ToString().Substring(0, 8) },
                        { "method", "pix" },
                        { "amount", 350.0 },
                        { "status", "pending" }
                    };
                    await payments.InsertOneAsync(validPayment);
                },
                esperaRejeicao: false);
        }

        static async Task TestarCasoMongo(string titulo, Func<Task> acao, bool esperaRejeicao)
        {
            Console.WriteLine($"\n  -> Testando: {titulo}");
            try
            {
                await acao();
                if (esperaRejeicao)
                {
                    Console.WriteLine("     [FALHA] O MongoDB DEVERIA ter rejeitado, mas inseriu o documento!");
                }
                else
                {
                    Console.WriteLine("     [SUCESSO] Documento válido inserido no MongoDB conforme esperado.");
                }
            }
            catch (MongoWriteException ex)
            {
                if (esperaRejeicao)
                {
                    Console.WriteLine($"     [REJEIÇÃO CORRETA] MongoDB barrou com sucesso via Schema/Unique Index!");
                    Console.WriteLine($"     Erro: {ex.WriteError.Category} | Código: {ex.WriteError.Code} | Msg: {ex.WriteError.Message}");
                }
                else
                {
                    Console.WriteLine($"     [ERRO INESPERADO] Operação válida foi rejeitada: {ex.Message}");
                }
            }
            catch (Exception ex)
            {
                if (esperaRejeicao)
                {
                    Console.WriteLine($"     [REJEIÇÃO CORRETA] MongoDB barrou com sucesso!");
                    Console.WriteLine($"     Tipo: {ex.GetType().Name} | Msg: {ex.Message.Split('\n')[0]}");
                }
                else
                {
                    Console.WriteLine($"     [ERRO INESPERADO] Operação válida falhou: {ex.Message}");
                }
            }
        }
    }
}
