# Adapter: domain-state/db-mcp

## Requirements

REQUIRED MCP: from config domain_state.server

The server name comes from `domain_state.server` in `.rastro/config.yml`. The server is any MCP server that runs read queries against the domain's database. The adapter does not name its query tool, because it differs between servers: use the one that takes a SQL statement and returns rows.

## Capabilities

### schema

Query the catalog, never the ORM entities. For each table asked about, run three read queries. The examples are for Postgres, with the table `catalog.books`.

Columns, types and nullability:

```sql
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'catalog' AND table_name = 'books'
ORDER BY ordinal_position;
```

Indexes, with their definitions:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'catalog' AND tablename = 'books';
```

Enum values. A column of an enum type shows `USER-DEFINED` in `data_type`, and its type name in `udt_name`:

```sql
SELECT t.typname, e.enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname = '<udt_name>'
ORDER BY e.enumsortorder;
```

Equivalents for MySQL:

- `information_schema.columns` exists with the same column names. `table_schema` is the database name, and `column_type` holds an enum as `enum('a','b')`, which replaces the enum query.
- Indexes come from `information_schema.statistics` (one row per indexed column) or from `SHOW INDEX FROM <table>`, in place of `pg_indexes`.

Return the columns, nullability, indexes and enum values of each table, as the database reported them.

### state_distribution

Count the rows per value of the column:

```sql
SELECT status, COUNT(*)
FROM catalog.books
GROUP BY status
ORDER BY COUNT(*) DESC;
```

The same statement works on MySQL, with the database name in place of the schema. Run it on columns that hold a state or a small set of values. It scans the table, so say so when the table is large. Never select the values of a column that holds data of a class listed in `architecture.sensitive_data`.

### write_policy

Never execute a write. That covers `INSERT`, `UPDATE`, `DELETE`, any DDL, and any call that changes data, even when the server would allow it.

When a change to the database is needed, draft the literal SQL for a human to run, and give with it what it changes, on which tables, the query that confirms the result, and the statement that reverts it. State plainly that it was not run.

## Known limits

- When the server does not answer, or a query is rejected, the claim that needed it is `NOT VERIFIED`. The adapter never fills the gap from ORM entities or migration files.
- The SQL above is Postgres. For another database, translate it using the MySQL notes or the database's own catalog, and say which catalog was used.
- Row counts are a snapshot taken when the query ran.
- The adapter has no way to prove the server is read-only. Connect it with credentials that cannot write.
