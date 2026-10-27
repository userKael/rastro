---
name: design-doc
description: Writes a design doc in the team's format and publishes it through the docs port for discussion. Grounds vocabulary in the real code through domain-context, records every technical decision as a stable DT-nn, adds domain invariants, a state diagram and code flows, and demotes slicing to a draft. Use when a request has no shape yet ("I want to rethink how X works", "I need a design doc for Y"), when the input is an ADR, a requirements document or a conversation, or when breakdown sends a shapeless request back. Do NOT use when the design doc already exists; that is breakdown. Ends at the publication gate, which opens the discussion and never approves or merges. It does not create work items, slice, reconcile or write code.
---

# design-doc

Writes the design doc of a change that has no shape yet, in the team's format, and publishes it for the team to discuss.

**Input:** a shapeless request ("I want to rethink how stock reservation works"), an ADR, a requirements document, or a conversation.

**Output:** a design doc published through the docs port, with its reference and version, ready for the "I have a design doc" entry of `breakdown`.

This skill carries the team's agreement, not the craft of writing design docs. When a general design-doc craft skill is installed, this skill drives it and applies its own rules on top. The agreement is versioned with the project. The craft is personal.

## Requirements

- `.rastro/config.yml`. Keys read: `docs.kind`, `docs.location`, `code_host.kind`, `project.languages.human`, `architecture.modules`, `architecture.layers`, `architecture.rules`, `architecture.golden_paths`, `architecture.contract_sources`, `domain.stateful_entities`, `review.rules`, `workspace`.
- The docs adapter, chosen by `docs.kind`. Read `.rastro/adapters/docs/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/docs/<kind>.md`, before `collapse`, `publish` and `update`. If the adapter file does not exist, stop and report.
- With `docs: repo`, the code-host adapter, chosen by `code_host.kind`, because publishing opens a change request through the code-host port. Read `.rastro/adapters/code-host/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/code-host/<kind>.md`, before `open_change_request`. If the adapter file does not exist, stop and report.
- The `domain-context` skill, `${CLAUDE_PLUGIN_ROOT}/skills/domain-context/SKILL.md`, for grounding. It reaches the `domain_state` port. This skill never reads the database itself. `domain-context` stops on a missing domain-state adapter, and this skill stops with it.
- The template `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.md`.
- Optional: a general design-doc craft skill. Without one, the template carries the craft.
- Optional: `.rastro/profiles/design-doc.md`, with the sections `## Sections`, `## Split rule` and `## Additional checks`.
- Optional: `.rastro/profiles/writing.md`. When it exists, its rules apply to every sentence of the design doc and of the gate.

The `doctor` checks the requirements of each adapter at session start. When it reported a requirement of this skill as missing, stop and report it to the human. Do not improvise the step that depends on it. A design doc written around a missing tool leaves the team's format in silence, and that is the failure the `doctor` exists to make visible.

## Precedence

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

In this skill, doctrine is: ground vocabulary, never decisions; every technical decision gets a stable `DT-nn`; the gate stops before publishing; publishing is not approving.

For architecture rules, conventions, templates and rulers, the order is `AGENTS.md`, then the team profile in `.rastro/profiles/`, then this skill's defaults, then the defaults of any craft skill. This skill does not copy the rules of `AGENTS.md`, because a copied rule diverges. It cites them by ID.

Refer to another skill or document by section title, never by line number. A line number is the most fragile identifier in a repository.

## Inviolable rules

1. **Ground vocabulary, never decisions.** The code keeps the design doc from contradicting facts: table, column and enum names, the errors the code really maps, golden paths, ADRs. The code does not choose the V1 cut and does not pick between options. A design doc derived from the code produces an empty reconciliation, and an empty reconciliation looks like success.
2. **Every technical decision gets a `DT-nn`.** Without an identifier, a decision cannot be cited in a plan, a commit or a PR description.
3. **Slicing in the design doc is a draft, and the template says so inside the section.** The authority for the cut is the `reconcile` skill plus the merge test of the `breakdown` skill.
4. **No estimates.** No days, no points, no phases with an owner. The design doc answers what and why, not how much.
5. **Never publish without the human gate.** The design doc exists to be discussed with the team.

## Step 1 — Grounding

Run the protocol of `${CLAUDE_PLUGIN_ROOT}/skills/domain-context/SKILL.md` in full. From its `## Context` block, build a vocabulary sheet for the writing step. Keep the sheet in `<workspace>/design-<slug>/`, where `<slug>` is a short kebab-case name of the change. It never enters the repository.

| Collect | Why |
|---|---|
| The modules touched, from `architecture.modules`, and the public API crossing between them | to name things right |
| The real schema, through `domain-context` | tables, columns, enums, nullability and uniqueness, never the ORM entity |
| The files in `architecture.golden_paths`: golden paths, patterns and ADRs | to avoid proposing against a decision already taken |
| The current state machines of the entities in `domain.stateful_entities` | base of the state diagram |
| The contracts on the touched path, from `architecture.contract_sources`: events, routes other repositories call, the error map when one is listed | the contracts other teams consume |

When a database is declared and does not answer, mark each schema claim `NOT VERIFIED` inside the design doc itself. Do not invent.

This step does not decide scope, choose between options or propose slicing. It only keeps the design doc from being wrong about facts.

## Step 2 — Writing

### 2.1 Craft and template

When a general design-doc craft skill is installed, invoke it for discovery, altitude, anti-patterns and language, and apply this step on top. Where the two disagree, this skill wins. Ignore any publication destination the craft skill offers: this skill publishes only through `docs.kind`.

Without a craft skill, write from `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.md`. When `.rastro/profiles/design-doc.md` has a `## Sections` section, it replaces the template's section list and the size profiles of 2.6.

Write the draft to `<workspace>/design-<slug>/draft.md`, in `project.languages.human`. `DT-nn`, `NOT VERIFIED` and the code-flow tags `new`, `changes` and `exists` stay literal.

### 2.2 Required and optional reading

Classify each section with one question: **If this is wrong, what changes?**

- It changes the design: required reading.
- It changes only because a decision changed: optional reading.

A derived section produces no design finding. A wrong test strategy fixes itself when the `DT-nn` behind it is fixed. The reverse almost never happens. Making the reviewer read derived sections spends attention away from where the expensive error lives.

Optional reading is not a cut, and it is not optional writing. These are two axes. A section can be required to write and optional to read. Every section is still written.

The collapse is the contract. Required reading publishes expanded. Optional reading carries the heading mark `{collapsed}` in the template. Render the mark through the `collapse` capability of the docs adapter when the adapter supports it. When it does not, leave the section visible and label its heading "optional reading". Either way, the reviewer knows what they owe the document without a legend.

**A technical decision found in an optional-reading section is a finding.** It belongs to a `DT-nn`. The derived section cites the decision and never takes it. Decisions hide in derived sections such as security and rollback, and this net exists to catch them. The net checks itself: if someone had to open a collapsed section to understand the design, the section is wrong, not the net.

V1 scope is the declared exception. Its content is a decision by construction: a delivery boundary, not a choice between implementation paths. The net targets technical decisions, the choices that propagate to code.

Collapse also works per block. Inside a required section, a block the reviewer looks up instead of reading collapses under its own `{collapsed}` heading: an enumeration, an example, a worked calculation, a payload, a reproduction recipe. Assertions, decisions, constraints and contract signatures stay in the reading path.

Other skills read some sections. Headings follow `project.languages.human`, as `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.md` says, so a reader finds each section by its role, never by a literal English heading. Keep every section of the template with its role.

| Section | Read later by |
|---|---|
| V1 scope, Solution and contracts | the path filter of the delta revalidation in `implement` |
| Technical decisions | the closed decisions of the PR description; a rule in `review.rules` matches `DT-nn` by identifier, never by field content |
| Domain invariants | the Given/When/Then scenarios of the plan |
| Risks | the risk section of the PR description |
| Code flows | the strong direction of `reconcile`; the paths of `exists` and `changes` items join the delta filter |

### 2.3 Technical decisions

Each `DT-nn` opens with its record and collapses its deliberation, as the template shows.

- **Record:** Decided, Consequence, Verifiable in. It outlives the decision and is cited later.
- **Deliberation:** Context, Options, Why (b) lost. It serves while the decision is open.

`Why (b) lost` is mandatory. Without it, collapsing the deliberation turns the discard into a pointer. Months later, "why not (b)?" must return the argument, not a number. Collapsing leaves about three visible lines per decision, and no field, word or identifier disappears.

Numbering:

- **Contiguous from `DT-01`, per family of documents, not per file.** A sibling created by the split rule continues the parent's numbering. If the parent ends at `DT-07`, the sibling opens at `DT-08`. Two sequences that both start at `DT-01` collide.
- **A DT freezes when the first work item cites it.** The reason to freeze is the citation in a commit, and a commit is not rewritten. Before that citation, renumbering costs nothing. Publication starts the discussion, and that is the worst moment to freeze an identifier.
- **A removed DT leaves a hole.** Do not renumber. With a sibling numbering from the parent's end, closing the hole only moves it to the end of the sequence, and two documents change instead of one.

### 2.4 Invariants and state diagram

The invariants table feeds the test scenarios downstream. An empty table is a finding, not a success.

When the design touches an entity listed in `domain.stateful_entities`, the state diagram is required. It is a mermaid `stateDiagram-v2` with the current and the proposed states in the same figure, and each new transition marked `(new)`. When the design touches none of them, the section says in one line which entities were checked.

### 2.5 Candidate slicing

Candidate slicing replaces the implementation plan of any craft skill. It has no phases by layer, no owner and no estimate, and it keeps the draft notice of the template. Slicing by technical layer is an anti-pattern: it contradicts a subtask that is revertible on its own, and it pushes tests to the end.

### 2.6 Size: by type of change, not by time

Run the split rule of 2.7 first. The split rule decides how many documents exist; this table decides the depth of each. In the other order, a design that hands its contract to a sibling falls into the core profile as a side effect.

| The change | Profile |
|---|---|
| Touches a state machine or a published contract | full: every section of the template |
| Touches one module, with no external contract | core: the nine required-reading sections, plus code flows, security, tests, observability, and rollback and flag; out of scope and candidate slicing only when there is something to say |
| Touches no domain: observability, configuration, an operational chore | probably no design doc; send it back to the triage of `breakdown` |

Time does not enter. It is not a property of the design. `## Sections` in the profile overrides this table.

### 2.7 Split rule

One document per published-contract boundary. The default is one document, and two triggers split it. Both are decidable by reading.

- **Trigger 1, a published contract.** The part that creates or changes a contract crossing the repository boundary goes to its own document. This holds whether V1 delivers the contract or only designs it. `architecture.contract_sources` says what counts as a published contract. The consumers live outside the repository. rastro has no impact port, so ask the human who consumes the contract.
- **Trigger 2, a declared prerequisite.** The part that merges first, and that another document depends on, goes to its own document.

An internal change stays in the same document, whatever its size. Size is not a trigger. The remedy for a long document is optional reading and collapse.

The boundary is declared once, and the reference points up only:

- In the parent, the boundary is one line of the out-of-scope section, with the link. It gets no `DT-nn`: the out-of-scope line already says it, and two copies diverge.
- The child declares its parent in its header. The parent does not list the child.
- The parent keeps one line in Risks, on its own merit, when the missing contract is a V1 risk.

A boundary DT spreads the same reference across many sections, and one declaration point is enough.

Do not split by any of these:

| Criterion | Why not |
|---|---|
| Execution route | the cut by route already lives in candidate slicing |
| Use case or verb | each document ends with a DT of the same title and the opposite decision |
| Module | it cuts an invariant in half when a transaction crosses modules |
| Size | size is not a trigger |

Splitting by any of them redoes the work of `breakdown` with a second ruler. `breakdown` slices the delivery. This rule decides document boundaries.

When `.rastro/profiles/design-doc.md` has a `## Split rule` section, it replaces this rule.

### 2.8 Code flows

The template's `## Code flows` section projects the `DT-nn` and the rules onto code components: which handler, which service, what is reused, what is new, where each module's public API is crossed, where the transaction opens, where work turns asynchronous. It does not decide. A choice it reveals that no rule, pattern or golden path forces becomes a `DT-nn`, and the section cites it.

Writing the section is the detector, so it is required writing in both size profiles. Writing the flow exposes a transaction with no mechanism behind it, or an order of steps an existing component cannot satisfy. The domain design hides both.

The boundary binds; the name of a new component is a suggestion. Type, module, reuse, public API crossed, transaction owner and async boundary bind the implementation, and a divergence from them is a reconciliation finding. Renaming a new component is not. An existing component is named with the smallest path fragment that identifies its file in the repository, without a line number. Here this skill wins over a craft skill whose altitude avoids file paths.

Components are a list in three groups, never a table: new (`new`), changes (`changes`) and reused without change (`exists`). A list wraps at any width.

Ground, do not derive. The code says what exists, and reuse is vocabulary. Choosing between two paths is still a `DT-nn`.

| # | Rule | What it catches |
|---|---|---|
| 1 | The type is a layer name from `architecture.layers`, and it binds: the rules in `architecture.rules` read it | a component of a layer that a rule forbids there |
| 2 | A `new` item cites, in its why, the `DT-nn` or the rule, pattern or golden path that forces it; citing neither is a finding | a decision hidden in a component |
| 3 | Every module crossing in a sequence goes through that module's public API; cite the rule by its ID from `architecture.rules` | a crossing that bypasses the public API |
| 4 | Every transaction boundary of the invariants becomes a `rect` with a named owner; a transaction that crosses modules cites its mechanism | a cross-module transaction with no mechanism |
| 5 | A lane is a listed component or an external actor; a pure domain service and a module's own repository become a `Note`; one `box` per module | a diagram too wide to read |

One `###` per entry point: a request, a job, a webhook. A sad path goes in an `alt` block or in its own `###`.

## Step 3 — Validation

Before the gate, check every item:

- [ ] Every technical decision has a `DT-nn`, contiguous from `DT-01` within the family.
- [ ] Every table, column and enum name matches the schema from `domain-context`, or carries `NOT VERIFIED`.
- [ ] The invariants table is not empty.
- [ ] The state diagram is present when the design touches an entity in `domain.stateful_entities`.
- [ ] The code-flow section is present. Every `new` item cites a `DT-nn` or a rule, every `rect` has an owner, and every module crossing goes through a public API.
- [ ] Candidate slicing carries the draft notice.
- [ ] No estimate in days, points or phases with an owner.
- [ ] No proposal contradicts an ADR or a golden path without saying so.
- [ ] Every `DT-nn` opens with its record and collapses its deliberation.
- [ ] Every `DT-nn` has `Why (b) lost` filled with the argument, never a pointer.
- [ ] Every section passed the question "If this is wrong, what changes?" and sits on the right side.
- [ ] No optional-reading section takes a technical decision. Those that did became a `DT-nn`.
- [ ] A section outside the template exists only through the split rule. Otherwise it belongs in a section that already exists.
- [ ] The split rule ran before the size profile.
- [ ] Measurement and hypothesis are separate, and each measurement says how to reproduce it.
- [ ] Each check in `## Additional checks` of `.rastro/profiles/design-doc.md` ran at the step it names. A check that names no step runs here.

An item that fails and cannot be resolved becomes a line in Open questions. It is never silenced.

## Step 4 — Gate and publication

Stop before publishing. The gate follows `## Gate anatomy` in the rastro block of `AGENTS.md` (template: `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`). **Class: fork.** Print the state only:

```markdown
**Gate — design doc of <slug> ready: publish it?**

| | |
|---|---|
| Profile applied | <full / core>, <one document / plus sibling <slug>> |
| Required / optional / DTs | <n> / <n> lines, <n> DTs; previous <n> / <n>, <n> |
| To read and contest | <DT-nn, DT-nn> of <n> |
| Invariants / state diagram | <n> / <present, does not apply> |
| Candidate slicing | <n> slices, draft |
| Open | <n> not verified, <n> questions |

The design doc exists to be discussed with the team. Publishing is not approving.
```

"To read and contest" is derived, never chosen. A `DT-nn` enters when it meets one of these conditions and Open questions does not declare it closed:

- its `Verifiable in` is `new`, so no precedent in the code supports it;
- its text declares a divergence from an ADR, a golden path or a current convention;
- it carries a claim marked `NOT VERIFIED`;
- an open question cites it.

The exclusion matters. A DT cited by a question that already closed is a finished review, and pointing the reviewer to it spends attention on what is resolved. When no DT qualifies, write `none: all rest on precedent` and say so to the team. That is information, not failure.

Count lines in `<workspace>/design-<slug>/draft.md`, before the docs adapter converts the markdown. Each count carries the previous pair. On the first gate, the previous pair is `first version`. A count without its previous pair is a number without a ruler: a hypothesis dressed as a measurement. These counts travel to the description of the PR that references this design doc.

A missing diagram with its reason, or a not-verified claim that changes the design, becomes one note below the table, never a parenthesis in a cell. The same goes for a gate check from `## Additional checks`.

Then ask with the structured question tool, recommended option first, without repeating the options in the text above it:

- **Publish** (recommended): opens the discussion with the team; with `docs: repo`, it also pushes the document branch; the reference and the version are recorded.
- **Adjust first**: the human says what changes, and the gate runs again.

Without a structured question tool, end the turn with the question.

A subagent never asks the human. When this skill runs inside a subagent, it returns the gate text and the draft path as its result, and ends. The session that dispatched it raises the gate.

On **Publish**, read `.rastro/adapters/docs/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/docs/<kind>.md`, before `publish`. Call `publish` with the draft, rendering each `{collapsed}` mark as the adapter's `collapse` says. Record the reference and the version it returns.

With `docs: repo`, publishing creates the branch `docs/design-<slug>` and opens a PR that adds the document, through the code-host port. Read `.rastro/adapters/code-host/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/code-host/<kind>.md`, before `open_change_request`. If the adapter file does not exist, stop and report. The PR is the discussion, and its merge is the approval. The gate opens the PR and never merges it. The branch carries no item id, because no item exists yet.

The code-host adapter opens a PR only from a branch that is already on the remote, and it leaves the push to its caller. So, after the commit and before `open_change_request`, push the branch:

```bash
git push -u origin docs/design-<slug>
```

The human's choice of **Publish** authorizes this push, and only this one. With `code_host: none`, do not push: stop after the commit, as the docs adapter says.

Republishing a design doc under discussion goes through `update`: a targeted edit that never deletes existing discussion. Never replace the whole document.

## Handoff

After publication and discussion with the team, the next entry is `breakdown`, through its "I have a design doc" entry, with the published reference.

`breakdown` reconciles the design doc against the code even though this skill wrote it. Grounding prevents contradictions of fact. It does not replace the confrontation. `breakdown` does not inherit candidate slicing as authority.

## What this skill does NOT do

- It does not create work items. That is `breakdown`.
- It does not slice. Candidate slicing is a seed, declared a draft.
- It does not reconcile. That is `reconcile`, later.
- It does not estimate.
- It does not write code.
- It does not merge its own PR. The merge is the team's approval.
- It does not replace discussion with the team. Publishing opens the conversation; it does not close it.
