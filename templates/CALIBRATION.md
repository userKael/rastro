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
