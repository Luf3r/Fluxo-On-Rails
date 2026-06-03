# 💰 Fluxo Rails

[English](README.md) | [Português](README.pt-BR.md)

> Um sistema de gestão financeira pessoal reconstruído em um monolito Rails 8.1. Desenvolvido por um único desenvolvedor júnior com assistência de IA, demonstrando como ferramentas modernas de IA ampliam a produtividade de um dev solo.

[![CI](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

---

## Sobre

Fluxo é uma plataforma de finanças pessoais onde os usuários poderão acompanhar receitas e despesas, gerenciar múltiplas contas financeiras, definir orçamentos por categoria, criar metas de economia e gerar relatórios analíticos.

Este repositório está atualmente na **primeira fase do MVP financeiro**: a base Rails, a autenticação Devise e o domínio de contas/transações estão no lugar. Usuários podem criar contas financeiras, registrar receitas e despesas e mover dinheiro por transferências representadas em duas linhas pareadas. O monorepo TypeScript anterior (NestJS + Next.js) serve como referência conceitual — este app começa do zero a partir das convenções Rails, sem portar a arquitetura anterior.

---

## Preview em produção

A versão atual em produção está disponível em
[https://fluxo-on-rails.fly.dev](https://fluxo-on-rails.fly.dev), mostrando na
prática a fundação Rails de autenticação, a landing page localizada e a UI
responsiva do projeto.

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
| Paginação | Pagy |
| Testes | RSpec · FactoryBot · Capybara · shoulda-matchers |
| Linting | RuboCop Rails Omakase |
| Serviços locais | Docker Compose (PostgreSQL para testes · Mailpit) |
| Deploy | App Fly.io `fluxo-on-rails` em `gru`, grupos de processo web/worker, usando Neon |

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

O Fly roda grupos de processo separados para `web` e `worker`. O grupo `web`
inicia Thruster/Puma com `bin/thrust bin/rails server`, o grupo `worker` inicia
Solid Queue com `bin/jobs start`, e o serviço HTTP com health checks em `/up`
fica escopado apenas para `web`. As Machines de web e worker usam
`shared-cpu-1x` com 512 MB de RAM, e produção mantém duas Machines web ativas
com `min_machines_running = 2` para evitar latência de cold start e as falhas de
OOM/health check em 256 MB observadas no primeiro deploy com processos
separados.

Secrets de produção são configurados na plataforma de deploy, não neste
repositório. Os secrets necessários incluem `RAILS_MASTER_KEY`, `DATABASE_URL` e
credenciais SMTP quando email transacional estiver habilitado.

SMTP é opcional no primeiro deploy. Sem configuração SMTP, o envio externo de
emails fica desabilitado; quando email transacional for necessário, configure um
provedor SMTP e um remetente verificado em `MAILER_FROM`.

Active Storage permanece intencionalmente no serviço de disco local para o
primeiro deploy. Configure object storage antes de aceitar uploads persistentes
de usuários em produção.

Deploy contínuo roda pelo GitHub Actions depois que o workflow `CI` passa.
Pushes para `develop` fazem deploy no ambiente `staging`, usando por padrão o
app Fly `fluxo-on-rails-staging`; pushes para `main` fazem deploy no ambiente
`production`, usando por padrão `fluxo-on-rails`. Configure `FLY_API_TOKEN`
como secret do GitHub e sobrescreva nomes de apps ou URLs de health check com
as variáveis do GitHub Actions `FLY_STAGING_APP`, `STAGING_APP_URL`,
`FLY_PRODUCTION_APP` e `PRODUCTION_APP_URL` quando necessário. Produção pode
ficar com aprovação manual ativando required reviewers no environment
`production` do GitHub.

Ao mudar configuração de deploy, rode
`bundle exec rspec spec/config/deployment_files_spec.rb` e
`fly config validate --config fly.toml` além dos checks normais do projeto.

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
bundle exec rspec spec/config/deployment_files_spec.rb
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec dotenv -f .env -- bin/rails assets:precompile
```

---

## Escopo Atual

**Implementado:**

- Scaffold Rails full-stack com Hotwire e Tailwind CSS
- Neon Serverless Postgres em runtime, com PostgreSQL local/CI para testes
- `User` Devise com `name`, `currency` (validado contra ISO 4217: BRL, USD, EUR), `avatar_url`, confirmacao de email e timestamp de paridade `email_verified_at`
- Chaves primarias UUID v7 para registros da aplicação, mantendo tabelas de infraestrutura Solid nos padrões dos adapters
- Throttles Rack::Attack para tentativas de login e recuperação de senha
- Content Security Policy aplicada nas respostas do navegador
- Página inicial e entradas completas de autenticação Devise: login, cadastro, recuperação de senha, confirmação de email e edição de conta
- Contas financeiras por usuário com IDs UUID v7, tipos, moedas, saldo inicial, cálculo de saldo atual e tratamento vermelho para saldo negativo
- Transações de receita, despesa e transferência, incluindo status pendente automático para datas futuras
- Transferências pareadas pelo serviço `Transfers::Create`, ligadas por `transfer_pair`, isoladas a contas do mesmo usuário, editadas/removidas em conjunto e bloqueadas quando origem e destino são a mesma conta
- Telas autenticadas de CRUD para contas e transações, com `404 Not Found` tenant-safe
- Busca de transações com PostgreSQL `ILIKE`, ordenação mais recente primeiro, paginação Pagy em 25 itens por página, filtros tolerantes a datas inválidas e que preservam idioma, formatação monetária por locale e validação amigável para valores fora da precisão decimal do banco
- Categorias com padrões do sistema traduzidos na interface, subcategorias customizadas em dois níveis, orçamento opcional por categoria, proteções para categorias folha, fallback seguro de exclusão para `Outros`, associação de categoria em transações e filtros de transações por categoria/tag
- Tags por usuário com normalização para minúsculas, criação automática a partir do formulário de transações e reuso isolado por tenant
- Cobertura ativa de locale para navegação financeira, telas de categorias, telas de transações e mensagens de validação em inglês e português
- Serviço local Mailpit para email em desenvolvimento
- Configuração de deploy Fly.io com Docker, grupos de processo `web`/`worker`, health check em `/up`, Machines de 512 MB e migrations por release command
- CI: migrations do banco, RSpec, RuboCop, auditorias de vulnerabilidade, Brakeman, Zeitwerk e precompile dos assets de produção
- CD: deploy Fly.io de staging a partir de `develop`, produção a partir de `main` e checagem `/up` pós-deploy

**Adiado para fases futuras:**

- Metas, analytics, dashboard, transações recorrentes e fluxos de notificação
- OAuth
- Relatórios em PDF e importação CSV

---

## Registros de Decisão Arquitetural

Decisões-chave documentadas em `docs/adr/`:

| # | Decisão | Escolha |
|---|---|---|
| 0001 | Arquitetura da aplicação | Monolito Rails 8.1.3 com Hotwire — evita a complexidade de SPA sem abrir mão da interatividade |
| 0002 | Fronteira de domínio autenticado | Controllers financeiros herdam autenticação e padrão tenant-safe de `404 Not Found` |
| 0003 | Contratos MVP do domínio financeiro | Regras de transferências, orçamentos, categorias, paginação/busca e testes de PDF |
| 0004 | Primeiro deploy Fly.io | App Fly, banco Neon em runtime, grupos web/worker separados, Machines de 512 MB e health checks de produção |
| 0005 | Chaves primarias UUID v7 | Registros da aplicação usam IDs UUID v7; tabelas de infraestrutura Solid mantêm IDs inteiros gerenciados pelos adapters |

Os contratos das próximas etapas ficam em [`future_specs/README.md`](future_specs/README.md). Eles são specs de planejamento, não fazem parte da suíte verde até a etapa ser promovida para `spec/`.

O fluxo de contribuição está em [`CONTRIBUTING.md`](CONTRIBUTING.md). O roadmap em etapas está em [`docs/roadmap.md`](docs/roadmap.md).

---

## Licença

[AGPL-3.0](LICENSE)

---

> Este projeto é desenvolvido com assistência de IA (Codex da OpenAI) como parte de uma exploração sobre desenvolvimento de software aumentado por IA. Todas as decisões arquiteturais, revisões de código e sessões de debugging envolvem colaboração com IA — demonstrando o que um desenvolvedor júnior consegue entregar ao usar ferramentas modernas de IA de forma efetiva.
