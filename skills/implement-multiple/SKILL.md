---
name: implement-multiple
description: Coordinates several published, dependency-aware work slices when the person asks for a batch or parallel implementation. Keeps one slice per isolated worktree, routes gates to the coordinator and hands verified branches to deliver. Use implement directly for a single item.
---

# implement-multiple

**Input:** a published story or flat publication group and the slices the human authorized to implement. **Output:** a delivery report with verified heads, targets, PR links when authorized, and waiting slices with the evidence needed to proceed.

## Requirements

- `.rastro/config.yml` and the tracker, docs and code-host adapters required by `implement` and `deliver`.
- `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md`.
- Git and writable, isolated worktrees for concurrent execution. Delegation is optional.

## Precedence

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill. The coordinator keeps each slice within the gates, human execution rules and verification of `implement` and `deliver`. Project conventions from `AGENTS.md` and their profiles still apply.

## Read the graph

Read the registered adapters before use. Resolve the graph and current targets using `implement` Stage 1. Check the reconciliation, item links, evidence and graph completeness before dispatch. Resolve unknown legacy dependencies at a decision gate before scheduling. A partial publication stays with `breakdown`. No card is created here.

Choose execution mode once for the story or publication id. The coordinating session owns that choice and any approvals. Batch scope never waives a decision, team or hard verification gate. No worker merges a PR or executes a `[HUMAN]` task.

Keep a private run ledger under `<workspace>/<top item>/`. For each authorized slice record the item id, prerequisites, effective target and its commit, assigned write paths, worktree, branch, latest verified commit, gate and publication state. Refresh evidence and check existing heads or PRs before retrying. A stopped worker keeps its worktree and reservations until the coordinator resumes it or releases ownership.

## Schedule ready work

At each dispatch, refresh the ready set using `implement` Stage 1, including the slice's own completion state. Exclude completed and in-progress slices from fresh dispatch; resume existing work by its id and worktree. A root targets the project base only while it has not already been delivered. A waiting slice reserves no worker. Re-evaluate it when its prerequisites satisfy the recorded conditions. Offer ready human work to its executor only once and resume dependents only on reviewed execution evidence.

Compare each ready slice's planned write paths with the active slices, including shared config, golden-path files, migrations and local tracker writeback. Unknown or overlapping write paths are processed serially until the scope is resolved. If a new overlap appears during work, pause the affected workers, resolve ownership and revalidate their bases before resuming.

When the harness supports worktrees and delegated execution and the human authorized parallel work, allocate one worker and one isolated worktree per ready slice. Create the worktree from its recorded starting commit, with the implementation branch using `conventions.branch`. Prefer the harness's native worktree capability when available. Otherwise use Git worktrees. If delegation is unavailable, run the same ready set serially through `implement` and `deliver`. Use separate item workspaces for plans and evidence. Supply the frozen input and verified refs to workers. The coordinator performs adapter reads or writes when workers lack that access.

## Own gates and publication

A worker runs the assigned slice through `implement` and delivery preparation using `deliver`. At each unresolved gate it returns the slice id, gate title, class, mode, state, proposed options and recommendation. It stops that slice at the gate. For a golden-path draft, use `implement`'s subagent sequence: commit the draft with its first instance, return the review rows, and let the coordinator raise the gate before another task runs. The person's answers land in the follow-up commit of that task. Other work covered by an unresolved decision stays uncommitted. The coordinator checks the evidence, raises the original gate or applies the recorded confirmation rule, records the answer per item, and resumes the same worktree only with that answer. Never let a worker take a new content decision. Independent workers can continue while another slice waits. The coordinator applies any shared tracker section updates in sequence and checks for intervening edits before writing.

A worker reports its branch, exact verified commit, effective target, verification outputs, unresolved human steps and prepared PR title and body. The coordinator checks the scoped diff and verification evidence against that commit. Run any check required when the head, target or scope changes. Only the coordinator continues publication through `deliver` with the applicable push and PR gates. It refreshes the graph after each PR or human confirmation and dispatches the next ready set when scope and approvals allow. Workers leave shared run mode and publication state to the coordinator.

## Report

Summarize by slice and include the actual target and latest verified state:

| Slice and item | Outcome | Branch and target | Verification | PR or blocker |
|---|---|---|---|---|
| <key and item link> | <delivered scope> | <branch and target> | <head and result> | <PR link or what must happen next> |

Call out pending human decisions and execution, waiting prerequisites and any withheld publication. A verified branch without an open PR is reported as prepared. End the run when a human stops it, or when no authorized action can advance it. Preserve the ledger and worktrees for a later resume and clear shared run mode.

## What this skill does NOT do

- Publish cards. `breakdown` owns their creation and recovery.
- Approve decisions, execute human steps or merge PRs. The human owns those actions.
