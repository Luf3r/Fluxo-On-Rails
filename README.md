# 💰 Fluxo Rails

[English](README.md) | [Português](README.pt-BR.md)

> A personal finance management system rebuilt on a Rails 8.1 monolith. Developed by a single junior developer with AI assistance, demonstrating how modern AI tools can amplify solo developer productivity.

[![CI](https://github.com/luf3r/fluxo/actions/workflows/ci.yml/badge.svg)](https://github.com/luf3r/fluxo/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

---

## About

Fluxo is a personal finance platform where users will track income and expenses, manage multiple financial accounts, set budgets per category, define savings goals, and generate analytical reports.

This repository is currently in its **base setup phase**: the Rails foundation is in place, but finance features are not yet implemented. The previous TypeScript monorepo (NestJS + Next.js) serves as a conceptual reference — this app starts fresh from Rails conventions rather than porting the prior architecture.

---

## Stack

| Layer | Technology |
|---|---|
| Language / Framework | Ruby 4.0.5 · Rails 8.1.3 |
| Database | Neon Serverless Postgres |
| Authentication | Devise (email + password) |
| Background jobs / Cache / WebSockets | Solid Queue · Solid Cache · Solid Cable |
| Frontend | Hotwire · Turbo · Stimulus · Tailwind CSS v4 |
| File storage | Active Storage (disk in dev/test) |
| Testing | RSpec · FactoryBot · Capybara |
| Linting | RuboCop Rails Omakase |
| Local services | Docker Compose (PostgreSQL for tests · Mailpit) |

---

## Getting Started

```bash
mise trust
mise install
cp .env.example .env
# Fill DATABASE_URL with your Neon URL. TEST_DATABASE_URL defaults to local Postgres.
docker compose up -d
bundle install
bin/rails db:migrate
bin/dev
```

- App: http://localhost:3000
- Mailpit: http://localhost:8025

Docker Compose starts PostgreSQL for local tests and Mailpit for development email. Development and production read a Neon URL from `DATABASE_URL`. Local tests default to `postgresql://postgres:postgres@localhost:5432/fluxo_test`, and you can override `TEST_DATABASE_URL` when you intentionally want a separate remote test database. GitHub Actions also uses an ephemeral PostgreSQL service for CI instead of a repository database secret.

`dotenv-rails` loads `.env` in development and test. Deployed environments should provide credentials through their runtime secret configuration.

Prefer a pooled Neon connection string for web and worker processes. Keep a direct URL available for migration or release commands if your deploy platform requires it. Solid Queue, Solid Cache and Solid Cable share `DATABASE_URL` in production unless `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL` or `CABLE_DATABASE_URL` are set separately.

---

## Verification

```bash
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec
bundle exec rubocop
bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec dotenv -f .env -- bin/rails assets:precompile
```

---

## Current Scope

**Implemented:**

- Rails full-stack scaffold with Hotwire and Tailwind CSS
- Neon Serverless Postgres for runtime, with local/CI PostgreSQL for tests
- Devise `User` with `name`, `currency` (validated against ISO 4217: BRL, USD, EUR), `avatar_url` and `email_verified_at` (parity field — Devise confirmable not enabled)
- Home page and Devise authentication entry points
- Local Mailpit service for development email
- CI: database migrations, RSpec, RuboCop, Zeitwerk and production asset precompile

**Deferred to future phases:**

- Accounts, transactions, categories, budgets, goals and dashboard
- OAuth and custom email confirmation flow
- PDF reports, CSV import, pagination and search
- Deployment configuration

---

## Architecture Decision Records

Key decisions documented under `docs/adr/`:

| # | Decision | Choice |
|---|---|---|
| 0001 | Application architecture | Rails 8.1.3 monolith with Hotwire — avoids SPA complexity without sacrificing interactivity |

---

## License

[AGPL-3.0](LICENSE)

---

> This project is developed with AI assistance (Codex by OpenAI) as part of an exploration into AI-augmented software development. Every architectural decision, code review and debugging session involves AI collaboration — demonstrating what a junior developer can ship when effectively leveraging modern AI tools.
