<!-- rastro:begin -->
## rastro

The rastro `setup` skill manages this block. `## Non-negotiable rules` belongs to the team and is preserved when setup runs again. Everything else between the markers is regenerated, so edit it outside the markers.

In rastro skills, `${CLAUDE_PLUGIN_ROOT}` means the rastro installation directory. Claude Code substitutes it; other agents read it from the environment variable `RASTRO_ROOT`. Project settings live in `.rastro/config.yml`.

Doctrine is not overridable: not by a profile, not by team text elsewhere in this file, not by any other skill. Doctrine is the stage sequence, the state table, reconciling before slicing, the `file:line` anchor, a human executor for work the agent cannot run, stable `D-n` and `DT-nn`, gates that stop by default, the execution mode chosen per run, the verdict before editing a failing test, unversioned agent artifacts, the golden-path checkpoint, and the source precedence below.

## Where you are in the flow

No skill drives the flow. The position follows from the artifacts: read the tracker and git, and the next step is in this table.

| What you observe | Next step |
|---|---|
| No source code yet | `init` |
{{state_table_first_row}}
| A {{tracker_item}} exists, without `## Reconciliation` in its description | `implement`, which calls `reconcile` |
| A {{tracker_item}} with `## Reconciliation`, no branch | `implement` |
| A branch with verified commits, no PR | `deliver` |
| A PR is open | Review: automatic when `review.kind` is not `none`; human always |

A request with no shape ("I want to rethink how stock reservation works") does not enter here. It goes to `design-doc`, which writes the design doc and publishes it. Publishing is not approving: the design doc goes back to the team for discussion, and then it enters through `breakdown`.

A repository with no source code yet starts at `init`. It records the first decisions as ADRs with the person, runs `setup`, and writes the walking skeleton as the intent of the first item, which `breakdown` takes. No golden path is written ahead of that code. In such a repository, the reconciliation's search for code behavior the intent does not mention is empty by construction: the gate says so, instead of treating the empty result as suspect.

Every gate stops by default. No skill moves to the next stage without an explicit choice: at the gate, or, in a continuous run, at the start, as `## Execution mode` says.

## Non-negotiable rules

The team writes its rules here, each in the format below. Skills cite a rule by ID, never by its position in the list, and `architecture.rules` in `.rastro/config.yml` points here by default. Replace the example with your own rules, then delete this paragraph.

- **[module-public-api]** A module imports another only through its public API.
  **Symptom:** an import of `<other-module>/internal/...`, or of any path outside `<other-module>/index.ts`.
  **Why here:** <the real consequence in this codebase>.
  **Ask the author:** <what the review comment asks for>.
  **Known debt:** <files that already violate the rule; optional>.

Known debt is not precedent and does not grow: a new file with the same defect is a blocking violation.

## Delivery conventions

These apply to every agent and every person who produces a commit, subagents included.

### Language

Branch, commit and PR title use `project.languages.machine`. The PR description and every other artifact for people use `project.languages.human`. With squash merge, the PR title becomes the commit message on the base branch.

Domain identifiers are never translated: `order`, `isbn`, `reserveCopies`.

### Branch name

The format is `conventions.branch`, by default `<type>/<id>-<short-slug>`. The `type` comes from `conventions.types` and matches the predominant type of the commits on the branch. The `<id>` is the item this PR delivers, never its umbrella story.

### Commit message

The format is `conventions.commit`, by default `<type>(<scope>): [<id>] <subject>`.

- The `scope` is a module from `architecture.modules`, or `shared`, `infra`, `ci` or `docs`.
- The subject is imperative, lowercase, without a trailing period, and at most 72 characters.
- The body is required. It explains why: the decision, the constraint or the bug behind the change. A commit that implements a named decision cites its ID (`DT-03`, `D-2`).
- When `conventions.co_author_trailer` is `true`, every commit ends with `Co-Authored-By: <the model that generated this commit> <vendor noreply address>`, review-response commits included. The trailer names the real model of the session, never a name copied from an example. The string stays the same across a branch, and changes when the model changes mid-branch.

The `commit-msg` hook validates the format. Never use `--no-verify`.

### Scope hygiene

`git add -A`, `git add .` and `git commit -a` are forbidden. Stage with explicit paths. Before each commit, compare `git diff --cached --name-only` with the scope of the item.

Without a written request, these never enter a commit: files matching `conventions.forbidden_paths`, the workspace, dumps and CSVs, and any file holding data listed in `architecture.sensitive_data`.

Git has no hook for `git add`, so only an agent harness can deny the wildcard forms. The `pre-commit` hook still refuses staged files that match `conventions.forbidden_paths`.

### Comments in code

The default is no comment. Write one only when the why is not obvious from the code: a hidden constraint, a workaround for a specific bug, a behavior that would surprise the reader. Never describe the what; a well-chosen name already does.

Never reference the task, the ticket or the caller in a comment (`// used by the order-cancel flow`, `// added for <item id>`). That belongs in the PR description. In code it rots when the code changes owner or the task is forgotten.

## Golden paths

A golden path is how this project builds one type of component, in the `architecture.golden_paths` folder, `docs/golden-paths/` by default and when the key is empty. Nobody writes one ahead of the code: the first instance of a type writes its golden path, in the same change, with the person implementing it. During the reconciliation, every later item classifies each component it adds or changes as `follows`, `extends`, `contradicts` or `no golden path`. A contradiction is a decision, never a block and never silent.

## Source precedence

When sources conflict, the one higher in this list wins.

1. Code and green tests: what runs in production.
2. `AGENTS.md`: the non-negotiable rules and these conventions.
3. ADRs: durable architecture decisions.
4. Golden paths and patterns: how to build.
5. Current plan: the plan of the item in progress.
6. Design doc: the source of the why, never of how the code is today.

Precedence settles what the code is. When code contradicts a `current` golden path, the golden-path gate settles what it should be: the golden path evolves to a new version, or the code changes. Neither wins silently.

## Gate anatomy

A gate asks the human for a decision. It prints three parts, in this order.

1. **Title.** The title is the question, in one line: `Gate — PR #12 open: stop or continue to W-14?`. A title that names the stage and hides the decision is wrong: `GATE 3 — continuity`.
2. **State.** A two-column table with at most 6 rows and at most 80 characters per cell. What does not fit becomes a note below the table, prefixed `⚠` only when it blocks the merge.
3. **Decision.** The class of the gate sets the channel.

| Class | When | Channel |
|---|---|---|
| Fork | 2 to 4 mutually exclusive paths | The structured question tool, recommended option first. The text above the question does not repeat the options |
| Deliberation | N items that each need an answer (`D-n`, `DT-nn`) | A table, one item per row, plus a quick-exit row. No widget |

Three prohibitions:

- **Never align by whitespace.** No padding with spaces, no `  ·  ` separators, no monospace key-value lists. Outside a code block they collapse into one line. Structure is bold, table and list.
- **Never exceed the cell budget, and never nest an explanatory parenthesis in a cell.** A generous slot gets filled with prose. The budget applies to prose: a value that must stay verbatim, such as a PR title, a `file:line` or a URL, is exempt, because truncating an identifier is worse than overflowing the cell.
- **Never print the same question twice.** A menu in the text plus a question widget is one decision in two formats.

Every gate declares its class and its mode on its title line, as in `Class: fork. Mode: confirmation.`, and `## Execution mode` defines the modes. The skill that prints the gate is its authority.

A subagent never asks the human. A subagent that meets a constraint returns the finding as text and ends its task; the session that dispatched it raises the gate. If there is no structured question tool, end the turn with the question.

## Execution mode

At the start of each run, the person chooses how the gates of that run behave: stop at every gate, the default, or continuous. The choice holds for that run only and is never a config key.

- **Who asks.** `breakdown`, `implement` and `deliver`, before their first gate, when no mode is recorded for the top item of the work: the parent of the item, or the item itself when it has no parent. `design-doc`, `init`, `setup`, and `reconcile` called on its own never ask, and their gates stop.
- **The question.** **Execution mode for <top item>: stop at every gate or continuous?** Ask with the structured question tool. **Stop at every gate** comes first and is recommended: every gate waits for an answer. **Continuous**: the confirmation gates take the recommended option and the PR lists them, while the decision and team gates still stop. Without that tool, end the turn with the question.
- **Where it lives.** `<workspace>/mode`, in three lines: `mode: stop` or `mode: continuous`, then `item: <top item id>`, then `date: <YYYY-MM-DD>`. A file for another top item, or written on an earlier day, does not count: ask again and overwrite it.
- **When it ends.** The run ends when the person stops at a gate, when a skill stops and sends the request elsewhere, or when the continuity gate of `deliver` finds no next item. Delete `<workspace>/mode` then, so a forgotten continuous mode never reaches the next run.
- **Reusing it.** When a skill reuses a recorded mode, it prints one line: `Execution mode: <stop at every gate | continuous>, chosen <date> for <top item>.`

Every gate declares its mode next to its class. The mode says what a continuous run does at that gate.

| Mode | The answer | In a continuous run |
|---|---|---|
| `confirmation` | confirms what the agent prepared | takes the recommended option |
| `decision` | changes the content: a `D-n`, a revalidation, a discovered constraint, a golden path | stops |
| `team` | belongs to the team, such as publishing a design doc | stops |

At a confirmation gate, a continuous run still prints the title and the state, then one line, `Continuous run: took <option>.`, and appends `- Continuous run, <skill>: <gate title> Took: <option>.` to `rulings.md` in the workspace folder of the item. `deliver` turns those lines into rows of `## Agent rulings`. A confirmation whose recommended option needs the person's input, such as adjusting the slicing, stops.

A decision gate with no open item counts as a confirmation: a reconciliation with no `D-n`, or a golden-path review with no decision row. The exception never applies to the golden-path review of a new golden path (version `1.0.0`): it always stops. An extension with no new or changed decision may pass. A `D-n` with a human executor does not stop a continuous run: its `[HUMAN]` task stays open, the run goes on unless that task blocks a later one, and the step appears under `Pending human execution` in the PR.

A continuous run passes gates only. A question that gathers input, such as the interview of `breakdown` or the repositories that consume a contract, still waits for the answer.

## Failing tests

A red test is a diagnosis before it is a fix. Before editing any file, write the verdict:

```
VERDICT — <test file>::<case name>
Wrong artifact: test | code | design doc
Why: <the correct behavior, with the file:line that defines it>
I will edit: <file>
```

If the wrong artifact is the design doc, stop and bring it to the human. A design doc is not fixed during execution.

Editing an existing test without a written verdict is a scope violation, even when the suite turns green. These count as editing a test: loosening an assertion, changing the expected value, skipping a case, widening a mock or a fixture so it accepts the current output, and deleting a case.

The rule asks for a diagnosis instead of saying "do not change tests" on purpose. A ban gets worked around. A written diagnosis forces the question "which artifact is wrong?" to be answered before the first edit.

## Agent artifacts are not versioned

The workspace (`workspace` in `.rastro/config.yml`, `.agent/` by default) is a gitignored working directory. The materialized design doc, the plan, the reconciliation and the execution ledger live there and never enter the repository. The repository's docs hold only what outlives the history: ADRs, patterns and golden paths.

What has to last goes in the PR description: divergences from the design doc, closed decisions, agent rulings, and the plan in a `<details>` block. Never cite a workspace path in the PR description or in the tracker: it is a dead link the next day.
<!-- rastro:end -->
