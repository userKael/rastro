# Reconciliation — <id>

> **Template.** Delete this note, the example rows, the example decisions and the revalidation block when filling in. Write the headings in `project.languages.human`; the file name and `Decided (<YYYY-MM-DD>):` stay literal. The file has exactly five sections, in this order. Every row of the first three tables carries a `file:line` anchor; a claim without evidence becomes a `D-n` question.

- Intent: `<path of the intent file>`, type `<design doc | root cause | interview>`, captured on `<YYYY-MM-DD>`, origin `<reference and version>`
- Reconciled on: `<YYYY-MM-DD>` against `<base_branch>@<sha7>`
- Declared scope: `<modules, repos and paths>`; `exists` paths: `<paths>`; `changes` paths: `<paths>`

## Divergences: intent vs code

| Intent item | What the code says | Evidence | Proposal |
|---|---|---|---|
| Orders are refused when stock is 0 | `PlaceOrderService` accepts the order and marks it backordered | `src/orders/place-order.service.ts:48` | Change the intent: backordered is a valid outcome |

## Already delivered

| Slice of the intent | Where on the base | Evidence |
|---|---|---|
| Reserve copies when an order is placed | `<sha7>` | `src/inventory/reserve-copies.service.ts:31` |

## Not sized

| Work needed | Why the intent did not foresee it | Evidence (file:line) | Cost in tasks and PRs |
|---|---|---|---|
| Backfill `catalog.books.isbn` before the unique index | The seed data holds two books with the same ISBN | `db/seeds/books.sql:12` | 1 task, 1 PR, plus the human step in D-2 |

## Code behavior the intent does not mention

| What the code does | Where | What the intent says | Impact |
|---|---|---|---|
| Cancelling an order releases its reserved copies | `src/orders/cancel-order.service.ts:27` | Nothing | The new reservation path must keep releasing on cancel |

## Decisions to close with the team

**D-1 — Is a backordered order a valid outcome?**

- (a) Yes: keep the current behavior and rewrite the intent.
- (b) No: refuse the order when stock is 0.

**Recommendation:** (a), because `PlaceOrderService` already returns `backordered` and two callers read it (`src/orders/place-order.service.ts:48`).

Decided (<YYYY-MM-DD>): <option chosen, and who decided>

**D-2 — Add a unique index on `catalog.books.isbn`** · **executor: human**

What has to happen: after the backfill, create the index in the shared database. The agent does not run it.

Artifact:

```sql
CREATE UNIQUE INDEX books_isbn_key ON catalog.books (isbn);
```

Environments: `staging`, then `production`, one at a time.

Rollback: `DROP INDEX catalog.books_isbn_key;`

Verification after running: the index `books_isbn_key` is listed for `catalog.books` in each environment, and inserting a duplicate ISBN fails.

When: before the merge of the PR that reads the index.

Decided (<YYYY-MM-DD>): <who runs it, when, and where; pending until the human says>

> **Revalidation.** Append this block, below the fifth section, only when `git log --oneline <sha>..<project.base_branch> -- <scope>` is not empty. Never rewrite the five sections above it.
>
> ```markdown
> ## Revalidation — <YYYY-MM-DD>, <base_branch>@<sha7>
>
> Commits in scope since the reconciliation: <number>
>
> | Affected item | What changed | Evidence | Consequence |
> |---|---|---|---|
> | <item> | <change> | `<file:line>` | <what this does to the plan or to a closed D-n> |
> ```
