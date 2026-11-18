> **Template.** Delete this note when filling in. Write the headings in `project.languages.human`. Sections that do not apply are removed whole: `## Pending human execution` and `## Agent rulings` most often. Never cite a workspace path. `## Pending human execution` goes at the top when it blocks the merge.

## Pending human execution

| Step | Environment | When | Blocks the merge |
|---|---|---|---|
| <step from the human-executed decision> | <environment> | <before or after the merge> | <yes or no> |

## Reviewer summary

- <outcome and scope>
- <review focus or operational risk>
- <verification result and any merge blocker>

## Dependency state

- Target: `<effective branch>`
- Prerequisites: <none, or each slice and linked PR or human task with its state>
- Merge order: <any requirement reviewers need before merging>

## Context

- Item: <id and link>
- Design doc: <link>, version <version>, captured on <YYYY-MM-DD>
- Slice: <stable key, or legacy ordinal when it was recorded>

<Why this PR exists, in two to four lines.>

## What this PR delivers

- <The contract this PR adds or changes, and the edge it stops at.>

## Closed decisions

| Decision | What was decided | New in this PR |
|---|---|---|
| `DT-nn` or `D-n` | <the choice> | <yes or no> |

## Risks and rollback

- Risk: <what can go wrong>; critical order: <what must happen first>
- Rollback: <how to undo this PR alone>

## Verification

| Check | Result |
|---|---|
| <command> | <exact number from the last run on this revision> |

<For a change to an external integration: say whether it was tested by hand and what is still not exercised. Coverage is not evidence of behavior.>

## Next PRs

| Slice | What it delivers | Depends on | State |
|---|---|---|---|
| <related slice and item link> | <artifact and consequence> | <keys> | <ready or waiting with reason> |

## Reconciliation

Link the reconciliation holder for a tracked item. With `tracker: none`, use the five tables and reviewed human-execution blocks in the work item template. Collapse the full content when supported.

## Divergences from the design doc

| Design doc says | The implementation does | Why |
|---|---|---|

## Recorded debt

- <What is left on purpose, and where it is anchored (`file:line`).>

## Golden paths created or evolved

Include only when this branch created a golden path or changed its version.

| Golden path | Change | Version | Instance |
|---|---|---|---|
| `<id>` | <created, extended or changed> | <old> → <new> | `<file:line>` |

## Rule self-check

Include only when a rule is flagged ⚠.

| Rule | Result | Evidence |
|---|---|---|
| `[<rule-id>]` | ⚠ | <`file:line` and the fix or the debt line> |

## Agent rulings

| Task | Finding | Ruling | Destination |
|---|---|---|---|
| <task> | <what the agent found> | <what it decided> | <where the decision went> |

<details>
<summary>Executed plan</summary>

<Tasks of this PR. When the plan is large, cut the tasks already delivered by prerequisite PRs and say that they were cut.>

</details>
