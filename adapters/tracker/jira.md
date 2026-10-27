# Adapter: tracker/jira

## Requirements

REQUIRED MCP: atlassian

The adapter uses these tools of that MCP server: `getJiraIssue`, `createJiraIssue`, `editJiraIssue`, `addCommentToJiraIssue`, `getJiraProjectIssueTypesMetadata`, `getJiraIssueRemoteIssueLinks`.

`tracker.key` is the Jira project key. An item id is `<tracker.key>-<n>`, for example `SHELF-12`.

## Detection

- A server named `atlassian` in `.mcp.json` or in `~/.claude.json`.

## Capabilities

### create_item

Resolve the type name through `item_types`, then call `createJiraIssue` with the project key `tracker.key`, the resolved type, the title as summary and the description. For a child, pass the parent id as the issue's parent. Return the new id.

### read_item

Call `getJiraIssue` with the id. Read the title, the description and the acceptance criteria (a section of the description, or the project's own field when it has one). Read the children from the issue's subtasks and the parent from its parent field. When the item has a parent, call `getJiraIssue` on the parent too, so the caller sees the real parent and not only its key.

The item URL that goes in a PR description is the browse URL of the issue, `<site>/browse/<id>`, built from the issue data `getJiraIssue` returns. Never build it from a remembered or guessed site address. If the returned data does not give the site, say that the URL is unknown and write the id alone.

### write_section

Call `getJiraIssue` for the current description. Replace the block that starts at the section's title and runs to the next heading of the same or a higher level. Leave every other line as it is. Write the whole description back with `editJiraIssue`. If the title does not exist, add the section at the end of the description.

A reconciliation section is written as tables only, with at most 200 characters per cell. Longer text is cut to its anchor (a file and line, or an identifier) and the rest stays in the workspace file.

### comment

Call `addCommentToJiraIssue` with the id and the text. Write the full URL of anything you cite.

### link_change_request

Call `getJiraIssueRemoteIssueLinks` with the id first. If a link to this change request exists, do nothing and say so. The adapter is idempotent, because the caller runs it again after review.

If no link exists, the MCP server cannot create one: it only reads remote links. Do this instead:

1. Comment on the subtask with `addCommentToJiraIssue`. The comment holds the change request URL and its title.
2. Ask the human to add the formal link: on the issue, Link, then Web link, with that URL.

Never say the link was created. When it does not exist, the report says it does not exist.

### item_types

Call `getJiraProjectIssueTypesMetadata` for the project key before creating anything, and map `bug`, `task`, `story` and `subtask` to the names it returns. The project may use localized names in its interface, so match by the names the tool returns and do not assume the English ones.

If `bug` has no type in the project, create a Task with the label `bug` and say at the gate what was replaced and why. If another framework type has no match, stop and report it at the gate. Do not pick a substitute.

## Known limits

- The MCP server has no tool that creates a web link, so `link_change_request` cannot create the formal link. The path is the comment and the request to the human, as written above.
- `editJiraIssue` replaces the description as a whole. A human edit made between the read and the write is overwritten. Read immediately before writing.
- Issue type names depend on the project. A type that the project does not enable cannot be created, and `item_types` is where that surfaces.
- The adapter does not change the status of an item.
