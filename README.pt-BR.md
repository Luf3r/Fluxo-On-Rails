# 💰 Fluxo Rails

[English](README.md) | [Português](README.pt-BR.md)

> Um sistema de gestão financeira pessoal reconstruído em um monolito Rails 8.1. Desenvolvido por um único desenvolvedor júnior com assistência de IA, demonstrando como ferramentas modernas de IA ampliam a produtividade de um dev solo.

[![CI](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

---

## Sobre

Fluxo é uma plataforma de finanças pessoais onde os usuários poderão acompanhar receitas e despesas, gerenciar múltiplas contas financeiras, definir orçamentos por categoria, criar metas de economia e gerar relatórios analíticos.

Este repositório está atualmente na **fase de setup base**: a fundação Rails está no lugar, mas as funcionalidades financeiras ainda não foram implementadas. O monorepo TypeScript anterior (NestJS + Next.js) serve como referência conceitual — este app começa do zero a partir das convenções Rails, sem portar a arquitetura anterior.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Linguagem / Framework | Ruby 4.0.5 · Rails 8.1.3 |
| Banco de dados | Neon Serverless Postgres |
| Autenticação | Devise (email + senha) |
| Proteção contra abuso | Rate limiting com Rack::Attack |
| Jobs / Cache / WebSockets | Solid Queue · Solid Cache · Solid Cable |
| Frontend | Hotwire · Turbo · Stimulus · Tailwind CSS v4 |
| Armazenamento de arquivos | Active Storage (disco em dev/test) |
| Testes | RSpec · FactoryBot · Capybara |
| Linting | RuboCop Rails Omakase |
| Serviços locais | Docker Compose (PostgreSQL para testes · Mailpit) |

---

## Começando

```bash
mise trust
mise install
cp .env.example .env
# Preencha DATABASE_URL com sua URL Neon. TEST_DATABASE_URL usa Postgres local por padrão.
docker compose up -d
bundle install
bin/rails db:migrate
bin/dev
```

- App: http://localhost:3000
- Mailpit: http://localhost:8025

O Docker Compose sobe PostgreSQL para testes locais e Mailpit para email em desenvolvimento. Desenvolvimento e produção leem uma URL Neon de `DATABASE_URL`. Testes locais usam `postgresql://postgres:postgres@localhost:5432/fluxo_test` por padrão, e você pode sobrescrever `TEST_DATABASE_URL` quando quiser usar um banco remoto de teste separado. O GitHub Actions também usa um serviço PostgreSQL efêmero na CI em vez de um secret de banco do repositório.

O `dotenv-rails` carrega `.env` no desenvolvimento e nos testes. Ambientes de deploy devem fornecer credenciais pela configuração de secrets/runtime da plataforma.

Prefira uma connection string Neon pooled para processos web e workers. Mantenha uma URL direct disponível para migrations ou release commands quando a plataforma de deploy exigir. Solid Queue, Solid Cache e Solid Cable compartilham `DATABASE_URL` em produção, a menos que `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL` ou `CABLE_DATABASE_URL` sejam definidas separadamente.

---

## Verificação

```bash
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec
bundle exec rubocop
bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec dotenv -f .env -- bin/rails assets:precompile
```

---

## Escopo Atual

**Implementado:**

- Scaffold Rails full-stack com Hotwire e Tailwind CSS
- Neon Serverless Postgres em runtime, com PostgreSQL local/CI para testes
- `User` Devise com `name`, `currency` (validado contra ISO 4217: BRL, USD, EUR), `avatar_url` e `email_verified_at` (campo de paridade — Devise confirmable não ativado)
- Throttles Rack::Attack para tentativas de login e recuperação de senha
- Página inicial e entradas de autenticação Devise
- Serviço local Mailpit para email em desenvolvimento
- CI: migrations do banco, RSpec, RuboCop, Zeitwerk e precompile dos assets de produção

**Adiado para fases futuras:**

- Contas, transações, categorias, orçamentos, metas e dashboard
- OAuth e fluxo customizado de confirmação de email
- Relatórios em PDF, importação CSV, paginação e busca
- Configuração de deploy

---

## Registros de Decisão Arquitetural

Decisões-chave documentadas em `docs/adr/`:

| # | Decisão | Escolha |
|---|---|---|
| 0001 | Arquitetura da aplicação | Monolito Rails 8.1.3 com Hotwire — evita a complexidade de SPA sem abrir mão da interatividade |

---

## Licença

[AGPL-3.0](LICENSE)

---

> Este projeto é desenvolvido com assistência de IA (Codex da OpenAI) como parte de uma exploração sobre desenvolvimento de software aumentado por IA. Todas as decisões arquiteturais, revisões de código e sessões de debugging envolvem colaboração com IA — demonstrando o que um desenvolvedor júnior consegue entregar ao usar ferramentas modernas de IA de forma efetiva.
