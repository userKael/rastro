# rastro

A development workflow for coding agents, packaged as a Claude Code plugin: skills, adapters, templates and bash hooks. The aim is that two people with the same request walk the same path and leave the same trail. *Rastro* is Portuguese for trail.

## What rastro is

rastro is seven skills that take a change from an unshaped request to an open pull request, and the files they share.

| Skill | Takes | Produces |
|---|---|---|
| `setup` | your repository | `.rastro/config.yml`, a block in `AGENTS.md`, git hooks |
| `design-doc` | a request with no shape, an ADR, a requirements document | a design doc published for the team to discuss |
| `breakdown` | a design doc, a bug or a well-formed request | work items, with the reconciliation in the top item |
| `reconcile` | an intent file and a scope | `reconciliation.md`, with `file:line` evidence |
| `domain-context` | a domain question | the real state of the domain: schema, rules, constraints |
| `implement` | a work item id | a branch with verified commits |
| `deliver` | that branch | a PR that is open and linked to its item |

The skills never name a tool. A skill reads `.rastro/config.yml`, finds the adapter for the tool you declared, and asks the adapter how to do each step. The adapters are markdown files, so you can read them, change them or replace them.

What ships in the repository:

| Directory | Holds |
|---|---|
| `skills/` | the seven skills |
| `adapters/` | one markdown file per tool, grouped by port, and the contract they follow |
| `templates/` | the config, the `AGENTS.md` block, the work item, the design doc, the plan, the PR description, CI files |
| `hooks/` | the git hooks and the Claude Code hooks |
| `profiles/examples/` | an example architecture profile and an example set of writing rules |
| `scripts/` | the checks the repository runs on itself |

rastro does not ship an automated review engine. It defines the format of a review rule, and the `none` review adapter. It does not measure the impact of a change across repositories.

Status: version 0.1.0. The tool commands in the shipped adapters were not verified against live tools. Agents other than Claude Code are untested (see Agent support).

## The flow

Five stages, in this order:

1. `design-doc`, when the request has no shape yet.
2. `breakdown`, which turns an intent into work items.
3. `implement`, which turns one item into a branch with verified commits.
4. `deliver`, which opens the PR and links it to the item.
5. Review of the open PR: automatic when `review.kind` is not `none`, human always.

`reconcile` and `domain-context` run inside the stages. `breakdown` and `implement` call `reconcile`, which compares the intent with the code in both directions: what the intent says that the code contradicts, and what the code does that the intent ignores. It calls `domain-context` to read the real schema. Zero findings in the second direction is treated as suspect, not as success.

No skill drives the flow. The position follows from the artifacts: read the tracker and git, and the next step is in this table. `setup` writes the table into your `AGENTS.md`, with "item" worded for your tracker.

| What you observe | Next step |
|---|---|
| No work item exists | `breakdown` |
| An item exists, without `## Reconciliation` | `implement`, which calls `reconcile` |
| An item with `## Reconciliation`, no branch | `implement` |
| A branch with verified commits, no PR | `deliver` |
| A PR is open | review |

Every skill stops at a gate before the step that is hard to undo, and a gate stops by default: no skill moves to the next stage without an explicit choice. A gate has three parts.

1. A title that is the question: `Gate — PR #12 open: stop or continue to W-14?`.
2. A two-column state table.
3. The decision. A fork between two to four paths goes through the structured question tool when the agent has one. A list of `D-n` or `DT-nn` items that each need an answer goes in a table, one item per row. Where there is no question tool, the gate ends the turn with the question. A subagent never asks the human.

Work files live in the workspace, `.agent/` by default. It is gitignored. What has to outlive the branch goes in the PR description: the divergences from the design doc, the closed decisions, the agent's rulings and the plan.

## What is not configurable

These rules are the doctrine. They have no configuration key.

- The sequence of stages above.
- The state table in `AGENTS.md`, with no orchestrating skill.
- Reconcile before slicing, in both directions.
- The `file:line` anchor: a claim about code carries the file and the line that back it.
- A decision the agent cannot execute has a human executor. The agent drafts the artifact and a person runs it.
- Stable `D-n` and `DT-nn` identifiers: a number is never reused or renumbered.
- Gates that stop by default, with the fixed anatomy above.
- A written verdict before editing a test that fails: which artifact is wrong (test, code or design doc), why, with the `file:line` that defines the correct behavior, and which file will change.
- Agent artifacts are not versioned.
- Source precedence when sources conflict: code and green tests, then `AGENTS.md`, then ADRs, then golden paths and patterns, then the plan of the item in progress, then the design doc.
- Ground the vocabulary of a design doc in the code, and never its decisions.

Config fills gaps and never disables the doctrine. No key turns off a gate, the reconciliation, the anchor or the human executor, and `setup` never offers one. A profile cannot override the doctrine, and neither can the team's text in `AGENTS.md`. Every skill says so in its own file: `Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.`

Profiles and `AGENTS.md` do take part in another precedence, the one for architecture rules, conventions, templates and rulers. From strongest to weakest: the team's `AGENTS.md`, the team's profile in `.rastro/profiles/`, the default of the skill, the defaults of superpowers.

## Install

Requirements: `git` and `bash`. On Windows, use Git Bash. Nothing else is needed at runtime: no `jq`, no `yq`, no Python, no Node.

```bash
claude plugin marketplace add userKael/rastro
claude plugin install rastro@rastro
```

To try a local checkout without installing it:

```bash
claude --plugin-dir <path-to-rastro>
```

Claude Code invokes the skills of a plugin as `/<plugin>:<skill>`, so these are `/rastro:setup`, `/rastro:design-doc`, `/rastro:breakdown`, `/rastro:reconcile`, `/rastro:domain-context`, `/rastro:implement` and `/rastro:deliver`.

Install the plugin once per machine. Run `/rastro:setup` once per repository.

## Configure

Run `/rastro:setup` in your repository. It detects before it asks: the git remote, the stack manifest, the MCP servers in `.mcp.json` and `~/.claude.json`, an existing `AGENTS.md` or `CLAUDE.md`, and any linter or commit-message tool. It asks the rest one question at a time, shows the diff of every file, and stops for your approval. It writes nothing before that and it never commits.

On approval, it writes:

| File | Content |
|---|---|
| `.rastro/config.yml` | your answers |
| `AGENTS.md` | the rastro block between `<!-- rastro:begin -->` and `<!-- rastro:end -->`. The rest of the file is yours and `setup` never edits it |
| `CLAUDE.md` | the line `@AGENTS.md`, created or added, because Claude Code reads `AGENTS.md` only when no `CLAUDE.md` exists |
| `.gitignore` | the workspace |
| `.rastro/git-hooks/`, `.rastro/lib/` | the git hooks, wired through `core.hooksPath` or through the hook manager already in place |
| CI file, `.rastro/CALIBRATION.md` | only when you say yes |

`setup` is idempotent: a second run with the same answers changes nothing. `/rastro:setup --doctor` prints the health of the installation and writes nothing.

The shortest valid config:

```yaml
project:
  name: bookstore
  languages:
    human: en

tracker:
  kind: local
  key: W

code_host:
  kind: github

verify:
  unit: npm test
```

Required: `project.name`, `project.languages.human`, `tracker.kind`, `tracker.key` unless the kind is `none`, `code_host.kind`, and at least one `verify` command. `templates/config.yml` lists every key with its default and a comment. A key left out takes that default, so the config above still refuses `.env*`, `*.bak` and `.agent/` at commit time, and still validates the PR title as with `squash`. An explicit empty list, `[]`, stays empty. Lists are written inline (`[a, b]`), because the hooks read nothing else.

The default pattern `.env*` also refuses `.env.example`. Negation is not supported: to commit `.env.example`, list exact names in `conventions.forbidden_paths` instead, such as `[.env, .env.local, "*.bak"]`.

### Profiles

A profile is a markdown file that replaces a default of one skill. Put it at `.rastro/profiles/<skill>.md`, for example `.rastro/profiles/breakdown.md`. Each skill says, at the step where it uses a ruler or a template, which section of its profile replaces it.

| Skill | What a profile can replace |
|---|---|
| `design-doc` | the section template, the rule for splitting a document |
| `breakdown` | the story and subtask rulers, the format of the subtask summary |
| `reconcile` | the threshold of the size signal |
| `deliver` | the sections of the PR description |
| every skill | `## Additional checks`: extra checks, each with the step where it runs, what it verifies and whether it is a gate or an observation |

Writing rules go in `.rastro/profiles/writing.md`, and every skill applies them to the text a person reads. `profiles/examples/writing.md` is a starting point. `profiles/examples/architecture-services/` holds an example set of architecture rules in a bookstore domain, and four golden paths with gaps for your stack.

`setup` does not create `.rastro/profiles/` or `.rastro/adapters/`, because git does not version an empty directory. Create each one when you have a first file for it.

### Rules

The non-negotiable rules of your project live in `AGENTS.md`, in the section `## Non-negotiable rules` of the rastro block. `setup` keeps that section when it runs again. Every rule has an ID and four parts:

```markdown
- **[module-public-api]** A module imports another only through its public API.
  **Symptom:** an import of `<other-module>/internal/...`.
  **Why here:** <the real consequence in your codebase>.
  **Ask the author:** <what the review comment asks for>.
  **Known debt:** <files that already violate the rule; optional>.
```

Skills cite a rule by its ID, never by its position. `deliver` generates its self-check from the list, so no skill copies the text of a rule. Known debt is not precedent: a new file with the same defect is a blocking violation.

### Calibration

rastro ships no calibration numbers. Where another workflow would quote a figure, the default rulers say "measure". `.rastro/CALIBRATION.md`, from `templates/CALIBRATION.md`, is where you record your own measurements, each with a date and a source.

## Working without an issue tracker or a docs tool

You need neither. Each row below is a mode that needs no external tool. Together they cover the tracker, the docs tool, the code host, the database connection and superpowers.

| Setting | What the flow does | What you lose |
|---|---|---|
| `tracker: local` | An item is a markdown file in `tracker.local_dir` (default `work/`), with frontmatter and the same sections as a tracker item. There is no status field: the state table reads the branch and the PR | An item exists for other clones only after its PR merges into the base branch |
| `tracker: none` | The item lives in the conversation and in the workspace. The reconciliation goes to the PR description | The work cannot be resumed before the PR exists. The state table starts at the branch row. `setup` says so before it accepts `none` |
| `docs: repo` | `design-doc` creates the branch `docs/design-<slug>` and opens a PR with `docs/design/<slug>.md`. The PR is where the team discusses, and its merge is the approval. The publication gate opens the PR and never merges it | The version is a commit sha, not a counter. With `code_host: none` there is no PR, so there is no place for the discussion |
| `code_host: none` | `deliver` audits the branch and writes the PR description to `<workspace>/<id>/pr-description.md` | A person pushes the branch and opens the PR. There is no URL, no CI state and no automatic link between item and PR |
| `domain_state: none` | `domain-context` reads the migrations and the ORM schema | Every claim about the live database is marked `NOT VERIFIED` |
| superpowers absent | Each skill uses a built-in fallback, listed below | Not measured: how the built-in fallbacks compare with the superpowers skills |

With `tracker: local`, the item enters the base branch like any other change. After the breakdown gate, `breakdown` creates the branch `chore/<id>-<slug>`, commits the item files and opens a PR through the code host. With `code_host: none` it commits on the branch and says that the merge is manual. The link between an item and its PR is the item id in the PR title.

Without superpowers, the skills fall back like this:

| Where | With superpowers | Without |
|---|---|---|
| `implement`, the plan | `writing-plans` | `templates/plan.md` |
| `implement`, the execution | `subagent-driven-development` when the skill's size criteria are met | inline, one task at a time, one commit per task |
| `breakdown`, the bug branch | `systematic-debugging` | a short built-in protocol: reproduce, hypothesis, evidence, root cause with `file:line` |
| `deliver`, opening the PR | `finishing-a-development-branch` | straight through the `code_host` port |
| `design-doc`, the craft | a general design-doc skill, when installed | `templates/design-doc.md` |

## Bring your own adapter

Adapters ship for these tools:

| Port | Config key | Shipped adapters |
|---|---|---|
| `tracker` | `tracker.kind` | `jira`, `github`, `local`, `none` |
| `docs` | `docs.kind` | `notion`, `repo` |
| `code-host` | `code_host.kind` | `github`, `gitlab`, `none` |
| `domain-state` | `domain_state.kind` | `db-mcp`, `schema-files`, `none` |
| `review` | `review.kind` | `none` |

The tool commands and tool names in these adapters were not verified against live tools. Check each one once before you rely on it.

If your tool has no adapter, write one. Create `.rastro/adapters/<dir>/<kind>.md`, for example `.rastro/adapters/tracker/linear.md`, then set the port's `kind` to `linear` in `.rastro/config.yml`. The format is the public contract in [`adapters/CONTRACT.md`](adapters/CONTRACT.md): the sections every adapter has, the marker lines that declare its requirements, and the capabilities of each port by name.

A skill looks for the adapter in your repository first, then in rastro. Yours wins, so you can also replace a shipped adapter by writing one with the same `kind`. When neither exists, the skill stops and reports the missing file. It never improvises a capability that no adapter describes. `/rastro:setup --doctor` reports the same condition as `missing adapter <dir>/<kind>`, and it reads the requirements of your adapter like those of a shipped one.

Until your adapter exists, set the port to its tool-free kind: `local` or `none` for the tracker, `repo` for docs, `none` for the code host.

## Hooks in three layers

| Layer | What it does | Applies to |
|---|---|---|
| 1. Git hooks | `pre-commit` refuses a staged file that matches `conventions.forbidden_paths`. `commit-msg` validates the message against `conventions.commit`. It requires the `[id]` only when the branch name carries an id, and a design doc branch does not | Any agent, and people |
| 2. CI | `check-changed-paths` fails when a forbidden path is in the change set. `check-pr-title` validates the PR title as a commit message when `code_host.merge` is `squash`. `check-commits` validates the message of every commit of the branch when it is not. `run-verify` runs the `verify.*` commands, and fails when none is configured. Templates ship for GitHub and GitLab in `templates/ci/`, and `setup` offers to write one | Any agent, and people |
| 3. Agent harness | `guard-git.sh` denies `git add -A`, `git add .`, `git add --all`, `git commit -a` and `--no-verify`, also behind `git -C <dir>`. It also denies any `core.hooksPath` other than `.rastro/git-hooks`, set with `git config` or `git -c`. After each file edit, the hook runs `verify.lint_file` on that file, and tells the agent when the linter is missing. When the agent tries to stop, the hook lints the changed files that match `verify.source_globs` and blocks while the result is red, and lists the `verify.typecheck`, `verify.unit` and `verify.integration` commands that still need to run. At session start, the hook runs the doctor | Claude Code only |

Four limits:

- With `code_host.merge` set to `squash`, the default, CI validates the PR title, because the title becomes the commit on the base branch. The individual commit messages are then checked by the local `commit-msg` hook, not by CI, because they never reach the base branch. With any other merge mode, `check-commits` validates every commit message of the branch in CI, so a commit made in a clone without the hook is caught there.
- Layer 3 starts once `setup` has written `.rastro/config.yml`. Until then, `guard-git.sh` and the lint hooks exit without checking anything, and the doctor says to run `setup`. Installing the plugin is not enough.
- Git has no hook for `git add`, so only layer 3 denies the wildcard forms. A file that a wildcard drags in is still refused by layer 1.
- `guard-git.sh` reads the command text of each shell call. It is a guard against slips, not a sandbox: a command that a script assembles at run time is not seen.

The git hooks, the CI scripts and the Claude Code hooks need bash and git, and no other dependency. On Windows they run in Git Bash. The doctor never blocks a session. It reports each problem, and it says so when it could not check something instead of reporting a pass.

`setup` installs the git hooks by copying them to `.rastro/git-hooks/` and setting `core.hooksPath`. Git keeps that setting in the local configuration, which is not versioned, so each clone runs `git config core.hooksPath .rastro/git-hooks` once. When a hook manager is already in place, `setup` appends a call to its `pre-commit` and `commit-msg` hooks instead.

## Agent support

Claude Code is the reference. The plugin, the `/rastro:<skill>` commands and layer 3 of the hooks exist only there. Layers 1 and 2 work with any agent and for people.

Other agents that read AGENTS.md and SKILL.md: compatible by design, not tested.

To try rastro in such an agent:

- Export `RASTRO_ROOT` with the path of the rastro directory. The skills cite their files as `${CLAUDE_PLUGIN_ROOT}/...`, which Claude Code replaces by itself. Another agent reads the same directory from `RASTRO_ROOT`.
- Copy or link the skills where that agent discovers skills. Keep `adapters/`, `templates/` and `profiles/` in the rastro directory: each file exists once, and the skills reach it through `RASTRO_ROOT`.
- Run `setup` for the repository. Its gates end the turn with the question when the agent has no structured question tool.

## License

MIT. See [LICENSE](LICENSE).
