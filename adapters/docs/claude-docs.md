# Adapter: docs/claude-docs

## Requirements

REQUIRED MCP: claude-docs

The adapter uses these tools of the Claude Docs connector: `batch` to create a document from blocks and markdown, `read` to read it, `update` to edit the content of a tab, `export` to get markdown, PDF, Word or Google Docs, and the comment threads on blocks. `docs.location` is the container where documents are created, as the connector references it. When it is empty, the connector's default is used.

The server name `claude-docs` in the marker line is an assumption (NOT VERIFIED). The note of the doctor about opaque connector ids applies: a connector can be registered under an id that is not its name.

## Detection

- A server of the Claude Docs connector in `.mcp.json` or in `~/.claude.json`.

## Capabilities

### fetch

Call `read` with the document reference. Expand every collapsed block and put its content in the text as if it were open. Collapsing tells a human what to read first. It never tells the agent what it may skip.

Return the markdown with its provenance on the first lines: the document reference, the version or the last-edited time as the tool returns it, and the date of the fetch. If the tool returns no version, write `version: not returned`. The status line is at the top of the text, for the people who read the document. No skill gates on it. Other agents read the document through the same connector.

### publish

Call `batch` to create the document under `docs.location`. The first block is the line `Status: draft`, and the rest of the document follows as markdown. The title is the document's first heading, left out of the body.

The agent writes `Status: approved by <person> on <date>` only when the person says so, naming who approved. It never writes the approval by inference, and never because the document looks finished.

At publication, sharing with the team is a human step. This adapter says so and does not share the document. Return the document reference and the version the tool reports.

### update

Call `update` and edit only the text that needs to change, and never delete discussion:

- A block that carries a comment thread, open or resolved, never enters the text being replaced, changed or unchanged.
- To collapse a section that contains a commented block, collapse the blocks around it and leave the commented block where it is, as in `docs/notion`.
- Insert new text next to existing text instead of rewriting it.

Changing the content after the line reads `approved` rewrites the line to `Status: draft` and tells the person, because the approval was for the earlier text.

### collapse

Not supported until the connector proves otherwise (NOT VERIFIED). A heading that ends with `{collapsed}` marks optional reading, and follows the rule of `docs/repo`:

- Strip `{collapsed}` from the heading text.
- Keep the section visible and append ` (optional reading)` to the heading.

## Known limits

- The document's durability is the connector's: it lives there. The way out is `export` to markdown, and, if the team wants it, committing that markdown as a file of the repository with the `repo` adapter.
- There is no change request. The discussion happens in the comment threads of the connector.
- The approval is a line of text, not an access control. Anyone who can edit the document can change it.
- The version may not be returned. Then `fetch` writes `version: not returned`.
- These names are unverified against the live tool — verify before relying on it: the tools `batch`, `read`, `update`, and `export`, and the server name `claude-docs`.
