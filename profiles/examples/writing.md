# Example profile: writing rules

A starting point for how a team writes the text that people read in a repository. It is an example, not doctrine. Copy it to `.rastro/profiles/writing.md`, cut what your team does not want and add what it does.

## Scope

The rules apply to every text that a person reads and the repository governs: `AGENTS.md`, skill and profile files, docs, PR descriptions, commit bodies, gate texts, tracker comments and design docs. They do not apply to code or to identifier names.

## Two tests per sentence

Ask of each sentence: does it change what the reader does? Does it serve the reader's interest or mine? Cut the sentence that fails either test.

The failure these tests guard against is an essay written where the request was an operating norm.

## Rules

- **Measured vs hypothesis.** Say which one it is, explicitly, every time. `212 tests, 0 failures` is a measurement. `coverage should be fine` is a hypothesis. A hypothesis dressed as a number is the costliest defect a document can carry, because the reader acts on the number.
- **Provenance is a date and a source, not a recipe.** `read on <YYYY-MM-DD> from <source>` fits on one line. The query or command that produced a number enters only when it is not obvious, and then it sits in a collapsed block, never on the reading path. Without this rule, the recipe lands between the reader and the finding.
- **Number instead of qualifier.** Write no `much`, `significantly` or `far better` without the number beside it. When there is no number, write that there is none.
- **Bottom line up front, per unit.** A paragraph, a table cell and a decision record open with the decision, the answer or the action. This governs the unit, not the order of sections. A versioned template defines the section order, and it wins.
- **One idea per sentence.** Split the sentence instead of adding a comma or a semicolon.
- **Active voice, named actor.** `The order service reserves the copies`, not `the copies are reserved`.
- **Present for a fact, imperative for a procedure.** Fact: `The handler returns 409 when stock is short.` Procedure: `Run the migration, then restart the worker.`
- **Fact, then consequence.** `Stock is read without a lock, so two orders can reserve the last copy.`
- **One word, one meaning.** Do not vary vocabulary for style. A document that says `reservation` never calls the same thing a `hold`.

**Always cut:** a preamble, a warm-up, a closing summary, narration of your own process (`Cross-checking the schema against the code, I found that...`), scope beyond the request that only makes the text look complete, decorative adjectives and a marketing tone.

**Never cut: uncertainty, caveat, limit, anchor.** The test for a caveat: if it changes what someone does, it stays. If it only protects the writer, it goes.

## Anchors are not ornament

A generic writing guide attacks parentheses, dashes and subordinate clauses. In a technical text those constructions hold anchors, symbols and counts, and a style pass that strips them deletes facts. Three things stay, whatever a generic guide says.

- **The anchor stays in the body.** A `file:line`, a table, a column, an enum, a symbol. The reader is a developer or an agent, and the `reconcile` skill checks each claim against its anchor. The advice to avoid tool mechanics is for non-technical readers and does not apply here.
- **"X already does this today" stays.** Grounding a proposal in what exists shows the design is viable. `PlaceOrderService already reserves copies without touching the order status` is that proof, and it is not a display of effort.
- **The rejected alternative stays, with the reason.** The `Why (b) lost` field of each decision in the design-doc template exists for this. A ban on the "X, not Y" construction erases the argument for the discard, and that argument keeps the same alternative from returning to the table months later with nobody remembering why it fell.

Not measured for this profile: how often these constructions carry facts in your documents. To find out, take one document, list its facts, run your style pass and list them again.
