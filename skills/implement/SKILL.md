---
name: implement
description: Implements one work item end to end, from its id. It reads the item and its real parent, freezes a copy of the design doc the item cites, inherits or runs the reconciliation of that design doc against the code, writes a plan with test scenarios per task, and executes it until the branch has verified commits. Use when the request is "implement <id>", "code this item", "start the PR for <id>", or any change that already has a work item. Do NOT use without an item: an unshaped request goes to design-doc and a request with no item goes to breakdown. Do NOT use to open or describe the PR: that is deliver, which this skill hands off to.
---

# implement

**Input:** the id of the item to implement: a subtask, or a task or bug that has no subtasks. Never an item that has subtasks. With `tracker: none`, the input is the item file in the workspace, `<workspace>/<slug>/item.md`.

**Output:** a branch with verified commits, plus the workspace `<workspace>/<id>/`: the frozen copy of the design doc, `reconciliation.md`, `plan.md` and `rulings.md`, after subagent execution or a continuous run. The workspace is gitignored. `deliver` transposes it into the PR description.

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
- The template `${CLAUDE_PLUGIN_ROOT}/templates/golden-path.md`, when the item creates a golden path.
- Team profile, optional: `.rastro/profiles/implement.md`. Its `## Additional checks` section lists extra checks, each with the stage where it runs and whether it is a gate or an observation. Run each one at its stage. A check marked as a gate that fails makes the recommended option of its gate "adjust", so that gate stops even in a continuous run. Environment preparation before integration tests, and title aliases of the team's older design docs, belong there.
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

1. Read the item with `read_item`: title, description, children, and the real parent. Read the parent with `read_item` too. Then read the execution mode, as `## Execution mode` in the AGENTS.md block says (template: `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`), for a project whose AGENTS.md block predates the section: the top item is the parent, or the item itself when it has no parent.
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

With `superpowers:writing-plans`, follow that skill, except its execution handoff: this skill's plan gate replaces it. Without it, fill `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`. Either way, five bindings apply.

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
- **Applicable golden paths.** Only the golden paths of the `architecture.golden_paths` folder this plan uses, each with why.
- **Golden paths this item creates or evolves.** Each `no golden path`, `extends` and decided `contradicts` row of the reconciliation: the golden path, the change (created, extended or changed), the task that writes it, and how it is verified, `review` or the command. That task is the task of the instance, never a task of its own. For a type in `architecture.boundary_types`, the line adds that the task writes `## Security` from the reference the template names and a real-system scenario in `## Verification`.
- **Relevant state machines.** Each entity of `domain.stateful_entities` the plan touches: states, allowed transitions, and the `file:line` that defines them.
- **Code-flow boundaries.** Only the `new` and `changes` items of the code flow that survived the reconciliation.
- **Decisions of this item.** Each `D-n` and each `DT-nn` that still binds the plan.

An inflated block dilutes the reviewer's attention. Leave out what this plan does not use.

### Test scenarios in each task

Every task carries `### Expected test scenarios` before its steps, as Given/When/Then. The human writes them, or this stage writes them, reviewed at the plan gate by the person or, in a continuous run, by the choice made at the start. The agent derives the tests from the scenarios, and only then implements. A task without scenarios cannot execute and goes back to the plan gate.

The invariants role feeds the scenarios. Each task also keeps its **Files** block (paths with lines, and the test file), its **Interfaces** block (what it consumes and produces), and steps of 2 to 5 minutes in the cycle: write the test, see it fail, implement, see it pass, commit.

### Footprint and tier of each task

Each task carries a footprint and a tier under its title, in the shape of the plan template: `Footprint: diff <small | medium | large>, read <small | medium | large>` and `Tier: <light | standard | deep>`. The diff bucket is how much the task changes; the read bucket is how much of the codebase the agent has to read to change it safely. The tier comes from the table in `.rastro/CALIBRATION.md`, where the project records what each bucket means in lines and files, and which model runs each tier. When `.rastro/CALIBRATION.md` is absent or its tier table is unfilled, every task is `standard`. When that table says "not measured", every task is `standard` and the plan says the tiers are not calibrated. The footprint is a planning aid inside `plan.md`: never write it to a tracker item, because items carry no estimate. After a task is committed, record its real size next to the prediction, `Actual: <n> lines in <k> files`, from the diff of its commit. The read scope has no recorded actual; the person compares it.

### Where the plan lives

The plan lives in `<workspace>/<id>/plan.md`. It is not versioned: it feeds execution and is not durable knowledge of the codebase. The repository's docs gain only what outlives the item: an ADR, a pattern, a golden path.

What lasts goes to the PR description, and `deliver` puts it there: the whole plan in a collapsed block when the code host supports it, plus the divergences and the decisions of the reconciliation.

### Human execution steps

A `D-n` whose executor is a human becomes a task of its own, marked `[HUMAN]` and blocking, never a note at the end. Use the `[HUMAN]` task shape of the plan template: executor, literal artifact, environments one by one, when, rollback, verification, and the tasks it blocks.

Read the six fields from the human-execution block of that `D-n` in the holder's `## Reconciliation`: executor, environments, when, rollback, verification and the artifact in its fenced block. With `tracker: none`, read them from `reconciliation.md`. Never rebuild a field from the decisions table, from memory or from the design doc. When the block is missing, or its artifact is, stop and report: the reviewed artifact did not reach the item, and only the reconciliation gate can restore it.

- Never tick a box by inference. Only the human's explicit confirmation closes it.
- Never start a blocked task while its boxes are open. When the human orders to go on anyway, record that order in the plan; `deliver` carries it to the PR.
- In a continuous run, a `[HUMAN]` task that blocks no remaining task stays open, and execution goes on; `deliver` reports it under `Pending human execution`. A `[HUMAN]` task that blocks a remaining task stops execution there, as in a run that stops at every gate.
- Never rewrite the artifact. It was reviewed at the reconciliation gate, and a rewritten artifact is one nobody reviewed.

## Stage 4 — EXECUTION

Execution starts only after the plan is approved at the gate below, by the person or, in a continuous run, by the choice made at the start.

### Inline or subagents

Use `superpowers:subagent-driven-development` when any of these holds:

- the parent's stack has 2 or more PRs, that is, `<n>` in `PR <k> of <n>` is 2 or more. An item with no parent is a stack of one;
- the plan has 6 or more tasks;
- the plan touches 2 or more modules of `architecture.modules`;
- the plan includes a migration.

Otherwise, inline execution. Without superpowers, inline execution is the only option, whatever the criterion says.

Announce inline or subagent execution and the criterion that set it. The human may override it at the gate.

When subagents run, each task's implementer and reviewer use the model its tier maps to in `.rastro/CALIBRATION.md`. A task with no mapping uses the session's own model.

The handoff of this skill replaces the branch-finishing step of `superpowers:subagent-driven-development` and `superpowers:executing-plans`. In a continuous run, never enter `superpowers:finishing-a-development-branch`: invoke `deliver`.

**Gate — plan for <id>: execute it as announced?** Class: fork. Mode: confirmation. State:

| | |
|---|---|
| Tasks | <n>, of which <k> are `[HUMAN]` |
| PRs in the parent's stack | <n> |
| Modules touched | <names> |
| Migration | <yes or no> |
| Execution | <subagents or inline>, because <criterion> |

Ask with the structured question tool, recommended option first: execute as announced, switch between inline and subagents, or adjust the plan. Without that tool, end the turn with the question.

### Inline execution

Run the tasks one at a time, in plan order:

1. Read the task's scenarios. No scenarios: back to the plan gate.
2. Write the failing test for one scenario, run it, and see it fail for the expected reason.
3. Implement the smallest change that makes it pass, and run it again.
4. Repeat for each scenario of the task.
5. For a task that wrote or extended a golden path, raise the golden-path review gate of `### Writing a golden path` before the commit.
6. Commit with explicit paths, following the convention.
7. Tick the task in `plan.md`.
8. At a `[HUMAN]` task, stop and ask the human, unless `### Human execution steps` lets a continuous run go on. Never start a task it blocks.

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

### Writing a golden path

The task that delivers the first instance of a type writes its golden path. The golden path lands in the same task as its instance:

- Copy `${CLAUDE_PLUGIN_ROOT}/templates/golden-path.md` to a file named `<type>.md` in the `architecture.golden_paths` folder, `docs/golden-paths/` when the key is absent or empty. Create the folder when it is absent.
- When the design doc recorded a `DT-nn` for this first instance, the draft starts from that `DT-nn`'s decisions and `## Security` from its threats. Fill the rest from the code just written. `instances` holds the `file:line` of the instance and never a copy of its code. Every decision carries its `Why:` and its `Revisit if:`. A decision with no reason is a circumstance of the first instance, not a decision: leave it out.
- Set `status: current`, `version: 1.0.0` and `verified_by: review`. An automated check written against one instance freezes its accidents. It comes when a later instance confirms the golden path.
- Fill `## Security` for every type: the threats considered, the control for each and how it is verified, or "none identified" with the reason. A type in `architecture.boundary_types`, or one that its `DT-nn` says crosses a trust boundary (the same `DT-nn` that adds the layer), is a boundary type, and "none identified" does not serve it: draw its threats from the public reference that `${CLAUDE_PLUGIN_ROOT}/templates/golden-path.md` names, one line per threat with its control and how the control is verified, and give `## Verification` at least one scenario against the real system, without mocks, in the shape the template gives.
- When the type is not yet in `architecture.layers`, the same commit adds it to `.rastro/config.yml`, as the decided `DT-nn` says, and to `architecture.boundary_types` when that `DT-nn` says the type crosses a trust boundary.

An `extends` raises the minor version, adds the instance to `instances` and a row to `## History`. A `contradicts` decided for the golden path raises the major version, moves every instance that no longer follows it to `## Known debt`, and adds a row to `## History`. A `follows` adds the instance to `instances` when it is absent, in the same commit as the instance, with no version change and no review gate.

A golden path moves from `verified_by: review` to `automated: <command>` only in a task that writes the check, never in the task of its first instance. Before the change, run the command twice and paste both outputs in the task report: on the branch, where it exits 0, and with one instance edited to break one decision, where it exits non-zero and prints what the template's `## Verification` asks. Undo that edit. The same commit raises the minor version, adds a row to `## History`, rewrites `## Verification` to name the command, and makes `verify.lint` run the command, directly or through a script, so CI runs it too. This change adds no decision, so it raises no review gate.

The person implementing the task defines the golden path with the agent, at the golden-path review gate:

**Gate — golden path `<id>` <version> drafted: do these decisions hold?** Class: deliberation. Mode: decision. State, a two-column table:

| | |
|---|---|
| Golden path | `<id>` <version>, new or extended |
| Instance | `<file:line>` |
| Boundary type | <no, or yes: <n> threats, <n> real-system scenarios> |

Then the deliberation table, one row per decision the draft adds or changes, plus the quick-exit row:

| Decision | Why | Revisit if | Instance |
|---|---|---|---|
| <decision> | <the reason> | <the condition> | `<file:line>` |
| all hold as drafted | | | |

For a type in `architecture.boundary_types`, or one that its `DT-nn` says crosses a trust boundary, a second deliberation table follows, one row per threat the draft adds or changes in `## Security`, plus its own quick-exit row:

| Threat | Control | Verified by |
|---|---|---|
| <threat, with its item in the reference> | <the control> | <the check, the test or the real-system scenario> |
| all hold as drafted | | |

The person confirms, rewrites or drops each decision and each threat, and may add a threat the draft missed. The file keeps only what the person confirmed, rewrote or added. A boundary type keeps at least one threat. The sequence depends on inline or subagent execution:

- Inline: draft the golden path, raise the review gate, then commit the instance and the confirmed golden path together.
- With subagents: the subagent commits the instance with the drafted golden path and returns the review-gate rows as text, and never raises the gate, so the main session raises the review gate before it dispatches the next task. The person's answers land in one more commit of the same task that touches only the golden path.

### Discovered-constraint gate

Execution finds what the plan did not know: a constraint of a tool, a framework or a database that breaks a premise. That is a gate, not a footnote, because the path chosen changes what enters the PR.

Raise it when any of these holds:

- the premise that falls is written in the design doc, in a `DT-nn`, or in a closed `D-n`;
- the workaround changes global configuration, rollback semantics or migration order;
- the alternatives have different operational consequences for whoever runs production.

**Gate — <the constraint in one line>: which path do I take?** Class: fork. Mode: decision. State:

| | |
|---|---|
| Premise that falls | <`DT-nn`, `D-n` or plan task> — <what it assumed> |
| Evidence | <`file:line`, error name, or doc and version> |
| Affected scope | <files, migrations, configuration> |
| Already ruled out | <what was tried, and why it does not serve> |

Then ask with the structured question tool: one option per real path, each with its operational consequence in one line, plus "another approach". Without that tool, end the turn with the question.

Never turn this gate into a paragraph. Constraint, alternatives, consequences and question in ten lines of prose make the human reread to find the decision. `Already ruled out` keeps the human from proposing what was already tried.

A subagent never raises this gate. The subagent that meets the constraint fills the table as text, ends its task without working around the constraint, and the main session raises the gate. A workaround chosen inside a subagent is a production decision taken without the operating context.

### Golden-path gate

Execution can find what the reconciliation did not: the code this task needs breaks a decision or a checklist item of a `current` golden path. That is a gate, never a silent choice: otherwise the code that lands first becomes the precedent by default.

**Gate — <component> contradicts golden path `<id>`: which one changes?** Class: fork. Mode: decision. State:

| | |
|---|---|
| Golden path | `<id>` <version>, the decision or item at `<file:line>` |
| What the code needs | <the behavior, with the `file:line` that requires it> |
| Instances that follow it | <count>, the first at `<file:line>` |
| Already ruled out | <what was tried, and why it does not serve> |

Ask with the structured question tool: change the code to follow the golden path, or evolve the golden path to a new major version, as `### Writing a golden path` says. Without that tool, end the turn with the question. A subagent never raises this gate: it fills the table as text and ends its task.

### Verification before any claim of done

Run the configured commands and paste their output literally: `verify.lint`, `verify.typecheck`, `verify.unit`. Run `verify.integration` when the change touches a path that matches `verify.integration_when`, typically repositories, migrations and transaction boundaries. A key left empty is reported as not configured, never as passed.

The coverage figure comes from the output of `verify.unit` when it prints one. Every number that reaches the PR description, a review note or a commit is the same number, taken on the same revision. A number copied from an earlier run drifts between those three places.

Coverage is not evidence of behavior. A mock that returns a complete fixture hides code that wipes a field. A guard written on the wrong field passes a full suite. When the change touches an integration with an external system, say in the report that a manual test is missing and what it must exercise. When the type of a component has a golden path with real-system scenarios, the report lists them as the manual test to run.

### Preserve the rulings

Preserve rulings before deleting the workspace. Subagent execution keeps a workspace with a ledger of the controller's judgment calls: parked findings, rulings, deferred minors. Before deleting that workspace:

1. Append every ledger line that carries `Ruling:`, `parked` or `minor (deferred)` to `<workspace>/<id>/rulings.md`. Never overwrite the file: a continuous run may already have written its confirmations there.
2. Edit the lines you appended into readable prose: one line per item, with `file:line` when there is one. Leave each `- Continuous run,` line as it is: `deliver` reads it by that prefix.
3. Only then delete the subagent workspace.

Do not commit `rulings.md`. It becomes the agent rulings and recorded debt sections of the PR description. Deleted before that, a conscious decision looks to the reviewer like an oversight.

## Handoff

When every task is done and verification is green, print this block:

```
READY FOR deliver — <id>

Branch: <branch>   target: <base branch, or the previous PR's branch>
Commits: <n>   Position in the stack: PR <k> of <n>

Workspace <workspace>/<id>/, gitignored, for deliver to transpose:
- design-doc.md: frozen copy, version <v>, <date>; only the link goes to the PR
- reconciliation.md: divergences and decided D-n, for the PR sections
- plan.md: the executed plan, for the collapsed block
- rulings.md: agent rulings and continuous-run confirmations, for their section; absent without either

Verification, on this revision:
- lint: <output>   type check: <output>
- <n> suites, <n> tests, coverage <x>
- manual test pending: <no, or yes and what>

Pending [HUMAN] tasks: <none, or task and environment>
Decisions to cite: <D-1, DT-03, ...>
Risks to record: <...>
```

The next stage is `deliver`, at `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md`. In a run that stops at every gate, it runs when the human asks for it: this skill does not move on by itself. In a continuous run, invoke it with the id.

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
