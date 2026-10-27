# Adapter: code-host/none

## Requirements

REQUIRED: none

There is no code host the agent can call. The change request is opened by a human, from a description the agent writes.

## Capabilities

### open_change_request

Write `<workspace>/<id>/pr-description.md`, where `<id>` is the item id. The file starts with the line `Title: <title>`, then a blank line, then the body. Then tell the human how to publish:

- The branch to push, with the command: `git push -u origin <branch>`.
- The target branch and the title, for the form the host shows.
- That the body is in the file, ready to paste.

Return the path of the file. There is no URL.

### update_body

Rewrite the body in `<workspace>/<id>/pr-description.md`, below the `Title:` line, and tell the human to paste it into the change request if it is already open.

### ci_status

Unavailable: there is no host to ask. Say so. Never report the pipeline as passing.

### collapsible

Not supported. The adapter cannot know how the description will be rendered. Put the block in a plain section and append ` (optional reading)` to its title.

## Known limits

- No URL, no pipeline state and no automatic link between the item and the change request. The human opens the change request and reports its URL.
- The workspace is gitignored, so the description file is not shared. It is a draft for the person who opens the change request.
