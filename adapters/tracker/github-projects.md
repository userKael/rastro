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

1. Run `gh project field-list <project> --owner <owner>` and check that the `Status` field has the option `Todo`. If the field or the option is missing, name what is missing and stop before writing. The adapter does not create fields or options.
2. Run `gh project item-add <project> --owner <owner> --url <issue url>`.
3. Run `gh project item-edit <project> --owner <owner> --url <issue url> --field Status --value "Todo"`.

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

Only after the line is in the body, mirror the status: run `gh project item-edit <project> --owner <owner> --url <issue url> --field Status --value "In review"`. If writing the Status fails, say so. The failure does not undo or block the link.

`Done` is not written by this adapter. The built-in workflow of the Project sets it when the item closes, and closing an item is a decision for the human.

### item_types

As in `tracker/github`: the framework type is a label with the same name (`bug`, `task`, `story`, `subtask`), checked with `gh label list`. When the organization defines issue types, the type can be set with `--type` instead. Labels are the default. A label that does not exist is named at the gate and created only after the human says yes.

## Known limits

- The Status is a mirror. It can differ from the real state when someone moves the card by hand, and nothing in this adapter corrects it.
- The Project may lack the `Status` field, or the option `Todo` or `In review`. The adapter names what is missing and does not create it.
- `gh` needs the `project` scope. Without it, the issue is created and the Project steps are reported as not done.
- Native sub-issues need a `gh` with `--parent` on `gh issue create` and `--add-sub-issue` on `gh issue edit`. Without them the hierarchy is the textual hierarchy of `tracker/github`, with its limits.
- `Refs #<n>` links but does not close.
- NOT VERIFIED: the GraphQL mutation `addSubIssue` was not checked against the documentation and this adapter does not use it; only the `gh` flags were checked, locally. The exact name of the field and of its options in a Project that does not use the default template, and the `Done` automation when an item closes (it depends on the built-in workflow being on in the Project), are unverified against the live tool — verify before relying on it.
