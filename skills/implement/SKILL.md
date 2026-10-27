---
name: implement
description: Implements one work item end to end, from its id. It reads the item and its real parent, freezes a copy of the design doc the item cites, inherits or runs the reconciliation of that design doc against the code, writes a plan with test scenarios per task, and executes it until the branch has verified commits. Use when the request is "implement <id>", "code this item", "start the PR for <id>", or any change that already has a work item. Do NOT use without an item: an unshaped request goes to design-doc and a request with no item goes to breakdown. Do NOT use to open or describe the PR: that is deliver, which this skill hands off to.
---

# implement

**Input:** the id of the item to implement: a subtask, or a task or bug that has no subtasks. Never an item that has subtasks. With `tracker: none`, the input is the item file in the workspace, `<workspace>/<slug>/item.md`.

**Output:** a branch with verified commits, plus the workspace `<workspace>/<id>/`: the frozen copy of the design doc, `reconciliation.md`, `plan.md` and, after subagent execution, `rulings.md`. The workspace is gitignored. `deliver` transposes it into the PR description.

Four stages, in order, never skipped: INTAKE → RECONCILIATION → PLAN → EXECUTION.

## Requirements

- `.rastro/config.yml`. Without it, stop and tell the human to run the `setup` skill.
- Two ports, reached through their adapters and never by naming a tool:
  - Tracker, with `<kind>` from `tracker.kind`. Read `.rastro/adapters/tracker/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/tracker/<kind>.md`, before `read_item` or `write_section`.
  - Docs, with `<kind>` from `docs.kind`. Read `.rastro/adapters/docs/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/docs/<kind>.md`, before `fetch`.
- If the adapter file does not exist, stop and report. Never improvise a capability the adapter does not describe.
- The `doctor` checks each adapter's requirements at session start. When it reported a problem for an adapter this skill uses, stop and report it. Do not work around the missing tool.
- The `reconcile` skill, at `${CLAUDE_PLUGIN_ROOT}/skills/reconcile/SKILL.md`, which owns the reconciliation protocol and its gate.
- The `deliver` skill, at `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md`, which receives the handoff.
- Plan template: `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`.
- Team profile, optional: `.rastro/profiles/implement.md`. Its `## Additional checks` section lists extra checks, each with the stage where it runs and whether it is a gate or an observation. Run each one at its stage. Environment preparation before integration tests, and title aliases of the team's older design docs, belong there.
- Writing rules, optional: when `.rastro/profiles/writing.md` exists, apply it to every text a person reads: reports, gates, the plan.
- Optional skills, each with a built-in fallback:
  - `superpowers:writing-plans` writes the plan. Without it, fill `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`.
  - `superpowers:subagent-driven-development` executes the plan when the criterion of Stage 4 fires. Without it, inline execution, one task at a time, one commit per task.
  - `superpowers:executing-plans` may drive inline execution when it is installed.

## Precedence

`AGENTS.md` › the team profile › the defaults of this skill › the superpowers defaults. That order governs rules and conventions.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill. In this skill, doctrine is: the four stages in order, reconciling before planning, the `file:line` anchor, a human executor for work the agent cannot run, stable `D-n` and `DT-nn`, gates that stop by default, the verdict before editing a failing test, and unversioned agent artifacts.

The rules at `architecture.rules` precede this skill and are not repeated in it. A duplicated rule drifts from its source, and emphasis spread over twenty items highlights none.

Scope hygiene is not in the rules below on purpose. Hooks enforce it: the agent harness denies wildcard staging and `--no-verify`, and the `pre-commit` hook refuses forbidden paths. When that enforcement fails, the fix is in the hook.

## Inviolable rules

Read these first. A violation means stop and report, never work around.

1. The input is the work item, never the design doc.
2. Never skip the reconciliation gate: neither the first one, nor the one a revalidation raises when the delta contradicts a closed `D-n`. Planning without an explicit answer to every `D-n` invalidates everything after it.
3. Never report success with verification pending. Suite counts, test counts and coverage come from a real run on the current revision, pasted literally.
4. Never invent a section the design doc does not have. An absence is a finding for `Not sized`. A role not found is not "does not apply".
5. Never write an absolute machine path. Every path is relative to the repository root, because an absolute path breaks on the next machine.
6. Never edit the materialized design doc. It is a frozen copy with provenance, and every divergence goes to the reconciliation.
7. Never cite in the tracker a path that does not exist in git. Workspace paths are dead links the next day.

## Stage 1 — INTAKE

Intake comes before reconciliation, plan and execution.

### Entry gate

The input is the id of the item to implement. With `tracker: none`, it is the item file. When the human brings only a design doc link, stop and ask for the item id. When the id names any item that has subtasks, stop and ask which subtask: one PR delivers one subtask, never the whole parent.

The direction matters. Tracing from a design doc to its item is weak: a design doc's metadata can name the wrong parent. Tracing from the item to its design doc is strong: the `## Sources` of the item, or of its parent, names the design doc as the source of truth.

### Steps

1. Read the item with `read_item`: title, description, children, and the real parent. Read the parent with `read_item` too.
2. Extract the acceptance criteria from the item. An item without them yields the first finding of the reconciliation.
3. Find the design doc in `## Sources` of the parent when the item has one, otherwise of the item itself: the item that holds, or will hold, `## Reconciliation`. When the parent has no `## Sources`, fall back to the item's own. With `tracker: local`, the sources may sit in the `sources:` frontmatter field instead of a section. Otherwise look for a design doc link in the description. Otherwise stop and ask the human which design doc applies. When the human says there is none, the item description is the intent: materialize it in place of the design doc, at the same path and with the same header.
   - A bug with no design doc: its root cause is the intent. Skip the role mapping: `reconcile` runs in root-cause mode.
   - Any other item with no design doc: map the roles against the description, and record every absent role together as one `Not sized` finding.
4. Materialize the design doc with `fetch` into `<workspace>/<id>/design-doc.md`, keeping mermaid blocks. The workspace is gitignored: commit nothing from it.
5. Expand everything that was collapsed. Collapsing tells a person what to read first, never what the agent may skip. Check that the copy has one deliberation per `DT-nn` and that no section arrived with only its title. An empty section is a capture failure. A capture gap becomes a false `Not sized` finding, which is a whole PR of invented work.
6. Write the provenance header at the top of the copy, with the frozen-copy notice below.
7. Map the semantic roles below, by content, and fail loudly on each role that is missing.

Why materialize: a subagent reads local files and has no MCP connection. A design doc that exists only in a docs tool is out of its reach. The file must be reachable, not versioned. What lasts is the PR description, which carries the design doc's link, version and date.

### Provenance header

```markdown
---
item: <id>
parent: <parent id>
source: <design doc reference, as fetch returned it>
version: <version, or "not returned">
captured_on: <YYYY-MM-DD>
---

> **Frozen copy.** Do not edit this file. The original lives at `source` and may have
> changed since `captured_on`. Every divergence between this copy and the code goes to
> `reconciliation.md`.
```

### Semantic roles

Match each role by what a section holds, never by its title. Titles vary between documents and teams.

| Role | What it holds | What it feeds downstream |
|---|---|---|
| scope | what this delivery includes and excludes | the cut: what is out never enters the plan; its paths filter the delta revalidation |
| technical decisions | each `DT-nn` with its record | names cited in the plan, the commits and the PR description |
| contracts | signatures, error statuses, published events | checked against what the code maps; a divergence goes to the reconciliation |
| invariants | rules that always hold, transaction boundaries, compensation | the Given/When/Then scenarios and their assertions |
| code flow | components, order of effects, transaction owners | the seed of the plan's file map: type, module and boundary bind; a new component's name is a suggestion |
| risks | what can go wrong | the risk section of the PR |
| slicing | the candidate slicing | the seed of the PR stack; a draft, never authority |

These absences recur and must be listed when they occur: acceptance criteria, state diagram, rollout plan, feature flag, test strategy, monitoring, code flow.

### Intake report

This is a report, not a gate: it has no decision. It still follows part 2 of `## Gate anatomy` in the AGENTS.md block.

**INTAKE <id>**

| | |
|---|---|
| Item | <id> — <title> |
| Real parent | <id> — <title> |
| Acceptance criteria | <n> extracted, or absent |
| Design doc | <reference> <version>, <date>, copied to the workspace |
| Roles found | <scope, DT-01 to DT-nn, contracts, ...> |
| Roles not found | <invariants, state diagram, ... or none> |

A role not found is not "does not apply". Each one becomes a `Not sized` item of the reconciliation. Without a design doc, all of them together become one item. For a bug with no design doc, both role rows say `root-cause mode`.

## Stage 2 — RECONCILIATION

The design doc was written before the code existed, and the code is what runs. This stage contests the design doc. The protocol lives in `reconcile` and is not repeated here.

### Does the item already have a reconciliation?

`## Reconciliation` lives on the parent when there is one, and on the item itself otherwise, as for a task or a bug with no subtasks. Call that item the holder. Read the holder's description and look for the section. With `tracker: local`, read its item file. With `tracker: none`, the reconciliation is a file, never a section: `breakdown` leaves `reconciliation.md` in the folder of the top item. When `item.md` has a `Parent:` line, look first at `<workspace>/<parent id>/reconciliation.md`, with the id that line names. Then look at `<workspace>/<id>/reconciliation.md`.

**It has one.** Inherit it, and do not redo the protocol.

1. Write its tables into `<workspace>/<id>/reconciliation.md`, with the holder's id, the reading date and the stamp `<base_branch>@<sha7>` from the holder's `## Sources` at the top. Copy each human-execution block below the decisions table too, with its artifact verbatim. When the holder has no `## Sources`, read the item's own. With `tracker: none`, the file already has its stamp: copy it only when it was found under the parent. The plan needs that file.
2. Revalidate by delta, with `<scope>` from the holder's `## Scope`, or from the item's own when the holder has none. Update `project.base_branch` from the remote first, then run:

   ```bash
   git log --oneline <sha7>..<project.base_branch> -- <scope>
   ```

   The range ends at the base branch, not at `HEAD`: the question is what landed on the base since the stamp, and the commits of this branch are not that. When neither names a path, stop and ask the human for the scope. Never run the command without a path: it would list every commit since the stamp.
3. Empty output: accept the reconciliation as it is. That is the common case.
4. Non-empty output: run `reconcile` in revalidation mode, with the identifier and the directory listed below, passing the items whose files appear in the log. A closed `D-n` does not reopen, unless the delta contradicts it. Then `reconcile` raises its deliberation gate again, citing the `D-n` and the commit.

**It has none.** The item was written by hand, or before the project adopted rastro. Run `reconcile` in full:

- intent: `<workspace>/<id>/design-doc.md`, of type `design doc`, or `root cause` for a bug that has no design doc
- declared scope: the modules, repositories and paths of the item
- identifier: `<id>`
- directory: `<workspace>/<id>/`, where `reconcile` writes `reconciliation.md`

The gate belongs to `reconcile`. Never write the plan before every `D-n` carries `Decided (<YYYY-MM-DD>):`. "Approved as is" closes only the decisions whose executor is the agent. A decision with a human executor stays open until the human says whether, when and where it runs.

After the gate, write `## Reconciliation` where this stage looked for it, on the parent or on the item itself, with `write_section`: tables only, in the form `${CLAUDE_PLUGIN_ROOT}/templates/work-item.md` gives, plus the human-execution block of each `D-n` with a human executor, never a workspace path.

- With `tracker: local`, create the implementation branch first, named as `### Branch and commits` says. Then write the section into the holder's file, and commit that file alone as the first commit of the branch.
- With `tracker: none`, it does not go to the item: `deliver` puts the reconciliation in the PR description.

## Stage 3 — PLAN

With `superpowers:writing-plans`, follow that skill. Without it, fill `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`. Either way, five bindings apply.

### The Spec field

The plan header points at the reconciliation, never at the raw design doc:

```markdown
- **Spec:** `<workspace>/<id>/reconciliation.md`
```

The Spec is what every subagent opens when it needs the why. The raw design doc still holds slices already delivered, wrong error contracts and internal contradictions. The reconciliation is the only document that went through the code and through the human gate.

### The Global Constraints block

The `## Global Constraints` block reaches the reviewer of each task verbatim. What is not in it is not checked. It is the highest-leverage part of the plan.

- **Rules by ID.** Each rule ID from `architecture.rules` that this plan touches, with why. One line gives the resolved location of `architecture.rules`, such as `AGENTS.md#non-negotiable-rules`, so the reviewer can open the text there. The rule text is never copied.
- **Delivery conventions.** The branch format and the commit format, repeated here for the reviewer.
- **Applicable golden paths.** Only the files of `architecture.golden_paths` this plan uses, each with why.
- **Relevant state machines.** Each entity of `domain.stateful_entities` the plan touches: states, allowed transitions, and the `file:line` that defines them.
- **Code-flow boundaries.** Only the `new` and `changes` items of the code flow that survived the reconciliation.
- **Decisions of this item.** Each `D-n` and each `DT-nn` that still binds the plan.

An inflated block dilutes the reviewer's attention. Leave out what this plan does not use.

### Test scenarios in each task

Every task carries `### Expected test scenarios` before its steps, as Given/When/Then. The human writes them, or this stage writes them under human review. The agent derives the tests from the scenarios, and only then implements. A task without scenarios cannot execute and goes back to the plan gate.

The invariants role feeds the scenarios. Each task also keeps its **Files** block (paths with lines, and the test file), its **Interfaces** block (what it consumes and produces), and steps of 2 to 5 minutes in the cycle: write the test, see it fail, implement, see it pass, commit.

### Where the plan lives

The plan lives in `<workspace>/<id>/plan.md`. It is not versioned: it feeds execution and is not durable knowledge of the codebase. The repository's docs gain only what outlives the item: an ADR, a pattern, a golden path.

What lasts goes to the PR description, and `deliver` puts it there: the whole plan in a collapsed block when the code host supports it, plus the divergences and the decisions of the reconciliation.

### Human execution steps

A `D-n` whose executor is a human becomes a task of its own, marked `[HUMAN]` and blocking, never a note at the end. Use the `[HUMAN]` task shape of the plan template: executor, literal artifact, environments one by one, when, rollback, verification, and the tasks it blocks.

Read the six fields from the human-execution block of that `D-n` in the holder's `## Reconciliation`: executor, environments, when, rollback, verification and the artifact in its fenced block. With `tracker: none`, read them from `reconciliation.md`. Never rebuild a field from the decisions table, from memory or from the design doc. When the block is missing, or its artifact is, stop and report: the reviewed artifact did not reach the item, and only the reconciliation gate can restore it.

- Never tick a box by inference. Only the human's explicit confirmation closes it.
- Never start a blocked task while its boxes are open. When the human orders to go on anyway, record that order in the plan; `deliver` carries it to the PR.
- Never rewrite the artifact. It was reviewed at the reconciliation gate, and a rewritten artifact is one nobody reviewed.

## Stage 4 — EXECUTION

Execution starts only after the human approved the plan at the gate below.

### Execution mode

Use `superpowers:subagent-driven-development` when any of these holds:

- the parent's stack has 2 or more PRs, that is, `<n>` in `PR <k> of <n>` is 2 or more. An item with no parent is a stack of one;
- the plan has 6 or more tasks;
- the plan touches 2 or more modules of `architecture.modules`;
- the plan includes a migration.

Otherwise, inline execution. Without superpowers, inline execution is the only mode, whatever the criterion says.

Announce the mode and the criterion that set it. The human may override it at the gate.

**Gate — plan for <id>: execute it as announced?** Class: fork. State:

| | |
|---|---|
| Tasks | <n>, of which <k> are `[HUMAN]` |
| PRs in the parent's stack | <n> |
| Modules touched | <names> |
| Migration | <yes or no> |
| Mode | <subagents or inline>, because <criterion> |

Ask with the structured question tool, recommended option first: execute as announced, switch the mode, or adjust the plan. Without that tool, end the turn with the question.

### Inline execution

Run the tasks one at a time, in plan order:

1. Read the task's scenarios. No scenarios: back to the plan gate.
2. Write the failing test for one scenario, run it, and see it fail for the expected reason.
3. Implement the smallest change that makes it pass, and run it again.
4. Repeat for each scenario of the task.
5. Commit with explicit paths, following the convention.
6. Tick the task in `plan.md`.
7. At a `[HUMAN]` task, stop and ask the human. Never start a task it blocks.

### Branch and commits

Whoever executes the task commits it: the subagent, or this skill inline. `deliver` audits the commits later and does not write them.

The commit convention lives in the AGENTS.md block, which reaches every subagent as project instruction. The Global Constraints repeat it for the reviewer, who receives only that block. Confirm both copies before executing.

- One branch per PR, named by `conventions.branch` with the id of the item the PR delivers and a slug in `project.languages.machine`.
- A stacked PR branches from the previous PR's branch and targets it, never the base branch.
- Every commit follows `conventions.commit`, with a body that says why and cites the `DT-nn` or `D-n` it implements. When `conventions.co_author_trailer` is `true`, every commit carries the trailer naming the real model of the session.
- Domain identifiers are never translated.
- With squash merge, the PR title becomes the commit on the base branch, and no local hook validates it. That title belongs to `deliver`.

### Failing tests

A red test is a diagnosis before it is a fix. Before editing any file, write the `VERDICT` block of `## Failing tests` in the AGENTS.md block. When the wrong artifact is the design doc, stop and bring it to the human: a design doc is not fixed during execution.

### Discovered-constraint gate

Execution finds what the plan did not know: a constraint of a tool, a framework or a database that breaks a premise. That is a gate, not a footnote, because the path chosen changes what enters the PR.

Raise it when any of these holds:

- the premise that falls is written in the design doc, in a `DT-nn`, or in a closed `D-n`;
- the workaround changes global configuration, rollback semantics or migration order;
- the alternatives have different operational consequences for whoever runs production.

**Gate — <the constraint in one line>: which path do I take?** Class: fork. State:

| | |
|---|---|
| Premise that falls | <`DT-nn`, `D-n` or plan task> — <what it assumed> |
| Evidence | <`file:line`, error name, or doc and version> |
| Affected scope | <files, migrations, configuration> |
| Already ruled out | <what was tried, and why it does not serve> |

Then ask with the structured question tool: one option per real path, each with its operational consequence in one line, plus "another approach". Without that tool, end the turn with the question.

Never turn this gate into a paragraph. Constraint, alternatives, consequences and question in ten lines of prose make the human reread to find the decision. `Already ruled out` keeps the human from proposing what was already tried.

A subagent never raises this gate. The subagent that meets the constraint fills the table as text, ends its task without working around the constraint, and the main session raises the gate. A workaround chosen inside a subagent is a production decision taken without the operating context.

### Verification before any claim of done

Run the configured commands and paste their output literally: `verify.lint`, `verify.typecheck`, `verify.unit`. Run `verify.integration` when the change touches a path that matches `verify.integration_when`, typically repositories, migrations and transaction boundaries. A key left empty is reported as not configured, never as passed.

The coverage figure comes from the output of `verify.unit` when it prints one. Every number that reaches the PR description, a review note or a commit is the same number, taken on the same revision. A number copied from an earlier run drifts between those three places.

Coverage is not evidence of behavior. A mock that returns a complete fixture hides code that wipes a field. A guard written on the wrong field passes a full suite. When the change touches an integration with an external system, say in the report that a manual test is missing and what it must exercise.

### Preserve the rulings

Preserve rulings before deleting the workspace. Subagent execution keeps a workspace with a ledger of the controller's judgment calls: parked findings, rulings, deferred minors. Before deleting that workspace:

1. Extract every ledger line that carries `Ruling:`, `parked` or `minor (deferred)` into `<workspace>/<id>/rulings.md`.
2. Edit the file into readable prose: one line per item, with `file:line` when there is one.
3. Only then delete the subagent workspace.

Do not commit `rulings.md`. It becomes the agent rulings and recorded debt sections of the PR description. Deleted before that, a conscious decision looks to the reviewer like an oversight.

## Handoff

When every task is done and verification is green, print this block, then stop:

```
READY FOR deliver — <id>

Branch: <branch>   target: <base branch, or the previous PR's branch>
Commits: <n>   Position in the stack: PR <k> of <n>

Workspace <workspace>/<id>/, gitignored, for deliver to transpose:
- design-doc.md: frozen copy, version <v>, <date>; only the link goes to the PR
- reconciliation.md: divergences and decided D-n, for the PR sections
- plan.md: the executed plan, for the collapsed block
- rulings.md: agent rulings, for their section; absent without subagents

Verification, on this revision:
- lint: <output>   type check: <output>
- <n> suites, <n> tests, coverage <x>
- manual test pending: <no, or yes and what>

Pending [HUMAN] tasks: <none, or task and environment>
Decisions to cite: <D-1, DT-03, ...>
Risks to record: <...>
```

The next stage is `deliver`, at `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md`. It runs when the human asks for it: this skill does not move on by itself.

## What this skill does NOT do

| Not this skill | Who does it |
|---|---|
| Write the PR title and description, open or stack the PR | `deliver` |
| Review the code it produced | the review port, and a human always |
| Measure the impact of a contract on other repositories | the human, on request |
| Write or update the design doc | the human and `design-doc`; this skill only freezes a copy |
| Decide a `D-n` | the human, at the reconciliation gate |
| Create items | `breakdown` |
| Merge, roll out, flip a flag or deploy | the human |
