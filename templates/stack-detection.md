# Stack detection

The `setup` and `init` skills read the repository's CI workflow files and manifests, and propose values for the `verify.*` keys of `.rastro/config.yml`. Every value is a proposal: the skill shows it, and writes only what the human confirms. A proposal comes from a file or a script the repository already has. When none exists, the key stays empty, because a command that cannot fail reports success without checking anything.

`verify.integration` and `verify.integration_when` have no portable proposal; the skill asks.

`verify.lint_file` runs after each edit with `{file}` replaced by the edited path. It must take one file and exit non-zero on a finding. `verify.source_globs` is an inline list of the globs of source files the Stop hook checks.

## CI workflows

Detect: the CI workflow files below. A command that CI runs is the one that really verifies the code, so it comes before the manifest proposals.

| CI system | Files | Commands |
|---|---|---|
| GitHub Actions | `.github/workflows/*.yml`, `.github/workflows/*.yaml` | the `run:` of each step |
| GitLab CI | `.gitlab-ci.yml`, and the local files its `include:` names | the `script:` of each job |
| Bitbucket Pipelines | `bitbucket-pipelines.yml` | the `script:` of each step |
| CircleCI | `.circleci/config.yml` | the `run:` of each step, or its `command:` |
| Azure Pipelines | `azure-pipelines.yml` | the `script:` of each step |

| Key | Proposal | When |
|---|---|---|
| `verify.lint` | the command of the step that lints | a step lints the whole project |
| `verify.typecheck` | the command of the step that type-checks | a step type-checks the whole project |
| `verify.unit` | the command of the step that runs the unit tests | a step runs the unit tests |
| `verify.integration` | the command of the step that runs the integration tests | a step runs them; `verify.integration_when` is still asked |

When a CI step and a manifest section below propose different commands for the same key, propose the CI step, and show the manifest proposal next to it in the detection report.

Never propose these as a verify command; show them in the detection report instead:

- a step that checks out, installs, caches, builds a release, deploys or publishes;
- a step that calls `.rastro/git-hooks/`: those are rastro's own checks, which run the verify commands, so a verify command that calls them calls itself;
- a command that reads a variable only CI sets, such as a matrix value, a CI token or a CI path: it fails on a developer's machine;
- a step that runs more than one command: ask which one each key takes.

`verify.lint_file` and `verify.source_globs` never come from CI: a CI step checks the whole project, not one file. They come from the manifest sections below.

## package.json

Detect: `scripts` in `package.json`, `tsconfig.json`, and an ESLint configuration file.

| Key | Proposal | When |
|---|---|---|
| `verify.lint` | `npm run lint` | a `lint` script exists |
| `verify.lint` | `npx eslint .` | no `lint` script, an ESLint configuration exists |
| `verify.typecheck` | `npm run typecheck` | a `typecheck` script exists |
| `verify.typecheck` | `npx tsc --noEmit` | no `typecheck` script, `tsconfig.json` exists |
| `verify.unit` | `npm test` | a `test` script exists |
| `verify.lint_file` | `npx eslint {file}` | an ESLint configuration exists |
| `verify.source_globs` | `["src/**/*.ts", "src/**/*.tsx"]` | `tsconfig.json` exists; use `.js` and `.jsx` otherwise |

## pyproject.toml

Detect: the tables `[tool.ruff]`, `[tool.mypy]` and `[tool.pytest.ini_options]` in `pyproject.toml`, and a `tests/` folder.

| Key | Proposal | When |
|---|---|---|
| `verify.lint` | `ruff check .` | `[tool.ruff]` exists |
| `verify.typecheck` | `mypy .` | `[tool.mypy]` exists |
| `verify.unit` | `pytest` | `[tool.pytest.ini_options]` or a `tests/` folder exists |
| `verify.lint_file` | `ruff check {file}` | `[tool.ruff]` exists |
| `verify.source_globs` | `["src/**/*.py"]` | a `src/` folder exists; use `["**/*.py"]` otherwise |

## go.mod

Detect: `go.mod`, and a `.golangci.yml` or `.golangci.yaml` file.

| Key | Proposal | When |
|---|---|---|
| `verify.lint` | `golangci-lint run` | a golangci-lint configuration exists |
| `verify.lint` | `go vet ./...` | no golangci-lint configuration |
| `verify.typecheck` | `go build ./...` | always |
| `verify.unit` | `go test ./...` | always |
| `verify.lint_file` | `golangci-lint run {file}` | a golangci-lint configuration exists; otherwise leave it empty, because `go vet` works per package, not per file |
| `verify.source_globs` | `["**/*.go"]` | always |
