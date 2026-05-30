# ADR 0001: Rails monolith foundation

## Status

Accepted

## Context

Fluxo is being rebuilt from the current TypeScript reference into a Rails application. This phase establishes the Rails foundation and authentication layer, not the full finance product implementation.

## Decision

Use a conventional Rails 8.1.3 monolith with Neon Serverless Postgres, Hotwire, Tailwind CSS and Devise.

Authentication starts with email and password through Devise. The `users` table keeps the base Devise fields plus `name`, `currency`, nullable `avatar_url`, `preferred_locale`, Devise confirmable columns and nullable product-level `email_verified_at` for TypeScript reference parity. Devise confirmable owns account confirmation; `email_verified_at` mirrors the confirmed timestamp for product-level compatibility.

Database configuration uses Neon for runtime and disposable PostgreSQL databases for tests. Development and production read the Neon runtime URL from `DATABASE_URL`. Test defaults to the local Docker PostgreSQL URL and can be overridden with `TEST_DATABASE_URL` when an isolated remote test database is intentionally needed. CI uses an ephemeral PostgreSQL service.

Local infrastructure uses Docker Compose for test PostgreSQL and Mailpit. Rails uses Solid Queue, Solid Cache and Solid Cable. Active Storage uses disk services in development and test.

Normal Rails web and worker processes should prefer pooled Neon connection URLs. A direct Neon URL can be kept for migration or release workflows that need it. Solid Cache, Queue and Cable can share the production `DATABASE_URL` or use `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` and `CABLE_DATABASE_URL` if separate Neon databases are provisioned.

## Consequences

The app can evolve through standard Rails conventions with a low operational footprint. Future phases should add accounts, transactions, categories, budgets, reports and integrations incrementally instead of importing the full TypeScript architecture at once. Adding OAuth requires a separate decision.
