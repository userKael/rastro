---
id: creating-a-migration
type: migration
version: 1.0.0
status: current
verified_by: review
instances: [src/inventory/migrations/1700000000000-add-reserved-copies-to-stock.ts:1]
origin: example, bookstore, 2026-11-11
---

# Golden path: creating a migration

## When to use

A migration changes the schema and carries the way back. The migration tool writes it, and a person reviews it. Replace every `<stack: ...>` gap with the tool, path or command of your stack, then list this file in `architecture.golden_paths` of `.rastro/config.yml`.

Rule in play, defined in `../rules.md`: `[migration-via-tool]`.

Not covered here: a data fix run once by hand on one `inventory` store, which leaves no migration file and has no reversal to review. A change to the model that does not alter the schema does not need a migration either.

## Decisions

- **The migration tool writes the migration.** Why: a file written by hand has no command to cite and drifts from the model (`[migration-via-tool]`). Revisit if: the tool cannot express a change that the stack needs often.
- **Every migration carries a reversal that undoes exactly the forward step.** Why: the way back must work without improvising during an incident. Revisit if: the store cannot reverse a change, and a restore from backup replaces it.
- **A destructive step ships in a later PR than the change that stops using the column.** Why: the old code still running during a deploy must not lose a column it reads. Revisit if: deploys stop overlapping old and new code.
- **A table lives in the schema or under the prefix of the module that owns it.** Why: ownership stays visible in the store as in the code. Revisit if: modules share one store layout.

## Checklist

- [ ] Change the model first when the tool generates migrations from the model: `<stack: model or schema file>`.
- [ ] Generate the migration with the tool: `<stack: command that generates a migration from a model change>`. When the model cannot express the change, such as a data backfill, create an empty migration with `<stack: command that creates an empty migration>` and write only the statements. Never create the file by hand (`[migration-via-tool]`).
- [ ] Read the generated statements before you stage them. Delete what does not belong to the change: the tool diffs the whole model, not your intent.
- [ ] Give the migration a reversal that undoes exactly what the forward step did, no more and no less (`[migration-via-tool]`).
- [ ] Put the table in the schema or under the prefix of the module that owns it: `<stack: schema or naming convention per module>`.
- [ ] Split a destructive step (dropping a column, narrowing a type) from the change that stops using the column. Ship the destructive step in a later PR, after the code that stopped using it is deployed.
- [ ] On a scratch database, run the migration forward, then back, then forward again. Each run must exit 0: `<stack: command that runs pending migrations>` and `<stack: command that reverts the last migration>`.
- [ ] Name in the PR description the command that produced the migration.

## Worked example

Stack: TypeScript, one class per migration. The bookstore `inventory` module starts tracking reserved copies, so `PlaceOrderService` can reserve stock through `inventory`. The tool produces the file and the timestamp in its name. `Queryable` stands for the connection your tool passes in: `<stack: the type the migration tool passes to up and down>`.

`src/inventory/migrations/1700000000000-add-reserved-copies-to-stock.ts`:

```ts
type Queryable = { query(sql: string): Promise<void> };

export class AddReservedCopiesToStock1700000000000 {
  async up(db: Queryable): Promise<void> {
    await db.query(
      'ALTER TABLE inventory.stock ADD COLUMN reserved_copies integer NOT NULL DEFAULT 0',
    );
  }

  async down(db: Queryable): Promise<void> {
    await db.query('ALTER TABLE inventory.stock DROP COLUMN reserved_copies');
  }
}
```

What the example shows:

- The table `stock` lives in the `inventory` schema, the module that owns it.
- `up` adds one column with a default, so existing rows stay valid. `down` drops that column and touches nothing else.
- The class name derives from the timestamp, as the tool generates it. A file written by hand has no such command to cite, which is what `[migration-via-tool]` flags.

## Security

- Data loss: a destructive step is split from the change that stops using the column and ships in a later PR. Verified in review by the destructive-step item of the checklist.
- A migration that cannot be undone: every migration has a reversal, and the forward, back and forward run on a scratch database must exit 0. Verified by that run, reported in the PR description.

## Verification

A reviewer checks each instance against the checklist above, and the PR description names the command that produced the migration. No command enforces this golden path yet, so `verified_by` is `review`.

## Known debt

None.

## History

| Version | Date | Item | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-11 | example | Created from the first instance |
