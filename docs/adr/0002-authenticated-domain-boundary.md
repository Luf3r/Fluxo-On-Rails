# ADR 0002: Authenticated domain boundary

## Status

Accepted

## Context

The next stages add user-owned financial data: accounts, transactions, categories,
goals, imports, analytics, reports and background jobs. The future contracts
consistently require tenant isolation, authenticated access and indistinguishable
404 responses when a user references another user's resource.

## Decision

Future product controllers should inherit from `AuthenticatedController`.
That base controller requires Devise authentication and converts
`ActiveRecord::RecordNotFound` into `404 Not Found`.

Resource lookups should start from the current user's associations, for example
`current_user.accounts.find(params[:id])`, instead of global model lookups.
Services and jobs that receive resource ids should make the same ownership check
before mutating or reporting data.

## Consequences

The public marketing/home and Devise controllers can remain on
`ApplicationController`, while finance-domain controllers get a secure default.
Cross-user access can fail through normal Active Record lookup semantics without
revealing whether the target record exists for another user.
