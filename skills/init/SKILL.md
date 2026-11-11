---
name: init
description: Starts rastro in an empty directory or a repository with no source code yet. It interviews the person one question at a time about the minimum decisions (purpose, stack, modules, layers, boundary types, verify commands, tracker, docs, code host and languages), drafts an ADR for each decision, which the person confirms, rewrites or drops at its gate, hands the answers to setup, and writes the walking skeleton as the intent of the first item, for breakdown. It writes nothing before its gate, never commits, never pushes and never writes a golden path, because golden paths are born from code. Use when the repository has no source code, or when the state table says "No source code yet". Do NOT use in a repository with source code (that is setup), to start work on a request (design-doc, breakdown) or to write code (implement).
---

# init

**Input:** an empty directory, or a repository with no source code, at its root.

**Output:** after the gate, the ADRs in `docs/adr/`, from `${CLAUDE_PLUGIN_ROOT}/templates/adr.md`, and `git init` when the directory was not a repository. Then, through the gate of `setup`, the files that `setup` writes. Last, `<workspace>/breakdown-walking-skeleton/intent.md`. Nothing is committed.

## Requirements

- `git` and `bash`.
- Framework files: `${CLAUDE_PLUGIN_ROOT}/templates/adr.md`, `${CLAUDE_PLUGIN_ROOT}/templates/stack-detection.md` and `${CLAUDE_PLUGIN_ROOT}/templates/config.yml`.
- Skills: `${CLAUDE_PLUGIN_ROOT}/skills/setup/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/breakdown/SKILL.md`.
- Writing rules, optional: when `.rastro/profiles/writing.md` exists, apply it to the questions, the gate and the closing report.

## Precedence

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill. Here that means: the person decides and the agent drafts; no golden path before there is code; gates stop by default; nothing is written before the gate.

Configuration belongs to `setup`. Init hands over answers and never writes `.rastro/config.yml`.

## Inviolable rules

1. **Only where there is no source code.** Use this definition:

   **Source code** is a file a build, an interpreter or a test runner reads as program text. These are not source code: documentation and prose, a license, ignore and editor files, manifests and lock files, CI workflow files, and what rastro writes (`.rastro/`, `AGENTS.md`, `CLAUDE.md`, `docs/adr/`). When `.rastro/config.yml` sets `verify.source_globs`, source code is a file outside `.rastro/` that matches it. List the files with `git ls-files --cached --others --exclude-standard` in a repository, and with `find . -type f -not -path './.git/*'` outside one. When one file is unclear, name it and ask.

2. One question at a time.
3. **The person decides, the agent drafts.** An ADR with no human decision behind it is fabricated. An ADR records the person's answer. The agent never supplies a decision, a reason or an alternative. A reason the person did not give appears as `<reason not given>`.
4. Never write a golden path. Golden paths are born from code: each component type of the skeleton writes its own through `implement`, like every first instance.
5. Write nothing before the gate. That includes the ADRs. `git init` runs only after the gate, and only when the directory is not a repository.
6. Never commit and never push.
7. init asks no execution mode. Its gate is a decision and always stops. `breakdown` asks the mode, for the first item.

## Step 0 — Where init starts

Check three things before asking anything.

- **Source code.** Apply rule 1. When it finds source code, say that This repository has source code, point to `${CLAUDE_PLUGIN_ROOT}/skills/setup/SKILL.md`, and stop.
- **Another repository.** Run `git rev-parse --show-toplevel`. When it prints a directory other than the current one, the current directory is inside another repository. Say so, and ask: start a new repository here, with `git init` after the gate, or stop, because the project belongs to the outer repository, where `setup` runs at the root. This is a question, not a gate.
- **What is already answered.** The values of `.rastro/config.yml`, when it exists, and the accepted ADRs in `docs/adr/` whose `origin` names `init`. Steps 2 to 6 ask, draft, write and hand to `setup` only what is still open. A value read from the config is not drafted again as an ADR. When nothing is open, go to Step 7.

## Step 1 — Detect

Print one report, a two-column table, with no decision in it:

- whether the directory is a repository, and the current branch, from `git symbolic-ref --short HEAD`;
- the output of `git remote -v`;
- the files present, and why none of them is source code;
- the CI files and manifests, read as the `## CI workflows` section and the manifest sections of `${CLAUDE_PLUGIN_ROOT}/templates/stack-detection.md` describe, with the proposals for the verify commands;
- the ADRs already in `docs/adr/`, and the next free number;
- `AGENTS.md` and `CLAUDE.md`, which stay for `setup`.

## Step 2 — Interview

One question at a time. Ask with the structured question tool. Without that tool, end the turn with the question. A detected value is the recommended answer, first.

Purpose, stack, modules, layers and boundary types have no recommended answer: rastro chooses neither a stack nor an architecture. The agent may list options and mark none.

Ask in this order, only what is still open:

1. **Purpose.** What the project does and for whom, in one or two sentences. `project.name` comes from the directory name and shows in the diff of `setup`, with no question of its own.
2. **Stack.** Language, runtime and framework.
3. `architecture.modules`. "none yet" is an answer, and becomes `[]`.
4. `architecture.layers`. The component types, in the order a request crosses them.
5. `architecture.boundary_types`. The layers that cross a trust boundary. A name outside the layers is refused, and the question comes back. "None" becomes `[]`.
6. **Verify.** One question for the set `verify.lint`, `verify.typecheck`, `verify.unit`, `verify.lint_file` and `verify.source_globs`.
   - The proposals come from the CI files and the manifests.
   - With neither, ask for each command the stack will run, and say that the skeleton makes each one real.
   - At least one of lint, typecheck and unit is filled.
   - `verify.source_globs` is required here: it is how `reconcile` recognizes a repository with no code.
7. `tracker.kind`, `docs.kind` and `code_host.kind`. One at a time, as `## Step 2 — Ask` of `setup` asks them, with the same answer checks.
8. `project.languages.human`.

Everything else is for `setup`.

## Step 3 — Draft the ADRs

Build the files in a temporary directory from `mktemp -d`, outside the repository, from `${CLAUDE_PLUGIN_ROOT}/templates/adr.md`.

- At most three ADRs: the stack; the structure (modules, layers and boundary types); the verification (verify commands and CI).
- Tracker, docs, code host and languages do not become ADRs.
- Numbering uses the next free number of `docs/adr/`, from `0001`. Init never overwrites an existing file, and a number is never reused.
- Each ADR has `status: accepted`, `decided_by: <person>` and `origin: init, <YYYY-MM-DD>`.

## Step 4 — Gate

**Gate — decisions of <project.name>: do these ADRs hold, and do I write them?** Class: deliberation. Mode: decision. State:

| | |
|---|---|
| Purpose | <one line> |
| Stack | <the answer> |
| Structure | <modules, or none yet>; layers <in order> |
| Boundary types | <the types, or none> |
| Verify | <n> of 3 commands set; source globs <the globs> |
| Files | <n> ADRs in `docs/adr/`; `git init`: <yes / no> |

Then the deliberation table, one row per drafted ADR, plus the quick-exit row:

| ADR | Decision | Why | Revisit if |
|---|---|---|---|
| `<NNNN>-<title>` | <the decision> | <the reason, or `<reason not given>`> | <the condition> |
| all hold as drafted | | | |

The person confirms, rewrites or drops each ADR. A rewritten ADR is drafted and shown again. A dropped ADR is not written; its answer still goes to `setup` when it is a config key. Changing an interview answer drafts again. Stopping writes nothing.

Write only after an explicit answer to each row. A subagent never raises this gate, as `## Gate anatomy` of the `AGENTS.md` block says.

## Step 5 — Write

After the person chose to write:

1. When Step 0 found that the directory is not a repository, run `git init`, now and not before.
2. Copy the confirmed and rewritten ADRs into `docs/adr/`.
3. Read the branch with `git symbolic-ref --short HEAD`. It is the answer for `project.base_branch`.

Nothing else is written.

## Step 6 — Setup

Invoke `${CLAUDE_PLUGIN_ROOT}/skills/setup/SKILL.md` with the answers, one per key: `project.name`, `project.base_branch`, `project.languages.human`, `tracker.kind`, `docs.kind`, `code_host.kind`, `architecture.modules`, `architecture.layers`, `architecture.boundary_types`, and the verify keys of question 6.

`setup` asks only what is missing, raises its own gate, writes, prints its closing report and hands the turn back. When the person stops at the gate of `setup`, init stops too. The ADRs stay, and the next `init` starts again at Step 0.

## Step 7 — Walking skeleton

Ask one question: the entry point the skeleton carries end to end, and the layers it crosses, in order. The agent proposes both from the purpose and from `architecture.layers`. A layer the skeleton does not cross gets its golden path at its first instance, later.

Write the intent to `<workspace>/breakdown-walking-skeleton/intent.md`, with `<workspace>` read from the config just written. When the intent already exists, keep it as it is.

The format is exact:

```markdown
---
type: interview
origin: init, conversation with <person>
captured_on: <YYYY-MM-DD>
---

## What changes

A walking skeleton: <the entry point>, end to end through <the layers, in order>, with <the verify commands> green on a developer's machine and in CI. When setup wrote the CI file, the skeleton also fills its toolchain step, so CI can run the verify commands. It holds nothing beyond what the entry point needs to answer.

## Who observes

<The CI, when the repository has a CI file; otherwise the developer who runs the verify commands>: every verify command runs and passes on the change request of the skeleton.

## Current contract

None: the repository has no source code. The decisions are in <the path of each accepted ADR> and in `.rastro/config.yml`.

## Components

New (`new`): <count>

- `<ComponentName>`: module `<a module, or none yet>`, type `<a layer from architecture.layers>`, <responsibility>; why: `<ADR file:line>`
```

## Handoff

When `git ls-tree --name-only <project.base_branch> -- .rastro/config.yml` prints nothing, print the closing report and stop:

- the files to commit, each by its explicit path: the list of `setup` plus each ADR;
- commit on the base branch before the first item, because the reconciliation stamps that branch;
- with `code_host.kind` other than `none`, add the remote and push the base branch, because `breakdown` and `deliver` need them;
- then run `init` again, or `breakdown` with the path of the intent.

When the base branch already has the file, invoke `${CLAUDE_PLUGIN_ROOT}/skills/breakdown/SKILL.md` with the intent. `breakdown` asks the execution mode.

## What this skill does NOT do

| Not this skill | Who does it |
|---|---|
| Choose the stack or the architecture | the person, in the interview |
| Write a golden path | the first instance of each type, through `implement` |
| Write `.rastro/config.yml`, `AGENTS.md` or the git hooks | `setup` |
| Create items or slice the skeleton | `breakdown` |
| Write code | `implement` |
| Commit or push | the human |
| Install rastro in a repository with source code | `setup` |
| Ask the execution mode | `breakdown`, `implement`, `deliver` |
