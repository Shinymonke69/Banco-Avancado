# Guia Passo a Passo: Atividade MongoDB no Laravel

Este guia foi criado para te orientar na execução da atividade de MongoDB. Siga os passos abaixo, alterando os arquivos necessários e tirando os prints (capturas de tela) nos momentos indicados.

## Passo 1: Configurar as Models (Customer, Order e OrderItem)
A model `Product` já está configurada. Você precisa fazer a mesma coisa nas outras models (`Customer`, `Order` e `OrderItem`), que ficam na pasta `api/app/Models`.

**O que fazer em cada uma delas:**
1. Altere o `use Illuminate\Database\Eloquent\Model;` para `use MongoDB\Laravel\Eloquent\Model;`.
2. Adicione a propriedade `$connection = 'mongodb';` dentro da classe.

## Passo 2: Popular o Banco de Dados (Seed)
No terminal do seu projeto (dentro da pasta `api`), execute o comando para popular o banco de dados inicial:
```bash
php artisan db:seed
```
*(Lembre-se de primeiro acessar o container com `docker exec -it advanced_bd_php bash` e então rodar o comando `php artisan db:seed`)*

## Passo 3: Primeiros Prints no Mongo Express 📸
Acesse o **Mongo Express** no seu navegador (geralmente em `http://localhost:8081`).
Navegue até o seu banco de dados e encontre as collections.

**O que você deve printar agora:**
1. **📸 Print 1:** Abra a collection `orders` e tire um print mostrando pelo menos 2 registros inseridos.
2. **📸 Print 2:** Abra a collection `order_items` e tire um print mostrando pelo menos 2 registros inseridos lá.

## Passo 4: Ajustar o Mapeamento para Embed (Documento Incorporado)
Agora você vai mudar a model `Order` para que os itens do pedido fiquem "dentro" do documento do pedido (Embedded Documents), em vez de ficarem numa collection separada.

Abra o arquivo `api/app/Models/Order.php` e altere/adicione o relacionamento `items()` (ou `orderItems()`) usando a funcionalidade de *embedsMany* do MongoDB, conforme a [documentação do Laravel MongoDB](https://www.mongodb.com/pt-br/docs/drivers/php/laravel-mongodb/current/model-data/relationships/#embedded-document-example). 

Vai ficar algo parecido com isso na model `Order`:
```php
public function items()
{
    return $this->embedsMany(OrderItem::class);
}
```

## Passo 5: Repopular os Orders (Seed)
Como mudamos a estrutura para embed, precisamos gerar novos dados para ver isso funcionando no banco.
No terminal, rode especificamente o seeder de orders:
```bash
php artisan db:seed --class=OrderSeeder
```

## Passo 6: Último Print no Mongo Express 📸
Volte ao **Mongo Express** no seu navegador e abra a collection `orders`.

**O que você deve printar agora:**
1. **📸 Print 3:** Tire um print mostrando pelo menos 3 pedidos (`orders`). Expanda os dados (clicando nas setinhas ou nos arrays de `items`) para mostrar que os **order items** agora estão **embutidos/incorporados** diretamente dentro do documento do `order`, e não mais apenas referenciados.

## Passo 7: Enviar a Atividade
1. Pegue o **Print 1**, **Print 2** e **Print 3**.
2. Cole-os em um documento (Word ou Google Docs).
3. Salve/exporte como arquivo **.pdf**.
4. Envie o PDF no sistema/plataforma da sua faculdade.
