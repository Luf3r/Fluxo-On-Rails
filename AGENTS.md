# Agent Instructions

This file is the operating guide for AI agents and external contributors working
on Fluxo Rails. Keep changes small, verified, and aligned with the documented
architecture.

## Read First

Before changing code, read:

- `README.md` or `README.pt-BR.md` for setup and project status.
- `CONTRIBUTING.md` for local workflow and quality gates.
- `docs/adr/` for architectural decisions.
- `docs/roadmap.md` for planned phases and open decisions.
- `future_specs/README.md` before editing future-facing specs.

Use a git worktree for non-trivial implementation or architecture work. Do not
overwrite user changes; inspect `git status` before editing and keep commits
focused.

## Project Direction

Fluxo Rails is a Rails-first monolith. Prefer Rails conventions, Hotwire, server
rendered flows, and small Ruby objects over SPA-style architecture. Do not port
the older TypeScript implementation structure into this codebase.

Keep controllers thin, models explicit about invariants, and service objects for
business workflows that touch multiple records. Prefer simple scopes and SQL that
PostgreSQL can optimize before adding new infrastructure.

## Verification

`bin/ci` is the checked-in canonical local and CI gate. It runs the test database
migration, RSpec, RuboCop, gem and importmap vulnerability audits, Brakeman,
Zeitwerk, and production asset precompile. Run it before committing or opening a
PR when you change behavior, migrations, security-sensitive code, or shared
documentation contracts.

If `bin/ci` does not exist in an older branch, partial checkout, or temporary
workspace, run the focused checks below instead of improvising an unverified
replacement.

Useful focused checks:

- `bundle exec rspec`
- `bin/rubocop`
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
- `bin/bundler-audit`
- `bin/importmap audit`
- `RAILS_ENV=test bin/rails zeitwerk:check`

Do not claim work is complete unless the relevant checks were run in the current
session and the output was inspected.

## Domain Contracts

Follow the current finance MVP decisions from `docs/adr/0003-finance-domain-mvp-contracts.md`:

- Transfers are represented by two linked transactions via `transfer_pair`; both
  rows use `transaction_type: :transfer`. Analytics must exclude transfers with
  `where.not(transaction_type: :transfer)`.
- Category budgeting uses nullable decimal `budget_amount` directly on
  `Category`. Do not add a `Budget` model until monthly history, rollover, or
  shared category budgets are required.
- Categories support at most two levels: parent -> child. Transactions can only
  be assigned to categories with no children. Creating or editing a subcategory
  requires a valid `parent_id`.
- Use Pagy for pagination, defaulting to 25 items per page. MVP search should
  use PostgreSQL `ILIKE`; do not add Elasticsearch or `pg_search` yet.
- PDF generation uses Prawn. `pdftotext` from `poppler-utils` is only needed
  when specs assert PDF text content.

## Authentication And Isolation

Future authenticated domain controllers should inherit from
`AuthenticatedController`. Load tenant-owned records through `current_user`
associations and return `404` for missing or cross-user records. Avoid exposing
whether another user's resource exists.

Use strong parameters, Devise defaults, existing CSP/Rack::Attack patterns, and
security scans in `bin/ci`. Never commit secrets, `.env` values, credentials, or
API keys.

## Future Specs

Files under `future_specs/` are executable design contracts for upcoming phases,
not part of the active suite until promoted. When implementing a phase, move or
copy only the relevant specs into `spec/`, update factories and schema, and keep
the future specs aligned with any accepted ADR changes.

## Documentation

Any change that modifies architecture, security posture, data contracts, setup,
or contributor workflow should update the corresponding README, ADR, roadmap, or
future spec note in the same branch. Add an ADR for durable decisions rather than
leaving them implicit in implementation.

If a decision is not covered by existing ADRs or the roadmap, stop and surface
the open question instead of resolving it implicitly in code.

## Pull Requests

Base project PRs on `develop` unless the maintainer requests another target.
AI agents should only push or open PRs when explicitly asked and authenticated
tooling is available. Otherwise, leave the branch state, suggested base branch,
and PR summary for a human contributor to apply.

When preparing a PR, include:

- A concise summary of user-visible or architectural changes.
- The verification commands that were run.
- Any known gaps or follow-up decisions.
