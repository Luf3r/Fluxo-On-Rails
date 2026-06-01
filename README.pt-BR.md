# 💰 Fluxo Rails

[English](README.md) | [Português](README.pt-BR.md)

> Um sistema de gestão financeira pessoal reconstruído em um monolito Rails 8.1. Desenvolvido por um único desenvolvedor júnior com assistência de IA, demonstrando como ferramentas modernas de IA ampliam a produtividade de um dev solo.

[![CI](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

---

## Sobre

Fluxo é uma plataforma de finanças pessoais onde os usuários poderão acompanhar receitas e despesas, gerenciar múltiplas contas financeiras, definir orçamentos por categoria, criar metas de economia e gerar relatórios analíticos.

Este repositório está atualmente na **fase de fundação e autenticação**: a base Rails, banco de dados, fluxos Devise, rate limiting e CI estão no lugar, mas as funcionalidades financeiras ainda não foram implementadas. O monorepo TypeScript anterior (NestJS + Next.js) serve como referência conceitual — este app começa do zero a partir das convenções Rails, sem portar a arquitetura anterior.

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
| Deploy | App Fly.io `fluxo-on-rails` em `gru`, usando Neon |

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

## Deploy

O primeiro alvo de produção é Fly.io, usando Neon via `DATABASE_URL`. O contrato
de deploy fica versionado em `Dockerfile` e `fly.toml`; decisões duráveis e
detalhes operacionais estão documentados em
[`docs/adr/0004-flyio-first-deploy.md`](docs/adr/0004-flyio-first-deploy.md).

Secrets de produção são configurados na plataforma de deploy, não neste
repositório. Os secrets necessários incluem `RAILS_MASTER_KEY`, `DATABASE_URL` e
credenciais SMTP quando email transacional estiver habilitado.

SMTP é opcional no primeiro deploy. Sem configuração SMTP, o envio externo de
emails fica desabilitado; quando email transacional for necessário, configure um
provedor SMTP e um remetente verificado em `MAILER_FROM`.

Active Storage permanece intencionalmente no serviço de disco local para o
primeiro deploy. Configure object storage antes de aceitar uploads persistentes
de usuários em produção.

---

## Verificação

```bash
bin/ci
```

O `bin/ci` é o equivalente local do pipeline do GitHub Actions. Ele roda migration do banco de teste, RSpec, RuboCop, auditorias de vulnerabilidade de gems e importmap, Brakeman, Zeitwerk e precompile dos assets de produção.

Specs de conteúdo de PDF usam `pdftotext` de `poppler-utils` quando forem promovidas para a suíte ativa. A geração de PDF em si deve usar Prawn e não depende de pacotes de sistema.

Checks individuais úteis:

```bash
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec dotenv -f .env -- bin/rails assets:precompile
```

---

## Escopo Atual

**Implementado:**

- Scaffold Rails full-stack com Hotwire e Tailwind CSS
- Neon Serverless Postgres em runtime, com PostgreSQL local/CI para testes
- `User` Devise com `name`, `currency` (validado contra ISO 4217: BRL, USD, EUR), `avatar_url`, confirmacao de email e timestamp de paridade `email_verified_at`
- Throttles Rack::Attack para tentativas de login e recuperação de senha
- Content Security Policy aplicada nas respostas do navegador
- Página inicial e entradas completas de autenticação Devise: login, cadastro, recuperação de senha, confirmação de email e edição de conta
- Serviço local Mailpit para email em desenvolvimento
- Configuração de deploy Fly.io com Docker, health check em `/up` e migrations por release command
- CI: migrations do banco, RSpec, RuboCop, auditorias de vulnerabilidade, Brakeman, Zeitwerk e precompile dos assets de produção

**Adiado para fases futuras:**

- Contas, transações, categorias, orçamentos, metas e dashboard
- OAuth
- Relatórios em PDF, importação CSV, paginação e busca

---

## Registros de Decisão Arquitetural

Decisões-chave documentadas em `docs/adr/`:

| # | Decisão | Escolha |
|---|---|---|
| 0001 | Arquitetura da aplicação | Monolito Rails 8.1.3 com Hotwire — evita a complexidade de SPA sem abrir mão da interatividade |
| 0002 | Fronteira de domínio autenticado | Controllers financeiros herdam autenticação e padrão tenant-safe de `404 Not Found` |
| 0003 | Contratos MVP do domínio financeiro | Regras de transferências, orçamentos, categorias, paginação/busca e testes de PDF |

Os contratos das próximas etapas ficam em [`future_specs/README.md`](future_specs/README.md). Eles são specs de planejamento, não fazem parte da suíte verde até a etapa ser promovida para `spec/`.

O fluxo de contribuição está em [`CONTRIBUTING.md`](CONTRIBUTING.md). O roadmap em etapas está em [`docs/roadmap.md`](docs/roadmap.md).

---

## Licença

[AGPL-3.0](LICENSE)

---

> Este projeto é desenvolvido com assistência de IA (Codex da OpenAI) como parte de uma exploração sobre desenvolvimento de software aumentado por IA. Todas as decisões arquiteturais, revisões de código e sessões de debugging envolvem colaboração com IA — demonstrando o que um desenvolvedor júnior consegue entregar ao usar ferramentas modernas de IA de forma efetiva.
