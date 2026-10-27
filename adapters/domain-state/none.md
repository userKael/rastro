# Adapter: domain-state/none

## Requirements

REQUIRED: none

No database and no schema files are declared. The adapter behaves like `schema-files`, with nothing declared: it looks for the schema in the repository and never connects to a database.

## Capabilities

### schema

Search the repository for migration folders, `.sql` files, and schema or ORM model files, by name and by content. Read the migrations in the order they run, because a later migration can change what an earlier one created. Return, for each table asked about, the columns, nullability, indexes and enum values as those files declare them, and name the file each came from.

Every statement about the live database carries `NOT VERIFIED`. When the search finds nothing for a table, say that nothing was found, and do not guess a schema.

### state_distribution

Unavailable: row counts live in the database. Return `NOT VERIFIED`. When the column is an enum, the allowed values may be listed as declared, labeled as declared and not as a distribution.

### write_policy

Never execute a write, and the adapter has nothing to execute it against. When a change to the database is needed, draft the literal SQL or the migration for a human to run, with what it changes, how to confirm it, and how to revert it. State plainly that it was not run.

## Known limits

- Everything about the live database is `NOT VERIFIED`: no file in the repository proves what the database holds.
- The search is by convention. A schema kept outside the repository, or in a folder the search does not recognise, is not found. Declare the files in `domain_state.schema_files` and use the `schema-files` adapter.
- There is no distribution of values.
