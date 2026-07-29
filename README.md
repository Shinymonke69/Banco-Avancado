# ES & TADS - 2026

Projeto exclusivo para uso didático na disciplina de **Banco de Dados Avançado** dos cursos:
- **Engenharia de Software (ES)**
- **Tecnologia em Análise e Desenvolvimento de Sistemas (TADS)**.

# Setup

## Download

Download do projeto completo

```sh
git clone git@github.com:cjchamado/tads-es-2026-bd.git bd-avancado
```

## Up

Subir os containers de serviços

```sh
cd bd-avancado
```

**EXECUTE APENAS UM DOS COMANDOS ABAIXO**

**Opção 1 (verbose):**
> Execute este comando na primeira execução, este formato permite que você analise se tudo está OK.

```sh
docker compose up --build
```

**Opção 2 (background):**
> Para garantir que tudo está OK, utilize este formato somente depois da primeira vez que rodar os containers.

```sh
docker compose up --build -d
```

## Check

Verificar se tudo está online (OK)

```sh
docker ps | grep advanced_bd
```
> Uma lista de containers em execução deve ser exibida após o comando.

## API (Laravel)

**Utilizaremos o framework laravel para de testes de carga, seeding e outros facilitadores que possibilitem o melhor aproveitamento na disciplina.**

1. Acessar o container do php para execução dos comandos do laravel (artisan).

```sh
docker exec -it advanced_bd_php bash
```

2. Instalar as dependências
> Apenas a primeira vez ou quando novas dependências forem adicionadas

```sh
composer install
```

3. Configurar o arquivo de variáveis de ambiente (.env)
> As configurações básicas já estão definidas

```sh
cp .env.example .env
```

4. Gerar chave secreta da aplicação

```sh
php artisan key:generate
```

5. Inicializar migrations

```sh
php artisan migrate
```

6. Rodar seeders

```sh
php artisan db:seed
```

# Acesso aos recursos web:

- [**phpMyAdmin** - http://localhost:8584](http://localhost:8584)
- [**API** - http://localhost:8582](http://localhost:8582)
