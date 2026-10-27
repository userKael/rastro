# Adapter: review/none

## Requirements

REQUIRED: none

## Capabilities

### trigger

There is no automatic reviewer. Review of an open change request is human review. The adapter starts nothing.

### rules_location

The rules live in the file named by `review.rules`. The file is ready for a reviewer that does not exist yet: a future adapter reads the same file, so the rules written today are not rewritten later.

The file uses the same rule format as `architecture.rules`. Each rule has an id in brackets and four fields:

```markdown
- **[<rule-id>]** <the rule, in one sentence>.
  **Symptom:** <what in the code or the diff shows the rule is broken>.
  **Why here:** <the real consequence in this service>.
  **Ask the author:** <what the review comment asks for>.
  **Known debt:** <files that already break the rule, optional>.
```

## Known limits

- No automatic review. A change request is reviewed by a person, and the rules file informs that person.
- The adapter does not check that the rules file exists or that its rules follow the format.
