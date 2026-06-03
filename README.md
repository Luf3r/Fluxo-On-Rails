# 💰 Fluxo Rails

[English](README.md) | [Português](README.pt-BR.md)

> A personal finance management system rebuilt on a Rails 8.1 monolith. Developed by a single junior developer with AI assistance, demonstrating how modern AI tools can amplify solo developer productivity.

[![CI](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/luf3r/fluxo-on-rails/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

---

## About

Fluxo is a personal finance platform where users will track income and expenses, manage multiple financial accounts, set budgets per category, define savings goals, and generate analytical reports.

This repository is currently in its **first finance MVP phase**: the Rails base, Devise authentication and the account/transaction domain are in place. Users can create financial accounts, record income and expenses, and move money through paired transfer rows. The previous TypeScript monorepo (NestJS + Next.js) serves as a conceptual reference — this app starts fresh from Rails conventions rather than porting the prior architecture.

---

## Live Preview

The current production build is available at
[https://fluxo-on-rails.fly.dev](https://fluxo-on-rails.fly.dev), showing the
Rails authentication foundation, localized landing page and responsive UI as the
project works in practice.

---

## Stack

| Layer | Technology |
|---|---|
| Language / Framework | Ruby 4.0.5 · Rails 8.1.3 |
| Database | Neon Serverless Postgres |
| Authentication | Devise (email + password) |
| Abuse protection | Rack::Attack rate limiting |
| Background jobs / Cache / WebSockets | Solid Queue · Solid Cache · Solid Cable |
| Frontend | Hotwire · Turbo · Stimulus · Tailwind CSS v4 |
| File storage | Active Storage (disk in dev/test) |
| Pagination | Pagy |
| Testing | RSpec · FactoryBot · Capybara · shoulda-matchers |
| Linting | RuboCop Rails Omakase |
| Local services | Docker Compose (PostgreSQL for tests · Mailpit) |
| Deployment | Fly.io app `fluxo-on-rails` in `gru`, web/worker process groups, backed by Neon |

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

## Deployment

The first production target is Fly.io, backed by Neon through `DATABASE_URL`.
The deployment contract is versioned in `Dockerfile` and `fly.toml`; durable
decisions and operational details are documented in
[`docs/adr/0004-flyio-first-deploy.md`](docs/adr/0004-flyio-first-deploy.md).

Fly runs separate `web` and `worker` process groups. The `web` group starts
Thruster/Puma with `bin/thrust bin/rails server`, the `worker` group starts
Solid Queue with `bin/jobs start`, and the HTTP service plus `/up` health checks
are scoped only to `web`. Web and worker Machines currently use
`shared-cpu-1x` with 512 MB RAM, and production keeps two web Machines warm with
`min_machines_running = 2` to avoid cold-start latency and the 256 MB OOM/health
check failures seen during the first split-process deploy.

Production runtime secrets are configured in the deploy platform, not in this
repository. Required secrets include `RAILS_MASTER_KEY`, `DATABASE_URL` and SMTP
credentials when transactional email is enabled.

SMTP is optional for the first deploy. When it is not configured, outbound email
delivery stays disabled; once transactional email is needed, configure an SMTP
provider and a verified `MAILER_FROM` sender.

Active Storage intentionally remains on the local disk service for the first
deploy. Configure object storage before accepting persistent user uploads in
production.

Continuous deployment runs through GitHub Actions after the `CI` workflow
passes. Pushes to `develop` deploy to the `staging` environment, defaulting to
the Fly app `fluxo-on-rails-staging`; pushes to `main` deploy to the
`production` environment, defaulting to `fluxo-on-rails`. Configure
`FLY_API_TOKEN` as a GitHub secret and override app names or health-check URLs
with GitHub Actions variables `FLY_STAGING_APP`, `STAGING_APP_URL`,
`FLY_PRODUCTION_APP` and `PRODUCTION_APP_URL` when needed. Production can be
held behind a manual approval by enabling required reviewers on the GitHub
`production` environment.

When changing deployment configuration, run
`bundle exec rspec spec/config/deployment_files_spec.rb` and
`fly config validate --config fly.toml` in addition to the normal project checks.

---

## Verification

```bash
bin/ci
```

`bin/ci` is the local equivalent of the GitHub Actions pipeline. It runs the test database migration, RSpec, RuboCop, gem and importmap vulnerability audits, Brakeman, Zeitwerk and production asset precompile.

PDF content specs use `pdftotext` from `poppler-utils` when they are promoted into the active suite. PDF generation itself should use Prawn and does not require system packages.

Useful individual checks:

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

## Current Scope

**Implemented:**

- Rails full-stack scaffold with Hotwire and Tailwind CSS
- Neon Serverless Postgres for runtime, with local/CI PostgreSQL for tests
- Devise `User` with `name`, `currency` (validated against ISO 4217: BRL, USD, EUR), `avatar_url`, email confirmation, and `email_verified_at` parity timestamp
- UUID v7 primary keys for application-owned records, with Solid infrastructure tables left on their adapter defaults
- Rack::Attack throttles for login and password reset attempts
- Enforced Content Security Policy for browser responses
- Home page and complete Devise authentication entry points: sign in, sign up, password recovery, email confirmation, and account editing
- User-owned accounts with UUID v7 ids, account types, currencies, initial balances, current balance calculation and red negative-balance treatment
- Transactions for income, expenses and transfers, including automatic pending status for future dates
- Paired transfer rows through `Transfers::Create`, linked by `transfer_pair`, isolated to accounts owned by the same user, updated/deleted together, and blocked when source and destination are the same account
- Authenticated CRUD screens for accounts and transactions, with tenant-safe `404 Not Found` behavior
- Transaction search with PostgreSQL `ILIKE`, newest-first ordering, Pagy pagination at 25 items per page, invalid-date-tolerant locale-preserving filters, locale-aware money formatting, and user-facing validation for values outside the database decimal precision
- Active locale coverage for finance navigation, transaction screens and transaction validation messages in English and Portuguese
- Local Mailpit service for development email
- Fly.io deployment configuration with Docker, split `web`/`worker` process groups, `/up` health checks, 512 MB Machines and release migrations
- CI: database migrations, RSpec, RuboCop, vulnerability audits, Brakeman, Zeitwerk and production asset precompile
- CD: Fly.io staging deploys from `develop`, production deploys from `main`, and post-deploy `/up` checks

**Deferred to future phases:**

- Categories, tags, budgets, goals, analytics and dashboard
- OAuth
- PDF reports and CSV import

---

## Architecture Decision Records

Key decisions documented under `docs/adr/`:

| # | Decision | Choice |
|---|---|---|
| 0001 | Application architecture | Rails 8.1.3 monolith with Hotwire — avoids SPA complexity without sacrificing interactivity |
| 0002 | Authenticated domain boundary | Finance-domain controllers inherit authentication and tenant-safe `404 Not Found` defaults |
| 0003 | Finance domain MVP contracts | Transfers, budgets, categories, pagination/search and PDF testing rules for the finance stages |
| 0004 | Fly.io first deploy | Fly app, Neon runtime database, split web/worker process groups, 512 MB Machines and production health checks |
| 0005 | UUID v7 primary keys | Application-owned records use UUID v7 IDs; Solid infrastructure tables keep adapter-managed integer IDs |

Future-stage contracts live in [`future_specs/README.md`](future_specs/README.md). They are planning specs, not part of the green test suite until a stage is promoted into `spec/`.

Contributor workflow is documented in [`CONTRIBUTING.md`](CONTRIBUTING.md). The staged roadmap is in [`docs/roadmap.md`](docs/roadmap.md).

---

## License

[AGPL-3.0](LICENSE)

---

> This project is developed with AI assistance (Codex by OpenAI) as part of an exploration into AI-augmented software development. Every architectural decision, code review and debugging session involves AI collaboration — demonstrating what a junior developer can ship when effectively leveraging modern AI tools.
