# <item id> Implementation Plan

> **Template.** Delete this note when filling in. The plan lives in `<workspace>/<item id>/plan.md` and is not versioned. Write the headings in `project.languages.human`; `[HUMAN]`, `D-n` and `DT-nn` stay literal.

- **Goal:** <one sentence: what exists when this plan is done>
- **Spec:** `<workspace>/<id>/reconciliation.md`
- **Execution:** <inline | subagents>, because <the criterion that applied>

## Global Constraints

The reviewer of each task receives this block verbatim. What is not here is not checked.

### Rules by ID

Text read from `architecture.rules`; do not copy it here.

- `[<rule-id>]`: <why this plan touches it>

### Delivery conventions

- Branch: `<conventions.branch>`
- Commit: `<conventions.commit>`, body explains why, trailer names the real model

### Applicable golden paths

Only the golden paths this plan uses.

- `<path>`: <why it applies>

### Relevant state machines

- `<entity>`: states `<a, b, c>`; allowed transitions `<a to b, b to c>`; defined at `<file:line>`

### Code-flow boundaries

Only the `new` and `changes` items that survived the reconciliation.

| Component | Module and type | Crossing | Transaction or job owner | Decision |
|---|---|---|---|---|

### Decisions of this item

- `D-n`, `DT-nn`: <the decisions that still bind this plan>

## Task 1: <what this task delivers>

**Files:**

- Modify: `<path>:<line range>`
- Test: `<path of the test file>`

**Interfaces:**

- Consumes: <what earlier tasks or existing code provide>
- Produces: <what later tasks rely on>

### Expected test scenarios

Written before the steps. A person writes them, or the planning step writes them under human review. The agent derives the tests from them and only then implements. A task without scenarios goes back to the gate.

1. **Given** a book with 1 copy in stock, **When** two orders reserve it at the same time, **Then** one reservation succeeds, the other is refused, and the stock is 0.
2. **Given** an order with reserved copies, **When** the order is cancelled, **Then** the copies return to stock.

### Steps

- [ ] **Step 1: Write the failing test** for scenario 1, in `<test path>`.
- [ ] **Step 2: Run it.** Expected: FAIL, with `<the failure message>`.
- [ ] **Step 3: Implement** the smallest change that makes it pass.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** with explicit paths.

## Task 2: [HUMAN] <what has to be executed>

- **Executor:** human
- **Artifact:** the literal artifact from `D-n`, copied without editing.
- **Environments:** <one by one, in order>
- **When:** <before or after the merge of which PR>
- **Rollback:** <from the human-execution block of the `D-n`, copied without editing>
- **Verification:** <what the human checks after running>
- **Blocks:** Task <N>, Task <M>

The agent never ticks these boxes by inference and never starts a blocked task before the human says to.

- [ ] Executed in `<environment>` on <YYYY-MM-DD> by <who>
- [ ] Verified in `<environment>`: <result>
