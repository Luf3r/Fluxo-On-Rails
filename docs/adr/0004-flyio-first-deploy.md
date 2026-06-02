# ADR 0004: Fly.io first production deploy

## Status

Accepted

## Context

The foundation and authentication phase needs an initial production deployment
target before the finance features are promoted. The app already depends on
Neon Serverless Postgres for runtime data, Solid Queue/Cache/Cable for Rails
database-backed infrastructure and `/up` for health checks.

## Decision

Use Fly.io as the first deployment platform, with app name
`fluxo-on-rails`, primary region `gru` and initial public URL
`https://fluxo-on-rails.fly.dev`.

Deploy through the checked-in Dockerfile and `fly.toml`. Fly runs
`bin/rails db:prepare` as the release command so migrations run once before new
Machines receive traffic. The web process starts through Thruster and Puma, and
Solid Queue runs as a separate Fly process group through `bin/jobs start`. The
HTTP service and health checks are scoped to the `web` process group so queue
maintenance cannot make the only web Machine unavailable.

Web and worker Machines run as `shared-cpu-1x` with 512 MB RAM. The first
separate-process deploy let Fly create 256 MB Machines by default; the worker
was OOM-killed during boot and web health checks became intermittent under a
small burst of public requests. Keep two web Machines running in `gru` through
`min_machines_running = 2` so public traffic does not pay cold-start latency or
route through a just-starting web process.

GitHub Actions owns continuous deployment after the checked-in `CI` workflow
passes: `develop` deploys the staging Fly app and `main` deploys the production
Fly app. Both deployment jobs verify `/up` after `flyctl deploy` completes.
Production can require a manual approval through GitHub Environment protection
rules without changing the repository workflow.

Keep Neon as the production database through Fly secrets. Use a pooled
`DATABASE_URL` for the app and optional `CACHE_DATABASE_URL`,
`QUEUE_DATABASE_URL` and `CABLE_DATABASE_URL` only if separate Neon databases
are later provisioned. Do not introduce Fly Postgres for this first deploy.

Configure production host, protocol and SMTP through environment variables.
Non-secret runtime settings live in `fly.toml`; secrets such as
`RAILS_MASTER_KEY`, `DATABASE_URL` and SMTP credentials live in Fly secrets.
SMTP is optional for the first deploy; if `SMTP_ADDRESS` is absent, production
keeps outbound email delivery disabled. When Brevo is enabled later, set
`SMTP_ADDRESS=smtp-relay.brevo.com`, `SMTP_PORT=587`,
`SMTP_AUTHENTICATION=plain`, `SMTP_ENABLE_STARTTLS_AUTO=true`,
`SMTP_USERNAME`, `SMTP_PASSWORD` and `MAILER_FROM`. `MAILER_FROM` should be a
sender address accepted by Brevo. A custom domain is not required for the
initial deploy if Brevo is configured with a verified sender.

Active Storage remains on the local disk service until user uploads become a
real production feature. Before accepting persistent uploads, choose and
configure object storage such as S3, Cloudflare R2 or Fly Tigris.

## Consequences

The first deploy has a small operational footprint and keeps database ownership
consistent with the existing Neon architecture. Background jobs run on their own
Machine, which adds a small amount of operational cost but prevents queue
supervision and recurring maintenance from competing with Puma for web
availability.

The Fly footprint is intentionally larger than the absolute minimum: normally two
512 MB web Machines plus one 512 MB worker are available. This avoids the 256 MB
default that caused OOM and health-check failures, and trades a small monthly
cost increase for predictable auth-page latency and deploy stability.

Machine-local uploaded files are not durable. Production features that depend on
uploads must not launch until object storage is configured and documented.
