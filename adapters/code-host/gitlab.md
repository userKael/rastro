# Adapter: code-host/gitlab

## Requirements

REQUIRED CLI: glab, git

## Detection

- The host of the `origin` remote URL contains `gitlab`.

## Capabilities

### open_change_request

Run:

```bash
glab mr create --source-branch <branch> --target-branch <target> --title <title> --description "$(cat <file>)"
```

Write the body to a file first and pass it through `cat`, so line breaks survive. `glab` prints the URL of the new merge request, and the adapter returns it.

The default description template is `.gitlab/merge_request_templates/Default.md`. When `code_host.template` is set, it names the template instead.

For a stacked change request, set `--target-branch` to the branch of the previous merge request, not to `project.base_branch`.

The source branch must already exist on the remote. Pushing is the caller's step, after its own gate. If the branch is not on the remote, report that and do not push.

### update_body

Run `glab mr update <number|branch> --description "$(cat <file>)"`. The file holds the whole new description.

### ci_status

Run `glab ci status --branch <branch>`. Report the state of the latest pipeline of the branch.

When the branch has no pipeline, say that the pipeline did not run or the project has none. Never read it as passing.

### collapsible

Supported. A merge request description renders `<details><summary>Title</summary>...</details>` as a collapsed block. Leave a blank line after the summary so the markdown inside renders.

## Known limits

- The rule about which pipeline sources count is the project's own. It goes in the project's profile, under `## Additional checks`. The adapter reports the pipeline and does not judge where it came from.
- `glab` must be authenticated (`glab auth status`). The adapter does not log in.
- A merge request is opened from a pushed branch. The adapter does not push.
- Merging is not a capability of this adapter.
- These commands are unverified against the live tool — verify before relying on it: `glab mr create` with `--source-branch`, `--target-branch`, `--title` and `--description`; `glab mr update` with `--description`; `glab ci status` with `--branch`.
