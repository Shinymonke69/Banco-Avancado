# Passo a Passo: Atividade Prática de Banco de Dados Avançado (E-commerce)

Este guia foi montado com base nas instruções do seu professor. Como o seu banco de dados já está estruturado com clientes, produtos, pedidos, etc., vamos focar exatamente nos requisitos avançados (Views, Procedures, Functions e Triggers). 

Vou explicar o **porquê** e o **como** de cada item, e deixarei o esqueleto do SQL para você preencher ou entender a lógica antes de executar no seu banco.

---

## Passo 1: Criação de Novas Tabelas (Estrutura Adicional)

O primeiro passo é criar duas tabelas para servir de histórico, onde os Triggers vão gravar as informações automaticamente.

### 1.1 Tabela `stock_movements`
**Objetivo**: Registrar toda vez que o estoque de um produto for alterado.
**Campos exigidos**:
- `id` (Chave Primária, Auto Increment)
- `product_id` (Chave Estrangeira para `products`)
- `type` (Pode ser IN, OUT ou ADJUSTMENT. O ideal é usar um ENUM ou VARCHAR)
- `quantity` (Quantidade movimentada)
- `stock_before` (Estoque antes da ação)
- `stock_after` (Estoque depois da ação)
- `reference_type` (Para identificar se a origem foi um ORDER ou MANUAL)
- `reference_id` (O ID do pedido, se aplicável)
- `created_at` (Timestamp padrão)

**Exemplo de DDL (Criação)**:
```sql
CREATE TABLE stock_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    type VARCHAR(20) NOT NULL,
    quantity BIGINT NOT NULL,
    stock_before BIGINT NOT NULL,
    stock_after BIGINT NOT NULL,
    reference_type VARCHAR(50),
    reference_id BIGINT UNSIGNED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

### 1.2 Tabela `order_status_history`
**Objetivo**: Registrar sempre que o status de um pedido for modificado.
**Campos exigidos**:
- `id` (Chave primária)
- `order_id` (Chave Estrangeira para `orders`)
- `old_status` (Status anterior)
- `new_status` (Status novo)
- `changed_at` (Timestamp da mudança)

---

## Passo 2: Functions (Cálculos e Regras Reutilizáveis)

As funções devem retornar apenas um valor escalar e são ótimas para encapsular regras matemáticas ou buscas de somatórios.

### 2.1 Function: `fn_order_total`
**Objetivo**: Receber o `order_id` e retornar o valor total (Soma de `product_price * quantity` da tabela `order_items`).
- **Parâmetro**: `p_order_id BIGINT UNSIGNED`
- **Retorno**: `DECIMAL(10,2)`
- **Lógica**: Faça um `SELECT SUM(...) INTO v_total FROM order_items WHERE order_id = p_order_id;`, e depois dê um `RETURN v_total;`.

### 2.2 Function: `fn_customer_lifetime_value`
**Objetivo**: Receber o `customer_id` e retornar o total gasto por esse cliente (apenas em pedidos "pagos" ou "concluídos").
- **Parâmetro**: `p_customer_id BIGINT UNSIGNED`
- **Retorno**: `DECIMAL(10,2)`
- **Lógica**: Use a tabela `orders`, filtre pelo `customer_id` e pelo status adequado (ex: `status = 'paid'`), faça o `SUM(total)` e retorne esse valor.

---

## Passo 3: Views (Consultas Reutilizáveis)

As views são como "tabelas virtuais" montadas a partir de um `SELECT` complexo. O objetivo é facilitar a leitura de relatórios pela aplicação.

### 3.1 View: `vw_product_sales`
**Objetivo**: Mostrar o desempenho de vendas de cada produto.
- **Campos esperados**: `product_id`, `product_name`, `quantity_sold`, `revenue` (faturamento) e `average_price`.
- **Lógica**: Faça um `JOIN` entre `products`, `order_items` e `orders`. Filtre apenas pedidos válidos/pagos. Use `GROUP BY` no `product_id`. `revenue` será a soma do preço * quantidade, e o `average_price` pode ser a média do preço vendido.

### 3.2 View: `vw_customer_ranking`
**Objetivo**: Mostrar os melhores clientes do e-commerce.
- **Campos esperados**: `customer_id`, `customer_name`, `orders_count` (total de pedidos), `total_spent` (total gasto), `average_order_value` (ticket médio) e `last_order_at` (data do último pedido).
- **Lógica**: Faça um `JOIN` entre `customers` e `orders`. Agrupe pelo cliente e utilize as funções de agregação como `COUNT()`, `SUM()`, `AVG()` e `MAX()` (para a última data). Lembre-se de ordenar usando `ORDER BY total_spent DESC`.

---

## Passo 4: Stored Procedures (Operações e Regras de Negócio)

Ao contrário das funções, as procedures não têm um retorno direto e podem modificar o banco (INSERT, UPDATE) envolvendo várias tabelas. O professor exigiu que as procedures possuíssem **Transações (Transaction)** e tratamento de erros.

### 4.1 Procedure: `sp_recalculate_order`
**Objetivo**: Recalcular o valor total de um pedido e atualizar na tabela `orders`.
- **Parâmetro**: `order_id`
- **Lógica Obrigatória**:
  1. Verificar se o pedido existe (se não existir, dispare um erro com `SIGNAL SQLSTATE`).
  2. Usar a função `fn_order_total(order_id)` que você criou no passo 2 para pegar o novo total.
  3. Fazer um `UPDATE orders SET total = v_novo_total WHERE id = order_id;`.
  4. Retornar um SELECT com as informações atualizadas.

### 4.2 Procedure: `sp_finalize_order`
**Objetivo**: Fechar um pedido, marcar como pago e validar os dados.
- **Parâmetro**: `order_id`
- **Lógica Obrigatória**:
  1. Usar `START TRANSACTION;`.
  2. Incluir um `DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;` para segurança.
  3. Verificar se o pedido existe e qual seu status atual.
  4. Recalcular o valor usando a `fn_order_total(order_id)`.
  5. Atualizar a tabela `orders`: Mudar status (para pago/closed), registrar `paid_at = NOW()` e salvar o `total`.
  6. Em caso de sucesso, usar `COMMIT;`.

---

## Passo 5: Triggers (Automatização e Integridade)

Os gatilhos vão escutar eventos e reagir automaticamente, evitando que a aplicação precise cuidar disso.

### 5.1 Trigger: Controle Automático de Estoque (`BEFORE INSERT ON order_items`)
**Objetivo**: Impedir vendas sem estoque e registrar o movimento.
- **Lógica**:
  1. No momento do insert de um item, buscar o `stock` do produto associado.
  2. Verificar se o estoque é maior ou igual à quantidade solicitada (`NEW.quantity`).
  3. **Se for menor**, bloqueie a operação disparando um erro: `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente';`.
  4. **Se for maior/igual**, faça o `UPDATE products SET stock = stock - NEW.quantity...`.
  5. Faça um `INSERT` na tabela `stock_movements` (criada no passo 1) gravando as informações de saída (`type = 'OUT'`).

### 5.2 Trigger: Histórico de Alteração de Status (`AFTER UPDATE ON orders`)
**Objetivo**: Sempre que o status de um pedido mudar, salvar na tabela de histórico.
- **Lógica**:
  1. Compare o status antigo com o novo: `IF OLD.status <> NEW.status THEN ...`
  2. Se mudou, faça um `INSERT` na tabela `order_status_history` passando o ID do pedido, o `OLD.status` e o `NEW.status`.

*(Nota: O professor passou um "Desafio Adicional" de trigger AFTER UPDATE na order_items. Fica a seu critério fazê-lo, mas a lógica envolve checar se NEW.quantity > OLD.quantity e ajustar a diferença no estoque).*

---

## Passo 6: Cenários de Testes Obrigatórios

Após criar tudo isso, o trabalho exige que você prove que funciona através de chamadas de teste. No final do seu arquivo `.sql`, você deve colocar os testes:

```sql
-- Teste 1: Function de Pedido
SELECT fn_order_total(1) AS Total_Pedido_1;

-- Teste 2: Function de Cliente
SELECT fn_customer_lifetime_value(1) AS Lifetime_Value_Cliente_1;

-- Teste 3: View de Produtos
SELECT * FROM vw_product_sales ORDER BY quantity_sold DESC LIMIT 5;

-- Teste 4: View de Clientes
SELECT * FROM vw_customer_ranking LIMIT 5;

-- Teste 5: Procedure de recálculo
CALL sp_recalculate_order(10);

-- Teste 6: Procedure de finalização
CALL sp_finalize_order(10);

-- Teste 7 e 8: Teste os triggers forçando um erro de estoque e um sucesso (Tente inserir num pedido via INSERT)
```

## Resumo e Como Proseguir

1. Leia este guia com calma.
2. Crie um arquivo SQL limpo (ex: `meu_trabalho_avancado.sql`).
3. Vá codificando os itens na ordem (Tabelas -> Functions -> Views -> Procedures -> Triggers -> Testes).
4. No final, elabore também o Relatório em PDF que ele pede (Seção 14 do edital), que deve descrever qual foi o objetivo e os parâmetros de cada função que você criou.

Qualquer dúvida específica de código que você agarrar (por exemplo, como escrever o Trigger de estoque certinho), me mande aqui que eu te dou a sintaxe!
