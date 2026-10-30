DOCUMENTO DE ENTREGA: DESAFIO TICKETCORE - 04 DESEMPENHO E OTIMIZAÇÃO
Disciplina: Banco de Dados Avançado
Professor: Claudinei José Machado
Tecnologia de Demonstração / Validação: C# (.NET)
Bancos de Dados: MySQL 9 e MongoDB Community 9


1. INTRODUÇÃO E OBJETIVO DA INVESTIGAÇÃO
Com a evolução do sistema TicketCore, o volume de transações cresce exponencialmente. Um modelo relacional ou NoSQL que funciona bem com centenas de linhas pode apresentar severa degradação de tempo de resposta, alto consumo de memória e bloqueios de I/O quando atinge dezenas de milhares ou milhões de registros.

Nesta etapa, atuamos como engenheiros de desempenho. Geramos uma massa de teste representativa de mais de 20.000 pedidos distribuídos temporalmente e selecionamos duas consultas estratégicas da etapa anterior para dissecar seus planos de execução:
- Consulta 1: Faturamento por Evento e Período (Consulta analítica com filtro de intervalo de datas e status, múltiplos agrupamentos e junções).
- Consulta 4: Pedidos Pendentes de Pagamento com Fila de Expiração (Consulta operacional frequente com filtro de igualdade e ordenação temporal para cancelamento automático).

O objetivo não é criar índices de forma indiscriminada, mas comprovar tecnicamente quando um índice realmente melhora a performance e quando sua presença pode gerar sobrecusto desnecessário.


2. METODOLOGIA E GERAÇÃO DA MASSA DE DADOS (20.000 REGISTROS)

Para que a análise de EXPLAIN no MySQL e explain("executionStats") no MongoDB fosse real e significativa:
- No MySQL, implementamos e executamos a Stored Procedure sp_generate_bulk_orders(20000), inserindo 20.000 pedidos e seus respectivos itens em lotes transacionados, com distribuição proporcional de clientes, lotes, status (confirmed, pending, cancelled) e datas ao longo dos meses de outubro e novembro.
- No MongoDB, executamos um script com insertMany em lotes de 2.000 documentos, atingindo 20.006 pedidos complexos com arrays de subdocumentos embutidos.


3. ANÁLISE DA CONSULTA OPERACIONAL (CONSULTA 4 - PEDIDOS PENDENTES)

A pergunta de negócio respondida é: Quais pedidos estão pendentes e qual a ordem cronológica de expiração para liberar as cotas bloqueadas?

3.1 No MySQL

Consulta executada:
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
ORDER BY o.expires_at ASC;

Cenário ANTES do índice específico:
- Plano de Execução (EXPLAIN ANALYZE):
  -> Sort: o.expires_at (actual time=11..11.3 rows=4002 loops=1)
      -> Nested loop inner join (actual time=2.98..7.25 rows=4002 loops=1)
          -> Table scan on c (cost=1.3 rows=3)
          -> Index lookup on o using idx_orders_customer (customer_id = c.id, status = 'pending') (rows=1000 loops=4)
- Registros examinados na tabela orders: O otimizador utilizou o índice existente em customer_id + status, precisando varrer iterativamente 4 loops (um para cada cliente) e aplicar uma operação cara de ordenação em memória (Filesort / Sort explícito: actual time=11.3ms).

Índice Criado:
CREATE INDEX idx_orders_status_expires ON orders (status, expires_at);

Justificativa:
O predicado WHERE o.status = 'pending' exige igualdade, e o ORDER BY o.expires_at ASC exige ordenação. Pela regra de ouro dos índices B-Tree (Equality-Sort-Range), um índice composto que começa por status e continua por expires_at atende o filtro e entrega os registros já ordenados diretamente das folhas da árvore.

Cenário DEPOIS do índice específico:
- Plano de Execução (EXPLAIN ANALYZE):
  -> Index lookup on o using idx_orders_status_expires (status = 'pending') (actual time=0.937..5.24 rows=4002)
  -> Inner hash join (c.id = o.customer_id) (actual time=5.72..5.99)
- Redução de tempo: O custo de leitura caiu de 11.3ms para 9.4ms, eliminando a busca fragmentada por cliente.

3.2 No MongoDB

Consulta executada:
db.orders.find({ status: "pending" }).sort({ expires_at: 1 });

Cenário ANTES do índice:
- Plano de Execução (executionStats):
  - Stage vencedor: SORT em memória com inputStage COLLSCAN (Varredura total da coleção).
  - Total de documentos examinados (totalDocsExamined): 20.006 documentos.
  - Chaves de índice examinadas (totalKeysExamined): 0.
  - Documentos retornados (nReturned): 4.002.
  - Tempo de execução medido: 11 ms.
  - Memória consumida na ordenação (peakTrackedMemBytes): 2.390.487 bytes (~2.4 MB).
- Diagnóstico: O MongoDB precisou carregar 20.006 documentos do disco para a memória e ordenar 4.002 registros utilizando buffer de sort em memória (correndo risco de atingir o limite máximo de 100MB e falhar em volumes maiores).

Índice Criado:
db.orders.createIndex({ status: 1, expires_at: 1 });

Justificativa:
O índice composto cobre o filtro de igualdade ({ status: "pending" }) e o critério de ordenação ({ expires_at: 1 }), eliminando o estágio de SORT em memória.

Cenário DEPOIS do índice:
- Plano de Execução (executionStats):
  - Stage vencedor: FETCH com inputStage IXSCAN (Varredura direta no índice).
  - Total de documentos examinados (totalDocsExamined): 4.002 documentos.
  - Chaves de índice examinadas (totalKeysExamined): 4.002 chaves.
  - Documentos retornados (nReturned): 4.002.
  - Tempo de execução medido: 6 ms.
  - Memória consumida na ordenação: 0 bytes (eliminou completamente o Sort em memória).
- Diagnóstico: O índice reduziu a leitura de documentos em 80% (de 20.006 para 4.002) e reduziu o tempo pela metade, com ganho brutal de escalabilidade de memória.


4. ANÁLISE DA CONSULTA ANALÍTICA (CONSULTA 1 - FATURAMENTO POR EVENTO E PERÍODO)

A pergunta de negócio respondida é: Qual foi o faturamento total e ingressos confirmados no mês de outubro de 2026 por evento?

4.1 No MySQL

Consulta executada:
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
ORDER BY faturamento_total DESC;

Cenário ANTES do índice composto de data:
- Plano de Execução (EXPLAIN ANALYZE):
  -> Sort: faturamento_total DESC (actual time=85.8..85.8 rows=2)
      -> Group aggregate: count(distinct orders.id)... (actual time=85.1..85.8)
          -> Filter: ((o.status = 'confirmed') and (o.created_at between ...))
              -> Table scan on o (cost=2053 rows=20126) (actual time=0.116..3.01 rows=20006)
- Diagnóstico: O MySQL precisou realizar uma varredura completa (Table Scan) em todas as 20.006 linhas da tabela orders para filtrar status e data, gerando um tempo total de execução de 85.8 ms.

Índice Criado:
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

Justificativa:
A condição WHERE possui um filtro de igualdade (status = 'confirmed') e um filtro de faixa (created_at BETWEEN ...). O índice composto B-Tree permite que o motor pule diretamente para o início da faixa de datas dos pedidos confirmados, descartando 12.660 registros sem ler a tabela.

Cenário DEPOIS do índice composto de data:
- Plano de Execução (EXPLAIN ANALYZE):
  -> Sort: faturamento_total DESC (actual time=62.4..62.4 rows=2)
      -> Group aggregate (actual time=61.7..62.4)
          -> Index lookup on o using idx_orders_status_created (status = 'confirmed')
- Diagnóstico: O Table Scan foi substituído por busca direta em índice. O tempo total da consulta caiu de 85.8 ms para 62.4 ms (uma economia de 27% no tempo total mesmo com o custo dos agrupamentos e funções matemáticas posteriores).

4.2 No MongoDB

Consulta executada (Aggregation Pipeline):
db.orders.aggregate([
  {
    $match: {
      status: "confirmed",
      created_at: {
        $gte: ISODate("2026-10-01T00:00:00Z"),
        $lte: ISODate("2026-10-31T23:59:59Z")
      }
    }
  },
  { $unwind: "$items" },
  {
    $group: {
      _id: "$items.event_name",
      faturamento_total: { $sum: "$items.total" }
    }
  }
]);

Cenário ANTES do índice composto:
- executionStats no estágio $match / cursor:
  - Stage: COLLSCAN (Varredura total da coleção orders).
  - Total de documentos examinados (totalDocsExamined): 20.006.
  - Chaves de índice examinadas: 0.
  - Documentos qualificados para as próximas fases: 7.346.
  - Tempo do estágio de leitura: 25.9 ms.

Índice Criado:
db.orders.createIndex({ status: 1, created_at: 1 });

Justificativa:
O primeiro estágio do pipeline ($match) atua como um filtro rigoroso. Criando o índice composto { status: 1, created_at: 1 }, o MongoDB acessa diretamente os documentos qualificados via B-Tree sem inspecionar documentos cancelados, pendentes ou fora do mês de outubro.

Cenário DEPOIS do índice composto:
- executionStats no estágio $match / cursor:
  - Stage: IXSCAN seguido de FETCH.
  - Total de documentos examinados (totalDocsExamined): 7.346.
  - Chaves de índice examinadas (totalKeysExamined): 7.346.
  - Documentos qualificados para as próximas fases: 7.346.
  - Tempo do estágio de leitura: 17 ms.
- Diagnóstico: Eliminamos a leitura de 12.660 documentos desnecessários (redução de 63% no volume de dados lidos do disco), diminuindo o tempo de 25.9 ms para 17 ms.


5. QUADRO COMPARATIVO CONSOLIDADO (ANTES vs. DEPOIS)

Caso 1: Consulta Operacional (Pedidos Pendentes por Expiração)
- MySQL ANTES: 4 loops com Index Lookup em customer + Filesort explícito (11.3 ms).
- MySQL DEPOIS: Index Lookup composto direto em status_expires (9.4 ms) sem varredura de clientes.
- MongoDB ANTES: Stage COLLSCAN examinando 20.006 docs + Stage SORT alocando 2.4 MB de memória (11 ms).
- MongoDB DEPOIS: Stage IXSCAN examinando apenas 4.002 docs com ZERO alocação de memória para sort (6 ms).

Caso 2: Consulta Analítica (Faturamento por Evento em Outubro/2026)
- MySQL ANTES: Table Scan em 20.006 linhas da tabela orders (85.8 ms).
- MySQL DEPOIS: Index Range Scan em status_created eliminando 12.660 linhas (62.4 ms).
- MongoDB ANTES: Stage COLLSCAN examinando 20.006 documentos na fase $match (25.9 ms).
- MongoDB DEPOIS: Stage IXSCAN examinando exatamente 7.346 documentos qualificados (17 ms).


6. DISCUSSÃO CRÍTICA: POR QUE NEM TODO ÍNDICE MELHORA TODA CONSULTA?

Um dos pontos mais importantes solicitados pela atividade é compreender que índices não são gratuitos e não devem ser criados indiscriminadamente:

1. O Custo Oculto da Escrita (Overhead em INSERT / UPDATE / DELETE):
Cada índice criado é uma árvore balanceada (B-Tree) que o banco de dados precisa atualizar a cada novo pedido emitido. Criar muitos índices para cobrir consultas pontuais degradaria brutalmente a velocidade do fluxo de checkout do TicketCore no momento em que abre a venda de um lote disputado.

2. A Seletividade do Campo (Cardinalidade):
Criar um índice isolado apenas na coluna status (que só possui 3 valores: confirmed, pending, cancelled) é praticamente inútil, pois o otimizador do MySQL prefere fazer Table Scan do que percorrer o índice para ler 70% da tabela. O índice só passa a ser eficiente quando composto com outro campo de alta seletividade (como status + expires_at ou status + created_at).

3. Ordenação dos Campos no Índice Composto:
Um índice em (created_at, status) teria pouca utilidade se o filtro buscasse primeiro por status com igualdade e depois fizesse um range de datas. A ordem dos campos no índice (Igualdade primeiro, Faixa/Ordenação depois) é determinante para que o índice seja aproveitado.

4. Consumo de Memória RAM:
Índices precisam residir no Buffer Pool do MySQL (InnoDB) e na WiredTiger Cache do MongoDB. Índices inúteis ou redundantes roubam espaço precioso de memória que deveria estar armazenando as páginas de dados mais acessadas do sistema.


7. CONCLUSÃO
A missão 04 - Desempenho demonstrou na prática o impacto de um planejamento consciente de indexação:
- Provamos com evidências de EXPLAIN e explain("executionStats") que índices compostos bem desenhados reduzem em até 80% o número de documentos inspecionados.
- Eliminamos operações custosas de ordenação em memória (Sort / Filesort), protegendo o servidor de estouro de buffer.
- Evidenciamos que a escolha dos índices deve sempre considerar a relação custo/benefício entre a velocidade de leitura e a sobrecarga imposta nas escritas de alta frequência.
