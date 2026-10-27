---
name: deliver
description: Prepares a branch with verified commits for review and opens its PR. It checks scope hygiene, the branch name and every commit message, writes the PR title and a durable PR description, generates a self-check from the project's rules by ID, runs a final verification that must be green, opens the PR through the code host and links it to its work item. Use when the request is "open the PR", "prepare the PR", "finish the branch", "ready for review", or right before a branch-finishing skill opens a PR. Do NOT use to write or fix feature code (that is implement), to create work items (that is breakdown), or to review someone else's PR. Ends at a continuity gate that stops by default.
---

# deliver

**Input:** a branch with verified commits, plus the workspace `<workspace>/<id>/` that `implement` left: `design-doc.md`, the frozen copy of the design doc; `reconciliation.md`; `plan.md`; and, after subagent execution, `rulings.md`.

**Output:** a PR open on the code host and linked to its item, with a description that holds everything that has to outlive the workspace. With `code_host.kind` set to `none`, the output is the description file the code-host adapter writes, for a human to publish.

Steps 0 to 10 run in order, then the continuity gate. This skill does not write the commits: they exist when it runs. It audits them and fixes what can still be fixed.

## Requirements

- `.rastro/config.yml`. Without it, stop and tell the human to run the `setup` skill.
- Two ports, reached through their adapters and never by naming a tool:
  - Code host, with `<kind>` from `code_host.kind`. Read `.rastro/adapters/code-host/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/code-host/<kind>.md`, before `open_change_request`, `update_body`, `ci_status` or `collapsible`.
  - Tracker, with `<kind>` from `tracker.kind`. Read `.rastro/adapters/tracker/<kind>.md` when it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/adapters/tracker/<kind>.md`, before `read_item`, `comment` or `link_change_request`.
- If the adapter file does not exist, stop and report. Never improvise a capability the adapter does not describe.
- The `doctor` checks each adapter's requirements at session start. When it reported a problem for an adapter this skill uses, stop and report it. Do not work around the missing tool.
- PR description template: the project's own template when there is one, that is the file named by `code_host.template`, or else the default template file that the code-host adapter names, when it exists in the repository. Otherwise `${CLAUDE_PLUGIN_ROOT}/templates/pr-description.md`.
- Team profile, optional: `.rastro/profiles/deliver.md`. Its `## PR description` section replaces the sections of the template. Its `## Additional checks` section lists extra checks, each with the step where it runs and whether it is a gate or an observation. Run each one at its step.
- Writing rules, optional: when `.rastro/profiles/writing.md` exists, apply it to every text a person reads. That covers the PR description, comments on the item and gates.
- Optional skill: `superpowers:finishing-a-development-branch`. When it is installed, it opens a new PR with the title, body and target this skill produces. Without it, this skill opens the PR directly through the code-host port. Step 9 says when this skill pushes or updates the PR itself.

## Precedence

`AGENTS.md` › the team profile › the defaults of this skill › the superpowers defaults. That order governs rules and conventions.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill. In this skill, doctrine is: every gate stops by default, the final verification gate is absolute, the `file:line` anchor backs every claim, and agent artifacts are never versioned or cited.

The rules at `architecture.rules` and the conventions in the AGENTS.md block precede this skill. It cites them by rule ID or by section title, and never copies their text: a copied rule drifts from its source.

This skill is the preprocessor of PR creation. With `superpowers:finishing-a-development-branch`, run this skill until every gate is green, then hand that skill exactly the title, body and target produced here. If the finishing skill has already reached PR creation, stop it, run this skill, then go back. A PR never opens without passing here.

## Inviolable rules

1. It is FORBIDDEN to report completion, to say "ready" or "ready for review", or to hand off to a branch-finishing skill while any configured verify command is red.
2. No suppression closes a gate. No disabled lint rule, no skipped, focused or excluded test, no comment or cast that silences the type checker.
3. Never cite a workspace path in the PR description or in the tracker: it is a dead link the next day. Never commit a workspace file.
4. Never rewrite the history of a branch that has an open PR.
5. Never pretend the link exists. A link that was not created is reported as not created.
6. Verification numbers come from a real run on the current revision. The PR description is the only source of those numbers.
7. Known debt in a rule is never precedent, and this skill never adds to it.

## Step 0 — Traceability context

Collect and print these fields before anything else:

| Field | Source | Required |
|---|---|---|
| Item | the id in the branch name, read with `read_item` | yes |
| Parent item | `read_item` on the parent | when there is one |
| Design doc | provenance header of `<workspace>/<id>/design-doc.md`, the frozen copy: link, version, capture date | when there is one |
| Plan | `<workspace>/<id>/plan.md` | yes |
| Reconciliation | `<workspace>/<id>/reconciliation.md`, or the parent's `## Reconciliation` | when there was one |
| Position in the stack | PR <k> of <n>, and the branch of the previous PR | when stacked |
| Branch state | Not pushed, Pushed, no PR, or Pushed with a PR open | yes |

With `tracker: none`, the item is `<workspace>/<slug>/item.md`. With `tracker: local`, `read_item` reads the item file.

The branch is pushed when `git ls-remote --heads origin <branch>` prints it. A PR is open when the human, or an earlier run of this skill, gives its URL. When that is not known, the gate below asks.

- The plan is not versioned. What lasts is its content, transposed into the PR description in Step 5. If `<workspace>/<id>/plan.md` does not exist, stop. Either the execution did not go through `implement`, or the workspace was deleted too early, and without the plan there is nothing to transpose.
- The Context section of the PR carries only links that outlive the workspace: the item, and the design doc with its version and date.
- When the parent declared in the design doc differs from the item's real parent, record the divergence in the PR description. Do not propagate it.

**Gate — traceability of <id>: is this the right context?** Class: fork. State:

| Field | Value |
|---|---|
| Item | <id> — <title> |
| Parent item | <id> — <title>, or none |
| Design doc | <link>, version <v>, <date>, or none |
| Plan | `<workspace>/<id>/plan.md`, <n> tasks |
| Reconciliation | <where it was read>, or none |
| Branch state | <Not pushed, Pushed, no PR, or Pushed with a PR open> |

When the PR is stacked, the position goes in one note below the table: `Stack: PR <k> of <n>, after <branch of the previous PR>.`

Then ask with the structured question tool, recommended option first: confirm, or correct a field. Without that tool, end the turn with the question.

## Step 1 — Scope hygiene

Run and read:

```bash
git status --porcelain
git diff --stat
git diff --stat <target>...HEAD
```

`<target>` is `project.base_branch`, or the branch of the previous PR when this PR is stacked.

Compare every file, uncommitted or already on the branch, with the scope of the item from Step 0. A file that does not serve the item does not enter the PR.

Stage with explicit paths only. `git add -A`, `git add .` and `git commit -a` are forbidden. The agent harness denies them, and the `pre-commit` hook refuses the files they would drag in.

Without a written request from the human, these never enter: files matching `conventions.forbidden_paths`, the workspace, dumps and CSVs, and any file holding data of a class listed in `architecture.sensitive_data`.

Before each commit, read what is staged:

```bash
git diff --cached --stat
git diff --cached --name-only
```

**Scope gate.** Go on only when every line of `git diff --cached --name-only` is justified by the item in one sentence. An unjustified staged file leaves the index. An unjustified file already committed on the branch follows the Step 3 table. While no PR is open, rewrite it out of the history; when the branch was already pushed, the push in Step 9 then uses `--force-with-lease`. With a PR open, remove it in a commit of its own and record it in `## Recorded debt`. A sensitive file that was already pushed is a leak: stop and tell the human, because removing it from the branch does not remove it from the remote.

## Step 2 — Branch name

The format is `conventions.branch`. The type comes from `conventions.types`. The id is the item this PR delivers, never its umbrella story. The slug has 2 to 5 words in `project.languages.machine`.

The type of the branch matches the predominant type of its commits. Count them:

```bash
git log --format=%s <target>..HEAD | sed -E 's/^([a-z]+).*/\1/' | sort | uniq -c | sort -rn
```

A `feat` branch whose commits are all `docs` should be a `docs` branch.

| Branch state | Wrong type or format |
|---|---|
| Not pushed | Rename it: `git branch -m <type>/<id>-<slug>` |
| Pushed, no PR | Rename it, push the new name in Step 9, and tell the human the old remote branch still exists |
| Pushed with a PR open | Do not rename. Record the divergence in `## Recorded debt` |

## Step 3 — Commit audit

The commits already exist: whoever executed the plan committed each task. This step audits them.

The convention is `### Commit message` under `## Delivery conventions` in the AGENTS.md block, with the format in `conventions.commit`. Check every commit against it:

```bash
git log --format=%s <target>..HEAD
git rev-list --count <target>..HEAD
git log --format=%B <target>..HEAD | grep -c '^Co-Authored-By:'
```

- Every subject matches `conventions.commit`, with a scope from `architecture.modules` or `shared`, `infra`, `ci`, `docs`, written in `project.languages.machine`.
- Every commit has a body that says why. It cites the `DT-nn` or `D-n` it implements.
- When `conventions.co_author_trailer` is `true`, the trailer count equals the commit count. The trailer names the real model of the session that wrote the commit, never a name copied from an example. The string stays the same across the branch, and changes when the model changes mid-branch.

| Branch state | A commit out of format |
|---|---|
| Not pushed | Rewrite it with `git rebase` or `git commit --amend`, then check again with `git log --format=%s <target>..HEAD` |
| Pushed, no PR | Rewrite it. The push in Step 9 then uses `--force-with-lease`, and the push gate says so, so anyone following the branch is warned |
| Pushed with a PR open | Do not rewrite. Record it in `## Recorded debt`, and make sure the PR title is right: with squash merge, the title is what lands on the base branch |

The `commit-msg` hook validates each message when it is written. Never use `--no-verify`. When the hook refuses, the message is wrong, not the hook.

With a merge mode other than squash, every commit lands on the base branch as it is. In this mode the CI file runs `check-commits`, which validates the subject of every commit of the branch against `conventions.commit`, and the PR title check does not run. When the git hooks are installed, run the same check before the push:

```bash
bash .rastro/git-hooks/check-commits <target> <branch>
```

Many commits out of format means the convention does not reach whoever commits. The fix belongs in the AGENTS.md block, not in this skill. Say so in the report.

## Step 4 — PR title

The title is written in `project.languages.machine`. A stack ordinal such as `PR 2 of 4` goes in `## Context` of the body, never in the title, because the title outlives the stack.

When `code_host.merge` is `squash`, the title becomes the commit message on the base branch, and no local hook sees it. Validate it as a commit: the format in `conventions.commit`, a valid type and scope, a non-empty subject, no trailing period, and at most 100 characters. Print the character count. When the git hooks are installed, run the check the CI runs:

```bash
bash .rastro/git-hooks/check-pr-title "<title>" "<branch>"
```

**Title gate.** Go on only when the check passes and the count is printed. With another merge mode, the title is not a commit, and only the language and the ordinal rule apply.

## Step 5 — PR description

Fill the template from Requirements: every section it does not mark optional. When `.rastro/profiles/deliver.md` has a `## PR description` section, its sections replace the template's. Write in `project.languages.human`. Markers and identifiers stay literal: `## Reconciliation`, `[HUMAN]`, `D-n`, `DT-nn`, rule IDs.

The framework template has two optional sections that exist only for this skill. `## Rule self-check` is used only when Step 6 leaves a ⚠. `## Reconciliation` is used only with `tracker: none`, where the PR description holds the reconciliation. When the project's own template lacks a section that applies, add it at the end.

Rules by section:

- **Pending human execution.** From the `[HUMAN]` tasks of the plan: per environment, what already ran and what has not. Write that a step ran only when the person who ran it confirmed it. When the merge depends on a step not yet run, this section goes at the top, because it decides whether the PR can merge. Remove it whole when the plan had no `[HUMAN]` task.
- **Context.** The Step 0 fields, with no placeholder and no "to be defined". The design doc enters as link, version and date, never as content. The plan enters as content in the collapsed block at the end, never as a path. When this PR adds or changes a design doc, Context also carries three counts of that document: required sections, optional sections and `DT-nn`. Each count comes with the count of the previous version, both taken from the materialized markdown.
- **What this PR delivers.** The contract and its edge: changed signatures, new fields, error statuses. When the error contract of the design doc differs from what the code maps, the implementation wins, and the divergence is recorded here.
- **Closed decisions.** By ID. A decision taken during implementation that is not in the design doc is marked new.
- **Risks and rollback.** The order that cannot be inverted, the compensation, and what happens when the change fails halfway.
- **Verification.** The exact numbers from Step 8, never a checkbox.
- **Next PRs.** With the `Depends on` column.
- **Reconciliation.** Only with `tracker: none`, where the PR description is the home of the reconciliation.
- **Divergences from the design doc.** Transposed from `reconciliation.md`. Without it the reviewer rereads the design doc and concludes the PR is wrong.
- **Recorded debt.** What was left out on purpose: the branch name divergence of Step 2, the commits Step 3 could not rewrite, a red check proven pre-existing in Step 8, and every ⚠ of Step 6 that was not fixed.
- **Rule self-check.** Only when Step 6 left a ⚠.
- **Agent rulings.** From Step 7. Removed whole without subagent execution.
- **Executed plan.** The whole content of `plan.md`. Collapsed when the `collapsible` capability of the code-host adapter says supported, otherwise a plain section marked optional in its title. When the plan dominates the description, cut the tasks delivered by earlier PRs of the stack and say they were cut.

The numbers stay in sync. After each commit that answers a review, rerun Step 8 and update the description with `update_body` in the same push. A test added during review without that update leaves one PR with several counts, and the description is the only source of the numbers.

## Step 6 — Self-check against the rules

Read the rules where `architecture.rules` points. Each rule is an entry `**[<rule-id>]**` with its symptom, why it matters here, what to ask the author, and its known debt. Generate the table from that list, one row per rule ID. Never number the rules and never copy their text into the table.

| Rule | Result | Evidence |
|---|---|---|
| `[<rule-id>]` | ✅, ⚠ or n/a | `file:line`, or the reason |

- ✅ cites the `file:line` that complies, or the search over the diff that found no symptom.
- n/a only when the diff does not touch what the rule covers. Say why in one sentence.
- ⚠ requires one of two things: a fix before the push, or a line in `## Recorded debt` with its justification. When any ⚠ remains, paste the table into `## Rule self-check`.
- Known debt lists the files that already broke the rule when it was written. It is not precedent, and the list does not grow. A new file with the same defect is a blocking ⚠, and this skill never adds a file to that list.

An entry whose fields are still `<...>` placeholders, as in the shipped example, is not a rule. When the target holds no rule entry, or only placeholder entries, say "no rules defined" in the report and skip the table. Never audit a placeholder entry, and never invent a rule.

When `docs.public_portal` is set, add one observation. If the diff touches a business rule, a contract or a published event and no portal file changed, answer in one sentence: is the published rule still true? If yes, go on. If not, fix the page now, or record in `## Recorded debt` which page is now wrong. This is a safety net. The primary detection belongs to `reconcile` and `breakdown`, and a page that arrives here outdated escaped both. Code commits rarely touch the public docs, which is why the question exists.

Run here every check of `## Additional checks` that names this step.

## Step 7 — Agent rulings

After subagent execution, `implement` extracted the rulings into `<workspace>/<id>/rulings.md` before deleting the subagent workspace. Read that file.

If the file is missing and the subagent workspace still exists, extract now from its ledger every line that carries `Ruling:`, `parked` or `minor (deferred)`. Once that workspace is deleted, nothing is recoverable.

Write one row per ruling in `## Agent rulings`: the task, the finding, the ruling, and where it went (a next item, recorded debt, or dropped). Subagents read local files and never see the session that dispatched them. A ruling that lives only in their workspace never reaches the human reviewer, and the PR description is the one durable place.

Without subagent execution, remove the section whole. Never leave an empty heading.

## Step 8 — Final verification

Run the configured commands in this order and capture their output: `verify.lint`, `verify.unit`, `verify.typecheck`. Also run `verify.integration` when a path in `git diff --name-only <target>...HEAD` matches `verify.integration_when`. A key left empty is reported as not configured, never as passed.

Extract the exact numbers from the output: test suites, tests, and the coverage line when the unit command prints one. They go to `## Verification`.

**Verification gate. It is absolute.** It is FORBIDDEN to report completion while any of these commands is red.

- A red lint is fixed in the code, never by disabling the rule.
- A red test follows `## Failing tests` in the AGENTS.md block: the verdict comes before any edit. It is never fixed by skipping, focusing or excluding a test, or by widening a mock or a fixture.
- A red type check is fixed in the code, never by an ignore comment, an escape-hatch type or a non-null assertion. An inventoried suppression debt only shrinks.
- A command already red before this branch: prove it on `<target>` in a temporary worktree, never with `git stash`. Run `tmp=$(mktemp -d)` and `git worktree add --detach "$tmp/target" <target>`, rerun the command inside `$tmp/target`, then `git worktree remove --force "$tmp/target"`. A failure caused by the fresh worktree itself, such as missing dependencies, proves nothing. Record a proven pre-existing failure in `## Recorded debt`. Only then does the gate pass for that command.

Coverage is not evidence of behavior. A mock that returns a complete fixture hides code that wipes a field, and a guard on the wrong field passes a full suite. When the PR touches an integration with an external system, `## Verification` says whether it was tested by hand against that system, and what is still not exercised.

## Step 9 — Handoff

With every gate green, print the delivery block:

```
Branch: <branch>
Title:  <title>   (<n> characters)
Target: <project.base_branch> | <branch of the previous PR>
Body:   <the full description, ready to paste>
```

A stacked PR targets the branch of the previous PR in the stack, never the base branch.

The branch must be on the remote before the PR opens. The push is `git push -u origin <branch>`, with `--force-with-lease` added when Step 3 rewrote history. Step 3 rewrites only while no PR is open.

| Branch state | After a yes at the gate below |
|---|---|
| Not pushed, or Pushed, no PR | Push, then call `open_change_request` with the branch, the target, the title and the body |
| Pushed with a PR open | Push, then call `update_body` with the whole new description. Never open a second PR |

Who runs the row:

- With `code_host.kind` set to `none`, nothing is pushed, even when the finishing skill is installed: `none` wins. `open_change_request` or `update_body` writes the description file and gives the human the push command.
- With a PR open, this skill runs the row itself. A branch-finishing skill would open a second PR.
- With `superpowers:finishing-a-development-branch` and no PR open, hand it exactly this title, body and target at its PR option. Its option menu is the push decision: do not raise the gate below. After a Step 3 rewrite, raise the gate and run the lease push here first, then hand over. The lease push never leaves this skill.
- Without that skill, raise the gate below, then run the row.

**Gate — PR for <id>: push <branch> and open the PR, or update its description?** Class: fork. State:

| | |
|---|---|
| Branch | `<branch>`, <n> commits, <branch state> |
| Target | `<target>` |
| Title | `<title>` (<n> characters) |
| Verification | <lint, tests and type check, with their numbers> |
| Push | plain, or with lease after a rewrite |
| PR | opened after the push, or <link> with its description updated |

Ask with the structured question tool, recommended option first: push and run the row, or adjust. Without that tool, end the turn with the question.

After the PR exists:

- Call `ci_status` and confirm the pipeline ran. An absent pipeline is never reported as passing.
- When the PR is stacked, confirm its target is the branch of the previous PR.

## Step 10 — Item ↔ PR link

Link the item named in the branch to the PR URL. Check what exists first: this skill runs again after each review, so the step is idempotent.

- `tracker: local`: the link is the item id in the PR title. Nothing is written to the item file. Confirm the title carries the id.
- `tracker: none`: there is no item outside the workspace to link. Say so.
- Any other tracker: call `link_change_request` with the item id and the PR URL, through the tracker port. The adapter checks for an existing link, creates one when its tool can, and otherwise gives the path that exists, such as a comment on the item with the PR URL and title plus a one-line request to the human for the formal link.

Never pretend the link exists. The report names the path that produced the result: already linked by an integration, created, commented with a human action pending, or the id in the title. With every item linked to its PR, whether one item maps to one PR becomes measurable; a link reported but absent corrupts exactly that measure.

## Gate — continuity

Class: fork. Print the state only:

**Gate — PR <ref> open: stop for review or continue to <next id>?**

| | |
|---|---|
| PR | <link> — <title> |
| Item | <id>, with <n> items left under <parent> |
| Item ↔ PR link | <linked, commented and pending, id in the title, or no tracker> |
| Human execution | <none, done in some environments, or all pending> |
| CI | <state from `ci_status`, or unavailable> |

Each pending action becomes one note of one line below the table, never a parenthesis in a cell:

- `Formal link pending: <the one action the human takes>.`
- `⚠ <id> (<what it is>) is pending and blocks the merge of this PR.`

`⚠` marks only what blocks the merge. The human should not discover it in the PR description after approving.

Then ask with the structured question tool, without repeating the options in the text. Without that tool, end the turn with the question.

| Option | What it does |
|---|---|
| Stop here (recommended) | Hands the PR to review: automatic through the review port when `review.kind` is not `none`, and human always |
| Next item <id> | Starts `implement` on that item, only once the review of this PR is addressed |

The default is to stop. A stack of PRs takes days and involves other people, and this skill does not pretend to run it in one go.

A subagent never raises a gate of this skill. It returns the state as text and ends; the session that dispatched it asks the human.

## Anti-patterns: immediate refusal

- `git add -A`, `git add .` or `git commit -a`.
- `git commit --no-verify`.
- A PR title outside `conventions.commit` when merging by squash, written in `project.languages.human`, or carrying a stack ordinal.
- A commit message in `project.languages.human`, without a body, or without the trailer when `conventions.co_author_trailer` is `true`.
- A trailer with a model name copied from an example instead of the real model of the session.
- A code comment that breaks `### Comments in code` under `## Delivery conventions` in the AGENTS.md block.
- `## Verification` with a checkbox instead of a number, or with a number from an earlier push.
- Reporting completion with a red check.
- A suppression used to close a gate.
- Pushing without the plan in the workspace.
- Committing any workspace file.
- Citing a workspace path in the PR description or in the tracker.
- Rewriting the history of a branch that has an open PR.

## Handoff

- Stop: the PR goes to review. A review that asks for changes is answered by fix commits, and this skill runs again from Step 1. It is idempotent: the link, the description and the numbers are checked before they are written.
- Next item: `implement`, with the id of the next item.

## What this skill does NOT do

| Not this skill | Who does it |
|---|---|
| Write feature code or the plan | `implement` |
| Create work items | `breakdown` |
| Write or change the design doc | `design-doc`, then the team |
| Decide `D-n` | the human, at the reconciliation gate |
| Review the PR | the review port, and a human always |
| Run a `[HUMAN]` step | the human |
| Merge, roll out, flip a flag or deploy | the human |
