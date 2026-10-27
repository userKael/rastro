---
name: breakdown
description: Entry skill of the rastro flow. Turns an intent (a published design doc, an observed bug, or a well-formed change request) into work items through the tracker port. The result is a bug, a task, or a story with subtasks, each subtask anchored in file:line, with the reconciliation embedded in the top item under the Reconciliation section. Use when the request is "start X", "I have a design doc to break down", "I found a bug and want an item", or "split this story into subtasks". Do NOT use when an item already exists and the request is to implement it; that is implement. Do NOT use for a shapeless request; that goes to design-doc. Ends by handing over the created item ids. It creates no implementation branch, writes no code and opens no implementation PR.
---

# breakdown

Entry skill of the flow. It turns an intent into work items that `implement` can pick up.

**Input:** an intent in any form: the reference of a published design doc, an observed bug, or one sentence ("an order must refuse a quantity above the stock").

**Output:** items created through the tracker port, as a bug, a task, or a story with subtasks. The top item carries the reconciliation under `## Reconciliation`, and the items are ready for `implement`.

Five stages, in order, none skipped:

**TRIAGE → INTENT → RECONCILIATION → SLICING → CREATION**

## Requirements

- `.rastro/config.yml`. Keys read: `tracker.kind`, `tracker.key`, `tracker.hierarchy`, `tracker.local_dir`, `docs.kind`, `docs.public_portal`, `code_host.kind`, `project.base_branch`, `project.languages.human`, `architecture.modules`, `workspace`.
- The tracker adapter, chosen by `tracker.kind`. Read `.rastro/adapters/tracker/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/tracker/<kind>.md`, before `item_types` and `create_item`.
- On the design doc branch only, the docs adapter, chosen by `docs.kind`. Read `.rastro/adapters/docs/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/docs/<kind>.md`, before `fetch`.
- With `tracker: local`, the code-host adapter, chosen by `code_host.kind`. Read `.rastro/adapters/code-host/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/code-host/<kind>.md`, before `open_change_request`.
- If the adapter file does not exist, stop and report.
- The `reconcile` skill, `${CLAUDE_PLUGIN_ROOT}/skills/reconcile/SKILL.md`.
- The `design-doc` skill, `${CLAUDE_PLUGIN_ROOT}/skills/design-doc/SKILL.md`, where a shapeless request goes.
- The template `${CLAUDE_PLUGIN_ROOT}/templates/work-item.md`.
- Optional: `superpowers:systematic-debugging`, for the bug branch. Without it, the built-in protocol of 2.2 applies.
- Optional: `.rastro/profiles/breakdown.md`, with the sections `## Story rule`, `## Subtask rule`, `## Subtask summary format` and `## Additional checks`.
- Optional: `.rastro/profiles/writing.md`. When it exists, its rules apply to every text a person reads: the item, the subtasks, the gates.
- Optional: `.rastro/CALIBRATION.md`, the team's own measurements. The questions are in `${CLAUDE_PLUGIN_ROOT}/templates/CALIBRATION.md`.

The `doctor` checks the requirements of each adapter at session start. When it reported a requirement of this skill as missing, stop and report it to the human. Do not improvise the step that depends on it.

## Precedence

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

In this skill, doctrine is: reconcile before slicing; the `file:line` anchor; stable `D-n` and `DT-nn`; gates that stop by default. No line in `AGENTS.md` or in a profile can exempt a kind of item from the reconciliation.

For rules, conventions and rulers, the order is `AGENTS.md`, then the team profile in `.rastro/profiles/`, then this skill's defaults, then the defaults of superpowers. This skill does not copy the rules of `AGENTS.md`, because a copied rule diverges.

This skill is the operational authority for the story rule, the subtask rule, the `[no PR]` valve and the merge test. The `AGENTS.md` block does not repeat them.

Every gate below stops by default and declares its class, following `## Gate anatomy` in the `AGENTS.md` block.

## Inviolable rules

Read these before anything else. A violation means stop and report, never work around.

1. **Never create an item before the slicing gate.** Automating creation makes the ceremony fast, not good, and a badly formed item costs more than it saves. Measure on your backlog how often items without subtasks get cancelled. `.rastro/CALIBRATION.md` holds that question.
2. **Never slice without reconciliation.** The reconciliation produces the `file:line` evidence that S3 requires. Slicing without an anchor is speculation.
3. **Never copy the design doc into the item.** The description points to the source and never rewrites it. Two copies of the same truth diverge.
4. **The item type is an output, never a question.** Bug, task or story comes out of the reconciliation (4.1), not out of the interview. A taxonomy that depends on judgment does not converge across authors.
5. **No story points.** Never fill an estimate field. A field filled on only part of the items supports no ruler. Measure on your backlog before trusting one.
6. **Never skip the reconciliation because `design-doc` wrote the design doc.** That design doc is grounded in vocabulary, not in decisions. It can still be wrong, and finding that is the job of the reconciliation. An empty reconciliation looks like success.
7. **Never inherit the candidate slicing of a design doc as authority.** It is a seed, and its own template says so. The cut comes from the reconciliation and the merge test (4.7).

## Step 1 — TRIAGE

Four branches. Choose by observation, not by an open question.

| Signal in the input | Branch | Go to |
|---|---|---|
| A reference to a published design doc | design doc | 2.1 |
| Observed behavior contradicts a pre-existing contract: a test, a design doc, an ADR, a golden path, a doc | bug | 2.2 |
| A nameable request, with a clear object and a clear contract | interview | 2.3 |
| A shapeless request ("I want to rethink how stock reservation works") | out of this skill | stop, see below |

### The shapeless branch

When the request has no nameable object and no contract, the gap is design, not information. Stop and send it back, in `project.languages.human`:

```
This has no shape to become an item yet: I cannot name the artifact or the
contract that changes. The path is design-doc, which writes the design doc in
the team's format, grounds its vocabulary in the code and publishes it.
Publishing is not approving: take it to the team, discuss it, and call me
again through "I have a design doc".
```

The skill is `${CLAUDE_PLUGIN_ROOT}/skills/design-doc/SKILL.md`. Do not supply the design with the interview. Three questions do not replace a design process, and slicing a badly formed intent wastes the reconciliation.

### Anchor test

Before going down any branch, ask: does the flow you will change already exist, so it can be read? With no existing flow to change, the work has no boundary. When the test fails, the branch is shapeless, even when a design doc exists.

### Branch declaration: not a question

Announce the branch in one line, with the `file:line` evidence, and accept a one-word correction. A question asked every time becomes noise and gets answered on autopilot. A visible declaration is a gate without ceremony.

```
Branch: interview (well-formed request: artifact and contract are nameable;
        the flow exists at src/orders/place-order.service.ts:48)
No design doc will be written.
  "design-doc" -> write a design doc anyway
  "shape"      -> it has no shape yet
```

Not every change needs a design doc. The flexibility lives here, correctable in one word.

## Step 2 — INTENT

Every branch converges on one file: `<workspace>/breakdown-<slug>/intent.md`. The workspace is gitignored, and nothing in it is ever committed. `<slug>` is a short kebab-case name derived from the request, such as `order-quantity-guard`. No item id exists yet.

Every intent record opens with a provenance header: type, origin, version when the source has one, and capture date.

### 2.1 Design doc branch

Read `.rastro/adapters/docs/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/docs/<kind>.md`, before `fetch`. Materialize the design doc as markdown, keeping its mermaid blocks, under this header:

```markdown
---
type: design doc
origin: <reference returned by fetch>
version: <version returned by fetch>
captured_on: <YYYY-MM-DD>
---
```

Do not edit the content. Every divergence goes to the reconciliation, also when `design-doc` wrote the design doc.

Collapsed content is content. Materialize everything, expanded. Collapse tells a person what to read first; it never tells the item what to cover. An intent without its collapsed parts produces a reconciliation that finds divergences where there was only a capture cut.

An out-of-scope line that links another design doc is a separate intent. The split rule of `design-doc` declares document boundaries there, and only there. That part is not the scope of this item and does not enter Not sized. Record the link under Sources and go on. Materializing the other design doc too would fuse two items that the design separated on purpose.

A hole in the `DT-nn` sequence is not a finding. It marks a decision that left for another document, and `design-doc` keeps the hole on purpose.

### 2.2 Bug branch

The root cause is not produced here. Use `superpowers:systematic-debugging` when it is installed, and take its output. Without it, run this built-in protocol and write down each step:

1. **Reproduce.** The shortest sequence that shows the behavior, with its output.
2. **Hypothesis.** One cause, stated so that evidence can refute it.
3. **Evidence.** What confirms or refutes the hypothesis. Back to step 2 when it is refuted.
4. **Root cause.** The `file:line` of the cause.

Record:

```markdown
---
type: root cause
origin: <superpowers:systematic-debugging, or the built-in protocol>
captured_on: <YYYY-MM-DD>
---

## Violated contract
<where the expected behavior is written: test, design doc, ADR, golden path, file:line>

## Observed behavior
<what happens, with reproducible evidence>

## Root cause
<file:line>
```

If the violated contract cannot be pointed to, it is not a bug. It is a change of behavior: go to 2.3.

### 2.3 Interview branch

Three questions, one at a time, in this order. Do not add questions: the deep inquiry belongs to the reconciliation, not to the interview.

1. **What changes?** The artifact and the behavior: an endpoint, a field, an event, a guard, a job.
2. **Who observes?** Who confirms it is done: a user, an operator, a developer who consumes an API, the CI, a dashboard, an event consumer. "The team" is not an answer.
3. **What contract exists today?** What the code does on that path today, and where that is written, if it is.

Record:

```markdown
---
type: interview
origin: conversation with <person>
captured_on: <YYYY-MM-DD>
---

## What changes
## Who observes
## Current contract
```

When the answer to question 2 is still generic after one re-ask, the request probably belongs to the shapeless branch. Say so and stop.

## Step 3 — RECONCILIATION

Invoke `${CLAUDE_PLUGIN_ROOT}/skills/reconcile/SKILL.md` with:

- **intent:** `<workspace>/breakdown-<slug>/intent.md`
- **declared scope:** the modules from `architecture.modules`, the repositories and the candidate paths. The declared scope becomes the path filter of the delta revalidation later, so a loose scope here costs later.
- **identifier:** `<slug>`, because no item id exists yet.
- **workspace directory:** `<workspace>/breakdown-<slug>/`. `reconcile` writes `reconciliation.md` there.

rastro has no impact port. Ask the human which other repositories consume the contracts in scope, and add them to the declared scope.

The deliberation gate on `D-n` belongs to `reconcile`. Do not go on until each `D-n` carries `Decided (<YYYY-MM-DD>):` in `reconciliation.md`.

Record the `<base_branch>@<sha7>` stamp of the reconciliation, where `<base_branch>` is `project.base_branch`. It goes into the item.

## Step 4 — SLICING

Slicing happens after the reconciliation and before any item exists.

### 4.1 The item type is an output

Count the mergeable slices that the reconciliation supports:

| Condition | Type |
|---|---|
| The intent restores a violated pre-existing contract | bug |
| 1 mergeable slice | task, with no subtasks |
| 2 or more mergeable slices | story, with one subtask per slice |

`tracker.hierarchy` names the levels, parent first. With the default `[story, subtask]`, a story holds subtasks. Each level maps to a port type: the parent level is `story` and the child level is `subtask`. The port types are `bug`, `task`, `story` and `subtask`. Any other name in `tracker.hierarchy` is a label for the gate and the summaries, and creation always passes the port type. With a single level, nothing nests: say so at the gate, and create one `task` per slice, each summary carrying its order.

Resolve the tool's name for each type through `item_types` of the tracker adapter before the gate. A substitution the adapter makes, such as a bug created as a task with a label, goes into a note below the gate's state table. It is never silent.

**Triviality escape.** When the reconciliation anchors everything in one file and one slice, the item is a task, or a bug, with no subtask. Skip the story rule and the merge test. The slicing gate still runs, with one row, because no item exists before it. A small item that is understood without subtasks is right, and this skill does not force subtasks on it.

### 4.2 Story rule: H1 to H5

Apply only when the type is story. All five items are required.

| # | Item | Fails when |
|---|---|---|
| H1 | Named observer | the observer is "the team", "we", or absent |
| H2 | Written assertion | no sentence exists that the observer can affirm at the end |
| H3 | Declared source | Sources has no design doc reference and no intent record |
| H4 | Closed scope | the modules, repositories and paths touched are not listed |
| H5 | Slice 1 writable today | slice 1 cannot be written today from a `file:line` |

H1 replaces the product-or-platform classification. The two differ in the observer, not in the rule: for platform work, the observer is a developer, the CI or an event consumer. Do not ask "is this product or platform?". Part of the real stories fits neither; measure on your backlog how many.

H5 is a declared proxy. It does not prove the story fits a sprint. It proves the story is understood well enough to start. A failing H5 means not understood, not necessarily too big. Return the story with what is missing, never with "split it more".

When `reconcile` reported its size signal, count it as an H5 failure and take it to the gate. The threshold lives only in `reconcile`, because a number repeated in two files diverges.

rastro ships no number that says how strictly to apply this rule. Measure on your backlog the share of stories without subtasks and their cancellation rate, and record both in `.rastro/CALIBRATION.md`.

When `.rastro/profiles/breakdown.md` has a `## Story rule` section, it replaces H1 to H5.

### 4.3 Subtask rule: S1 to S4

All four items are required.

| # | Item | Fails when |
|---|---|---|
| S1 | Revertible alone | reverting only this PR would leave the base branch not building or not passing |
| S2 | Artifact and consequence | the artifact is missing, the consequence is missing, or both |
| S3 | Anchor in the code | no `file:line`, symbol, table or migration coming from the reconciliation |
| S4 | Declared order | the subtask states neither its number in the sequence nor what it unblocks |

The summary format is required:

```
PR <N> — <artifact>: <consequence>
```

Summaries that pass:

- `PR 1 — Stock guard: placing an order no longer reserves more copies than inventory holds`
- `PR 2 — Reservation event: inventory publishes an event each time an order reserves copies`

Summaries that fail:

- `catalog-service`: a repository name, with no artifact and no consequence
- `Smoother browsing`: no object
- `Catch up with what the bookstore team agreed`: says neither what nor where

Out of the rule, on purpose: independence, isolated value, demonstrability and estimate. Slice 1 is often a foundation, and a foundation almost never demonstrates anything. INVEST is a story ruler and stays one. A subtask is a decomposition of work.

When `.rastro/profiles/breakdown.md` has a `## Subtask rule` section, it replaces S1 to S4. The `file:line` anchor stays required even then, because it is doctrine: a profile that drops S3 does not drop the anchor. When it has a `## Subtask summary format` section, that format replaces the one above. `.rastro/CALIBRATION.md` asks which format the team already uses.

### 4.4 The `[no PR]` valve

Not every subtask becomes a PR. Discovery, manual validation and alignment with another team exist and are legitimate. Prefix their summary with `[no PR]`. A `[no PR]` subtask is exempt from S1 and S3. S2 and S4 still apply.

When more than half of a story's subtasks carry `[no PR]`, it is not a story. It is a list of process tasks. Take that to the gate.

### 4.5 Public portal subtasks

This applies only when `docs.public_portal` is set. The portal is versioned: a change to it is a diff with its own PR. A portal subtask is therefore a real subtask. S1 and S3 apply, and it never takes `[no PR]`. Exempting it from S3 would drop the anchor where it matters most: which page, and which code rule the page now contradicts.

Each portal line that `reconcile` returns under Not sized becomes one subtask:

```
PR <N> — <portal page>: <what the page will state>
```

- **Anchor (S3):** the portal page and the `file:line` of the code it describes. Both ends, always.
- **Order (S4):** after the slice that changes the behavior. A page that describes code that does not exist yet is born wrong.

When the reconciliation found nothing for the portal, do not invent a doc subtask. Not every change publishes a rule: an index, an internal refactor or a log adjustment changes nothing the portal states.

### 4.6 Additional checks

When `.rastro/profiles/breakdown.md` has a `## Additional checks` section, run each check at the step it names. A check marked as a gate stops at the next gate of this skill. A check marked as an observation becomes a note below the state table of that gate.

### 4.7 Merge test

Before the gate, scan the adjacent pairs `(N, N+1)`, in order:

1. Merged, are they still revertible alone? (S1)
2. Merged, do they still name one artifact and one consequence? (S2)
3. Merged, is the resulting diff still reviewable in one sitting?

Merge when 1 and 2 are yes. Question 3 is the only size criterion, and it can only refuse a merge, never justify a cut. Repeat the scan until no pair passes. The trace of the merges is mandatory at the gate.

## Gate — slicing

Stop. Nothing has been created yet. **Class: fork.** Print the state and the proposal only:

```markdown
**Gate — slicing of <slug> proposed: create the items?**

| | |
|---|---|
| Base | `<base_branch>@<sha7>` |
| Type | <bug / task / story>: <reason in at most four words> |
| Story rule | <5 of 5 / FAILS H<n> / not applicable: task or bug> |
| Merge test | <n> initial slices, <k> final / not applicable: one slice> |
| Merged pairs | <3+4, 6+7 / none> |
| Observer | <observer>: "<assertion in one sentence>" |

| # | Slice | Anchor | Unblocks |
|---|---|---|---|
| 1 | PR 1 — <artifact>: <consequence> | `<file:line>` | <what> |

Nothing has been created yet.
```

A failed rule item becomes one note below the state table, naming the item, such as `H4`, and what is missing. The recommended option then becomes adjust, not create. A type substitution and each gate check from `## Additional checks` also become notes.

Then ask with the structured question tool, recommended option first, without repeating the options in the text above it:

- **Create** (recommended when the story rule passes 5 of 5 or does not apply): creates the items; with `tracker: local`, it also pushes the item branch and opens the item PR. No implementation branch and no code.
- **Adjust the slicing**: the human says what changes, and the gate runs again.
- **Stop**: nothing is created.

Without a structured question tool, end the turn with the question. Create items only after an explicit choice of **Create**.

## Step 5 — CREATION

Read `.rastro/adapters/tracker/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/tracker/<kind>.md`, before `create_item`. The adapter assigns the ids. `tracker.key` is the prefix the adapter uses.

### 5.1 Top item description

Write it from `${CLAUDE_PLUGIN_ROOT}/templates/work-item.md`, in `project.languages.human`. `## Reconciliation` stays literal. A task or a bug with no subtasks gets the same description.

- **Context:** 2 to 4 lines on why the item exists. It points to the source and never repeats the design doc.
- **Observer and assertion:** H1 and H2.
- **Scope:** H4, plus the declared scope of the reconciliation, with the paths of its `exists` and `changes` items. `implement` filters the delta revalidation by this list.
- **Sources:** the design doc reference, version and capture date, marked as the source of truth; the violated contract for a bug; the separate intents found in 2.1; the reconciliation stamp `<base_branch>@<sha7>` and its date.
- **`## Reconciliation`:** the five sections of `reconciliation.md`, as tables.

The `## Reconciliation` section holds tables only, with no free paragraph and no cell above 200 characters. It carries findings and decisions, never design doc content. A huge description and an empty one are both extremes. The target is a short table with `file:line`. Cut a long cell down to its anchor; the full text stays in the workspace.

One exception: each `D-n` with `executor: human` carries its human execution in the item, because `implement` builds its `[HUMAN]` task from the item and never from the workspace. Below the decisions table, write one block per such `D-n`, in the shape of `${CLAUDE_PLUGIN_ROOT}/templates/work-item.md`, with six fields copied from `reconciliation.md`:

- **Executor:** who runs it.
- **Environments:** named one by one, in order.
- **When:** before or after the merge, and of which PR.
- **Rollback:** how to undo it, or "not reversible".
- **Verification:** what proves it ran, in each environment.
- **Artifact:** verbatim, in a fenced block below the block's table. It is exempt from the 200-character budget and is never cut down to an anchor: a cut artifact is one nobody reviewed.

A rollback that is itself a script also goes verbatim in a fenced block. The decisions table keeps one short row per `D-n` and stays within the budget.

Never cite a workspace path anywhere in an item. It is a dead link the next day.

### 5.2 Subtask description

Short. Four fields, nothing else, as the template shows:

- **Unblocks:** S4, what the next slice can do only after this one.
- **Anchor:** S3, the `file:line`, symbol, table or migration.
- **Applicable decisions:** the `D-n` and `DT-nn` that bind this subtask, by identifier.
- **Revert:** S1, what returns to its previous state if this PR alone is reverted.

A `[no PR]` subtask writes `[no PR]` in Anchor and Revert. A subtask never repeats the reconciliation, which lives in the parent.

### 5.3 Links

- Each subtask has the story as its parent, through the parent argument of `create_item`.
- The story has its epic as its parent, when an epic exists.
- Link no PR here. The item-to-PR link belongs to `deliver`, once the PR exists.

### 5.4 By tracker

- **`tracker: local`:** after the gate, follow `create_item` of the adapter. It creates the branch `chore/<id>-<slug>` for the top item, commits the item files with explicit paths, pushes the branch with `git push -u origin chore/<id>-<slug>`, and only then opens a PR through the code-host port, because the code-host adapter opens a PR from a pushed branch and leaves the push to its caller. The human's choice of **Create** authorizes this push, and only this one. The item exists once it is on the base branch, which means after a human merges that PR. With `code_host.kind` set to `none`, commit on the branch, do not push, and say that the merge is manual. This item PR is the only PR this skill opens.
- **`tracker: none`:** the item lives in the conversation and in the workspace, and the reconciliation goes to the PR description later. After creation, copy `<workspace>/breakdown-<slug>/reconciliation.md` to `<workspace>/<item id>/reconciliation.md`, where `<item id>` is the id of the top item, and say so at the continuity gate. `implement` reads it there, which keeps one stamped reading. Say that the work cannot be resumed before a PR exists.
- **Any other tracker:** follow `create_item` and `item_types` of the adapter as written.

## Gate — continuity

**Class: fork.** Print the state, with the created ids linked:

```markdown
**Gate — <id> created: implement <subtask 1 / the item> now?**

| | |
|---|---|
| Created | [<id>](<url>), <type>, <k subtasks / no subtasks> |
| First subtask | <[<id>](<url>): PR 1 — <artifact> / not applicable> |
| Item PR | <URL / not applicable> |
| Code | nothing was coded |

- **[<id>](<url>)** — <summary of the top item>
  - [<id>](<url>) — PR 1 — <artifact>
  - [<id>](<url>) — PR 2 — <artifact>
```

A task or a bug with no subtasks prints only the top line of the list.

With `tracker: local`, add a note below the table: the items exist for other clones only after the item PR merges. With `tracker: none`, add a note with the path the reconciliation was copied to (5.4).

Then ask with the structured question tool, recommended option first, without repeating the options in the text above it:

- **Stop here** (recommended): the items are ready; the PRs take days and involve other people.
- **Implement <id>, PR 1**: invokes `implement` on the subtask, never on the story. For a task or a bug with no subtasks, on the item itself.

Without a structured question tool, end the turn with the question.

The default is to stop. Never go on to implementation without an explicit choice. A flow of several PRs takes days and involves other people, and this skill does not pretend to run it in one go.

## Handoff

When the human chooses to implement, invoke `implement` with the id of the subtask, never the story. For a task or a bug with no subtasks, pass the item id.

With any tracker but `none`, the `## Reconciliation` section of the item is the copy `implement` inherits: it finds the section in the parent. With `tracker: none`, `implement` reads the copy at `<workspace>/<item id>/reconciliation.md` (5.4). Either way, it revalidates by delta over the declared scope instead of running the protocol again.

After subtask 1, the loop goes on: `implement`, then `deliver`, then subtask 2. The human drives the loop at the continuity gate of `deliver`.

## What this skill does NOT do

- It does not design. A shapeless request goes to `design-doc`.
- It does not investigate bugs. The root cause comes from the debugging protocol of 2.2.
- It does not reconcile. The protocol belongs to `reconcile`.
- It does not create an implementation branch, write code or open an implementation PR. With `tracker: local`, the item PR is the only PR it opens.
- It does not estimate. No story points, no time.
- It does not link items to PRs. That is `deliver`.
- It does not work at product-discovery level. A product-level epic, built from objectives, product requirements or wireframes, is out of scope: this skill works at repository level, with slicing anchored in `file:line`.
