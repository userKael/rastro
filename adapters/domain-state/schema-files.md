# Adapter: domain-state/schema-files

## Requirements

REQUIRED: none

The adapter reads the files named by `domain_state.schema_files`, and the migrations in the repository. It never connects to a database.

## Capabilities

### schema

Read each file in `domain_state.schema_files`: SQL definitions, ORM models or a schema dump. Read the migrations in the order they run, because a later migration can change what an earlier one created. Return, for each table asked about, the columns, nullability, indexes and enum values as the files declare them, and name the file each came from.

Every statement about the live database carries `NOT VERIFIED`. A file says what the code expects to find. It does not say what the database holds.

### state_distribution

Unavailable: row counts live in the database and not in files. Return `NOT VERIFIED`. When the column is an enum, the allowed values may be listed as declared, labeled as declared and not as a distribution.

### write_policy

Never execute a write, and the adapter has nothing to execute it against. When a change to the database is needed, draft the literal SQL or the migration for a human to run, with what it changes, how to confirm it, and how to revert it. State plainly that it was not run.

## Known limits

- The files can drift from the live database. A migration that was never applied, or one applied by hand, is invisible here. That is why every claim about the live database is `NOT VERIFIED`.
- An ORM model describes what the code expects. It can disagree with the schema in the migrations and with the database.
- There is no distribution of values. A question that needs one waits for a human to run a query, or for the `db-mcp` adapter.
