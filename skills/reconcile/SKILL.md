---
name: reconcile
description: Contests a declared intent against the real code and writes reconciliation.md with file:line evidence, stamped with the base branch commit. The intent is a file - a design doc, an interview record, or the root cause of a bug. Use it to learn what is already on the base branch, what the intent gets wrong, what it did not size, and what code behavior it ignores, before slicing work or planning an implementation. The breakdown and implement skills call it; it is rarely invoked directly. It ends at a deliberation gate where the human closes each D-n. Do not use it for a domain question with no intent file: that is domain-context. Do not use it to slice work or create items (breakdown), to plan or write code (implement), or to find a root cause: the bug's root cause arrives from outside. When a stamped reconciliation already exists, run only its delta revalidation.
---

# reconcile

One protocol confronts a declared intent with the code, in both directions, before anyone slices or plans. Two callers use it, `breakdown` and `implement`, and neither needs a tracker id to call it.

**Input:** the path of an intent file; the declared scope (modules, repositories, paths); the identifier of the work, which is the item id when one exists, otherwise a short slug of the intent; and the caller's workspace directory, written `<directory>` below. The intent type is `design doc`, `interview` or `root cause`. Without a directory, stop and ask for it.

Callers pass these directories, where `<workspace>` is the `workspace` key of `.rastro/config.yml`, `.agent/` by default:

- `breakdown`: `<workspace>/breakdown-<slug>/`
- `implement`: `<workspace>/<id>/`

**Output:** `<directory>/reconciliation.md`, in the format of `${CLAUDE_PLUGIN_ROOT}/templates/reconciliation.md`, stamped `<base_branch>@<sha7>`. No other output location exists.

## Requirements

- `.rastro/config.yml`. If it does not exist, stop and tell the human to run the `setup` skill.
- An intent file. Without one the input is wrong: stop and ask for it. This skill does not produce intent.
- The `domain-context` skill, at `${CLAUDE_PLUGIN_ROOT}/skills/domain-context/SKILL.md`. This skill reaches the domain-state port only through it. If the adapter file does not exist, stop and report. `domain-context` stops on a missing domain-state adapter, and this skill stops with it.
- git, for the stamp and the delta revalidation.

## Precedence

Sources rank as in `## Source precedence` of the rastro block in `AGENTS.md` (template: `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`). Code and green tests win. A design doc is the source of the why, never of how the code is today.

The team's rules in `AGENTS.md` precede this skill for architecture rules and conventions. This skill cites them by ID and never repeats their text, because a duplicated rule diverges. It cites other skills and templates by section title, never by line number.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

## Inviolable rules

1. Never invent an intent section that does not exist. An absence is a finding under `Not sized`, never "not applicable".
2. Never edit the intent file. It is a frozen copy with provenance. Every divergence goes to `reconciliation.md`.
3. Every row of the first three tables carries a `file:line` anchor. A claim without evidence does not enter a table: it becomes a `D-n` question.
4. Never skip the human gate. The reconciliation exists for the human to decide. Moving on without an explicit answer to each `D-n` invalidates everything after it.
5. Never execute a write against a database, a credential, a deployment or shared infrastructure. Draft it as a `D-n` with a human executor.
6. Cite a rule by its ID, never by its position in the list.

Write every text for people in `project.languages.human`. Markers stay literal. When `.rastro/profiles/writing.md` exists, apply its rules to the file and to the gate.

When `.rastro/profiles/reconcile.md` exists, read its `## Additional checks` section once, and run each check at the step it names. A check marked as a gate stops the protocol until it passes. A check marked as an observation becomes a row in the table it names.

## Step 1 — Repository context

1. Run `${CLAUDE_PLUGIN_ROOT}/skills/domain-context/SKILL.md` whole, over the declared scope: the modules and the public APIs that cross them, the real schema, the domain docs, the most recent migrations of the tables in scope, and the constraints (nullability, uniqueness, indexes, enum values). Keep its `## Context` block.
2. A claim that `domain-context` marked `NOT VERIFIED` stays marked in the file and goes to the gate. Never present it as confirmed.
3. Read the architecture sources: the files in `architecture.golden_paths`, and the repository's architecture, pattern and decision docs. No config key names the ADRs: find them through `architecture.golden_paths` and the repository's docs.
4. Read the rules that `architecture.rules` points to, and note their IDs. Step 2 cites them.
5. Read the files in `architecture.contract_sources` that the scope touches: API specs, event schemas, any published contract.
6. Work that needs a write becomes a `D-n` with a human executor (see `### Work the agent cannot run`). It never blocks the reconciliation.
7. Stamp the commit. When a remote exists, fetch it and bring the local `project.base_branch` up to its remote tip. Then record `<base_branch>@<sha7>`:

```bash
git rev-parse --short <base_branch>
```

Never stamp HEAD of a feature branch. Read the code at the stamped commit; when the working tree is on another branch, read each file with `git show <sha7>:<path>`. The stamp is what makes the delta revalidation possible.

## Step 2 — Strong direction

For each item of the intent, ask: does the code agree? Look for these five kinds of finding:

1. **Internal contradiction.** Two parts of the intent say incompatible things, for example the scope and a `DT-nn`.
2. **Wrong error contract.** The intent names an error code or shape that the code's error mapping does not produce. Check every error the intent names against the place where the code maps errors.
3. **Slice already delivered.** Part of the intent is already on the base branch. Always check the base before anyone plans. It goes to `Already delivered`.
4. **Unsized foundation.** Mandatory work the intent did not foresee. It goes to `Not sized`, with its cost in tasks and PRs.
5. **Decision that would break production.** A decision that assumes behavior the current code does not have.

When the intent changes a contract, compare it with the file in `architecture.contract_sources` that publishes it. A consumer outside this repository cannot be measured from here, because no port covers it. When a published contract changes, ask the human about outside consumers as a `D-n`.

Run the additional checks that name this step.

### Code flows: the projection is contested too

The code-flow section of a design doc (`## Code flows` in `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.md`) is the part of the intent closest to the code. Design docs write headings in `project.languages.human`, so find the section by its role: the section that lists components tagged `new`, `changes` and `exists`. Never look for the literal English heading. Contest the components against `<base_branch>@<sha7>`:

- **`exists` and `changes`.** The component exists under that name, and its path points to one real file. When it does not exist, or the path matches more than one file, it is a divergence. Their paths go into the declared scope of the header.
- **`new`.** Its type is a name from `architecture.layers`; any other type is a divergence. Its type and module respect the rules of `architecture.rules`. Check each rule by ID. A violation is a divergence that cites the rule ID and the `file:line` where the rule lives.
- **`rect` blocks.** The owner named in a transaction block can open one transaction that covers every write listed inside it. When the code has no mechanism for that, it goes to `Not sized`.
- **Renaming a `new` component is not a divergence.** A change of type, module, module crossing, transaction owner or async boundary is.

### Bug mode

When the intent is the root cause of a bug, the direction inverts. Do not contest the document against the code. Contest the expected behavior against the observed behavior. Each row asks: which pre-existing contract is violated, and where is it written?

The contract has to be pointable: a test, a design doc, an ADR, a golden path, a published doc, documented behavior. If no pre-existing contract can be pointed to, it is not a bug. It is a behavior change, and the intent goes back to the caller for an interview.

This skill does not produce the root cause. It arrives from outside, from the debugging protocol that the `breakdown` skill runs on its bug branch. What enters is the confirmed hypothesis, the root cause and its `file:line`.

## Step 3 — Weak direction

Step 2 walks the intent and asks whether the code agrees. That is the easy direction. The direction that escapes is the inverse: behavior that exists in the code, matters, and that the intent never mentions. Silence produces no contradiction, so nothing fires on its own. Go and look for it.

Walk the files of the declared scope, not the intent, and list with `file:line` at least:

- **Unmentioned side effect:** a write, an event publication, an external call or an audit record on the changed path.
- **Unmentioned guard:** an early return, an eligibility check or a validation that already refuses input the intent assumes gets through.
- **Unmentioned state:** a transition, a status column, a timestamp or a flag the current path writes.
- **Unmentioned order:** the sequence between persistence and an external effect, which the intent does not draw.
- **Unmentioned published rule:** what the public docs say today about the changed path (see `### Public docs` below).

Zero findings in the weak direction is a suspicious result, not a good one. When the search finds nothing, write one line saying where you searched and why it came back empty.

Run the additional checks that name this step.

### Public docs: a published page is a declared contract

Run this only when `docs.public_portal` is set. Find the pages of each module in the declared scope under that location, including the pages of the events the module publishes when the portal has them. Sort each finding into one of two boxes:

| What you find | Where it goes |
|---|---|
| The page is already wrong today, before this change | `Code behavior the intent does not mention`: debt found in passing, not work of this item |
| The page will become wrong because of this change | `Not sized`: mandatory work the intent did not foresee |

A row enters only with `file:line` on both sides: the page and the code that contradicts it. Without the pair it is an impression, not a finding.

The code wins. This skill finds the divergence, `breakdown` turns it into a subtask, and `deliver` asks about it again before the push.

## Step 4 — Reconciliation file

Write `<directory>/reconciliation.md` following `${CLAUDE_PLUGIN_ROOT}/templates/reconciliation.md`:

- the header, with the intent (path, type, capture date, origin), the reconciliation date with `<base_branch>@<sha7>`, and the declared scope with the `exists` and `changes` paths. The declared scope is the filter of the delta revalidation;
- exactly the five sections of the template, in its order, nothing more and nothing less. Write the headings in `project.languages.human`. The file name and `Decided (<YYYY-MM-DD>):` stay literal.

Number the decisions `D-1`, `D-2`, and so on, contiguous, never letters: past ten decisions, a letter no longer tells the order. The prefix separates a `D-n` from a `DT-nn`. Write each `D-n` in one of the two shapes of the template: with an agent executor (question, options, recommendation with its evidence in the code), or with `executor: human`.

### Size signal

Sum the rows of the four tables: divergences, already delivered, not sized, and code behavior the intent does not mention. When the sum is above the threshold, that signals the item fails the size ruler of the `breakdown` skill. Do not truncate any table. Bring the number to the gate as a finding.

The default threshold is 20 rows. A team overrides it in `.rastro/profiles/reconcile.md`, section `## Size signal`, when that file exists.

### Work the agent cannot run

Part of legitimate work is out of an agent's reach: a write to a shared database, a credential rotation, a deployment, a maintenance window, a change to shared infrastructure. It neither blocks the work nor becomes "out of scope". It becomes a `D-n` with `executor: human`: the agent drafts the artifact, the human runs it, and the gate is where both agree. The prohibition is on running, not on drafting. A skill that freezes at this point is as useless as one that runs it.

Six rules for this kind of `D-n`:

1. **The artifact is literal and copyable.** The complete statement or command, with real names and no placeholder. If you cannot produce the exact artifact, the finding is not mature yet: say so instead of handing over a sketch.
2. **Environments are named one by one.** Each environment is a separate run with a separate result. Never write "run it on both" as a single step.
3. **Rollback is declared.** How to undo it, or the explicit words "not reversible", which often change the human's decision on their own.
4. **Verification is declared.** The query or command that proves the run worked. Without it nobody knows whether it ran.
5. **Never assume it ran.** Until the human confirms, the state is pending. `implement` carries it as a blocking task of the plan, and `deliver` reports what is still pending.
6. **State whether it runs before or after the merge.** It is almost never simultaneous, and getting the order wrong breaks production.

When the whole item depends on human execution and no code is left, say so at the gate: the item is probably not an implementation item.

## Step 5 — Human gate

Stop. Do not slice, do not plan, do not write code.

**Class: deliberation.** Each `D-n` needs its own answer, so the decision is a table, not a question widget. Print the gate in this shape, in `project.languages.human`:

```markdown
**Gate — reconciliation of <id>: do I close the decisions as recommended?**

| | |
|---|---|
| File | `<directory>/reconciliation.md` |
| Base | `<base_branch>@<sha7>` |
| Divergences | <n> |
| Already delivered | <n> of <n> slices, <n> left |
| Not sized / code not mentioned | <n> / <n> |
| Size signal | <fired, n rows / not fired> |

| Decision | Recommendation | Executor |
|---|---|---|
| D-1 | <one line> | agent |
| D-2 | <one line> | human, <environment> |
| All | Approve as recommended: closes the agent decisions only | — |
```

Below the tables, add one note per claim that is `NOT VERIFIED`, and one note when the item is only human execution. Prefix a note with `⚠` only when it blocks the merge.

"Approve as recommended" closes the technical recommendations only. It authorizes nobody to run anything. For each `D-n` with a human executor, the human says whether they will run it, when, and in which environment. Until they say so, the state is pending, and it stays pending in the plan and in the PR description.

Proceed only on an explicit answer. Record it in the file under each `D-n`, as `Decided (<YYYY-MM-DD>): <answer, and who decided>`.

A subagent never asks the human. When this skill runs inside a subagent, it writes the file, returns the gate text and the file path as its result, and ends. The session that dispatched it raises the gate, and records each answer in the file as `Decided (<YYYY-MM-DD>): <answer, and who decided>`.

## Delta revalidation

Whoever inherits a stamped reconciliation, typically `implement` reading the `## Reconciliation` section of an item, or the copy that `breakdown` leaves at `<workspace>/<id>/reconciliation.md` with `tracker: none`, does not redo the protocol. Update `project.base_branch` from the remote, then run:

```bash
git log --oneline <sha>..<project.base_branch> -- <scope>
```

The range ends at the base branch, never at `HEAD`. Run from a feature branch, `HEAD` would list the branch's own commits and miss what landed on the base after the branch was cut.

`<sha>` is the stamp of the reconciliation. `<scope>` is the list of paths in its declared scope.

| Result | Action |
|---|---|
| Empty | Accept the reconciliation as it is. This is the common case. |
| Not empty | Run Steps 2 and 3 again, only on the items whose files appear in the log. |

When the log is not empty, append the revalidation block of `${CLAUDE_PLUGIN_ROOT}/templates/reconciliation.md` below the five sections. Never rewrite the five sections.

Closed decisions do not reopen unless the delta contradicts them. When a commit contradicts a closed `D-n`, stop and raise a deliberation gate again. **Class: deliberation.** Print it in this shape, in `project.languages.human`:

```markdown
**Gate — revalidation of <id>: do the contradicted decisions still hold after <sha7>?**

| | |
|---|---|
| Source | <`<directory>/reconciliation.md` / `## Reconciliation` of <id>> |
| Stamp | `<base_branch>@<sha7 of the reconciliation>` |
| Revalidated at | `<base_branch>@<sha7>` |
| Commits in scope | <n> |
| Contradicted decisions | <n> of <n> closed |

| Decision | Contradicting commit | Recommendation |
|---|---|---|
| D-n | `<sha7>` | <keep / reopen, in one line> |
| All | Keep every decision as closed | — |
```

Proceed only on an explicit answer to each row.

There is one reading of the intent, stamped with a sha, and one revalidation rule, a `git log`. That is what keeps two people from reconciling the same intent two ways.

## Handoff

- Called by `breakdown`: return the path of `reconciliation.md` and the decisions recorded at the gate. `breakdown` derives the item type from them and slices.
- Called by `implement`: return the same. `implement` writes `## Reconciliation` on the item when it is missing, and plans.
- Called directly: stop after the gate, with the decisions recorded in the file.

## What this skill does NOT do

- It does not slice work. The rulers and the merge test belong to `breakdown`.
- It does not create or edit items in the tracker.
- It does not write a plan or code.
- It does not investigate a bug. The root cause arrives from outside.
- It does not produce intent. Without an intent file, it stops and asks.
- It does not execute a write. It drafts the artifact for a human executor.
