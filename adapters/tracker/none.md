# Adapter: tracker/none

## Requirements

REQUIRED: none

There is no tracker. The item lives in the conversation and in the workspace, at `<workspace>/<slug>/item.md`. The `<slug>` is the title in lowercase words joined by hyphens, and it serves as the item id.

## Capabilities

### create_item

Write `<workspace>/<slug>/item.md` with the title, the description and the type (`bug`, `task`, `story` or `subtask`). A parent is recorded as a line `Parent: <parent slug>`, and nothing follows it. Return the slug as the id.

### read_item

Read `<workspace>/<slug>/item.md`. When the workspace has no such file, the item is whatever the human gave in the conversation. Say so, and write the file before going on.

### write_section

Edit `<workspace>/<slug>/item.md`. Replace the block that starts at the section's title and runs to the next heading of the same or a higher level. Leave every other line as it is. If the title does not exist, add the section at the end.

The reconciliation is the exception: with this adapter it goes to the change request description, not to `item.md`.

### comment

Unavailable: there is no tracker. The caller says so and keeps the text in the conversation or in the change request description.

### link_change_request

Writes nothing. There is no item outside the workspace to link.

### item_types

The framework names are used as they are: `bug`, `task`, `story`, `subtask`. They are recorded in `item.md`. There is nothing to look up.

## Known limits

- The work cannot be resumed before the change request exists. The workspace is gitignored and local to one clone, and the conversation does not outlive the session. The `setup` skill tells the human this when `none` is chosen.
- Nothing outside the change request records what the item asked for once the workspace is deleted.
- There are no children and no parent in any tool. The `Parent:` line is text.
