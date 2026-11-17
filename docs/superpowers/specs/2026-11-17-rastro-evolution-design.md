# Rastro workflow evolution — design

## Intent
Make rastro useful for both solo and shared development. Break a story into complete, independently reviewable deliveries when the code allows it; coordinate concurrent agents without making every PR a stack. Reduce repetitive golden-path edits and improve setup, card publication, MR readability, and naming guidance.

## Constraints
Preserve the core sequence (reconcile, breakdown, implement, deliver), file:line evidence, stable decision IDs, human decisions for content-changing gates, human execution tasks, and verified delivery. Keep Bash-only runtime and the current adapter architecture. The plugin repository itself has no .rastro/config.yml; do not run setup here. Do not alter the darker-sistem repository in this work.

## Approach
Represent delivery order as an explicit dependency graph. Each slice has a stable identity, outcome, acceptance check, depends_on list, and branch target. A root slice targets the project base; a dependent slice targets only its declared dependency. If multiple parents cannot be represented as one branch target, the orchestrator waits for their merge to base before branching. Parallelism is optional and only among ready slices with non-overlapping worktree ownership. Each agent completes one slice through verification and delivery preparation; the coordinating session owns human gates and publishes a summary.

The setup asks about capabilities and destinations rather than a global solo/team mode. It detects existing paths and conventions, offers a versioned layout guide for project-specific naming and folder rules, and keeps details in that guide rather than growing config keys for each stack. Breakdown composes full card bodies before its publication gate and records results per item, including recovery of partial publication. The MR starts with a compact reviewer summary and dependency state; detailed plan and reconciliation remain available below.

Golden paths retain a few representative canonical instances and stable rules. A new component that follows an existing pattern does not edit the golden path. Audit finds candidate components through project paths/conventions and changed diffs, and checks them against the pattern. Versions and History change only for semantic changes. The source catalog of enum/list/preset values stays in code or schema; golden paths describe invariant rules for the catalog, not every value.

## Delivery boundaries
1. Dependency-aware breakdown, implement, deliver, and optional multi-agent batch orchestration.
2. Setup, tracker publication preview/recovery, layout guide, and MR summary.
3. Golden-path instance lifecycle and audit/doctor adjustments.

Each boundary must update tests, templates, README, and relevant adapters together. Repositories using the old format remain readable; migrations must be explicit, deterministic, and documented. No claim of cross-agent portability without an end-to-end scenario on the target harness.

## Acceptance
- A story with two independent slices yields two base-targeting branches and can be implemented concurrently; a third dependent slice waits and targets the correct base.
- Human decision gates remain with the coordinator; no worker invents answers or proceeds past an unresolved decision.
- The breakdown gate shows the final cards before creating anything and can report a partial publication without duplicate cards on retry.
- A following component does not change its golden-path file; an actual pattern change still raises the appropriate gate and version.
- Existing darker-sistem conventions (screen route group, feature folder, adjacent tests) can be represented as layout guidance without hardcoding Next.js or Python in the core.
- All shipped Bash tests pass, plus a focused end-to-end dry run for the independent/dependent delivery flow.
