---
name: domain-context
description: Establishes the real state of the domain before anything is claimed or proposed. Lists the affected modules, reads the real schema through the domain-state port, gathers domain rules, recent migrations and constraints, and prints a Context block that marks every unchecked database claim NOT VERIFIED. Use it for a domain question ("what happens to reserved copies when an order is cancelled?"), for a one-off investigation before a small fix, and as Step 1 of the reconcile skill, which runs it whole. Do not use it to implement a whole work item: that is the implement skill, which reaches this protocol through reconcile. Do not use it to contest a design doc or a root cause against the code: that is reconcile. It has no gate, writes no file and never executes a write against a database.
---

# domain-context

Know the real state of the domain (schema, rules, modules) before you claim anything or propose code.

**Input:** a domain question, or the call from Step 1 of the `reconcile` skill with its declared scope.

**Output:** a `## Context` block, printed before any answer or plan. No gate: this skill is a report.

## Requirements

- `.rastro/config.yml`. If it does not exist, stop and tell the human to run the `setup` skill.
- The domain-state adapter for `domain_state.kind`: `.rastro/adapters/domain-state/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/domain-state/<kind>.md`. If the adapter file does not exist, stop and report. Never improvise a capability the adapter does not describe.
- The adapter declares what it needs under its own `## Requirements`. The `doctor` checks that the declared server or tool is present when the session starts. This skill does not repeat that check in prose. It checks only what the `doctor` cannot: whether the source is connected and authenticated, which shows on the first query.

## When to use

- A domain question about entities, states or rules.
- A one-off investigation before a small fix.
- Step 1 of `reconcile`, which runs this protocol whole before it contests an intent against the code. `breakdown` and `implement` reach this skill that way, not directly.

A request to implement a whole item does not go through here. Send it to `implement`, which calls this protocol at the right moment.

## Precedence

Sources rank as in `## Source precedence` of the rastro block in `AGENTS.md` (template: `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`). The skill cites that list and does not copy it. Code and green tests win. A design doc is the source of the why, never of how the code is today.

The team's rules in `AGENTS.md` precede this skill for architecture rules and conventions. This skill cites them by ID and never repeats their text, because a duplicated rule diverges. It cites other skills and templates by section title, never by line number.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

## Inviolable rules

1. Never infer the schema from ORM entities when a database is declared.
2. Never invent a schema. A claim about the live database that no query confirmed carries `NOT VERIFIED`, with the reason.
3. Never execute a write. The prohibition is on executing a write, not on drafting it.
4. When a published doc and the code disagree, the code wins, and the disagreement is a finding to report, never a detail to smooth over.
5. Print the `## Context` block before answering or planning. Nothing proceeds without it.

Write every text for people in `project.languages.human`. Markers stay literal. When `.rastro/profiles/writing.md` exists, apply its rules to the block and to the answer.

## Protocol

Run the steps in this order. Each step names what it reads.

## Step 0 — Domain state gate

1. Read `domain_state.kind` in `.rastro/config.yml`. An empty value means `none`.
2. Read `.rastro/adapters/domain-state/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/domain-state/<kind>.md`, before calling `schema`, `state_distribution` or `write_policy`. If the adapter file does not exist, stop and report the missing path.
3. Decide what kind of answer the rest of the protocol can give:

| `domain_state.kind` | Schema claims | Live-database claims |
|---|---|---|
| `db-mcp` | the real schema, read from the database | confirmed when the query answers |
| `schema-files` | as the declared files say, with the file named | `NOT VERIFIED` |
| `none` | as the files found in the repository say, with the file named | `NOT VERIFIED` |

4. With `db-mcp`, the first schema query is the gate. When the server does not answer, rejects the credentials, or rejects the query:
   - do not invent a schema, and do not fall back on ORM entities or migration files to answer a live-database claim;
   - mark each such claim `NOT VERIFIED (domain state did not answer)`;
   - say so in the `## Context` block, so whoever decides knows what the decision rests on.
5. Writes. When the work needs a change in the database, draft the literal artifact through `write_policy` and hand it to a human. Inside `reconcile`, that draft becomes a `D-n` with a human executor. Refusing to draft is as wrong as running the write.

## Step 1 — Affected modules

Before any query, list:

- the affected modules, named as in `architecture.modules`. When the list is empty, name the directories that act as modules and say the list is inferred;
- the domain entities involved;
- whether one module talks to another. When it does, the boundary is the other module's public API, and the rules in `architecture.rules` that govern crossing it apply. Cite them by ID.

## Step 2 — Real schema

1. Call `schema` through the adapter for every table the question touches: columns, nullability, indexes, enum values.
2. When the question involves a state machine (an entity in `domain.stateful_entities`, or a status column), call `state_distribution` on that column. With `schema-files` and `none`, the adapter returns `NOT VERIFIED`, and declared enum values are labeled as declared, never as a distribution.
3. Never assume the schema matches the ORM entity. When both are at hand, compare them, and record every mismatch as a divergence in the block.

## Step 3 — Domain sources

1. Search the code by the name of the entity or the operation.
2. Without a useful result, read the files listed in `architecture.golden_paths` and the repository's own architecture, pattern and decision docs: state machines, invariants, domain events.
3. When `docs.public_portal` is set, read the published rules for the affected modules. When a page and the code disagree, the code wins, and the pair (page `file:line`, code `file:line`) goes to `Divergences` in the block. `reconcile` turns that finding into work.

## Step 4 — Migrations

1. Find the migrations that touched the affected tables: in the paths of `domain_state.schema_files` when set, otherwise by searching the repository.
2. Read the most recent migration for each table, to see how the schema got where it is.
3. Note whether that migration reverts exactly what it applies.

## Step 5 — Constraints checklist

Answer each item before proposing anything, and name the file where each constraint lives.

**Architecture**

- [ ] Which layer of `architecture.layers` does the logic belong to?
- [ ] Does it cross a module? Then through which public API, and under which rule IDs of `architecture.rules`?

**Domain**

- [ ] Which state transitions are valid for this operation?
- [ ] Is there a domain event to emit?
- [ ] Does it need a transaction? Where is the boundary, and what compensates a failure halfway?

**Schema**

- [ ] Does the migration revert exactly what it applies?
- [ ] Does every schema rule in `architecture.rules` hold? Cite each by ID.

**Additional checks.** When `.rastro/profiles/domain-context.md` exists, read its `## Additional checks` section and run each check that names this step. A check marked as a gate stops the protocol until it passes. A check marked as an observation goes to the block.

## Output

Print this block, then answer or plan. Write the labels in `project.languages.human`; `## Context` and `NOT VERIFIED` stay literal. The example values are a bookstore.

```markdown
## Context

**Domain state:** `db-mcp`, answered | `<kind>`, live-database claims NOT VERIFIED (<reason>)

**Affected modules:** catalog, inventory

**Schema:**
- catalog.books: columns isbn, title, status; status values DRAFT, PUBLISHED, RETIRED. Source: database
- inventory.stock: columns isbn, copies. Source: declared in db/migrations/0012_stock.sql, NOT VERIFIED

**Current state of the domain:**
- <fact, with its source>

**Constraints:**
- <constraint, with the file:line where it lives>

**Divergences:** published doc vs code, ORM entity vs schema, each with file:line on both sides, or "none"

**Ready to answer or plan.**
```

Only after the block, proceed.

## Handoff

- Called by `reconcile`: return the block. `reconcile` keeps it, carries every `NOT VERIFIED` to its gate, and continues its Step 1.
- Asked directly: answer the question after the block. When the answer leads to a change, the next step follows the state table in `AGENTS.md`.

## What this skill does NOT do

- It does not implement an item, slice work or write a plan.
- It does not contest an intent against the code. That is `reconcile`.
- It does not execute a write against any database. It drafts the artifact for a human.
- It does not fix a divergence between a published doc and the code. It reports it.
- It raises no gate. The skill that called it decides what the block means.
