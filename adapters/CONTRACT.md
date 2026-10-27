# Adapter contract

An adapter tells a skill how one external tool performs the capabilities of a port. The skills never name a tool. They read `.rastro/config.yml`, find the adapter for the declared `kind`, and call the port's capabilities through it.

This file is the public contract. Adapters shipped with the framework follow it, and so does any adapter you write yourself.

An adapter says how the tool does a thing. It does not say when a skill calls it, which gate sits around it, or how the result is worded. Those belong to the skill, and the adapter never restates them.

## How a skill finds an adapter

The adapter for a port is the file `<dir>/<kind>.md`, where `<dir>` is the port's directory name and `<kind>` is the value of the port's `kind` key in the config.

1. Look for `.rastro/adapters/<dir>/<kind>.md` in the adopter's repository.
2. Otherwise look for `adapters/<dir>/<kind>.md` in the framework.
3. If neither file exists, stop and report. The `doctor` reports the same condition as `missing adapter <dir>/<kind>`. A skill never improvises a capability the adapter does not describe.

The adopter's file wins, so an adopter can replace a shipped adapter by writing one with the same `kind`.

## Adapter file format

Every adapter is a markdown file with these sections, in this order:

| Section | Required | Content |
|---|---|---|
| `# Adapter: <dir>/<kind>` | yes | Title. Must match the file's path. |
| `## Requirements` | yes | The tools that must exist, as marker lines (see below). |
| `## Detection` | no | Signals the `setup` skill checks to propose this `kind`. |
| `## Capabilities` | yes | One `### <capability>` subsection per capability of the port, with the exact capability name. Each says how the tool does it. |
| `## Known limits` | yes | What the tool does not do, and the honest path when a capability is missing. |

### Marker lines

Under `## Requirements`, each requirement is a line that starts at column 0 with one of these markers:

| Marker line | Meaning |
|---|---|
| `REQUIRED MCP: <name>, <name>` | MCP servers that must be connected. |
| `REQUIRED MCP: from config <dotted.key>` | One MCP server whose name is the value of a config key, for example `domain_state.server`. An empty value is a problem. |
| `REQUIRED CLI: <name>, <name>` | Command-line tools that must be on the `PATH`. |
| `REQUIRED: none` | The adapter needs nothing outside the repository and git. |

Rules for marker lines:

- The part after the colon is a plain comma-separated list of names. No parenthetical text, no bold, no backticks.
- `REQUIRED: none` is the only accepted form of `REQUIRED:`. Never write `REQUIRED CLI: none` or `REQUIRED MCP: none`.
- A marker with an empty list is a problem, not an absence.
- Put explanations on separate lines that do not start with `REQUIRED`. The `doctor` reads every line of the file that starts with a marker.
- The `doctor` checks each CLI name with `command -v`. It matches each MCP name against the server names in `.mcp.json` and `~/.claude.json`, and reports a miss as a note, not as a problem, because connectors added through a hosted account use opaque ids.

### Detection

`## Detection` lists signals the `setup` skill can check without asking: a remote URL, a server name in the MCP config, a file in the repository. A signal proposes a `kind`. It never selects one, and the human confirms. Write one bullet per signal.

### Capabilities

Each subsection under `## Capabilities` is named after the capability, as in `### create_item`. It states the tool operation that performs the capability, with the commands or tool names, and what the adapter returns. A capability the tool cannot perform still gets its subsection, which says so and names the honest path.

### Known limits

The model is the item-to-change-request link in a tracker whose tool can only read links. The adapter says the tool cannot create the link, the path that exists (comment on the item, ask the human for the formal link), and that the result is never reported as done. A limit that is not written here becomes a silent failure in a skill.

## Port: tracker (config: tracker)

Work items and their hierarchy. The item types the framework uses are `bug`, `task`, `story` and `subtask`.

- `create_item`: `(type, title, description, parent?)`. Creates the item and returns its id. The type is a framework type, translated through `item_types`.
- `read_item`: `(id)`. Returns the title, the description, the children, the parent and the acceptance criteria.
- `write_section`: `(id, section, content)`. Replaces the section identified by its title and leaves the rest of the item untouched.
- `comment`: `(id, text)`. Adds a comment to the item.
- `link_change_request`: `(id, url)`. Links the item to a change request. Idempotent: it checks for an existing link first. When the tool cannot create the link, the adapter says so and gives the path that exists. It never reports a link that was not created.
- `item_types`: the map from `bug`, `task`, `story` and `subtask` to the names the tool uses. The adapter says how to read the names from the tool when they are not fixed.

## Port: docs (config: docs)

Design documents. `docs.location` says where they live.

- `fetch`: `(ref)`. Returns markdown with its provenance (source, reference, version or date) and with every collapsed block expanded.
- `publish`: `(markdown)`. Publishes the document at `docs.location` and returns its reference and version.
- `update`: `(ref, edit)`. Applies a targeted edit without deleting discussion that already exists on the document.
- `collapse`: whether the tool can collapse a block, and the syntax. Supported or not supported.

## Port: code-host (config: code_host)

Change requests: pull requests or merge requests.

- `open_change_request`: `(branch, target, title, body)`. Opens the change request and returns its URL. The target is the base branch, or the branch of the previous change request for a stacked one.
- `update_body`: `(change_request, body)`. Replaces the description.
- `ci_status`: `(change_request)`. Returns the state of the pipeline or checks, or says it is unavailable. An absent pipeline is never reported as passing.
- `collapsible`: whether the description renders collapsed blocks. Supported or not supported.

## Port: domain-state (config: domain_state)

The live state of the domain's database: structure and data.

- `schema`: `(tables)`. Returns columns, nullability, indexes and enum values.
- `state_distribution`: `(table, column)`. Returns each value of the column with its row count.
- `write_policy`: how writes are handled. The adapter never executes a write. It drafts the literal artifact for a human to run.

A claim about the live database that the adapter could not check is marked `NOT VERIFIED`.

## Port: review (config: review)

Review of an open change request.

- `trigger`: how the reviewer is started, or that there is none.
- `rules_location`: where the review rules live. The config key `review.rules` names the file, and the file uses the same rule format as `architecture.rules`: one entry per rule id, with its symptom, why it matters here, what to ask the author, and known debt.

## Writing your own adapter

Write an adapter when your tool has none in the framework: another tracker, another docs tool, another code host. Create `.rastro/adapters/<dir>/<kind>.md` in your repository, then set the port's `kind` to `<kind>` in `.rastro/config.yml`.

1. Pick `<dir>` from the ports above. It is the directory name, with a hyphen where the config key has an underscore: `code-host` for `code_host`.
2. Copy the skeleton below, and replace each line in angle brackets.
3. Write one `### <capability>` subsection for every capability of the port, using the exact names above. Skills look capabilities up by that name.
4. State the requirements with marker lines. Run the `doctor` and confirm it reports no problem for your adapter.
5. Fill in `## Known limits`: what the tool cannot do, and the path a skill takes instead.

````markdown
# Adapter: <dir>/<kind>

## Requirements

REQUIRED CLI: <command>

## Detection

- <a signal that proposes this kind>

## Capabilities

### <capability>

<How the tool performs it: the command or tool operation, and what it returns.>

## Known limits

- <What the tool does not do, and the honest path.>
````

`## Detection` is optional, and the skeleton shows it only to mark its place. Delete it when your tool has no signal worth checking.
