# Stack detection

The `setup` skill reads the repository's manifests and proposes values for the `verify.*` keys of `.rastro/config.yml`. Every value is a proposal: the skill shows it, and writes only what the human confirms. A proposal comes from a file or a script the repository already has. When none exists, the key stays empty, because a command that cannot fail reports success without checking anything.

`verify.integration` and `verify.integration_when` have no portable proposal; the skill asks.

`verify.lint_file` runs after each edit with `{file}` replaced by the edited path. It must take one file and exit non-zero on a finding. `verify.source_globs` is an inline list of the globs of source files the Stop hook checks.

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
