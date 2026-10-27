---
name: alpha
description: Fixture skill for the structure checks. Use it when testing the checks themselves.
---

# alpha

## Requirements

Read ${CLAUDE_PLUGIN_ROOT}/templates/note.md before starting.
Adapter files live in ${CLAUDE_PLUGIN_ROOT}/adapters/<port>/<kind>.md, or in .rastro/adapters/<port>/<kind>.md in the adopter repository.
The adapter directory is ${CLAUDE_PLUGIN_ROOT}/adapters/tracker/ and the template folder is ${CLAUDE_PLUGIN_ROOT}/templates/.
The note ends the sentence, see ${CLAUDE_PLUGIN_ROOT}/templates/note.md.
Hooks are copied to .rastro/git-hooks/ and libraries to .rastro/lib/.
Config keys read: `verify.lint`, `project.languages.human`, `workspace`, and the whole `verify.*` group.
Not a config key: `foo.bar`.
The step is read by a later step as DT-xx.

## Precedence

Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.

## What this skill does NOT do

It does nothing.
