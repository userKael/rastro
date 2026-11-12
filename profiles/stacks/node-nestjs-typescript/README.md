# Stack profile: Node.js, NestJS and TypeScript

This file teaches how to verify in this stack. It imposes no pattern: which patterns the project uses is the team's decision.

## What this profile is

Reference material for checking patterns in a Node.js codebase built with NestJS and TypeScript: how to turn a decision of a golden path into a check, how to test a module and a path end to end, and which security questions to answer for each trust boundary.

## What it is not

It is not a pattern. It ships no golden path, no list of layers and no folder layout. The project decides how it is organized; this profile only shows how to check what the project decided.

## How the project uses it

- Setup points to this profile when the stack detection finds `@nestjs/core` in `package.json` or a `nest-cli.json` file, by the path `profiles/stacks/node-nestjs-typescript/`.
- The profile is read where it is. It is never copied to `.rastro/profiles/`, which holds the profiles that replace the pattern of a skill; this one is consultation material.
- The person carries into the golden paths and into the project docs only what the team adopts.

## Files

- `verification.md`: how to move a golden path from `verified_by: review` to an automated check, and how to prove the check fails on a violation.
- `testing.md`: how to test one module, one path end to end, and the real-system scenarios of a boundary type.
- `security-questions.md`: questions to answer for each boundary type, grouped by concern.
