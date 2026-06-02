# Future specs

These specs describe later Fluxo Rails development stages from the project development order document.

They live outside `spec/` because the current executable setup includes the Rails foundation, Devise `User`, email confirmation, rate limiting, home page, database setup, and CI plumbing. Finance-domain contracts stay here until their stage is promoted. Keeping them here preserves project-level intent without making the current CI red.

Deployment contracts stay in active specs under `spec/config/`. Future specs
should not duplicate the current Fly contract, but any promoted stage that adds
jobs, uploads or mail delivery must keep the production deployment model in
mind.

Use these files as living product contracts. When starting a stage:

1. Move that stage's specs from `future_specs/etapa_*` into the normal `spec/` tree.
2. Add any missing test support for that stage, such as factories, `shoulda-matchers`, Devise request helpers, or Active Job test helpers.
3. Tighten placeholder expectations before implementing the feature.
4. Implement until the promoted specs pass in CI.

Run future specs explicitly when planning a stage. These commands are expected to fail until the target stage's dependencies, factories, routes and implementation have been promoted:

```bash
bundle exec rspec future_specs/etapa_03_accounts_transactions
```

Stage mapping:

- `etapa_02_authentication`: already promoted into `spec/`; see `spec/requests/authentication_spec.rb`, `spec/requests/devise_pages_spec.rb`, `spec/requests/rate_limiting_spec.rb` and `spec/models/user_spec.rb`.
- `etapa_03_accounts_transactions`: accounts, transactions, paired transfer rows, balances, CRUD.
- `etapa_04_categories_tags_filters`: categories, two-level sub-categories, tags, transaction filters.
- `etapa_05_analytics`: analytics queries and endpoints that exclude transfer rows from income/expense totals.
- `etapa_06_recurring_jobs`: recurring transactions and scheduled jobs.
- `etapa_07_goals`: financial goals, progress, projection.
- `etapa_08_email_notifications`: budget alerts and digest mailers.
- `etapa_09_csv_import`: CSV transaction import.
- `etapa_10_pdf_reports`: monthly PDF reports.

The development order also includes later stages that do not yet have contract specs here:

- Etapa 11: polished Hotwire frontend.
- Etapa 12: final test hardening, deployment, and release documentation.

Promotion checklist:

- Keep request specs explicit about authorization failures; current future contracts prefer `404 Not Found` for resources owned by another user.
- Keep CSV import behavior deterministic; current future contracts raise `Transactions::ImportCsv::InvalidFormatError` for non-CSV input.
- Preserve injectable executors for transfer persistence and recurring-rule processing so failure paths can be tested without `allow_any_instance_of`.
- Preserve tenant isolation contracts for every route, report, mailer, background job, and imported foreign key before moving specs into `spec/`.
- Keep authentication responses indistinguishable where differences would allow user enumeration.
- Keep each promoted spec aligned with the stage's actual dependencies and gems.
- For background jobs and mail delivery, keep execution through the separate
  Solid Queue worker process; do not re-enable `SOLID_QUEUE_IN_PUMA` to make a
  stage pass locally.
- When a stage introduces scheduled jobs, add an active config spec for
  `config/recurring.yml` after the exact cadence is decided.
- Before promoting any feature that stores persistent user files, update the
  deployment docs and ADR with the chosen object storage provider.

Locked contract decisions:

- Transfers use two paired transaction rows linked by `transfer_pair`; both rows have `transaction_type: "transfer"`. Analytics must exclude transfer rows from income and expense totals with `where.not(transaction_type: :transfer)`.
- Budgets are a nullable decimal `Category#budget_amount` in the MVP. Introduce a `Budget` model only when monthly history, rollover of unused balance, or shared budgets across categories appear.
- Category hierarchy has only two levels: parent -> child. Transactions can be assigned only to leaf categories. Sub-category create/update flows require a present, valid `parent_id`.
- Pagination uses Pagy with 25 transactions per page by default. Search uses a simple case-insensitive `ILIKE` scope for the MVP; do not add Elasticsearch or `pg_search`.
- PDF generation uses Prawn. PDF content assertions may use `pdftotext` from `poppler-utils`; response-only PDF specs do not need that system dependency.
- Production background jobs run through the Fly `worker` process group. Future
  recurring transactions, imports and notification jobs should be written to fit
  that worker model instead of sharing the web process.
