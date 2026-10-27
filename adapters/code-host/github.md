# Adapter: code-host/github

## Requirements

REQUIRED CLI: gh, git

## Detection

- The `origin` remote URL contains `github.com`.

## Capabilities

### open_change_request

Run:

```bash
gh pr create --base <target> --head <branch> --title <title> --body-file <file>
```

Write the body to a file first, so line breaks and quotes survive. `gh` prints the URL of the new pull request, and the adapter returns it.

The default description template is `.github/pull_request_template.md`, or the `.github/PULL_REQUEST_TEMPLATE/` directory when a repository has several. When `code_host.template` is set, it names the template instead.

For a stacked change request, set `--base` to the branch of the previous pull request, not to `project.base_branch`.

The head branch must already exist on the remote. Pushing is the caller's step, after its own gate. If the branch is not on the remote, report that and do not push.

### update_body

Run `gh pr edit <number|url|branch> --body-file <file>`. The file holds the whole new body.

### ci_status

Run `gh pr checks <number|url|branch>`. The exit status is 0 when every check passed, 1 when a check failed, and 8 when checks are still pending. Report the state of each check by name.

When `gh` reports no checks, say that the pipeline did not run or the repository has none. Never read it as passing.

### collapsible

Supported. A pull request description renders `<details><summary>Title</summary>...</details>` as a collapsed block. Leave a blank line after the summary so the markdown inside renders.

## Known limits

- `gh` must be authenticated (`gh auth status`). The adapter does not log in.
- A pull request is opened from a pushed branch. The adapter does not push.
- Merging is not a capability of this adapter.
- Project rules about which checks count, or about what must pass before a review, belong to the project's profile under `## Additional checks`. The adapter reports the checks and does not judge them.
- These commands are unverified against the live tool — verify before relying on it: `gh pr create` with `--base`, `--head`, `--title` and `--body-file`; `gh pr edit` with `--body-file`; `gh pr checks` and its exit statuses 0, 1 and 8.
