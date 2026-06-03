# ADR 0003: Finance domain MVP contracts

## Status

Accepted

## Context

The next stages introduce the finance domain: accounts, transactions,
categories, analytics, budget alerts, CSV import and PDF reports. Several
choices affect analytics correctness and future complexity, so they should be
explicit before implementation starts.

## Decision

Transfers are stored as two linked `Transaction` rows, one on the source account
and one on the destination account. Both rows use `transaction_type: "transfer"`
and are connected through `transfer_pair`. Transfers affect account balances,
but analytics queries must exclude them from income and expense totals with
`where.not(transaction_type: :transfer)`. The source and destination accounts
must be different; the transfer service enforces this invariant so UI changes
cannot create self-transfers. Updates and deletes must preserve the pair: editing
a transfer updates both rows, and deleting either row deletes its pair.

Finance decimal inputs, including transaction amounts and account initial
balances, must stay within the database decimal precision. Controllers that
accept finance input should reject out-of-range values with a user-facing `422
Unprocessable Content` response before PostgreSQL can raise a numeric overflow.

Budgets stay on `Category` as a nullable decimal `budget_amount` for the MVP. Do
not introduce a `Budget` model until at least one of these requirements appears:
monthly budget history, rollover of unused budget, or a shared budget across
multiple categories.

Category hierarchy is limited to two levels: parent -> child. Infinite nesting is
not supported. Transactions may be assigned only to categories that do not have
children. A parent category without children behaves like any normal category.
Creating or editing a sub-category requires a present, valid `parent_id`.

Transactions use Pagy for pagination with a default of 25 items per page. Keep
the page size hard-coded until there is real demand for configurability. MVP
search uses the existing case-insensitive `ILIKE` scope; do not add Elasticsearch
or `pg_search` yet. Transaction lists order by transaction date descending and
then creation time descending so newly-created items appear immediately on the
first page. Invalid date filter input is ignored rather than treated as an
application error.

Monthly PDF generation should use Prawn and must not depend on system packages.
Specs that assert generated PDF text may use `pdftotext` from `poppler-utils`;
response-level specs that only assert `application/pdf` and `200 OK` do not need
that dependency.

## Consequences

Dashboards can calculate income and expense without misclassifying internal
money movement. Budgeting remains simple until real requirements justify a new
aggregate. Category queries and UI stay tractable, and transaction listing avoids
heavier pagination and search dependencies during the MVP.
