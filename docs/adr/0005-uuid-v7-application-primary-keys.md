# ADR 0005: UUID v7 application primary keys

## Status

Accepted

## Context

Fluxo Rails is a finance application where future records will be exposed across
authenticated routes, background jobs, imports and reports. Integer primary keys
make record counts easy to infer and were already visible in the initial
`users` table because the Devise migration used Rails' default `bigserial`
primary key.

Rails 8.1 and PostgreSQL support native UUID columns, but PostgreSQL UUID
primary keys default to `gen_random_uuid()`, which creates UUID v4 values. The
project wants UUID v7 for application-owned records because UUID v7 preserves
time ordering while avoiding sequential integer identifiers.

## Decision

Application-owned tables use UUID primary keys. Rails generators are configured
with `primary_key_type: :uuid` so future generated tables and generated
references use UUID columns by default.

Application records assign UUID v7 IDs in Ruby before insert through
`SecureRandom.uuid_v7`. UUID primary key columns use `default: nil` so the
database does not silently fall back to UUID v4 generation.

The existing `users` primary key is converted from integer to UUID through a
data migration that assigns a UUID v7 to each existing row before replacing the
primary key column.

Solid Queue, Solid Cache and Solid Cable tables remain on the integer primary
keys expected by those Rails infrastructure adapters. They are implementation
tables, not application-domain records.

## Consequences

Application IDs are no longer enumerable integers, and future finance-domain
tables will line up with `users` when foreign keys are added.

The migration changes existing user IDs. There are no active application-domain
foreign keys to `users` yet, so this is low-risk at the current project phase.
Future migrations that add `user_id` or other application references should use
UUID references and should not assume integer IDs.

Raw SQL inserts into application-owned tables must provide UUID IDs unless they
go through Active Record model creation. This is intentional; application code
is the UUID v7 generation boundary.
