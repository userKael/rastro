# Adapter: tracker/github-projects

## Requirements

REQUIRED CLI: gh, git

`gh` needs the `project` scope (`gh auth refresh -s project`) and a version that supports `gh issue create --parent` (check with `gh issue create --help`).

`tracker.key` is `GH`. An item id is `GH-<n>`, where `<n>` is the issue number. `tracker.project` is the number of the GitHub Project that mirrors item status. `tracker.project_owner` is the login that owns the Project; when it is empty, the owner of the repository is used.

## Detection

- The `origin` remote URL contains `github.com`. This suggests the kind. The Project itself cannot be detected from the repository.
- `setup` asks `tracker.project` (the Project number, with no value proposed) and `tracker.project_owner` (empty proposed, which means the owner of the repository) once the kind is `github-projects`.

## Capabilities

### create_item

Create the issue as in `tracker/github`: write the body to a file, resolve the type label through `item_types`, and run `gh issue create --title <title> --body-file <file> --label <type label>`. When the item has a parent, add `--parent <n>` to the same command, so the issue is a native sub-issue of its parent. If the installed `gh` has no `--parent`, say so and use the textual hierarchy of `tracker/github` (the `Parent: GH-<n>` line and the parent's task list). Never report a sub-issue link that was not made.

Then add the issue to the Project and mirror its status:

1. Resolve the Project, Status field and Todo option ids as described under `publication`. If any are missing, name what is missing and leave the board steps pending.
2. Add the issue to the Project and record the returned item id.
3. Set the Todo option using the ids as described under `publication`.

Return `GH-<n>` from the number in the URL that `gh` prints. A failure in step 2 or 3 is reported, and the issue stays created.

### read_item

Run `gh issue view <n> --json title,body,labels,url,parent,subIssues`. The title, body and labels come from the issue. The parent and the children come from the native `parent` and `subIssues` fields, which `gh issue view <n> --json parent,subIssues` returns on their own. When the item was created with the textual hierarchy, read them from the body as `tracker/github` does. The framework type is the label from `item_types`.

The Status field is a mirror and is never read as a source. Do not read `projectItems` to decide the state of an item. The state comes from the branch and the change request.

### write_section

As in `tracker/github`: read the body, replace the block of the section, and write the whole body back with `gh issue edit <n> --body-file <file>`.

### comment

As in `tracker/github`: `gh issue comment <n> --body-file <file>`.

### link_change_request

The change request body contains `Refs #<n>`, as in `tracker/github`. Check that the line is in the body, and add it with the `update_body` capability of the code host if it is not. Do not report the link as made until the line is there.

Only after the line is in the body, mirror the status: resolve the Project, item, Status field and In review option ids and run `gh project item-edit` with those ids as described under `publication`. If writing the Status fails, say so. The failure does not undo or block the link.

`Done` is not written by this adapter. The built-in workflow of the Project sets it when the item closes, and closing an item is a decision for the human.

### item_types

As in `tracker/github`: the framework type is a label with the same name (`bug`, `task`, `story`, `subtask`), checked with `gh label list`. When the organization defines issue types, the type can be set with `--type` instead. Labels are the default. A label that does not exist is named at the gate and created only after the human says yes.

### publication

- Publication destination: the resolved GitHub repository and the selected Project owner and number. Resolve the Project and its Status field and Todo option before any issue write.
- Parent relationship: use native sub-issues when supported by the installed CLI and repository. If unavailable, preview and use the textual hierarchy of `tracker/github`.
- Dependency representation: delivery dependencies and slice ids are body text. Project Status mirrors workflow status.
- Recovery: look up the issue by exact marker as in `tracker/github`. For a native child, verify the parent through the issue or sub-issues endpoint. Use `gh issue edit <child> --parent <parent>` if supported and the expected parent is missing. Record the issue id as soon as it is known.
- Resolve the Project id with `gh project view <project> --owner <owner> --format json` and the field and option ids with `gh project field-list <project> --owner <owner> --format json`. Look for the exact issue URL in `gh project item-list <project> --owner <owner> --format json`, increasing `--limit` until the result covers the whole list. Reuse the existing project item. If the issue is absent and the read is complete, add it using `gh project item-add <project> --owner <owner> --url <issue url> --format json` and record its item id. If lookup is incomplete, leave membership pending.
- Finish the pending initial Status change using `gh project item-edit --id <item id> --project-id <project id> --field-id <status field id> --single-select-option-id <Todo option id>`. When the read already shows Todo, count it as done. When the receipt already marks the initial Status step complete, keep the current Status. When recovering and the item has already moved to another nonempty Status, report the observed value and leave it for the human to resolve. Verify each remaining step independently. Board failures leave the issue in place.

## Known limits

- The Status is a mirror. It can differ from the real state when someone moves the card by hand, and nothing in this adapter corrects it.
- The Project may lack the `Status` field, or the option `Todo` or `In review`. The adapter names what is missing and does not create it.
- `gh` needs the `project` scope. Without it, the issue is created and the Project steps are reported as not done.
- Native sub-issues need a `gh` with `--parent` on `gh issue create` and on `gh issue edit`. Without them the hierarchy is the textual hierarchy of `tracker/github`, with its limits.
- `Refs #<n>` links but does not close.
- NOT VERIFIED: Check the selected Project’s Status options and built-in workflow in the live tool before relying on them. See [GitHub CLI Project commands](https://cli.github.com/manual/gh_project) and [GitHub sub-issues API](https://docs.github.com/en/rest/issues/sub-issues).
