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

> **Template.** Delete this note when filling in. The headings and the frontmatter keys and values stay literal in English, because skills find sections by them; write the text under them in `project.languages.human`. The first instance of a component type writes this file, in the same change as the instance, and names it after the type. `status` is `current`, `under-review` or `retired`; a retired golden path adds `superseded_by: <id>`. `verified_by` is `review` until a check enforces the golden path, then `automated: <command>`. A type listed in `architecture.boundary_types` crosses a trust boundary: `## Security` and `## Verification` say what more it needs. `instances` points to real code by `file:line` and never copies it.

## When to use

<The situations this component type serves, and the ones that look similar and do not belong here.>

## Decisions

- **<decision>.** Why: <the reason>. Revisit if: <the condition that would change it>.

## Checklist

- [ ] <what every instance does, checkable in review>

## Security

<The threats considered for this type, the control for each, and how each control is verified. When none applies, write "none identified" and why.>

<A type in `architecture.boundary_types` crosses a trust boundary, and "none identified" does not serve it. Draw its threats from a public reference, such as the OWASP Application Security Verification Standard (ASVS) or the OWASP API Security Top 10, and cite each threat by its item there, never copying its text. A rule of the project adds a threat by its ID. One line per threat:>

- <threat>, from <reference and item>. Control: <the control>. Verified by: <the check, the test or the scenario that shows the control holds>.

## Verification

<How an instance is checked against this golden path: the checklist above in review, or the command named in `verified_by`.>

<A command named in `verified_by` exits non-zero when an instance breaks this golden path, and prints one line per violation: what is wrong, at its `file:line`; why, by the id of this golden path and the decision it breaks; and how to fix it. Make `verify.lint` run the same command, so CI runs it too. A violation line looks like this:>

```text
src/workers/resend-receipt.processor.ts:12: retries with no limit. Breaks processor, decision "Every retry has a bound". Fix: read the attempt limit from configuration.
```

<A type in `architecture.boundary_types` adds at least one scenario against the real system, without mocks:>

### Scenario: <what it proves>

- Context: <the environment, the data and the access the scenario needs>
- Steps: <what to run, in order>
- Success: <what shows that the control holds>
- When blocked: <what to do when the real system cannot be reached: whom to ask, and what to record in the PR>

## Known debt

<Instances that follow an older major version, each by `file:line`. Not precedent: a new instance follows the current version.>

## History

| Version | Date | Item | Change |
|---|---|---|---|
| 1.0.0 | <YYYY-MM-DD> | <item id> | Created from the first instance |
