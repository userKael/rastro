# Verification recipes

This file teaches how to verify in this stack. It imposes no pattern: which patterns the project uses is the team's decision.

## What this file is for

How to move a golden path from `verified_by: review` to `verified_by: automated: <command>` in this stack, following the check contract of `templates/golden-path.md`: the command exits non-zero when an instance breaks the golden path, prints one line per violation, and runs in `verify.lint` so CI runs it too. Do this only after the second instance exists and there is a pattern to verify; when to do it is a rule of the core, not of this file.

## Module boundary check: main recipe

Tool: dependency-cruiser. It reads the whole import graph, finds cycles, and runs as a single command, which fits `verified_by: automated:`.

1. Install it as a development dependency, then run `npx dependency-cruiser --init`. It asks a few questions and writes its config file in the current folder; the default name is `.dependency-cruiser.js`, so check the file `--init` created.
2. Add one rule to the `forbidden` list for the boundary that a decision of the golden path forbids. The shape, with placeholders:

```js
{
  name: '<rule name>',
  severity: 'error',
  comment: '<violation line, see below>',
  from: { path: '^src/<module>/' },
  to: { path: '<path pattern the module must not import>' },
}
```

`from.path` and `to.path` are regular expressions. `from` matches the module that holds the import; `to` matches the module it resolves to. Which boundary exists is the decision of the project.

3. Run the command:

```text
npx depcruise <source folder> --config .dependency-cruiser.js
```

The first word of the command must resolve on PATH, because the doctor checks it: `npx` does, but a local devDependency alone does not.

It exits non-zero when a rule of severity `error` is violated, and prints the violating dependencies. Rules of severity `warn` or `info` do not change the exit code: that follows from the documented exit code, which counts the `error` violations.

4. Chain the same command after the existing lint command in `verify.lint`, for example `npm run lint && npx depcruise <source folder> --config .dependency-cruiser.js`, or call it from inside the lint script, so CI runs both.

## Module boundary check: alternative

Tool: eslint-plugin-boundaries. Choose it when the boundary must show in `verify.lint_file`, per file, on every edit, because it runs inside the lint.

- Declare the elements first, in the lint settings: `boundaries/elements`, a list of entries with `type` and `pattern`.
- Then enforce the policies with the `boundaries/dependencies` rule. Older versions of the plugin may call the rule `boundaries/element-types`: check the one installed.
- A policy entry accepts a `message`, which is where the violation line goes.

The cost is the up-front declaration of elements; in return the feedback arrives while the file is being edited.

## The violation message

The check prints one line per violation, in the format of the template:

```text
<file:line>: <what is wrong>. Breaks <golden path id>, decision "<decision>". Fix: <how>.
```

Where to put it in each tool:

- dependency-cruiser: the `comment` of the rule, shown by the `err-long` reporter (`--output-type err-long`).
- eslint-plugin-boundaries: the `message` of the policy.

Fallback, when the reporter does not print the line in that format: a script of the project runs the command, reads its output, and prints the line in the format. The script is the command named in `verified_by: automated:`, and `verify.lint` runs it.

## Prove the check

A check that was never seen failing proves nothing. Before changing `verified_by`:

1. Run the command on the branch and see it exit 0.
2. Plant a real violation: import, across modules, what the decision forbids.
3. Run it again and see a non-zero exit code and a message with the `file:line`, `Breaks` and `Fix:`.
4. Then undo the violation with `git restore <file>` or `git checkout -- <file>`, and confirm the command exits 0 again.
5. Only then change `verified_by` to `automated: <command>` and raise the minor version of the golden path.

Beware of a check that never fails: a rule whose path matches nothing stays green forever, and only the planted violation shows it.

## Not verified

The consulted documentation did not confirm the following. Check each before relying on it:

- The exact text the `err-long` reporter of dependency-cruiser prints for the `comment`, and whether it fits the violation line format. If not, use the fallback script.
- The name of the policy rule of eslint-plugin-boundaries in the installed version (the current documentation shows `boundaries/dependencies`; `boundaries/element-types` is the older name, not confirmed here).
- The ESLint versions the plugin supports.
- The `message` placeholders available in a policy beyond the one the documentation shows.
- The default config name of `--init`: the default is `.dependency-cruiser.js`; check the file `--init` created.

Confirmed in the documentation: the rule fields `name`, `severity`, `comment`, `from` and `to`, with `path` as a regular expression; the `err` and `err-long` reporters, with an exit code equal to the number of `error` violations; `boundaries/elements` with `type` and `pattern`; the `message` option on policies.
