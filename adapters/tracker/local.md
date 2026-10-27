# Adapter: tracker/local

## Requirements

REQUIRED CLI: git

An item is a markdown file, `<tracker.local_dir><key>-<nnn>-<slug>.md`, where `<key>` is `tracker.key` and `<nnn>` is a number zero-padded to 3 digits. The item id is `<key>-<nnn>`, for example `W-007`. The slug is the title in lowercase words joined by hyphens, and it is not part of the id.

`tracker.local_dir` ends with a slash, as in the default `work/`, so the file of item `W-001` is `work/W-001-<slug>.md`. If the configured value has no trailing slash, add one before building a path.

The file follows `templates/work-item.md` in the framework: frontmatter with the keys `id`, `type`, `parent`, `created_on` and `sources`, then the sections of an item, among them `## Acceptance criteria`. There is no status field. Whether an item is done is read from the branch and the change request, not from the file.

## Capabilities

### create_item

1. Find the next number. When the repository has a remote (`git remote` prints a name), run `git fetch --all --quiet` first, so the remote refs are current, and tell the human the fetch ran. If the fetch fails, say so and go on with the refs already local. Then list the files under `<tracker.local_dir>` in every ref of `refs/heads` and `refs/remotes`, run from the repository root:

   ```bash
   git for-each-ref --format='%(refname)' refs/heads refs/remotes |
     while IFS= read -r ref; do
       git ls-tree -r --name-only "$ref" -- <tracker.local_dir>
     done
   ```

   Take the largest `<n>` among the names that match `<key>-<n>-` after the last `/`, add 1, and write it zero-padded to 3 digits. Also count the files already in the working copy of `<tracker.local_dir>`, so two items created before the first commit do not get the same number.
2. Write the file from `templates/work-item.md`. Fill `id` with the new id, `type` with the framework type (`story`, `task`, `bug` or `subtask`), `parent` with the parent id when there is one, `created_on` with today's date and `sources` with the references the item rests on.
3. Get the item onto the base branch. After the gate, create the branch `chore/<id>-<slug>`, where `<id>` and `<slug>` belong to the top item created. Commit the item files, following `conventions.commit`. Push the branch with `git push -u origin chore/<id>-<slug>`: the human's choice of Create at the caller's gate authorizes this push, and the code-host adapter opens a change request only from a pushed branch. Then open a change request through the `code_host` port. The item exists when its file is on `project.base_branch`.

With `code_host.kind` set to `none`, commit on the branch, do not push, and say that the merge is manual.

### read_item

Read the file. From the base branch use `git show <project.base_branch>:<path>`, and from the working copy read the path. The frontmatter keys `type` and `parent` give the type and the parent. The children are the files in `<tracker.local_dir>` whose `parent` key is this id. The acceptance criteria are the body of the `## Acceptance criteria` section of the item.

### write_section

Edit the file. Replace the block that starts at the section's title and runs to the next heading of the same or a higher level. Leave every other line as it is. If the title does not exist, add the section at the end.

A `## Reconciliation` section written after the item reached the base branch goes in the first commit of the implementation branch.

### comment

Unavailable: a file has no comment thread. The caller says so and puts the text in the change request description.

### link_change_request

Writes nothing. The link is the item id in the change request title.

### item_types

The framework names are used as they are: `bug`, `task`, `story`, `subtask`. They are recorded in the item's `type` key. There is nothing to look up.

## Known limits

- An item exists for other clones only after its change request is merged into `project.base_branch`. Until then it is on the branch.
- Two clones that create items before either pushes can pick the same number, because the adapter cannot see the other clone. The `doctor` reports duplicate ids once both files are visible. An id does not change once a commit cites it, so a human resolves the collision and the adapter never renumbers.
- There is no status field, no assignee and no comment thread. State comes from the branch and the change request.
