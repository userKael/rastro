---
name: setup
description: Installs or updates rastro in a repository. It detects the git remote, the stack, the MCP servers and the existing agent instruction files, asks only what it could not detect, one question at a time, shows the full diff and stops for approval, then writes .rastro/config.yml, the rastro block of AGENTS.md, the AGENTS.md import in CLAUDE.md, the workspace entry in .gitignore and the git hooks. Running it again with the same answers changes nothing. "setup --doctor" reports the health of an installation. Use when adopting rastro, when changing the tracker, docs tool or code host, after upgrading rastro, or to check an installation. Do NOT use to start work on a request (design-doc, breakdown or implement), or to write the team's rules, profiles or adapters.
---

# setup

**Input:** the adopter's repository, at its root. With `--doctor`, the installation to check.

**Output:** after approval, these files in the repository:

- `.rastro/config.yml`
- `AGENTS.md`, with the rastro block between `<!-- rastro:begin -->` and `<!-- rastro:end -->`
- `CLAUDE.md`, holding the line `@AGENTS.md`
- `.gitignore`, ignoring the workspace
- `.rastro/git-hooks/` and `.rastro/lib/`, with the git hooks wired through `core.hooksPath` or through the hook manager already in place
- optionally, the CI file and `.rastro/CALIBRATION.md`, only when absent

With `--doctor`, the output is the doctor's report, verbatim.

## Requirements

- `git` and `bash`. Setup calls no port capability. It reads the `## Detection` section of the adapters to propose values.
- Framework files: `${CLAUDE_PLUGIN_ROOT}/templates/config.yml`, `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`, `${CLAUDE_PLUGIN_ROOT}/templates/stack-detection.md`, `${CLAUDE_PLUGIN_ROOT}/templates/ci/`, `${CLAUDE_PLUGIN_ROOT}/templates/CALIBRATION.md`, the hooks under `${CLAUDE_PLUGIN_ROOT}/hooks/git/` and `${CLAUDE_PLUGIN_ROOT}/hooks/lib/`, the doctor at `${CLAUDE_PLUGIN_ROOT}/hooks/claude/doctor.sh`, and the adapters under `${CLAUDE_PLUGIN_ROOT}/adapters/`.
- Adapter contract: `${CLAUDE_PLUGIN_ROOT}/adapters/CONTRACT.md`, for a tool that has no shipped adapter.
- Writing rules, optional: when `.rastro/profiles/writing.md` exists, apply it to the questions, the gate and the closing report.

## Precedence

Setup writes configuration. It does not decide doctrine.

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill. No key of `.rastro/config.yml` turns off a gate, the reconciliation, the `file:line` anchor or the human executor. Setup never offers such a key and never writes one.

The text of `AGENTS.md` outside the markers belongs to the team. Setup never edits it.

## Inviolable rules

1. Detect before asking. A value that a file, the remote or the MCP configuration can answer is proposed, never asked from scratch.
2. One question at a time.
3. Write nothing before the gate. Every file and every git setting appears in the diff first.
4. Never touch `AGENTS.md` outside `<!-- rastro:begin -->` and `<!-- rastro:end -->`.
5. Refuse a `tracker.local_dir` inside the workspace. Work items must be versioned, and the workspace is gitignored.
6. Never create an empty `.rastro/profiles/` or `.rastro/adapters/`. Git does not version an empty directory, so the directory would vanish on the next clone. Say where each one goes instead.
7. Setup is idempotent. A second run with the same answers changes no file.
8. Never commit and never push. Setup leaves the files for the human to commit.

## Step 0 — Mode

With `--doctor`, run from the repository root:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/claude/doctor.sh"
```

Show its output verbatim. Do not summarize it, rank it or soften it, and never call an installation fine when the output lists a problem or says it could not check something. Then stop: `--doctor` writes nothing.

Without `--doctor`, check whether `.rastro/config.yml` exists. When it does, this is a re-run: its values count as answered, and the steps below ask only what is missing or what the human asked to change.

## Step 1 — Detect

Detect before asking. Run every detection below, then print one report: a two-column table of what was found, with no decision in it.

- **Adapters.** List the adapter files of each port, in `.rastro/adapters/<dir>/` first and then in `${CLAUDE_PLUGIN_ROOT}/adapters/<dir>/`, for `tracker`, `docs`, `code-host`, `domain-state` and `review`. An adopter file overrides a shipped file of the same kind. Read the `## Detection` section of each, and check each signal against the repository. A signal proposes a kind; it never selects one.
- **Git remote.** Run `git remote -v` and check each URL against the remote signals of the code-host and tracker adapters.
- **Base branch.** `git symbolic-ref --short refs/remotes/origin/HEAD` proposes `project.base_branch`, without the remote prefix.
- **Stack.** Read the manifests as `${CLAUDE_PLUGIN_ROOT}/templates/stack-detection.md` describes, and take its proposals for the verify commands, `verify.lint_file` and `verify.source_globs`. When no manifest gives a proposal, the key stays empty: a command that cannot fail reports success without checking anything.
- **MCP servers.** Take only the server names from `.mcp.json` and `~/.claude.json`: the keys of their `mcpServers` objects. Never print `~/.claude.json` and never read it whole: it may hold tokens. Check each MCP signal of the adapters with a command that prints nothing but the result, such as `grep -qE '"<name>"[[:space:]]*:' ~/.claude.json`. A server that exists only in `~/.claude.json` is personal: other clones do not have it. Say so. Moving it to `.mcp.json` is a decision for whoever manages the credentials, not for setup.
- **Instruction files.** Whether `AGENTS.md` exists, and whether it already has the rastro markers. Whether `CLAUDE.md` exists, and whether it has the line `@AGENTS.md`. An `AGENTS.md` with one marker and not the other is broken: stop and report it, and do not guess where the block ends.
- **Existing linters.** A lint configuration feeds the stack proposals. A commit-message linter configuration runs next to the rastro `commit-msg` hook, so both validate every commit: report it, because two different formats reject every commit.
- **Hooks.** The value of `git config --local --get core.hooksPath`. Then the directory that `git rev-parse --git-path hooks` prints, never an assumed `.git/hooks`, and any active hook in it that is not a `.sample` file. That command honors a `core.hooksPath` set at any level.
- **PR template.** The default template path the code-host adapter names, and any tracked file whose name matches `pull_request_template` in any case, as `git ls-files` lists them. A file found proposes `code_host.template`.
- **superpowers.** Whether the superpowers skills are installed, as the doctor checks. Without them, every skill uses its built-in fallback, and the report says so.
- **Project name and modules.** The manifest or the directory name proposes `project.name`. The top-level source directories propose `architecture.modules`.

## Step 2 — Ask

One question at a time. Each question names the detected value, when there is one, as the recommended answer. Ask with the structured question tool, recommended option first. Without that tool, end the turn with the question.

A detected value the human has no reason to doubt is not asked: it shows in the diff, where the human can still correct it. Ask, in this order, only what is still open:

1. `tracker.kind`: `local`, `none`, a shipped adapter, or the name of the team's own adapter.
2. `tracker.key`, unless the kind is `none`. Propose `W` for `local`. When the tracker adapter fixes the key, propose that key: `GH` for the shipped adapter whose item ids are `GH-<n>`. Read the key from the adapter file, never from memory.
3. `tracker.local_dir`, only for `local`, with `work/` proposed.
4. `docs.kind`, with `repo` proposed, then `docs.location` when the kind is not `repo`.
5. `code_host.kind`, then `code_host.merge`, with `squash` proposed, then `code_host.template` when Step 1 found a PR template.
6. `domain_state.kind`: `none`, `schema-files` with `domain_state.schema_files`, or `db-mcp` with `domain_state.server` among the detected MCP servers.
7. `project.languages.human`.
8. The verify commands the stack did not propose, then `verify.integration` and `verify.integration_when`, which have no portable proposal.
9. `architecture.modules`, confirming the proposal.
10. `architecture.sensitive_data`: the classes of data never logged and never committed, such as customer addresses.
11. `docs.public_portal`, when the repository publishes documentation for other teams.
12. Whether to write the CI file from `${CLAUDE_PLUGIN_ROOT}/templates/ci/`. Offer it only when a template exists whose file name starts with `code_host.kind`, and only when its destination does not exist. The first line of the template says where the file goes.
13. Whether to write `.rastro/CALIBRATION.md` from `${CLAUDE_PLUGIN_ROOT}/templates/CALIBRATION.md`, where the team records its own measurements. Offer it only when that file does not exist.

An optional file whose destination exists is never offered and never written. Leave it as it is, and say so at the gate: the team may have filled its toolchain step or recorded its measurements there. When the first line of the CI template says to merge its job into a file that already exists, show the job to merge in the closing report, and never overwrite that file.

Answers that need a check before they are accepted:

- **`tracker.local_dir`.** Refuse a directory equal to the workspace or inside it, and a directory that `git check-ignore -q` reports as ignored. Say why, then ask again: the state table reads items from git, and an unversioned item makes the table lose its source.
- **`tracker: none`.** Before accepting it, say what it loses. The item lives only in the conversation and the workspace. The work cannot be resumed before the PR exists. The reconciliation goes to the PR description. The state table starts at the branch row. Name `local` as the option that keeps items versioned without a tracker tool.
- **A tool with no adapter.** When the answer names a tool that has no adapter file in either location, point to `${CLAUDE_PLUGIN_ROOT}/adapters/CONTRACT.md`. The team writes `.rastro/adapters/<dir>/<kind>.md` from it. Until that file exists, every skill that uses the port stops, and the doctor reports `missing adapter <dir>/<kind>`. Offer the tool-free kind of that port for the meantime: `local` or `none` for the tracker, `repo` for docs, `none` for the code host.

## Step 3 — Compose

Build every file in a temporary directory outside the repository, from `mktemp -d`. Nothing in the repository changes in this step.

### `.rastro/config.yml`

Start from `${CLAUDE_PLUGIN_ROOT}/templates/config.yml`, keeping its comments, and fill in the answers. Lists stay inline, as `[a, b]`: the hooks read nothing else. On a re-run, start from the existing file instead. Change only the keys answered in this run, and add the keys that are new in the template with their defaults.

### The AGENTS.md block

Copy `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md` and fill its two placeholders:

- `{{tracker_item}}`: what an item is for the chosen tracker, in the words of its adapter, such as "issue". For `tracker: local`, it is an item file in `tracker.local_dir` on `project.base_branch`.
- `{{state_table_first_row}}`: for any tracker other than `none`, replace that line with the row below, with `<item>` worded like `{{tracker_item}}`.

```
| No <item> exists | `breakdown` |
```

With `tracker: none`, delete the `{{state_table_first_row}}` line and the two rows that contain `{{tracker_item}}`. Delete the lines themselves, so no blank line is left inside the table: the table starts at the branch row.

After filling, search the block for `{{`. When any placeholder remains, stop and report it with its line: the template has a placeholder this skill does not fill, and writing it would put a raw placeholder in `AGENTS.md`.

The block never carries an installation path. `AGENTS.md` is versioned and read on other machines, and a path written there is right on one machine only. Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` by itself. Another agent reads the installation directory from the environment variable `RASTRO_ROOT`, so the closing report tells the human to export it on each machine that runs such an agent.

`## Non-negotiable rules` inside the block belongs to the team. The section runs from its heading to the next `## ` heading inside the block, or to `<!-- rastro:end -->` when no heading follows. On a re-run, when the existing block's `## Non-negotiable rules` section differs from the shipped example, keep that section verbatim. Everything else between the markers is regenerated from the template.

Place the block:

- `AGENTS.md` with the markers: replace everything from `<!-- rastro:begin -->` to `<!-- rastro:end -->`, both included.
- `AGENTS.md` without them: append the block at the end, after a blank line.
- No `AGENTS.md`: create it with the block alone.

### `CLAUDE.md`

When an agent harness finds `CLAUDE.md`, it may read that file instead of `AGENTS.md`. The line `@AGENTS.md` imports the block.

- No `CLAUDE.md`: create it with the single line `@AGENTS.md`.
- `CLAUDE.md` without that line: add it as the first line, and keep the rest as it is.
- `CLAUDE.md` with the line: leave it untouched.

### `.gitignore`

When `git check-ignore -q` says the workspace (`workspace` in the config) is not ignored, add it as one line of `.gitignore`. Create the file when it does not exist. Never add the line twice.

### Git hooks

Copy `${CLAUDE_PLUGIN_ROOT}/hooks/git/*` to `.rastro/git-hooks/` and `${CLAUDE_PLUGIN_ROOT}/hooks/lib/*` to `.rastro/lib/`, replacing what a previous run installed. The files in `.rastro/git-hooks/` are executable. `pre-commit` and `commit-msg` are the git hooks; the other files there are the checks the CI file calls.

Then wire them by the value of `git config --local --get core.hooksPath`:

- Already `.rastro/git-hooks`: nothing to change.
- Pointing to another directory: a hook manager owns the hooks.
  - Resolve the directory from the repository root, `git rev-parse --show-toplevel`. When it resolves outside the repository, stop and report: a hooks directory outside the repository is not versioned with it, and may serve other repositories.
  - Append the line `.rastro/git-hooks/pre-commit "$@"` to its `pre-commit` hook and `.rastro/git-hooks/commit-msg "$@"` to its `commit-msg` hook, only when that hook file is tracked: `git ls-files --error-unmatch <dir>/<hook>` exits 0. Otherwise stop and ask the human where the manager's versioned hook lives. A manager may generate the directory from its own versioned file, and a line appended to a generated or untracked file reaches one clone only.
  - Never append a line that is already there.
- Not set: plan to run `git config core.hooksPath .rastro/git-hooks`. Git keeps that setting in the local configuration, which is not versioned, so each clone runs the command once. When the directory that `git rev-parse --git-path hooks` printed holds active hooks, that setting turns them off: say so at the gate.

### Optional files

- The CI file, when the human said yes and its destination is absent: the template from `${CLAUDE_PLUGIN_ROOT}/templates/ci/` for `code_host.kind`, at the path its first line names. Its toolchain step stays for the team to fill: rastro cannot guess the runtime the verify commands need.
- `.rastro/CALIBRATION.md`, when the human said yes and the file is absent: a copy of `${CLAUDE_PLUGIN_ROOT}/templates/CALIBRATION.md`.
- Nothing else. No empty `.rastro/profiles/` and no empty `.rastro/adapters/`.
- Setup does not create `tracker.local_dir`. The `breakdown` skill creates it with the first item.

## Step 4 — Gate

Show the diff of each file against the repository, with `git diff --no-index` for a changed file and the whole content for a new one. Then show the git setting setup will change, if any.

When nothing differs, say that the installation is current and stop: there is nothing to approve.

**Gate — setup of <project.name>: write these files?** Class: fork. State:

| | |
|---|---|
| Tracker | `<tracker.kind>`, key `<tracker.key>` |
| Docs and code host | `<docs.kind>`; `<code_host.kind>` with `<code_host.merge>` merge |
| Verify | <n> of 4 commands set; per-file lint <set or empty> |
| Git hooks | `core.hooksPath` set, or calls appended to <manager directory> |
| Files | <n> created, <m> changed, <k> unchanged |

Below the table, one line per note that applies:

- With `tracker: none`: what it loses, in one line.
- A kind without an adapter: the skills that use that port stop until `.rastro/adapters/<dir>/<kind>.md` exists.
- With `core.hooksPath` set by this run: each clone runs `git config core.hooksPath .rastro/git-hooks` once.
- Active hooks in the current hooks directory that the new setting turns off.
- An optional file left as it is because it exists, and a CI job to merge by hand.
- A personal MCP server the config relies on, absent from `.mcp.json`.
- Profiles and adapters: create `.rastro/profiles/<skill>.md` or `.rastro/adapters/<dir>/<kind>.md` when the team needs one. The rastro README explains both, and `${CLAUDE_PLUGIN_ROOT}/adapters/CONTRACT.md` gives the adapter format.

Ask with the structured question tool, recommended option first: write the files, change an answer, or stop. Without that tool, end the turn with the question. Write nothing until the human chooses to write.

## Step 5 — Write

After the human chose to write:

1. Copy each composed file into the repository.
2. Make the files in `.rastro/git-hooks/` executable with `chmod +x`.
3. Apply the hook wiring of Step 3: the `git config` command, or the appended lines.
4. Run the doctor as in Step 0, and show its output verbatim.

Then print the closing report:

- The files to commit, each by its explicit path. Hooks are staged with `git add --chmod=+x .rastro/git-hooks/<file>`, so the executable bit survives on systems that do not record it.
- When this run set `core.hooksPath`: each clone runs `git config core.hooksPath .rastro/git-hooks` once.
- When the CI file was written: the team fills in its toolchain step, the `toolchain:` comment in the file, before the first pipeline runs. When the job must be merged by hand: the job, ready to merge.
- When the block is new: the team replaces the example rule in `## Non-negotiable rules` with its own rules, each by ID. Setup keeps that section on every re-run once it differs from the example.
- For an agent other than Claude Code: export `RASTRO_ROOT` with the rastro installation directory on each machine that runs it.
- Every problem the doctor reported, with nothing added and nothing removed.

## Handoff

Setup stops after the closing report. The state table in the new block says where work starts: an unshaped request goes to `design-doc`, a shaped one to `breakdown`.

## What this skill does NOT do

| Not this skill | Who does it |
|---|---|
| Write the team's rules, profiles or adapters | the team, from the README and `${CLAUDE_PLUGIN_ROOT}/adapters/CONTRACT.md` |
| Commit or push the files it writes | the human |
| Edit `AGENTS.md` outside the markers | nobody: that text is the team's |
| Fix what the doctor reports | the human, then a re-run of setup |
| Offer a key that turns off a gate, the reconciliation, the anchor or the human executor | nobody: doctrine is not configurable |
| Start work on a request | `design-doc`, `breakdown`, `implement` |
