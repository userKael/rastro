# Adapter: docs/repo

## Requirements

REQUIRED CLI: git

Design documents are markdown files in the repository, at `<docs.location><slug>.md`. `docs.location` ends with a slash, as in the default `docs/design/`, so the path of a document is `docs/design/<slug>.md`. If the configured value has no trailing slash, add one before building a path. The change request that adds a document is opened through the `code_host` port.

## Capabilities

### fetch

Read the file. For a reference that is a path, use `git show <project.base_branch>:<path>`. For a document still in review, read it from its branch with `git show <branch>:<path>`. Return the markdown with its provenance on the first lines: the path, the commit it was read at (the first 7 characters of the sha) and the date of the fetch.

A `<details>` block is part of the text. Read its content as if it were open.

### publish

1. Create the branch `docs/design-<slug>` from `project.base_branch`.
2. Write the document to `<docs.location><slug>.md` and commit it, following `conventions.commit`. The branch carries no item id, so the commit does not need one.
3. Push the branch with `git push -u origin docs/design-<slug>`. The human's choice of Publish at the caller's gate authorizes this push. The code-host adapter opens a change request only from a pushed branch, and it does not push.
4. Open a change request through the `code_host` port, with the base branch as target.

The change request is where the team discusses the document, and its merge is the approval. The publication gate opens the change request and never merges it. Return the file path and the change request URL as the reference, and the commit sha as the version.

With `code_host.kind` set to `none`, stop after the commit and do not push. Say which branch holds the document and give the git command to publish it.

### update

Edit the file on the document's branch and add a new commit. Do not amend and do not rewrite pushed history, so the review comments stay anchored to the lines they were made on. Review discussion lives in the change request, not in the file, so an edit to the file does not delete it.

### collapse

Supported when the code host renders `<details>`: wrap the block in `<details><summary>Title</summary>` and `</details>`, and leave a blank line after the summary so the markdown inside renders. The answer follows the `collapsible` capability of the `code_host` adapter in use. When that adapter says it is not supported, or the code host is `none`, collapsing is not supported.

A heading that ends with `{collapsed}` marks optional reading. Render it by these rules:

- Strip `{collapsed}` from the heading text.
- Render the section collapsed: the heading text becomes the `<summary>`, with its heading level dropped, and the body goes inside the `<details>` block.
- When collapse is unsupported, keep the section visible and append ` (optional reading)` to the heading.

## Known limits

- The merge is manual. Nothing in this adapter approves a document.
- The version is a commit sha, not a counter, so a reader compares two versions with `git diff`.
- A document in review is on its branch, not on `project.base_branch`. A `fetch` by path on the base branch finds it only after the merge.
- With `code_host.kind` set to `none`, there is no change request and so no place for discussion. The team discusses outside the repository.
