# Adapter: tracker/github

## Requirements

REQUIRED CLI: gh, git

`tracker.key` is `GH`. An item id is `GH-<n>`, where `<n>` is the issue number. GitHub turns `GH-<n>` in text into a link to the issue.

## Detection

- The `origin` remote URL contains `github.com`.

## Capabilities

### create_item

Resolve the type label through `item_types`, then run `gh issue create --title <title> --body-file <file> --label <type label>`. Write the body to a file first, so line breaks and quotes survive. Return `GH-<n>` from the number in the URL that `gh` prints.

GitHub has no item hierarchy. The parent lists its children as a task list in its body, and each child declares its parent on the first line of its body:

- The child body starts with `Parent: GH-<n>`.
- After creating the child, append `- [ ] GH-<child>` to the task list in the parent's body, using `write_section` on the parent. Create the task list section if it does not exist.

### read_item

Run `gh issue view <n> --json title,body,labels,url`. The title and body come from the issue. Read the parent from the `Parent: GH-<n>` line of the body, and the children from the task list in the body. Read the acceptance criteria from the section of the body that holds them. The framework type is the issue's label from `item_types`.

### write_section

Read the body with `gh issue view <n> --json body`. Replace the block that starts at the section's title and runs to the next heading of the same or a higher level. Leave every other line as it is. Write the whole body back with `gh issue edit <n> --body-file <file>`.

### comment

Run `gh issue comment <n> --body-file <file>`.

### link_change_request

The change request body contains `Refs #<n>`. GitHub creates the cross-reference between the issue and the change request from that line, and nothing is written to the issue.

Check that the body of the change request has the line. If it does not, add it with the `update_body` capability of the code host. Do not report the link as made until the line is in the body.

### item_types

GitHub issues carry the framework type as a label with the same name: `bug`, `task`, `story`, `subtask`. Check the labels with `gh label list`. A label that does not exist is named at the gate, and is created with `gh label create` only after the human says yes.

## Known limits

- Hierarchy is a convention in text. The parent's task list and the child's `Parent:` line are kept in step by this adapter and by nothing else, and ticking a box in the task list does not close the child.
- Issues and pull requests share one number sequence on GitHub, so a number can name either. An item id is always an issue number.
- `Refs #<n>` links but does not close. Closing an issue is a decision for the human.
- `gh` must be authenticated (`gh auth status`). The adapter does not log in.
- The body is replaced as a whole. A human edit made between the read and the write is overwritten. Read immediately before writing.
