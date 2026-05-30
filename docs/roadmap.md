# Roadmap

This roadmap summarizes the intended order of work and the decisions that should
shape implementation. Detailed executable contracts live in `future_specs/`.

## Current

- Rails 8.1 monolith foundation
- Neon/PostgreSQL configuration
- Devise authentication with email confirmation
- Rack::Attack throttling
- CSP and security checks
- Local and CI verification through `bin/ci`

## Next Stages

1. Accounts, transactions and transfers
2. Categories, sub-categories, tags and transaction filters
3. Analytics views and cached query objects
4. Recurring transactions and scheduled jobs
5. Goals, budget alerts and digest emails
6. CSV import and monthly PDF reports
7. Hotwire UI polish, deployment and release documentation

## Locked Decisions

- Finance controllers inherit from `AuthenticatedController`.
- Cross-user resource access returns `404 Not Found`.
- Transfers use paired `transaction_type: "transfer"` rows linked by
  `transfer_pair`; analytics excludes transfers from income/expense totals.
- Category budgets use `Category#budget_amount` for the MVP.
- A separate `Budget` model waits for monthly history, rollover or shared budget
  requirements.
- Category hierarchy is limited to parent -> child.
- Transactions can only use leaf categories.
- Transaction pagination uses Pagy with 25 items per page.
- MVP search uses `ILIKE`; no Elasticsearch or `pg_search`.
- PDF generation uses Prawn; text assertions use `pdftotext` only in tests.

## Open Product Questions

- OAuth provider order and account-linking rules.
- Deployment target and runtime secret management.
- Whether CSV import should become asynchronous for large files after MVP.
- Whether budget alerts should support per-user notification preferences.
