# Future specs

These specs describe later Fluxo Rails development stages from the project development order document.

They live outside `spec/` because the current executable setup only includes the Rails foundation, Devise `User`, home page, database setup, and CI plumbing. Keeping them here preserves the project-level contracts without making the current CI red.

Use these files as living product contracts. When starting a stage:

1. Move that stage's specs from `future_specs/etapa_*` into the normal `spec/` tree.
2. Add any missing test support for that stage, such as factories, `shoulda-matchers`, Devise request helpers, or Active Job test helpers.
3. Tighten placeholder expectations before implementing the feature.
4. Implement until the promoted specs pass in CI.

Run future specs explicitly when planning a stage:

```bash
bundle exec rspec future_specs/etapa_03_accounts_transactions
```

Stage mapping:

- `etapa_02_authentication`: confirmable auth, password recovery coverage, rate limiting.
- `etapa_03_accounts_transactions`: accounts, transactions, transfers, balances, CRUD.
- `etapa_04_categories_tags_filters`: categories, tags, transaction filters.
- `etapa_05_analytics`: analytics queries and endpoints.
- `etapa_06_recurring_jobs`: recurring transactions and scheduled jobs.
- `etapa_07_goals`: financial goals, progress, projection.
- `etapa_08_email_notifications`: budget alerts and digest mailers.
- `etapa_09_csv_import`: CSV transaction import.
- `etapa_10_pdf_reports`: monthly PDF reports.

The development order also includes later stages that do not yet have contract specs here:

- Etapa 11: polished Hotwire frontend.
- Etapa 12: final test hardening, deployment, and release documentation.

Known cleanup before promotion:

- Remove placeholder expectations such as `expect(true).to be(true)`.
- Replace `rescue nil` in request specs with explicit expected status codes or exceptions.
- Replace permissive matchers like `.or satisfy { |_| true }` with one chosen behavior.
- Split files that describe multiple production files, such as mailer specs that cover more than one mailer.
- Keep each promoted spec aligned with the stage's actual dependencies and gems.
