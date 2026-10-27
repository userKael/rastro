---
id: W-007
type: <story | task | bug | subtask>
parent: <id of the parent item, or empty>
created_on: <YYYY-MM-DD>
sources: [<design doc reference>, <other source>]
---

> **Template.** Delete this note when filling in. With `tracker: local` this file lives in `tracker.local_dir`, frontmatter included. With another tracker there is no frontmatter: the tracker holds id, type and parent, and the sections below are the item description. The item has no status field, because the state comes from the artifacts (the state table in `AGENTS.md`) and a status field would be a second source. Write the headings in `project.languages.human`; `## Reconciliation` and `## Acceptance criteria` stay literal, because the state table and the `read_item` capability of the tracker adapters find them by title. The example ids use the default key `W` and 3 digits: the id of an item is `<tracker.key>-<nnn>`. Never cite a workspace path anywhere in the item.

## Context

<2 to 4 lines: why this item exists. Point to the source; do not repeat the design doc.>

## Observer and assertion

Observer: <who notices the item is done>

Assertion: <the sentence the observer will be able to say>

## Scope

<modules, repos and paths this item touches>

## Acceptance criteria

- <a criterion the observer can check without reading the code>

## Sources

- Design doc: <reference>, version <version>, captured on <YYYY-MM-DD>; the source of truth
- Reconciled against `<base_branch>@<sha7>` on <YYYY-MM-DD>

## Reconciliation

> Tables only, no free paragraph. Each cell holds at most 200 characters. Record findings and decisions, never design doc content. This section summarizes `reconciliation.md`; the five tables repeat its five sections. One exception: each `D-n` with executor `human` gets a human-execution block below the decisions table, with its artifact verbatim in a fenced block. The artifact is exempt from the 200-character budget and is never cut, because `implement` builds its `[HUMAN]` task from this block.

### Divergences: intent vs code

| Intent item | What the code says | Evidence | Proposal |
|---|---|---|---|

### Already delivered

| Slice of the intent | Where on the base | Evidence |
|---|---|---|

### Not sized

| Work needed | Why the intent did not foresee it | Evidence (file:line) | Cost in tasks and PRs |
|---|---|---|---|

### Code behavior the intent does not mention

| What the code does | Where | What the intent says | Impact |
|---|---|---|---|

### Decisions to close with the team

| D-n | Decision | Executor | Decided |
|---|---|---|---|
| D-1 | <question and recommendation> | agent | Decided (<YYYY-MM-DD>): <option chosen> |
| D-2 | <what has to happen, in one line> | human | Decided (<YYYY-MM-DD>): <who runs it, when and where; pending until the human says> |

#### D-2 — human execution

| Field | Value |
|---|---|
| Executor | human: <who runs it> |
| Environments | <staging, then production, one at a time> |
| When | <before or after> the merge of <which PR> |
| Rollback | <how to undo it, or "not reversible"; a rollback script goes in a second fenced block> |
| Verification | <what proves it ran, in each environment> |

Artifact, verbatim from `reconciliation.md`:

```sql
CREATE UNIQUE INDEX books_isbn_key ON catalog.books (isbn);
```

---

Subtask shape. A subtask is short: four fields, and it does not repeat the reconciliation, which lives in the parent.

```markdown
---
id: W-008
type: subtask
parent: W-007
created_on: <YYYY-MM-DD>
sources: [<design doc reference>]
---

**Unblocks:** <what this subtask makes possible, or the next subtask>

**Anchor:** `<file:line>` where the change lands

**Applicable decisions:** <D-n and DT-nn that bind this subtask>

**Revert:** <how to undo this subtask alone>
```
