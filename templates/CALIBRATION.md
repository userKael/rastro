# Calibration

rastro ships no calibration numbers. Where another team would quote a figure, the default rulers say "measure". Record your own measurements here, each with a date and a source. Write "not measured" when you have no number: a figure without a date and a source is a hypothesis, and this file keeps hypotheses apart from measurements.

## How many stories have no subtask?

How to measure: pick a period. Count the items of type `story` created in it that have no children. Divide by all stories created in the same period.

- Result: <number, or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <the tracker query or report that produced it>
- Feeds: how strictly your team applies the story ruler of the `breakdown` skill. rastro sets no threshold.

## What is the cancellation rate among those stories?

How to measure: of the stories counted above, count those cancelled without delivery. Run the same count for stories that do have subtasks, and compare the two rates.

- Result: <both rates, or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <the tracker query or report that produced it>
- Feeds: the same decision as the question above. A gap between the two rates is evidence for requiring subtasks; no gap is evidence against.

## What subtask summary format does the team already use?

How to measure: read the titles of a recent sample of subtasks and write down the pattern most of them follow.

- Result: <the format, with two real titles as examples, or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <where the titles were read>
- Feeds: the section `Subtask summary format` of `.rastro/profiles/breakdown.md`. When it exists, the `breakdown` skill writes subtask summaries in that format.

## What do the footprint buckets mean in this project?

How to measure: take a sample of recent tasks. For each, count the lines changed in its commit and the files the agent opened to do it (the session transcript lists them). Sort the tasks into three buckets for each dimension, and write down where each bucket starts and ends.

- Result: <small, medium and large for the diff, in lines; small, medium and large for the read scope, in files; or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <the commits and the sessions sampled>
- Feeds: the `Footprint` line of each task in a plan. rastro sets no limit.

## Which tier does each footprint get, and which model runs each tier?

How to measure: for each tier, run a few tasks of that footprint on the model you would map to it, and count how many pass review without rework. Raise the tier where rework is common; lower it where it is rare.

- Result: <a table of diff bucket by read bucket giving light, standard or deep, and the model of each tier, or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <the plans, with their `Actual:` lines, and the review results>
- Feeds: the `Tier` line of each task, and the model that subagent execution uses for it. Without a measured table, every task is `standard`.

## Before/after probe: what does the harness change?

How to measure, by hand; nothing automates it:

1. Pick one task that is typical for the project, already merged, with a known starting commit and a written description.
2. Make two clean checkouts of that starting commit: one without rastro (no `.rastro/`, no hooks, no rastro block in `AGENTS.md`) and one with it.
3. Give both the same prompt and the same model, and run each once, with no hint beyond the task description.
4. Record, for each run: the result of the `verify.*` commands at the end, the findings a reviewer raises, the size of the diff and the time taken. The two runs give different measures, so label them and do not subtract one from the other. With rastro, record first-pass (first lint of each file, with rastro), read from `<workspace>/metrics/lint.log`. Without rastro, record the end-of-run lint pass (without rastro): run `verify.lint_file` once over each changed file at the end and count how many pass.
5. Compare the two and write the numbers here.

- Result: <both runs, side by side, or "not measured">
- Measured on: <YYYY-MM-DD>
- Source: <the task, the starting commit and where each run's output is kept>
- Feeds: whether the harness pays for itself in this project. A single task is an anecdote: repeat it on another task before you rely on it.
