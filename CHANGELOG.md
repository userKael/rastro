# Changelog

## 0.2.0

The harness now grows with the project: golden paths are written from the first instance of a component type, a project can start from an empty directory, and drift is audited over time.

### Golden paths

- `architecture.golden_paths` names one folder (default `docs/golden-paths/`), with one `<type>.md` file per component type. The list form of 0.1.0 is reported by the doctor.
- A type with no golden path is a first instance: `implement` writes golden path 1.0.0 from its code, and the person approves it at a gate.
- `reconcile` classifies each component as follows, extends, contradicts or has no golden path. A contradiction stops at a gate.
- The doctor checks the frontmatter fields, the status and the instances of every golden path.
- A golden path can be verified by review or by an automated check. The doctor reports a check whose command is not on `PATH`.
- Golden paths of a boundary type (`architecture.boundary_types`) need a security section. `design-doc` asks for the threats of each boundary type.

### Execution mode

- Each run starts with a choice: stop at every gate, or continuous. It is never a config key.
- In continuous mode only confirmation gates proceed on their own. Content decisions and design-doc publication always stop, and `deliver` reports every gate that proceeded.

### Starting from an empty directory

- New skill `init`: it interviews the person about the first decisions and drafts them as ADRs for approval. It then runs `setup` with the answers and writes the walking skeleton as the intent of the first item.
- New template for ADRs.

### Stack profile

- New Node.js NestJS TypeScript stack profile, with verification recipes, testing recipes and security questions. `setup` detects NestJS and points to it.

### Drift audit and metrics

- New skill `audit` and the script `hooks/git/audit-drift`, which check the code against the golden paths. The verdicts are ok, review, drift and NOT VERIFIED.
- New CI templates to run the audit on a schedule.
- Lint verdicts are recorded and reported as first-pass and self-heal rates.
- Each plan task gets a footprint and a tier, with calibration guidance.

### Agents other than Claude Code

- `hooks/agents/adapt.sh` translates Codex CLI and Cursor hook payloads onto the same hook scripts Claude Code runs.
- `scripts/install-agent.sh` installs the skills and the hooks into a project for Codex CLI or Cursor.
- Both are covered by tests of the shim and the installer only. Runs in the agents themselves are not tested yet (see Agent support in the README).

### Adapters

- New tracker adapter `github-projects`: GitHub issues with sub-issues, mirrored into a GitHub Project's Status field.
- New docs adapter `claude-docs`, for design docs kept in Claude Docs.
- Neither has been run against the live tools yet. Their commands are marked NOT VERIFIED.

## 0.1.0

First release: seven skills, adapters for trackers, docs tools and code hosts, templates, and bash hooks in three layers (git, CI and Claude Code).
