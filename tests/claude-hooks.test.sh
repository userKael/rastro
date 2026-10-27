. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/json.sh"
unset CLAUDE_PROJECT_DIR RASTRO_CONFIG RASTRO_LIB
HOOKS="$RASTRO_TESTS_DIR/../hooks/claude"
FAKE_LINT="$RASTRO_TESTS_DIR/fixtures/fake-lint.sh"
write_config() {
  mkdir -p "$1/.rastro"
  printf '%s\n' "$2" >"$1/.rastro/config.yml"
}
full_config() {
  cat <<EOF
verify:
  lint_file: "bash $FAKE_LINT {file}"
  source_globs: [src/**/*.ts]
  typecheck: "npm run tc"
  unit: "npm test"
  integration: "npm run test:int"
  integration_when: ["**/migrations/**"]
workspace: .agent/
EOF
}
new_repo() {
  local repo
  repo=$(make_tmp_repo) || return 1
  write_config "$repo" "$(full_config)"
  printf '%s\n' "$repo"
}
put() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}
run_hook() {
  run_cmd env CLAUDE_PROJECT_DIR="$1" bash "$HOOKS/$2" <<<"$3"
}
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}
bash_input() {
  printf '{"tool_input":{"command":"%s"}}' "$(json_escape "$1")"
}
file_input() {
  printf '{"tool_input":{"file_path":"%s"}}' "$(json_escape "$1")"
}
tool_input() {
  printf '{"tool_name":"%s","tool_input":{"command":"%s"}}' "$1" "$(json_escape "$2")"
}
GUARD_TOOL=""
guard() {
  if [ -n "$GUARD_TOOL" ]; then
    run_hook "$GUARD_REPO" guard-git.sh "$(tool_input "$GUARD_TOOL" "$1")"
  else
    run_hook "$GUARD_REPO" guard-git.sh "$(bash_input "$1")"
  fi
}
as_tool() {
  GUARD_TOOL=$1
  shift
  "$@"
  GUARD_TOOL=""
}
expect_denied() {
  local cmd
  for cmd in "$@"; do
    guard "$cmd"
    assert_status 2 "denied: $cmd"
    assert_eq 1 "$([ -n "$ERR" ] && echo 1 || echo 0)" "denied with a reason: $cmd"
  done
}
expect_allowed() {
  local cmd
  for cmd in "$@"; do
    guard "$cmd"
    assert_status 0 "allowed: $cmd"
    assert_eq "" "$OUT$ERR" "allowed in silence: $cmd"
  done
}
GUARD_REPO=$(new_repo)
test_guard_denies() {
  expect_denied \
    'git add -A' 'git add --all' 'git add .' 'cd x && git add -A' 'git -C . add -A' \
    'git commit -am "x"' 'git commit --all -m x' 'git commit -m x --no-verify' 'git add .agent/plan.md'
}
test_guard_allows() {
  expect_allowed 'git add src/a.ts' 'git commit -m "add -A support"' 'git status' 'git add ./src/a.ts'
}
test_guard_ignores_quoted_text() {
  expect_allowed 'echo "git add -A"' "echo 'git commit --no-verify'"
}
test_guard_denies_variants() {
  expect_denied \
    'git -C "my dir" add -A' 'git -C . -c core.x=1 add --all' '/usr/bin/git add -A' 'git.exe add .' \
    'git add -fA' 'git add -- .' 'git add src/a.ts .' 'git add ./' 'git add *' \
    'git commit -a' 'git commit -vam x' 'git commit -m x -n' 'git commit -nm x' 'git commit --no-verify' \
    'git add .agent' 'git add ./.agent/plan.md' 'git add -f .agent/plan.md' 'git commit -m x .agent/plan.md' \
    'FOO=1 git add -A' 'env GIT_DIR=x git add -A' 'echo hi; git add .' 'true || git add -A' 'git status | git add -A' \
    '(git add -A)' 'echo $(git add -A)' 'if true; then git add -A; fi' '{ git add -A; }' 'git add -A # note' \
    'git add -A "src/a.ts"' $'git status\ngit add -A' $'git add \\\n  -A' 'echo x | xargs git add -A' \
    'git commit -m "msg" -a'
}
test_guard_allows_variants() {
  expect_allowed \
    'git add -u' 'git add -p' 'git add --patch src/a.ts' 'git commit --amend -m x' 'git commit --amend --no-edit' \
    'git commit -mamend' 'git commit -m -a' 'git commit -m x -- src/a.ts' 'git commit -F msg.txt' \
    'git add .agentx/file' 'git add src/.agent/file' 'git add .gitignore' 'git add .env.example' \
    'git commit -m x 2>.agent/log' 'git status > .agent/status.txt' 'git add src/a.ts > .agent/out' \
    'git log --all --oneline' 'git branch -a' 'git -C src status' 'git push' 'ls -la' 'npm run build -- -A' \
    'echo git add -A' 'echo x # git add -A' 'git commit -m "x" # git add -A' 'git add src/a.ts && git commit -m "fix: x"' \
    'git commit -m "$(git log -1 --format=%s)"' ''
}
test_guard_multiline_and_heredoc() {
  expect_allowed \
    $'cat > notes.md <<\'EOF\'\ngit add -A\ngit commit --no-verify\nEOF' \
    $'git commit -F - <<EOF\nuse git add -A never\nEOF' \
    $'git commit -m "$(cat <<\'EOF\'\nfix(hooks): block "git add -A" and git commit -a\n\nBody with (parens), `git add --all` and it\'s fine.\nEOF\n)"' \
    $'git status\nls'
  expect_denied \
    $'cat > notes.md <<\'EOF\'\nx\nEOF\ngit add -A' \
    $'git commit -m "$(cat <<\'EOF\'\nmsg "quoted"\nEOF\n)" -a' \
    $'echo "$(git add -A)"'
}
test_guard_powershell_denies() {
  as_tool PowerShell expect_denied \
    'git add -A' 'git commit -m x --no-verify' 'git -C . add -A' 'git add .agent/plan.md'
}
test_guard_powershell_allows() {
  as_tool PowerShell expect_allowed \
    'git add src/a.ts' 'git commit -m "add -A support"' $'git status `\n-s' "Write-Output 'git add -A'"
}
test_guard_powershell_lexing() {
  as_tool PowerShell expect_denied \
    'git add .agent\plan.md' 'git -C "C:\My Project\" add -A' 'git `add -A' '& git add -A' \
    'git add -A; git status' 'git status | git add .' 'git commit -am "x"' 'git commit -m x -n' \
    $'$m = @"\nmsg "x"\n"@\ngit add -A' $'git status `\n  && git add -A'
  as_tool PowerShell expect_allowed \
    'Write-Output "git add -A"' 'git add src\a.ts' 'echo `git add -A' \
    $'@\'\ngit add -A\n\'@ | Set-Content notes.md' \
    $'git commit -m @"\nmsg with git add -A and "quotes"\n"@' \
    'git commit -m "C:\dir\" -- src\a.ts' 'git commit -m x 2>.agent\log'
}
test_guard_bash_tool_name() {
  as_tool Bash expect_denied 'git add -A' 'git commit -m x --no-verify' 'echo `git add -A`'
  as_tool Bash expect_allowed 'git add src/a.ts' 'Write-Output "git add -A"' 'git add .agent\plan.md'
}
test_guard_workspace_path_forms() {
  write_config "$GUARD_REPO" $'workspace: .agent'
  expect_denied 'git add .agent/plan.md' 'git add .agent' 'git commit -m x ./.agent/plan.md'
  expect_allowed 'git add src/a.ts' 'git add .agentx'
  write_config "$GUARD_REPO" $'workspace: ""'
  expect_allowed 'git add .agent/plan.md'
  write_config "$GUARD_REPO" "$(full_config)"
}
test_guard_default_workspace_when_absent() {
  write_config "$GUARD_REPO" $'project:\n  name: bookstore'
  expect_denied 'git add .agent/plan.md' 'git commit -m x .agent/plan.md'
  expect_allowed 'git add src/a.ts' 'git add .agentx/file'
  guard 'git add .agent/plan.md'
  assert_contains "$ERR" ".agent/" "no workspace key: the reason names the default .agent/"
  write_config "$GUARD_REPO" "$(full_config)"
}
readme_config() {
  awk '
    { sub(/\r$/, "") }
    /^The shortest valid config:/ { want = 1; next }
    want && /^```yaml/ { on = 1; next }
    on && /^```/ { exit }
    on { print }
  ' "$RASTRO_TESTS_DIR/../README.md"
}
test_guard_readme_shortest_config_is_safe() {
  local cfg
  cfg=$(readme_config)
  assert_contains "$cfg" "verify:" "the shortest config is found in README.md"
  assert_not_contains "$cfg" "workspace" "the shortest config leaves workspace out"
  write_config "$GUARD_REPO" "$cfg"
  guard 'git add .agent/plan.md'
  assert_status 2 "README shortest config: git add .agent/plan.md is denied"
  write_config "$GUARD_REPO" "$(full_config)"
}
test_guard_hooks_path() {
  expect_denied \
    'git -c core.hooksPath=/dev/null commit -m x' 'git -c core.hookspath= commit -m x' \
    'git -c "core.hooksPath=/tmp/none" commit -m x' "git -c 'core.hooksPath=x' push" \
    'git -C . -c core.hooksPath=x commit -m y' 'git --config-env=core.hooksPath=HOOKS commit -m x' \
    'git --config-env core.hooksPath=HOOKS commit -m x' \
    'git config core.hooksPath /tmp/hooks' 'git config --local core.hooksPath .husky' \
    'git config --global core.hooksPath ~/hooks' 'git config core.hookspath x' \
    'git config --unset core.hooksPath' 'git config --unset-all core.hooksPath' \
    'git config set core.hooksPath x' 'git config unset core.hooksPath' \
    'git config core.hooksPath ".rastro/git-hooks-old"'
  expect_allowed \
    'git config core.hooksPath .rastro/git-hooks' 'git config core.hooksPath ./.rastro/git-hooks/' \
    'git config core.hooksPath ".rastro/git-hooks"' 'git config --local core.hooksPath .rastro/git-hooks' \
    'git config set core.hooksPath .rastro/git-hooks' \
    'git config core.hooksPath' 'git config --get core.hooksPath' 'git config get core.hooksPath' \
    'git -c user.name=x commit -m y' 'git config user.name x' 'git config --unset user.name' \
    'echo "git config core.hooksPath x"'
  guard 'git -c core.hooksPath=/dev/null commit -m x'
  assert_contains "$ERR" "core.hooksPath" "hooksPath override: names the setting"
  guard 'git config core.hooksPath /tmp/hooks'
  assert_contains "$ERR" ".rastro/git-hooks" "git config core.hooksPath: names the only value allowed"
  as_tool PowerShell expect_allowed 'git config core.hooksPath .rastro\git-hooks'
  as_tool PowerShell expect_denied 'git config core.hooksPath C:\hooks' 'git -c core.hooksPath=x commit -m y'
}
test_guard_reason_names_rule_and_fix() {
  guard 'git add -A'
  assert_contains "$ERR" "git add <path>" "add -A: names the right command"
  guard 'git commit -am x'
  assert_contains "$ERR" "git add <path>" "commit -a: names the right command"
  guard 'git commit -m x --no-verify'
  assert_contains "$ERR" "--no-verify" "no-verify: names the rule"
  guard 'git add .agent/plan.md'
  assert_contains "$ERR" ".agent" "workspace: names the folder"
}
test_guard_fails_closed_on_bad_config() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'workspace: [.agent/'
  run_hook "$repo" guard-git.sh "$(bash_input 'git status')"
  assert_status 2 "unsupported list form: blocks"
  assert_contains "$ERR" "unsupported list form" "unsupported list form: says why"
  run_hook "$repo" guard-git.sh "$(bash_input 'ls -la')"
  assert_status 0 "command that never mentions git: not blocked by the config"
  assert_eq "" "$OUT$ERR" "command that never mentions git: silent"
}
test_guard_ignores_other_input() {
  run_hook "$GUARD_REPO" guard-git.sh '{"tool_input":{"file_path":"a.ts"}}'
  assert_status 0 "input without a command: status"
  assert_eq "" "$OUT$ERR" "input without a command: silent"
  run_hook "$GUARD_REPO" guard-git.sh ''
  assert_status 0 "empty input: status"
}
test_lint_hook_clean() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "const a = 1"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 0 "clean file: status"
  assert_eq "" "$OUT$ERR" "clean file: silent"
}
test_lint_hook_red() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 2 "red file: status"
  assert_contains "$ERR" "BAD found" "red file: lint output reaches stderr"
  assert_contains "$ERR" "src/a.ts" "red file: names the repo-relative path"
}
test_lint_hook_ignores_non_source() {
  local repo
  repo=$(new_repo)
  put "$repo" README.md "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/README.md")"
  assert_status 0 "non-source file: status"
  assert_eq "" "$OUT$ERR" "non-source file: silent"
}
test_lint_hook_path_with_space() {
  local repo
  repo=$(new_repo)
  put "$repo" "src/my dir/a.ts" "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/my dir/a.ts")"
  assert_status 2 "path with space: status"
  assert_contains "$ERR" "src/my dir/a.ts:1: BAD found" "path with space: whole path reaches the linter"
}
test_lint_hook_path_with_shell_characters() {
  local repo
  repo=$(new_repo)
  put "$repo" "src/o'brien & co/\$x.ts" "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/o'brien & co/\$x.ts")"
  assert_status 2 "quote, ampersand and dollar in the path: status"
  assert_contains "$ERR" "src/o'brien & co/\$x.ts:1: BAD found" "quote, ampersand and dollar in the path: passed as one word"
}
test_lint_hook_windows_path_forms() {
  command -v cygpath >/dev/null || return 0
  local repo mixed win drive posix
  repo=$(new_repo)
  put "$repo" src/a.ts "BAD"
  mixed=$(cygpath -m "$repo")
  win=$(cygpath -w "$repo")
  drive=$(printf '%s' "${mixed:0:1}" | tr '[:upper:]' '[:lower:]')
  posix="/$drive/${mixed:3}"
  run_cmd env CLAUDE_PROJECT_DIR="$mixed" bash "$HOOKS/lint-edited-file.sh" <<<"$(file_input "$win\\src\\a.ts")"
  assert_status 2 "root C:/ and file C:\\: status"
  run_cmd env CLAUDE_PROJECT_DIR="$win" bash "$HOOKS/lint-edited-file.sh" <<<"$(file_input "$mixed/src/a.ts")"
  assert_status 2 "root C:\\ and file C:/: status"
  run_cmd env CLAUDE_PROJECT_DIR="$mixed" bash "$HOOKS/lint-edited-file.sh" <<<"$(file_input "$posix/src/a.ts")"
  assert_status 2 "root C:/ and file /c/: status"
  run_cmd env CLAUDE_PROJECT_DIR="$win" bash "$HOOKS/lint-edited-file.sh" <<<"$(file_input "${mixed:0:1}$(printf '%s' "${mixed:1}" | tr '[:upper:]' '[:lower:]')/src/a.ts")"
  assert_status 2 "differing case under a Windows root: status"
}
test_lint_hook_outside_project() {
  local repo other
  repo=$(new_repo)
  other="$RASTRO_TEST_TMP/elsewhere"
  put "$other" src/a.ts "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$other/src/a.ts")"
  assert_status 0 "file outside the project: status"
  assert_eq "" "$OUT$ERR" "file outside the project: silent"
}
test_lint_hook_without_lint_command() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  source_globs: [src/**/*.ts]'
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 0 "no verify.lint_file: status"
  assert_eq "" "$OUT$ERR" "no verify.lint_file: silent, no claim of success"
}
test_lint_hook_missing_linter_reaches_claude() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  lint_file: "rastro-no-such-linter {file}"\n  source_globs: [src/**/*.ts]'
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 2 "linter not found: status 2, so the reason reaches Claude"
  assert_contains "$ERR" "did not run" "linter not found: says so"
  assert_contains "$ERR" "lint did not run on src/a.ts" "linter not found: names the edited file"
  assert_contains "$ERR" "command not found" "linter not found: gives the reason"
  assert_not_contains "$ERR" "verify.lint_file failed" "linter not found: not reported as a red lint"
  put "$repo" src/b.ts "fine"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/b.ts")"
  assert_status 2 "linter not found: the next edit reports it again"
}
test_lint_hook_missing_file_and_empty_payload() {
  local repo
  repo=$(new_repo)
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/gone.ts")"
  assert_status 0 "file does not exist: status"
  run_hook "$repo" lint-edited-file.sh '{"tool_input":{"command":"ls"}}'
  assert_status 0 "payload without file_path: status"
  assert_eq "" "$OUT$ERR" "payload without file_path: silent"
}
test_lint_hook_unsupported_list_fails_closed() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  lint_file: "true {file}"\n  source_globs:\n    - src/**/*.ts'
  put "$repo" src/a.ts "x"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 2 "block list in source_globs: status"
  assert_contains "$ERR" "unsupported list form" "block list in source_globs: says why"
}
test_lint_hook_reports_rules_location() {
  local repo
  repo=$(new_repo)
  write_config "$repo" "$(full_config)"$'\narchitecture:\n  rules: "docs/rules.md"'
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 2 "red with architecture.rules: status"
  assert_contains "$ERR" "docs/rules.md" "red with architecture.rules: points at the rules"
}
STOP_IDLE='{"stop_hook_active":false}'
test_stop_active_noop() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" stop-check.sh '{"stop_hook_active":true}'
  assert_status 0 "stop already active: status"
  assert_eq "" "$OUT$ERR" "stop already active: silent"
}
test_stop_no_changes() {
  local repo
  repo=$(new_repo)
  printf '.rastro/\n' >"$repo/.gitignore"
  git -C "$repo" add .gitignore
  git -C "$repo" commit -q -m "init"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "clean tree: status"
  assert_eq "" "$OUT$ERR" "clean tree: silent"
}
test_stop_red() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 2 "red source file: status"
  assert_contains "$ERR" "src/a.ts:1: BAD found" "red source file: lint output reaches stderr"
  assert_contains "$ERR" "do not turn off a rule" "red source file: says not to silence the rule"
}
test_stop_green_reminds_integration() {
  local repo
  repo=$(new_repo)
  put "$repo" src/migrations/1.ts "const a = 1"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "green with migration: status"
  assert_eq '{"systemMessage":' "${OUT:0:17}" "green with migration: one systemMessage object on stdout"
  assert_contains "$OUT" "npm test" "green with migration: unit reminder"
  assert_contains "$OUT" "npm run test:int" "green with migration: integration reminder"
  assert_contains "$OUT" "npm run tc" "green with migration: typecheck reminder"
  assert_eq "" "$ERR" "green with migration: nothing on stderr"
}
test_stop_green_no_integration() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "const a = 1"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "green without migration: status"
  assert_eq '{"systemMessage":' "${OUT:0:17}" "green without migration: one systemMessage object on stdout"
  assert_contains "$OUT" "npm test" "green without migration: unit reminder"
  assert_not_contains "$OUT" "npm run test:int" "green without migration: no integration reminder"
}
test_stop_reminder_escapes_commands() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  source_globs: [src/**/*.ts]\n  unit: "echo \\"a b\\" C:\\\\x"'
  put "$repo" src/a.ts "const a = 1"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "command with quotes and a backslash: status"
  assert_contains "$(rastro_json_string systemMessage <<<"$OUT")" 'verify.unit: echo "a b" C:\x' "command with quotes and a backslash: survives the JSON round trip"
  assert_eq 1 "$([ "$(printf '%s\n' "$OUT" | wc -l)" -eq 1 ] && echo 1 || echo 0)" "the message is one line of JSON"
}
test_stop_non_source_change_is_silent() {
  local repo
  repo=$(new_repo)
  put "$repo" README.md "BAD"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "only a non-source file changed: status"
  assert_eq "" "$OUT$ERR" "only a non-source file changed: silent"
}
test_stop_tracked_modified_deleted_and_renamed() {
  local repo
  repo=$(new_repo)
  put "$repo" src/keep.ts "const a = 1"
  put "$repo" src/gone.ts "const b = 1"
  put "$repo" "src/old name.ts" "const c = 1"
  git -C "$repo" add src
  git -C "$repo" commit -q -m "init"
  put "$repo" src/keep.ts "BAD"
  rm "$repo/src/gone.ts"
  git -C "$repo" mv "src/old name.ts" "src/new name.ts"
  put "$repo" "src/new name.ts" "BAD"
  git -C "$repo" add "src/new name.ts"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 2 "tracked, deleted and renamed files: status"
  assert_contains "$ERR" "src/keep.ts:1: BAD found" "modified tracked file is linted"
  assert_contains "$ERR" "src/new name.ts:1: BAD found" "renamed file is linted under its new name"
  assert_not_contains "$ERR" "gone.ts" "deleted file is not linted"
  assert_not_contains "$ERR" "old name.ts" "rename origin is not linted"
}
test_stop_lists_every_red_file() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts "BAD"
  put "$repo" src/b.ts "BAD"
  put "$repo" src/c.ts "fine"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 2 "two red files: status"
  assert_contains "$ERR" "src/a.ts:1: BAD found" "first red file listed"
  assert_contains "$ERR" "src/b.ts:1: BAD found" "second red file listed"
  assert_not_contains "$ERR" "src/c.ts" "green file not listed"
}
test_stop_outside_git_repo() {
  local dir
  dir=$(mktemp -d "$RASTRO_TEST_TMP/plain.XXXXXX")
  write_config "$dir" "$(full_config)"
  put "$dir" src/a.ts "BAD"
  run_hook "$dir" stop-check.sh "$STOP_IDLE"
  assert_status 0 "not a git work tree: status"
  assert_eq "" "$OUT$ERR" "not a git work tree: silent"
}
test_stop_without_lint_command_still_reminds() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  source_globs: [src/**/*.ts]\n  unit: "npm test"'
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "no verify.lint_file: status"
  assert_contains "$OUT" "npm test" "no verify.lint_file: unit reminder"
}
test_stop_missing_linter_is_not_red() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  lint_file: "rastro-no-such-linter {file}"\n  source_globs: [src/**/*.ts]\n  unit: "npm test"'
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "linter not found: status"
  assert_contains "$ERR" "did not run" "linter not found: says so"
  assert_contains "$OUT" "npm test" "linter not found: unit reminder"
  assert_contains "$(rastro_json_string systemMessage <<<"$OUT")" "lint did not run: verify.lint_file exited 127, command not found" "linter not found: the systemMessage says lint did not run, and why"
  write_config "$repo" $'verify:\n  lint_file: "rastro-no-such-linter {file}"\n  source_globs: [src/**/*.ts]'
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "linter not found, no other verify command: status"
  assert_eq '{"systemMessage":' "${OUT:0:17}" "linter not found, no other verify command: a systemMessage is still printed"
  assert_contains "$OUT" "lint did not run" "linter not found, no other verify command: the message says lint did not run"
}
test_stop_unsupported_list_fails_closed() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  source_globs:\n    - src/**/*.ts'
  put "$repo" src/a.ts "x"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 2 "block list in source_globs: status"
  assert_contains "$ERR" "unsupported list form" "block list in source_globs: says why"
}
test_claude_hooks_noop_without_config() {
  local repo
  repo=$(make_tmp_repo)
  put "$repo" src/a.ts "BAD"
  run_hook "$repo" guard-git.sh "$(bash_input 'git add -A')"
  assert_status 0 "guard without config: status"
  assert_eq "" "$OUT$ERR" "guard without config: silent"
  run_hook "$repo" lint-edited-file.sh "$(file_input "$repo/src/a.ts")"
  assert_status 0 "lint without config: status"
  assert_eq "" "$OUT$ERR" "lint without config: silent"
  run_hook "$repo" stop-check.sh "$STOP_IDLE"
  assert_status 0 "stop without config: status"
  assert_eq "" "$OUT$ERR" "stop without config: silent"
}
test_hooks_json() {
  local file="$HOOKS/../hooks.json" script
  assert_eq 1 "$(grep -c '^  "hooks": {' "$file")" "top-level hooks key"
  for script in guard-git lint-edited-file stop-check doctor; do
    assert_contains "$(<"$file")" '${CLAUDE_PLUGIN_ROOT}/hooks/claude/'"$script.sh" "registers $script"
  done
  assert_contains "$(<"$file")" '"matcher": "Bash|PowerShell"' "guard matcher covers Bash and PowerShell"
  assert_contains "$(<"$file")" '"matcher": "Write|Edit|MultiEdit"' "lint matcher"
  for script in guard-git lint-edited-file stop-check; do
    assert_eq 1 "$([ -x "$HOOKS/$script.sh" ] && echo 1 || echo 0)" "$script.sh is executable"
  done
}
test_guard_denies; test_guard_allows; test_guard_ignores_quoted_text
test_guard_denies_variants; test_guard_allows_variants; test_guard_multiline_and_heredoc
test_guard_powershell_denies; test_guard_powershell_allows; test_guard_powershell_lexing; test_guard_bash_tool_name
test_guard_workspace_path_forms; test_guard_reason_names_rule_and_fix
test_guard_default_workspace_when_absent; test_guard_readme_shortest_config_is_safe; test_guard_hooks_path
test_guard_fails_closed_on_bad_config; test_guard_ignores_other_input
test_lint_hook_clean; test_lint_hook_red; test_lint_hook_ignores_non_source; test_lint_hook_path_with_space
test_lint_hook_path_with_shell_characters; test_lint_hook_windows_path_forms; test_lint_hook_outside_project
test_lint_hook_without_lint_command; test_lint_hook_missing_linter_reaches_claude
test_lint_hook_missing_file_and_empty_payload; test_lint_hook_unsupported_list_fails_closed
test_lint_hook_reports_rules_location
test_stop_active_noop; test_stop_no_changes; test_stop_red
test_stop_green_reminds_integration; test_stop_green_no_integration; test_stop_reminder_escapes_commands
test_stop_non_source_change_is_silent
test_stop_tracked_modified_deleted_and_renamed; test_stop_lists_every_red_file; test_stop_outside_git_repo
test_stop_without_lint_command_still_reminds; test_stop_missing_linter_is_not_red
test_stop_unsupported_list_fails_closed
test_claude_hooks_noop_without_config
test_hooks_json
finish
