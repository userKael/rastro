---
status: accepted
date: <YYYY-MM-DD>
decided_by: <the person who decided>
origin: <init, or the item id>, <YYYY-MM-DD>
---

# <NNNN>. <The decision, in a few words>

> **Template.** Delete this note when filling in. An agent drafts the ADR; a person decides it. An ADR records an answer the person gave, never a decision, a reason or an alternative the agent supplied alone: an ADR with no human decision behind it is fabricated. The file is `docs/adr/<NNNN>-<kebab-case title>.md`, numbered from `0001` in order; a number is never reused, and an existing file is never overwritten. The headings and the frontmatter keys stay literal in English; write the text under them in `project.languages.human`. `status` is `accepted`, or `superseded by <NNNN>` when a later ADR replaces this one, which then stays as it is. An ADR decides the stack, the structure or how the code is verified, never how to build one type of component: that is the golden path its first instance writes.

## Context

<What the project does, and the forces behind this decision, in the person's words.>

## Decision

<What the person decided.>

Why: <the person's reason, or `<reason not given>`>

## Alternatives considered

<Each option the person weighed, and why it lost. "None weighed" when the person named none.>

## Consequences

<What becomes easier, and what becomes harder.>

Revisit if: <the condition that would reopen this decision>
