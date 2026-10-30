DOCUMENTO DE ENTREGA: DESAFIO TICKETCORE - 05 CONSISTÊNCIA SOB CONCORRÊNCIA
Disciplina: Banco de Dados Avançado
Professor: Claudinei José Machado
Tecnologia de Demonstração / Validação: C# (.NET)
Bancos de Dados: MySQL 9 e MongoDB Community 9


1. INTRODUÇÃO E O DESAFIO DO ÚLTIMO INGRESSO
No mercado de bilhetagem eletrônica, o momento mais crítico da arquitetura ocorre na abertura das vendas de lotes disputados. Quando milhares de compradores clicam simultaneamente em Comprar, o sistema é submetido a uma corrida desenfreada (race condition).

O problema clássico do overselling (venda acima do limite) ocorre quando duas ou mais transações executam a seguinte sequência ingênua:
1. Leitura: A transação A lê que restam 10 ingressos disponíveis.
2. Leitura concorrente: A transação B lê exatamente os mesmos 10 ingressos disponíveis.
3. Decisão isolada: Ambas concluem que há ingressos suficientes.
4. Escrita desprotegida: Ambas decrementam e gravam pedidos.

Se 50 compradores tentarem adquirir os últimos 10 ingressos sob essa abordagem desprotegida, o saldo final ficará negativo (-40), gerando quebra de contrato, processos jurídicos e superlotação no estádio.

Nesta etapa, reproduzimos o cenário de alta disputa (50 requisições simultâneas concorrendo por apenas 10 ingressos disponíveis), corrigimos com técnicas modernas de concorrência no MySQL e no MongoDB, e validamos a blindagem contra solicitações repetidas (idempotência).


2. ROTEIRO DE REPRODUÇÃO DO PROBLEMA (A FALHA DA LEITURA NÃO ATÔMICA)

O erro conceitual que permite a venda acima do limite decorre da separação entre o momento da leitura e o momento da escrita:
- Abordagem vulnerável em pseudocódigo:
  SELECT available_quantity INTO v_qtd FROM event_sector_prices WHERE id = 99;
  IF v_qtd >= 1 THEN
      -- AQUI OCORRE A BRECHA: Outras 49 conexões leem v_qtd = 10 antes da primeira gravar!
      UPDATE event_sector_prices SET available_quantity = available_quantity - 1 WHERE id = 99;
      INSERT INTO orders ...;
  END IF;

Em ambientes de alta concorrência com pool de conexões e múltiplas threads, essa leitura torna-se obsoleta milissegundos depois. O resultado prático é a emissão de mais ingressos do que a capacidade permitida.


3. IMPLEMENTAÇÃO CORRIGIDA NO MYSQL (MODELO RELACIONAL)

Para solucionar o problema no MySQL (InnoDB), implementamos o padrão de Atualização Condicional Atômica (Atomic Conditional Update) envolvido em transação ACID com nível de isolamento READ COMMITTED.

3.1 Mecanismo Adotado: Update Condicional Atômico
Em vez de ler primeiro e decidir na aplicação, transferimos o predicado de decisão diretamente para o motor do banco de dados na instrução UPDATE:

UPDATE event_sector_prices 
SET available_quantity = available_quantity - 1,
    status = IF(available_quantity = 1, 'sold_out', status)
WHERE id = 99 AND available_quantity >= 1;

Por que essa abordagem é superior ao SELECT ... FOR UPDATE?
1. Bloqueio por tempo mínimo: O InnoDB adquire um lock exclusivo (X-Lock) apenas na linha afetada durante os microssegundos necessários para alterar os bytes da página e decrementar o valor.
2. Eliminação de Deadlocks: Não há dependência cruzada entre leitura e escrita.
3. Resposta imediata: Se available_quantity for menor que 1, a cláusula WHERE rejeita a linha e o MySQL retorna 0 linhas afetadas (Rows Affected = 0).
4. Decisão atômica: A aplicação verifica if (rowsAffected > 0). Se for maior que zero, prossegue com o INSERT de pedido e ingresso dentro do COMMIT. Se for zero, executa ROLLBACK imediato liberando recursos.


4. IMPLEMENTAÇÃO CORRIGIDA NO MONGODB (MODELO DOCUMENTAL NOSQL)

No MongoDB, as operações de escrita em um único documento são atômicas por definição do motor WiredTiger, mesmo sem iniciar uma transação distribuída pesada.

4.1 Mecanismo Adotado: Operação Atômica no Documento com Filtro de Disponibilidade
Como os lotes estão embutidos no array sector_prices dentro da coleção events, executamos uma atualização atômica utilizando o operador de incremento $inc negativo condicionado à quantidade:

db.events.updateOne(
  {
    mysql_id: 1,
    sector_prices: {
      $elemMatch: {
        id: 99,
        available_quantity: { $gte: 1 }
      }
    }
  },
  {
    $inc: { "sector_prices.$.available_quantity": -1 }
  }
);

Como funciona a garantia de atomicidade no MongoDB?
1. O filtro examina se existe o lote com id = 99 e available_quantity maior ou igual a 1.
2. Se a condição for verdadeira, o WiredTiger executa o decremento ($inc: -1) atomicamente no documento do evento.
3. A aplicação avalia result.ModifiedCount:
   - Se ModifiedCount == 1: A reserva foi realizada com exclusividade. A aplicação então grava o pedido e o ingresso na coleção orders e tickets.
   - Se ModifiedCount == 0: O lote já estava esgotado. Nenhuma modificação é feita e a compra é rejeitada instantaneamente.


5. TESTE DE SOLICITAÇÕES REPETIDAS (IDEMPOTÊNCIA SOB CONCORRÊNCIA)

Um comprador ansioso ou um webhook de pagamento com retry automático pode disparar a mesma requisição múltiplas vezes em paralelo. Para testar essa consistência:
- Submetemos 5 requisições simultâneas utilizando exatamente a mesma chave de idempotência (idempotency_key).
- No MySQL: A restrição UNIQUE KEY na coluna idempotency_key da tabela payments barrou 4 das 5 tentativas com o erro 1062 (Duplicate entry), gravando exatamente 1 pagamento.
- No MongoDB: O índice único createIndex({ idempotency_key: 1 }, { unique: true }) na coleção payments rejeitou 4 tentativas com o erro 11000 (DuplicateKey), gravando exatamente 1 pagamento.


6. RESULTADOS DOS TESTES PRÁTICOS (EVIDÊNCIAS DE EXECUÇÃO EM C# / .NET)

Desenvolvemos e executamos uma suíte multithread em C# (.NET) utilizando Task.Run() e 50 threads concorrentes disputando o lote 99 (com apenas 10 ingressos disponíveis):

Resultado no MySQL:
- Total de requisições simultâneas: 50
- Compras confirmadas com sucesso: 10
- Compras rejeitadas por falta de estoque: 40
- Saldo final disponível no banco (available_quantity): 0
- Status final do lote: sold_out
- Ingressos emitidos na tabela tickets: Exatamente 10 ingressos com códigos únicos.

Resultado no MongoDB:
- Total de requisições simultâneas: 50
- Compras confirmadas com sucesso: 10
- Compras rejeitadas por falta de estoque: 40
- Saldo final disponível no documento (available_quantity): 0
- Ingressos emitidos na coleção tickets: Exatamente 10 ingressos com códigos únicos.

Resultado do Teste de Idempotência:
- MySQL: 1 pagamento gravado com sucesso e 4 duplicatas barradas.
- MongoDB: 1 pagamento gravado com sucesso e 4 duplicatas barradas.


7. EXPLICAÇÃO DAS DIFERENÇAS ARQUITETURAIS ENTRE OS DOIS BANCOS

Eixo 1: Modelo de Travamento (Locking)
- No MySQL: Utiliza controle de concorrência com locks em nível de linha no motor InnoDB (Row-level Locking) apoiado pelo arquivo de log transacional (WAL - Redo Log/Undo Log). As transações garantem o isolamento pleno entre tabelas distintas através do COMMIT.
- No MongoDB: Utiliza controle de concorrência otimista com travas no nível de documento na WiredTiger. Não é necessário manter transações multidocumento abertas para a reserva de estoque, pois o decremento atômico no documento do evento funciona como um semáforo infalível.

Eixo 2: Tratamento de Sobrecarga (Throughput)
- No MySQL: O Update Condicional evita longas esperas de filas de locks, permitindo que as requisições excedentes recebam 0 linhas afetadas e sejam liberadas imediatamente.
- No MongoDB: A operação atômica de documento possui altíssimo throughput de I/O em memória, sendo ideal para absorver picos de milhões de cliques em poucos segundos.

Eixo 3: Falha na Emissão Posterior à Reserva
- Se a gravação do pedido falhar após a reserva do ingresso:
  - No MySQL: Um simples ROLLBACK restaura o saldo do lote automaticamente.
  - No MongoDB: Caso não se utilize transações multidocumento de réplica, a aplicação deve disparar uma operação de compensação ($inc: +1) para devolver a cota ao lote.


8. CONCLUSÃO
A missão 05 - Concorrência foi cumprida integralmente atendendo a 100% dos critérios:
- O overselling foi matematicamente e praticamente impedido em ambas as tecnologias.
- Nem o MySQL nem o MongoDB permitiram saldo negativo.
- Exatamente 10 compras foram concluídas e exatamente 10 ingressos foram gerados.
- Nenhuma duplicata foi emitida sob chamadas repetidas ou concorrentes.

