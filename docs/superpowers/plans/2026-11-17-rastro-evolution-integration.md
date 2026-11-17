# Rastro Evolution Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate three independently implemented rastro workflow improvements into one verified branch.

**Architecture:** Flow, setup/publication, and golden-path changes are developed in isolated worktrees from a common base. Integrate their commits sequentially, resolve contract conflicts, and update shared documentation once.

**Tech Stack:** Markdown skills/templates/adapters, Bash hooks and tests.

**Spec:** `docs/superpowers/specs/2026-11-17-rastro-evolution-design.md`

## Global Constraints

- Preserve the stage sequence, file:line evidence, stable decision IDs, human content decisions, and verified delivery.
- Preserve compatibility with old items and golden paths.
- Runtime remains Bash-only; no darker-sistem changes in this branch.
- No push or PR creation without an explicit request.

## Review Focus

- Partial tracker publication must not duplicate cards on retry.
- Independent slice must target project base, not a previous slice.
- Multi-parent dependency must wait until parents land on base.
- A following golden-path instance must leave the GP file unchanged.
- Existing config and golden-path files must still pass doctor.

---

### Task 1: Integrate agent branches

**Files:** Agent-owned files across skills, adapters, hooks, templates, and tests.

**Interfaces:** Flow packet must match publication adapter markers/status; implement lifecycle must match golden-path audit semantics.

- [ ] Collect each agent's commit IDs and focused test evidence.
- [ ] Cherry-pick or merge each branch into `codex/rastro-evolution` and resolve shared-file conflicts according to the spec.
- [ ] Compare actual interfaces across boundaries and repair mismatches.
- [ ] Run focused tests for flow, publication, golden paths and doctor.

### Task 2: Update shared documentation

**Files:** `README.md`, `CHANGELOG.md`, spec/plan, tests that assert README text.

**Interfaces:** Describe only behavior demonstrated by Task 1.

- [ ] Write README changes for dependency graph, batch implementation, publication recovery, layout guide, and exemplar golden paths.
- [ ] Update changelog and documentation tests as needed.
- [ ] Run `bash tests/run.sh` and confirm all tests pass.

### Task 3: End-to-end review

**Files:** Any defects discovered in integrated code/tests.

**Interfaces:** One solo flow and one two-root-one-dependent flow must match the spec.

- [ ] Inspect diffs and run an end-to-end dry run using fake tracker/code-host adapters or fixtures.
- [ ] Review the branch for compatibility and unsafe publication behavior; fix verified defects.
- [ ] Run `bash tests/run.sh`, capture the final result, and report commits/remaining limitations.
