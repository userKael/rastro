---
name: audit
description: Audits the golden paths for drift against the code. It runs the mechanical checks of the audit script, adds two checks that need reading the code (conformance of components discovered through project conventions and changed files, and `Revisit if:` conditions that now hold), compares the result with the previous report and writes it to the workspace. Use it on a schedule or before reviewing the architecture, to learn where the code and the golden paths have drifted apart and how first-pass, self-heal and the golden path lifecycle are moving. Do not use it to fix a drift: that is implement. It has no gate, writes only its report and never changes a golden path, code or an item.
---

# audit

One protocol looks for drift between the golden paths and the code, and reports it. The script does what can be checked mechanically. This skill adds what needs reading, compares the result with the last audit and writes the report. A finding is a question for the team, never a verdict on the code.

**Input:** none. The skill reads the config, the golden paths and the code, and the previous report when one exists.

**Output:** `<workspace>/audit/<YYYY-MM-DD>.md`, where `<workspace>` is the `workspace` key of `.rastro/config.yml`, `.agent/` by default. The report is not versioned.

## Requirements

- `.rastro/config.yml`. If it does not exist, stop and tell the human to run the `setup` skill.
- The folder named by `architecture.golden_paths`. If it does not exist or has no golden path, still run Step 1 (the script prints the metrics and says there are no golden paths), skip Step 2 and write the report in Step 3. In short: with no golden paths, still run Step 1 and skip Step 2.
- The script at `${CLAUDE_PLUGIN_ROOT}/hooks/git/audit-drift`. If it does not exist, stop and report.
- git, for the history the script and the judgment checks read.

## When to use

- On a schedule the team chose, or before a review of the architecture.
- After a run of items that changed instances of a golden path.
- When someone asks whether the golden paths still describe the code.

## Precedence

Sources rank as in `## Source precedence` of the rastro block in `AGENTS.md` (template: `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`). Code and green tests win. A golden path is the source of the pattern the team decided, never of how the code is today.

The team's rules in `AGENTS.md` precede this skill. This skill cites them by ID and never repeats their text. It cites other skills and templates by section title, never by line number.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

## Inviolable rules

1. The audit changes no golden path, no code and no item: it reports.
2. This skill has no gate, so it never asks for an execution mode. It reads, runs the script and writes one file.
3. The report is not versioned. It lives in the workspace, which is never committed, because the repository regenerates it. What must last goes to an item, a golden path or a PR description.
4. Never mark a judgment check as passed when the code was not read: write NOT VERIFIED and the reason. The same holds for a `Revisit if:` that speaks of something outside the repository.
5. A finding is a question for the team, never a verdict on the code. Write it as what was seen, where, and what the team may want to decide.
6. Every judgment finding carries a `file:line` or a commit. A claim without evidence does not enter the report.
7. Never cite the workspace path in a PR description or in the tracker.

Write every text for people in `project.languages.human`. Markers stay literal. Headings, check names and verdicts stay literal in English; the text under them is in `project.languages.human`. When `.rastro/profiles/writing.md` exists, apply its rules to the report.

## Step 0 — Requirements and previous report

1. Check the requirements above.
2. Find the previous report: the file with the greatest `<YYYY-MM-DD>.md` name in `<workspace>/audit/`. Report names are dates, so the greatest name is the latest. Today's file is named from the script's `Date:` line, so a report already written today is today's, not the previous one: skip it and take the next greatest. With none, the script prints `No previous audit.` and the comparison in Step 3 is skipped.

## Step 1 — Mechanical checks

Run the script with the previous report when there is one:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/git/audit-drift" --previous "<previous report>"
```

Without a previous report, run it without `--previous`. Read the `## Mechanical checks` table: one row per check and golden path, with the verdict `ok`, `review`, `drift` or `NOT VERIFIED`.

- A shallow clone, or any `NOT VERIFIED` row, enters the report as the script wrote it. Never turn it into `ok`, `review` or `drift`.
- The limit for `under-review-age` is `audit.under_review_days`. When it is empty, the script lists the age and sets no limit, and this skill invents none.
- `instance-missing` is drift: the instance listed in the golden path does not exist. It is never softened into a review.
- `instances-changed` flags a canonical example touched by a commit after its baseline or by uncommitted changes. The baseline is the later of the golden path's last version change and the commit that listed the example. Use `review` to check whether the example still follows the pattern.
- With optional `discovery` globs, `component-candidate` flags matching files outside `instances` that differ from the golden path's last committed version or are untracked and unignored. For a legacy file with no version change in history, the script uses its last commit. A path match is a `review` signal. Compare the component to the pattern in Step 2.

Keep the script's output whole: the tables, `## Metrics` and `## Changes since the previous audit`. The numbers of `## Metrics` are cumulative since the log began, so present them as a trend over the whole period, not as the result of one run.

## Step 2 — Judgment checks

For each golden path in the `architecture.golden_paths` folder whose status is not `retired`, run two checks.

**(a) Component conformance.** Find components of the type and compare them to `## Decisions`, `## Checklist` and `## Security` where applicable. Use:

- the candidate and changed-example rows from Step 1;
- the project conventions in the layout guide named by `layout` under `conventions` in the config, if present, including its `## Discovery` section if it has one;
- `## When to use`, the names and folders of canonical examples, and the module paths in `architecture.modules`;
- relevant added and modified files in the diff from the previous report's commit to `HEAD`, if available, and the staged and unstaged diffs. Without a usable previous commit, use the last committed golden-path version as the baseline. Search the relevant project paths when history or the layout guide is unavailable.

Use `## Known debt` to recognize documented exceptions. Record an `ok` finding for verified conformance and `drift` for a demonstrated violation, citing the decision or checklist item and the source evidence at `file:line`. Use `NOT VERIFIED` when the component's type or conformance cannot be determined. Report the scope searched even when it yields no candidates. A component can conform regardless of whether it appears in `instances`. For a catalog, check its invariant rules and treat source or schema as the inventory of values.

**(b) `Revisit if:` conditions.** Each decision in `## Decisions` of the golden path ends with a `Revisit if:` line. For each one, decide:

- the condition holds now: cite the `file:line` or the commit that shows it;
- the condition does not hold: say so, with where you looked;
- NOT VERIFIED, when the condition speaks of something outside the repository (a vendor, a load figure, a team decision).

Never mark a judgment check as passed when the code was not read: write NOT VERIFIED and the reason.

Record findings in the audit report. Route any pattern evolution through the item workflow and its golden-path gate.

## Step 3 — Report

1. Write `<workspace>/audit/<YYYY-MM-DD>.md`, named from the script's `Date:` line. A second run on the same day overwrites that day's file. The file holds the script's output, then `## Judgment checks`, with one subsection per golden path for (a) and (b). Each judgment finding is a row in the same shape as the script's, `| <check> | <subject> | <verdict> | <detail> |`, with the `file:line` or the commit in the detail.
2. End `## Judgment checks` with its own `### Changes since the previous audit`. When there is a previous report, compare its `## Judgment checks` with this one and list each finding by key (check and subject) as new, resolved, not verified or unchanged. A finding that is NOT VERIFIED now is never listed as resolved. The script already compared the mechanical rows.
3. Print a summary: the drifts and reviews per check, the numbers of `## Metrics`, and what changed since the previous audit. Do not repeat the whole report.
4. Close with the next steps, as text. A `review` row identifies a file to inspect. Record verified conformance in the judgment checks. The next item that touches a nonconforming component classifies it, and a contradiction goes through the golden path gate of `implement`. A drift the person wants to treat becomes an item through `breakdown`, and a change to a golden path happens through `implement`. This skill creates no item.

The report is not versioned. Do not stage it and do not cite its path outside the workspace.

## What this skill does NOT do

| It does not | Who does |
|---|---|
| Fix a drift | `implement` |
| Create items | `breakdown` |
| Change a golden path | `implement`, at the golden path gate of an item |
| Check the environment and the config | the `doctor` |
| Run the `automated:` check of a golden path | the CI and `deliver` |
