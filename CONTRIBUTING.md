# Contributing

Fluxo Rails is a conventional Rails monolith. Keep changes small, testable and
aligned with the existing Rails patterns unless an ADR says otherwise.

## Setup

```bash
mise trust
mise install
cp .env.example .env
docker compose up -d
bundle install
bin/rails db:migrate
bin/dev
```

Development and production expect `DATABASE_URL`. Tests default to the local
Docker PostgreSQL URL from `.env.example`.

## Checks

Run the full local pipeline before opening a PR:

```bash
bin/ci
```

Useful focused checks:

```bash
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
RAILS_ENV=test bin/rails zeitwerk:check
```

PDF content specs use `pdftotext` from `poppler-utils` when they become part of
the active suite. They are separate from PDF generation, which should use Prawn.

## Future Specs

Specs under `future_specs/` are product contracts for later stages. They are not
part of the green suite until a stage is promoted.

When starting a stage:

1. Move that stage's specs into `spec/`.
2. Add missing factories, gems and test helpers.
3. Tighten placeholder expectations.
4. Implement until `bin/ci` passes.

Preserve tenant isolation: load user-owned records from the current user's
associations and return `404 Not Found` for another user's resource.

## Documentation

Update README, ADRs and `docs/roadmap.md` when a change affects setup, workflow,
architecture or future-stage contracts.
