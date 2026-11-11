---
id: <file name without .md>
type: <one layer of architecture.layers>
version: 1.0.0
status: current
verified_by: review
instances: [<path>:<line>]
origin: <item id>, <branch>, <YYYY-MM-DD>
---

# Golden path: <type>

> **Template.** Delete this note when filling in. The headings and the frontmatter keys and values stay literal in English, because skills find sections by them; write the text under them in `project.languages.human`. The first instance of a component type writes this file, in the same change as the instance, and names it after the type. `status` is `current`, `under-review` or `retired`; a retired golden path adds `superseded_by: <id>`. `verified_by` is `review` until a check enforces the golden path, then `automated: <command>`. `instances` points to real code by `file:line` and never copies it.

## When to use

<The situations this component type serves, and the ones that look similar and do not belong here.>

## Decisions

- **<decision>.** Why: <the reason>. Revisit if: <the condition that would change it>.

## Checklist

- [ ] <what every instance does, checkable in review>

## Security

<The threats considered for this type, the control for each, and how each control is verified. When none applies, write "none identified" and why.>

## Verification

<How an instance is checked against this golden path: the checklist above in review, or the command named in `verified_by`.>

## Known debt

<Instances that follow an older major version, each by `file:line`. Not precedent: a new instance follows the current version.>

## History

| Version | Date | Item | Change |
|---|---|---|---|
| 1.0.0 | <YYYY-MM-DD> | <item id> | Created from the first instance |
