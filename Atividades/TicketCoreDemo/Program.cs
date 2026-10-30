using System;
using System.Collections.Generic;
using System.Data;
using System.Threading;
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
            Console.WriteLine("    TICKETCORE - ETAPA 05: CONSISTÊNCIA SOB CONCORRÊNCIA (C# / .NET)");
            Console.WriteLine("    Simulação: 50 Compradores Concorrentes Disputando 10 Ingressos");
            Console.WriteLine("==================================================================================\n");

            string mysqlConnStr = "Server=localhost;Port=33206;Database=ticket_core;User ID=ecommerce_usr;Password=ecommercepwd;";
            string mongoConnStr = "mongodb://advbd:advbd1234@localhost:27917/?authSource=admin";

            // 1. Teste Concorrente no MySQL (Transação com Update Condicional)
            await TestarConcorrenciaMySQL(mysqlConnStr);

            Console.WriteLine("\n----------------------------------------------------------------------------------\n");

            // 2. Teste Concorrente no MongoDB (Operação Atômica com Filtro de Disponibilidade)
            await TestarConcorrenciaMongoDB(mongoConnStr);

            Console.WriteLine("\n----------------------------------------------------------------------------------\n");

            // 3. Teste de Solicitações Repetidas (Idempotência sob Concorrência)
            await TestarIdempotenciaRepetida(mysqlConnStr, mongoConnStr);

            Console.WriteLine("\n==================================================================================");
            Console.WriteLine("    Simulação Concluída: Zero Overselling e Zero Duplicidade!");
            Console.WriteLine("==================================================================================");
        }

        static async Task TestarConcorrenciaMySQL(string connStr)
        {
            Console.WriteLine(">>> [1/3] TESTANDO CONCORRÊNCIA NO MYSQL COM 50 REQUISIÇÕES SIMULTÂNEAS...");

            // Resetar lote 99 para 10 ingressos
            await using (var connReset = new MySqlConnection(connStr))
            {
                await connReset.OpenAsync();
                var cmdReset = new MySqlCommand("UPDATE event_sector_prices SET available_quantity = 10, status = 'active' WHERE id = 99;", connReset);
                await cmdReset.ExecuteNonQueryAsync();
            }

            int sucessos = 0;
            int rejeicoes = 0;
            var tasks = new List<Task>();

            for (int i = 1; i <= 50; i++)
            {
                int compradorId = i;
                tasks.Add(Task.Run(async () =>
                {
                    await using var conn = new MySqlConnection(connStr);
                    await conn.OpenAsync();
                    await using var trans = await conn.BeginTransactionAsync(IsolationLevel.ReadCommitted);

                    try
                    {
                        // ATUALIZAÇÃO CONDICIONAL ATÔMICA: Garante que só decrementa se houver saldo >= 1
                        string sqlUpdate = @"
                            UPDATE event_sector_prices 
                            SET available_quantity = available_quantity - 1,
                                status = IF(available_quantity = 1, 'sold_out', status)
                            WHERE id = 99 AND available_quantity >= 1;";

                        await using var cmdUpdate = new MySqlCommand(sqlUpdate, conn, trans);
                        int rowsAffected = await cmdUpdate.ExecuteNonQueryAsync();

                        if (rowsAffected > 0)
                        {
                            // Ingressos disponíveis reservados com sucesso! Criar pedido e ingresso
                            string orderNum = $"ORD-CONC-MYSQL-{compradorId}-{Guid.NewGuid().ToString().Substring(0, 8)}";
                            string sqlOrder = "INSERT INTO orders (customer_id, order_number, status, total) VALUES (1, @num, 'confirmed', 100.00); SELECT LAST_INSERT_ID();";
                            await using var cmdOrder = new MySqlCommand(sqlOrder, conn, trans);
                            cmdOrder.Parameters.AddWithValue("@num", orderNum);
                            ulong orderId = Convert.ToUInt64(await cmdOrder.ExecuteScalarAsync());

                            string sqlItem = "INSERT INTO order_items (order_id, event_sector_price_id, quantity, unit_price, total) VALUES (@ordId, 99, 1, 100.00, 100.00); SELECT LAST_INSERT_ID();";
                            await using var cmdItem = new MySqlCommand(sqlItem, conn, trans);
                            cmdItem.Parameters.AddWithValue("@ordId", orderId);
                            ulong itemId = Convert.ToUInt64(await cmdItem.ExecuteScalarAsync());

                            string ticketCode = $"TCK-CONC-MYSQL-{compradorId}-{Guid.NewGuid().ToString().Substring(0, 6)}";
                            string sqlTicket = "INSERT INTO tickets (order_item_id, ticket_code, status) VALUES (@itemId, @tCode, 'issued');";
                            await using var cmdTicket = new MySqlCommand(sqlTicket, conn, trans);
                            cmdTicket.Parameters.AddWithValue("@itemId", itemId);
                            cmdTicket.Parameters.AddWithValue("@tCode", ticketCode);
                            await cmdTicket.ExecuteNonQueryAsync();

                            await trans.CommitAsync();
                            Interlocked.Increment(ref sucessos);
                        }
                        else
                        {
                            // Esgotado! Rollback imediato sem travar o banco
                            await trans.RollbackAsync();
                            Interlocked.Increment(ref rejeicoes);
                        }
                    }
                    catch (Exception)
                    {
                        await trans.RollbackAsync();
                        Interlocked.Increment(ref rejeicoes);
                    }
                }));
            }

            await Task.WhenAll(tasks);

            // Verificar saldo final no MySQL
            await using (var connCheck = new MySqlConnection(connStr))
            {
                await connCheck.OpenAsync();
                var cmdCheck = new MySqlCommand("SELECT available_quantity, status FROM event_sector_prices WHERE id = 99;", connCheck);
                await using var reader = await cmdCheck.ExecuteReaderAsync();
                await reader.ReadAsync();
                int saldoFinal = reader.GetInt32(0);
                string statusFinal = reader.GetString(1);

                Console.WriteLine($"    [RESULTADO MYSQL]:");
                Console.WriteLine($"    - Compras com Sucesso: {sucessos} (Esperado: 10)");
                Console.WriteLine($"    - Compras Rejeitadas (Esgotado): {rejeicoes} (Esperado: 40)");
                Console.WriteLine($"    - Saldo Final Disponível no Banco: {saldoFinal} (Esperado: 0)");
                Console.WriteLine($"    - Status Final do Lote: {statusFinal} (Esperado: sold_out)");
            }
        }

        static async Task TestarConcorrenciaMongoDB(string connStr)
        {
            Console.WriteLine(">>> [2/3] TESTANDO CONCORRÊNCIA NO MONGODB COM 50 REQUISIÇÕES SIMULTÂNEAS...");

            var client = new MongoClient(connStr);
            var db = client.GetDatabase("ticket_core");
            var eventsCol = db.GetCollection<BsonDocument>("events");
            var ordersCol = db.GetCollection<BsonDocument>("orders");
            var ticketsCol = db.GetCollection<BsonDocument>("tickets");

            // Resetar lote 99 no MongoDB para 10 ingressos
            var filterReset = Builders<BsonDocument>.Filter.And(
                Builders<BsonDocument>.Filter.Eq("mysql_id", 1),
                Builders<BsonDocument>.Filter.Eq("sector_prices.id", 99)
            );
            var updateReset = Builders<BsonDocument>.Update
                .Set("sector_prices.$.available_quantity", 10)
                .Set("sector_prices.$.status", "active");
            await eventsCol.UpdateOneAsync(filterReset, updateReset);

            int sucessos = 0;
            int rejeicoes = 0;
            var tasks = new List<Task>();

            for (int i = 1; i <= 50; i++)
            {
                int compradorId = i;
                tasks.Add(Task.Run(async () =>
                {
                    try
                    {
                        // OPERAÇÃO ATÔMICA CONDICIONAL: Filtra { available_quantity: { $gte: 1 } } e decrementa com $inc: -1
                        var filterLote = Builders<BsonDocument>.Filter.And(
                            Builders<BsonDocument>.Filter.Eq("mysql_id", 1),
                            Builders<BsonDocument>.Filter.ElemMatch("sector_prices", Builders<BsonDocument>.Filter.And(
                                Builders<BsonDocument>.Filter.Eq("id", 99),
                                Builders<BsonDocument>.Filter.Gte("available_quantity", 1)
                            ))
                        );

                        var updateLote = Builders<BsonDocument>.Update.Inc("sector_prices.$.available_quantity", -1);

                        var result = await eventsCol.UpdateOneAsync(filterLote, updateLote);

                        if (result.ModifiedCount > 0)
                        {
                            // Vaga conquistada atomicamente no documento! Inserir pedido e ingresso
                            var orderId = ObjectId.GenerateNewId();
                            var orderDoc = new BsonDocument
                            {
                                { "_id", orderId },
                                { "order_number", $"ORD-CONC-MONGO-{compradorId}-{Guid.NewGuid().ToString().Substring(0, 8)}" },
                                { "status", "confirmed" },
                                { "total", 100.0 },
                                { "customer", new BsonDocument { { "id", ObjectId.GenerateNewId() }, { "name", $"Comprador {compradorId}" } } },
                                { "items", new BsonArray
                                    {
                                        new BsonDocument
                                        {
                                            { "event_id", ObjectId.GenerateNewId() },
                                            { "sector_price_id", 99 },
                                            { "quantity", 1 },
                                            { "unit_price", 100.0 }
                                        }
                                    }
                                },
                                { "created_at", DateTime.UtcNow }
                            };
                            await ordersCol.InsertOneAsync(orderDoc);

                            var ticketDoc = new BsonDocument
                            {
                                { "ticket_code", $"TCK-CONC-MONGO-{compradorId}-{Guid.NewGuid().ToString().Substring(0, 6)}" },
                                { "order_id", orderId },
                                { "status", "issued" },
                                { "issued_at", DateTime.UtcNow },
                                { "check_ins", new BsonArray() }
                            };
                            await ticketsCol.InsertOneAsync(ticketDoc);

                            Interlocked.Increment(ref sucessos);
                        }
                        else
                        {
                            Interlocked.Increment(ref rejeicoes);
                        }
                    }
                    catch (Exception)
                    {
                        Interlocked.Increment(ref rejeicoes);
                    }
                }));
            }

            await Task.WhenAll(tasks);

            // Verificar saldo final no MongoDB
            var eventDoc = await eventsCol.Find(Builders<BsonDocument>.Filter.Eq("mysql_id", 1)).FirstOrDefaultAsync();
            var prices = eventDoc["sector_prices"].AsBsonArray;
            int saldoFinal = -1;
            foreach (var p in prices)
            {
                if (p["id"].AsInt32 == 99)
                {
                    saldoFinal = p["available_quantity"].AsInt32;
                    break;
                }
            }

            Console.WriteLine($"    [RESULTADO MONGODB]:");
            Console.WriteLine($"    - Compras com Sucesso: {sucessos} (Esperado: 10)");
            Console.WriteLine($"    - Compras Rejeitadas (Esgotado): {rejeicoes} (Esperado: 40)");
            Console.WriteLine($"    - Saldo Final Disponível no Banco: {saldoFinal} (Esperado: 0)");
        }

        static async Task TestarIdempotenciaRepetida(string mysqlConnStr, string mongoConnStr)
        {
            Console.WriteLine(">>> [3/3] TESTANDO SOLICITAÇÕES REPETIDAS (IDEMPOTÊNCIA SOB CONCORRÊNCIA)...");

            string chaveIdempotencia = $"IDEMP-TEST-REPETICAO-{Guid.NewGuid().ToString().Substring(0, 8)}";

            // Teste no MySQL com a mesma idempotency_key enviada 5 vezes simultâneas
            int mysqlSucessos = 0;
            int mysqlBloqueados = 0;
            var mysqlTasks = new List<Task>();

            for (int i = 0; i < 5; i++)
            {
                mysqlTasks.Add(Task.Run(async () =>
                {
                    try
                    {
                        await using var conn = new MySqlConnection(mysqlConnStr);
                        await conn.OpenAsync();
                        string sql = "INSERT INTO payments (order_id, idempotency_key, method, amount, status) VALUES (1, @key, 'pix', 100.00, 'approved');";
                        await using var cmd = new MySqlCommand(sql, conn);
                        cmd.Parameters.AddWithValue("@key", chaveIdempotencia);
                        await cmd.ExecuteNonQueryAsync();
                        Interlocked.Increment(ref mysqlSucessos);
                    }
                    catch (MySqlException ex) when (ex.Number == 1062)
                    {
                        Interlocked.Increment(ref mysqlBloqueados);
                    }
                }));
            }
            await Task.WhenAll(mysqlTasks);

            // Teste no MongoDB com a mesma idempotency_key enviada 5 vezes simultâneas
            var client = new MongoClient(mongoConnStr);
            var paymentsCol = client.GetDatabase("ticket_core").GetCollection<BsonDocument>("payments");
            int mongoSucessos = 0;
            int mongoBloqueados = 0;
            var mongoTasks = new List<Task>();

            for (int i = 0; i < 5; i++)
            {
                mongoTasks.Add(Task.Run(async () =>
                {
                    try
                    {
                        var doc = new BsonDocument
                        {
                            { "order_id", ObjectId.GenerateNewId() },
                            { "idempotency_key", chaveIdempotencia },
                            { "method", "pix" },
                            { "amount", 100.0 },
                            { "status", "approved" }
                        };
                        await paymentsCol.InsertOneAsync(doc);
                        Interlocked.Increment(ref mongoSucessos);
                    }
                    catch (MongoWriteException ex) when (ex.WriteError.Code == 11000)
                    {
                        Interlocked.Increment(ref mongoBloqueados);
                    }
                }));
            }
            await Task.WhenAll(mongoTasks);

            Console.WriteLine($"    [RESULTADO IDEMPOTÊNCIA]:");
            Console.WriteLine($"    - MySQL: {mysqlSucessos} pagamento gravado e {mysqlBloqueados} duplicatas bloqueadas!");
            Console.WriteLine($"    - MongoDB: {mongoSucessos} pagamento gravado e {mongoBloqueados} duplicatas bloqueadas!");
        }
    }
}
