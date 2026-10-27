# Protocol markers

One skill reads another skill's output by literal text, and the state table in `AGENTS.md` depends on a section title. These markers therefore stay literal, in English, whatever `project.languages.human` is. Every other word of an artifact is written in `project.languages.human`.

Identifiers are not translated either: `D-n`, `DT-nn`, rule IDs, domain names.

| Marker | Written by → read by |
|---|---|
| `## Reconciliation` | `breakdown` or `implement` → state table, `implement` |
| `## Acceptance criteria` | `breakdown` → `implement`, through `read_item` of the tracker adapter |
| `reconciliation.md` | `reconcile` → `breakdown`, `implement`, `deliver` |
| `NOT VERIFIED` | `domain-context` → every skill |
| `[HUMAN]` | `implement` (task) → `deliver` |
| `[no PR]` | `breakdown` → rulers |
| `## Context` | `domain-context` → `reconcile` |
| `Decided (<YYYY-MM-DD>):` | deliberation gate → `implement` |
| `D-n`, `DT-nn` | decision identifiers; stable once cited |
| `new` | `design-doc` → `reconcile`, `implement` |
| `changes` | `design-doc` → `reconcile`, `implement` |
| `exists` | `design-doc` → `reconcile` |

The last three tag the components of `## Code flows` in a design doc: `new` is a component that does not exist yet, `changes` is one that exists and this change edits, and `exists` is one that is reused without change.

An item without `## Reconciliation` is a hand-made item and gets a full reconciliation. That covers items written before the adopter installed rastro.
