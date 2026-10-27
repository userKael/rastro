# Adapter: docs/notion

## Requirements

REQUIRED MCP: notion

The adapter uses these tools of that MCP server: `notion-fetch` to read a page, `notion-create-pages` to publish, and `notion-update-page` to edit. `docs.location` is the Notion database or parent page that design documents are published under, as a URL or an id.

## Detection

- A server named `notion` in `.mcp.json` or in `~/.claude.json`.

## Capabilities

### fetch

Call `notion-fetch` with the page URL or id. Convert the result to markdown and keep mermaid blocks as fenced `mermaid` blocks.

Expand every collapsed block, whether a toggle heading, a toggle list or a `<details>` block, and put its content in the text as if it were open. Collapsing tells a human what to read first. It never tells the agent what it may skip.

Return the markdown with its provenance on the first lines: the page URL, the page's last-edited time or version as the tool returns it, and the date of the fetch. If the tool returns no version, write `version: not returned`.

### publish

Call `notion-create-pages` with the document as the content, under the parent given by `docs.location`. The title is the document's first heading, left out of the body. Return the page URL and the version or last-edited time the tool reports for the new page.

### update

Edit surgically with `notion-update-page` and the `update_content` command, which replaces one exact piece of text with another. Never use `replace_content`, which substitutes the whole page.

- Never put a block that carries discussion, open or resolved, in the text being replaced. Rewriting, re-indenting or turning such a block into a toggle deletes its comments, and a resolved comment is not recoverable through the API.
- Treat a commented block that enters the replaced text unchanged as destructive too. It is not known to be safe.
- To collapse a section that contains a commented block, collapse the blocks around it and leave the commented block where it is.
- Insert new text next to existing text instead of rewriting it.

### collapse

Supported, in two forms:

- A heading marked `{toggle="true"}`, with the body indented by one tab.
- A `<details><summary>Title</summary>...</details>` block.

Pick one form and keep it for the whole document. Inside a toggle, indent both fence lines of a fenced code block with a tab and leave the content between them unindented.

A heading that ends with `{collapsed}` marks optional reading. Render it by these rules:

- Strip `{collapsed}` from the heading text.
- Render the section collapsed. In the toggle form, the heading keeps its level and takes `{toggle="true"}`, and the body goes under it, indented by one tab. In the `<details>` form, the heading text becomes the `<summary>` and the body goes inside the block. A heading nested in the body stays in the body.
- When collapse is unsupported, keep the section visible and append ` (optional reading)` to the heading. This is the case when the toggle forms did not render on your draft page (see Known limits).

## Known limits

- A mermaid `sequenceDiagram` that groups participants with `box` may not render in Notion. This is not verified for this adapter. Check it once on a draft page before relying on it. If it does not render, drop the `box` and keep the participants.
- The toggle forms above, and the tab-indented fences inside a toggle, are not verified here either. Publish a draft page and read it back with `fetch` the first time you depend on them.
- `update_content` cannot edit a block it cannot match by exact text. When the text has changed under you, fetch again and match against the current text.
- A comment on a block disappears with the block. The only protection is the rule in `update`: do not touch it.
- These names are unverified against the live tool — verify before relying on it: the tool names `notion-fetch`, `notion-create-pages` and `notion-update-page`, and the `update_content` and `replace_content` commands of `notion-update-page`.
