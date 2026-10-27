# Golden path: creating a migration

A migration changes the schema and carries the way back. The migration tool writes it, and a person reviews it. Replace every `<stack: ...>` gap with the tool, path or command of your stack, then list this file in `architecture.golden_paths` of `.rastro/config.yml`.

Rule in play, defined in `../rules.md`: `[migration-via-tool]`.

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
