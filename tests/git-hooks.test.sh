. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
unset CLAUDE_PROJECT_DIR RASTRO_CONFIG RASTRO_LIB
HOOKS="$RASTRO_TESTS_DIR/../hooks/git"
MSG="$RASTRO_TEST_TMP/msg.txt"
assert_failed() {
  assert_eq 1 "$([ "$STATUS" -ne 0 ] && echo 1 || echo 0)" "$1"
}
in_repo() {
  ( cd "$1" && shift && "$@" )
}
new_repo() {
  local repo
  repo=$(make_tmp_repo) || return 1
  use_config "$repo" hooks
  printf '%s\n' "$repo"
}
write_config() {
  mkdir -p "$1/.rastro"
  printf '%s\n' "$2" >"$1/.rastro/config.yml"
}
stage() {
  mkdir -p "$(dirname "$1/$2")"
  printf 'x\n' >"$1/$2"
  git -C "$1" add -f -- "$2"
}
commit() {
  git -C "$1" commit -q -m "$2"
}
init_commit() {
  git -C "$1" commit -q --allow-empty -m "init"
}
test_precommit_blocks_env() {
  local repo
  repo=$(new_repo)
  stage "$repo" .env.local
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "env file staged: status"
  assert_contains "$ERR" "forbidden path staged: .env.local" "env file staged: message"
}
test_precommit_blocks_workspace() {
  local repo
  repo=$(new_repo)
  stage "$repo" .agent/plan.md
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "workspace staged with add -f: status"
  assert_contains "$ERR" "forbidden path staged: .agent/plan.md" "workspace staged: message"
}
test_precommit_blocks_workspace_without_trailing_slash() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'workspace: .agent'
  stage "$repo" .agent/plan.md
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "workspace without a trailing slash: status"
  assert_contains "$ERR" "forbidden path staged: .agent/plan.md" "workspace without a trailing slash: message"
}
test_precommit_allows_source() {
  local repo
  repo=$(new_repo)
  stage "$repo" src/a.ts
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 0 "source staged: status"
  assert_eq "" "$OUT$ERR" "source staged: silent"
}
test_precommit_path_with_space() {
  local repo
  repo=$(new_repo)
  stage "$repo" "notes/my old.bak"
  stage "$repo" "My Project/src/a.ts"
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "path with space: status"
  assert_contains "$ERR" "forbidden path staged: notes/my old.bak" "path with space: whole path in message"
  assert_not_contains "$ERR" "My Project" "path with space: allowed sibling not reported"
}
test_precommit_lists_every_forbidden_path() {
  local repo
  repo=$(new_repo)
  stage "$repo" .env
  stage "$repo" coverage/lcov.info
  stage "$repo" src/a.ts
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "several forbidden: status"
  assert_contains "$ERR" "forbidden path staged: .env" "several forbidden: first listed"
  assert_contains "$ERR" "forbidden path staged: coverage/lcov.info" "several forbidden: second listed"
  assert_not_contains "$ERR" "src/a.ts" "several forbidden: source not listed"
}
test_precommit_non_ascii_name() {
  local repo
  repo=$(new_repo)
  stage "$repo" "café.bak"
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "non-ASCII name: status"
  assert_not_contains "$ERR" '\303' "non-ASCII name: path is not C-quoted"
}
test_precommit_allows_deletion() {
  local repo
  repo=$(new_repo)
  stage "$repo" .env
  commit "$repo" "add env by mistake"
  git -C "$repo" rm -q -f --cached -- .env
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 0 "removing a forbidden file from the index: status"
  assert_eq "" "$OUT$ERR" "removing a forbidden file from the index: silent"
}
test_precommit_first_commit_on_unborn_branch() {
  local repo
  repo=$(new_repo)
  stage "$repo" .env
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "unborn branch: status"
  assert_contains "$ERR" "forbidden path staged: .env" "unborn branch: message"
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
test_precommit_defaults_when_keys_are_absent() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" $'project:\n  name: bookstore'
  stage "$repo" .env
  stage "$repo" notes/old.bak
  stage "$repo" .agent/plan.md
  stage "$repo" src/a.ts
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "no forbidden_paths and no workspace: status"
  assert_contains "$ERR" "forbidden path staged: .env" "no forbidden_paths: default .env* applies"
  assert_contains "$ERR" "forbidden path staged: notes/old.bak" "no forbidden_paths: default *.bak applies"
  assert_contains "$ERR" "forbidden path staged: .agent/plan.md" "no workspace: default .agent/ applies"
  assert_not_contains "$ERR" "src/a.ts" "defaults: source not listed"
}
test_precommit_explicit_empty_means_empty() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" $'conventions:\n  forbidden_paths: []'
  stage "$repo" .env
  stage "$repo" .agent/plan.md
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "forbidden_paths: [] and no workspace: status"
  assert_contains "$ERR" "forbidden path staged: .agent/plan.md" "forbidden_paths: [] keeps the default workspace"
  assert_not_contains "$ERR" "staged: .env" "forbidden_paths: [] refuses no pattern"
  write_config "$repo" $'conventions:\n  forbidden_paths: []\nworkspace: ""'
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 0 "forbidden_paths: [] and workspace: \"\": status"
  assert_eq "" "$OUT$ERR" "forbidden_paths: [] and workspace: \"\": silent"
}
test_readme_shortest_config_is_safe() {
  local repo cfg
  cfg=$(readme_config)
  assert_contains "$cfg" "verify:" "the shortest config is found in README.md"
  assert_not_contains "$cfg" "forbidden_paths" "the shortest config leaves forbidden_paths out"
  assert_not_contains "$cfg" "merge" "the shortest config leaves code_host.merge out"
  repo=$(make_tmp_repo)
  write_config "$repo" "$cfg"
  stage "$repo" .env
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 1 "README shortest config: .env staged, status"
  assert_contains "$ERR" "forbidden path staged: .env" "README shortest config: .env staged, message"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "Totally Bad Title."
  assert_status 1 "README shortest config: bad PR title, status"
  assert_contains "$ERR" "PR title rejected" "README shortest config: bad PR title, message"
}
test_precommit_unsupported_list_fails_closed() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'conventions:\n  forbidden_paths:\n    - .env*\nworkspace: .agent/'
  stage "$repo" .env
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 2 "block list: status"
  assert_contains "$ERR" "conventions.forbidden_paths" "block list: message names the key"
  stage "$repo" src/a.ts
  git -C "$repo" rm -q -f --cached -- .env
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 2 "block list with only allowed files staged: still fails closed"
}
test_installed_layout() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/.rastro/git-hooks" "$repo/.rastro/lib"
  cp "$HOOKS"/* "$repo/.rastro/git-hooks/"
  cp "$RASTRO_TESTS_DIR/../hooks/lib/"* "$repo/.rastro/lib/"
  stage "$repo" .env
  run_cmd in_repo "$repo" .rastro/git-hooks/pre-commit
  assert_status 1 "installed under .rastro: status"
  assert_contains "$ERR" "forbidden path staged: .env" "installed under .rastro: finds its lib"
  run_cmd in_repo "$repo" env RASTRO_LIB="$repo/nowhere" .rastro/git-hooks/pre-commit
  assert_status 1 "RASTRO_LIB pointing nowhere: fails instead of passing"
  assert_not_contains "$ERR" "forbidden path staged" "RASTRO_LIB pointing nowhere: lib is not found"
}
test_git_commit_through_hooks_path() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/.rastro/git-hooks" "$repo/.rastro/lib"
  cp "$HOOKS"/* "$repo/.rastro/git-hooks/"
  cp "$RASTRO_TESTS_DIR/../hooks/lib/"* "$repo/.rastro/lib/"
  git -C "$repo" config core.hooksPath .rastro/git-hooks
  git -C "$repo" checkout -q -b feat/W-001-search
  stage "$repo" .env
  run_cmd git -C "$repo" commit -q -m "feat(catalog): [W-001] add search"
  assert_status 1 "git commit with a forbidden file: status"
  assert_contains "$ERR" "forbidden path staged: .env" "git commit with a forbidden file: pre-commit ran"
  git -C "$repo" rm -q -f --cached -- .env
  stage "$repo" src/a.ts
  run_cmd git -C "$repo" commit -q -m "add search"
  assert_status 1 "git commit with an invalid header: status"
  assert_contains "$ERR" "header does not match" "git commit with an invalid header: commit-msg ran"
  run_cmd git -C "$repo" commit -q -m "feat(catalog): [W-001] add search"
  assert_status 0 "git commit with a valid header: status"
  assert_eq "feat(catalog): [W-001] add search" "$(git -C "$repo" log -1 --format=%s)" "git commit with a valid header: commit created"
}
test_commit_msg_reads_first_non_comment_line() {
  local repo
  repo=$(new_repo)
  printf '# Please enter the commit message\n# Lines starting with # are ignored\nfeat(catalog): [W-001] add search\n\nBody Line with Capitals.\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "comment lines then a valid header: status"
  assert_eq "" "$OUT$ERR" "comment lines then a valid header: silent"
  printf '# comment\nadd search\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 1 "comment lines then an invalid header: status"
  assert_contains "$ERR" "header does not match" "comment lines then an invalid header: reason"
  assert_contains "$ERR" "add search" "comment lines then an invalid header: header quoted"
  printf '\n\n# comment\nfeat(catalog): add search\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "leading blank lines skipped"
  printf '# only comments\n# nothing else\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "message with only comments is left to git"
  printf 'feat(catalog): [W-001] add search\r\n\r\nbody\r\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "CRLF message file"
  printf 'feat(catalog): [W-001] add search' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "header without trailing newline"
}
test_commit_msg_uses_branch_id() {
  local repo
  repo=$(new_repo)
  git -C "$repo" checkout -q -b feat/W-001-search
  printf 'feat(catalog): add search\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 1 "branch with id, header without: status"
  assert_contains "$ERR" "missing id [W-001]" "branch with id, header without: reason"
  printf 'feat(catalog): [W-001] add search\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "branch with id, matching header"
}
test_commit_msg_detached_head() {
  local repo
  repo=$(new_repo)
  init_commit "$repo"
  git -C "$repo" checkout -q --detach
  printf 'fix(orders): fix total\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "detached HEAD: status"
  assert_eq "" "$OUT$ERR" "detached HEAD: silent"
}
test_commit_msg_unsupported_list_fails_closed() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'architecture:\n  modules:\n    - catalog\ntracker:\n  key: W'
  printf 'feat(catalog): [W-001] add search\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 2 "block list: status"
  assert_contains "$ERR" "architecture.modules" "block list: message names the key"
}
test_commit_msg_missing_file_fails() {
  local repo
  repo=$(new_repo)
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$RASTRO_TEST_TMP/does-not-exist"
  assert_failed "unreadable message file is not a pass"
}
test_check_pr_title_skips_without_squash() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'tracker:\n  key: W\ncode_host:\n  merge: merge'
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "totally invalid" "feat/W-001-search"
  assert_status 0 "merge strategy merge: status"
  assert_eq "" "$OUT$ERR" "merge strategy merge: silent"
  write_config "$repo" $'tracker:\n  key: W'
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "totally invalid" "feat/W-001-search"
  assert_status 1 "no code_host.merge: the default squash applies, status"
  assert_contains "$ERR" "header does not match" "no code_host.merge: the default squash applies, reason"
  write_config "$repo" $'tracker:\n  key: W\ncode_host:\n  merge: ""'
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "totally invalid" "feat/W-001-search"
  assert_status 1 "empty code_host.merge: the default squash applies"
}
test_check_pr_title_checks_merge_and_autosquash_prefixes() {
  local repo title
  repo=$(new_repo)
  for title in "Merge branch 'main' into feat/W-001-search" "fixup! feat(catalog): [W-001] add search" "squash! feat(catalog): [W-001] add search"; do
    run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "$title" "feat/W-001-search"
    assert_status 1 "PR title '$title' is checked, not exempt: status"
    assert_contains "$ERR" "PR title rejected" "PR title '$title' is checked, not exempt: reason"
  done
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" 'Revert "feat(catalog): [W-001] add search"' "feat/W-001-search"
  assert_status 0 "PR title that reverts a commit stays exempt: status"
  assert_eq "" "$OUT$ERR" "PR title that reverts a commit stays exempt: silent"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" 'Draft: Revert "feat(catalog): [W-001] add search"' "feat/W-001-search"
  assert_status 0 "draft revert title stays exempt"
  git -C "$repo" checkout -q -b feat/W-001-search
  for title in "Merge branch 'main' into feat/W-001-search" "fixup! feat(catalog): [W-001] add search" "squash! feat(catalog): [W-001] add search" 'Revert "feat(catalog): [W-001] add search"'; do
    printf '%s\n' "$title" >"$MSG"
    run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
    assert_status 0 "commit-msg still exempts '$title'"
  done
}
test_check_pr_title_squash() {
  local repo
  repo=$(new_repo)
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "feat(catalog): [W-001] add search" "feat/W-001-search"
  assert_status 0 "squash, valid title: status"
  assert_eq "" "$OUT$ERR" "squash, valid title: silent"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "totally invalid" "feat/W-001-search"
  assert_status 1 "squash, invalid title: status"
  assert_contains "$ERR" "header does not match" "squash, invalid title: reason"
  assert_contains "$ERR" "totally invalid" "squash, invalid title: title quoted"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "feat(catalog): [W-002] add search" "feat/W-001-search"
  assert_status 1 "squash, id differs from the head branch: status"
  assert_contains "$ERR" "id differs from branch (W-001)" "squash, id differs from the head branch: reason"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "docs(docs): add design" "docs/design-search"
  assert_status 0 "squash, head branch without id"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "docs(docs): add design" ""
  assert_status 0 "squash, empty head branch (not a PR event)"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "feat(catalog): add search" "feat/W-001-search"
  assert_status 1 "squash, title without the id of the head branch: status"
  assert_contains "$ERR" "missing id [W-001]" "squash, title without the id of the head branch: reason"
}
test_check_pr_title_draft_prefix() {
  local repo prefix
  repo=$(new_repo)
  for prefix in "Draft: " "[Draft] " "WIP: " "draft: " "[DRAFT] " "wip: "; do
    run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "${prefix}feat(catalog): [W-001] add search" "feat/W-001-search"
    assert_status 0 "draft prefix '$prefix' is stripped before validation: status"
    assert_eq "" "$OUT$ERR" "draft prefix '$prefix' is stripped before validation: silent"
  done
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "Draft: Bad title" "feat/W-001-search"
  assert_status 1 "draft prefix does not excuse a bad title: status"
  assert_contains "$ERR" "header does not match" "draft prefix does not excuse a bad title: reason"
  assert_contains "$ERR" "Draft: Bad title" "draft prefix does not excuse a bad title: title quoted as given"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "Draft: WIP: feat(catalog): [W-001] add search" "feat/W-001-search"
  assert_status 1 "only one leading draft prefix is stripped"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "Draft:feat(catalog): [W-001] add search" "feat/W-001-search"
  assert_status 1 "a prefix without its trailing space is not a draft marker"
}
test_check_changed_paths() {
  local repo
  repo=$(new_repo)
  init_commit "$repo"
  git -C "$repo" checkout -q -b feat/W-001-x
  stage "$repo" src/a.ts
  commit "$repo" "add source"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" main
  assert_status 0 "clean branch: status"
  assert_eq "" "$OUT$ERR" "clean branch: silent"
  stage "$repo" coverage/x
  stage "$repo" "notes/my old.bak"
  commit "$repo" "add generated files"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" main
  assert_status 1 "branch with forbidden files: status"
  assert_contains "$ERR" "forbidden path changed: coverage/x" "branch with forbidden files: first listed"
  assert_contains "$ERR" "forbidden path changed: notes/my old.bak" "branch with forbidden files: path with space listed"
  assert_not_contains "$ERR" "src/a.ts" "branch with forbidden files: source not listed"
}
test_check_changed_paths_ignores_deletions() {
  local repo
  repo=$(new_repo)
  stage "$repo" .env
  commit "$repo" "env committed on main"
  git -C "$repo" checkout -q -b fix/W-002-remove-env
  git -C "$repo" rm -q -- .env
  commit "$repo" "remove env"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" main
  assert_status 0 "branch that deletes a forbidden file: status"
}
test_check_changed_paths_errors() {
  local repo
  repo=$(new_repo)
  init_commit "$repo"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" no-such-ref
  assert_failed "unknown base ref is not a pass"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths"
  assert_status 2 "missing base ref: status"
  assert_contains "$ERR" "usage" "missing base ref: usage"
  write_config "$repo" $'conventions:\n  forbidden_paths:\n    - .env*'
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" main
  assert_status 2 "block list: status"
  assert_contains "$ERR" "conventions.forbidden_paths" "block list: message names the key"
}
MERGE_CONFIG=$'tracker:\n  kind: local\n  key: W\narchitecture:\n  modules: [catalog]\ncode_host:\n  merge: merge'
test_check_commits_with_merge() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" "$MERGE_CONFIG"
  init_commit "$repo"
  git -C "$repo" checkout -q -b feat/W-001-search
  stage "$repo" src/a.ts
  commit "$repo" "feat(catalog): [W-001] add search"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "merge mode, valid commits: status"
  assert_eq "" "$OUT$ERR" "merge mode, valid commits: silent"
  git -C "$repo" checkout -q main
  stage "$repo" src/main.ts
  commit "$repo" "Main Moved On."
  git -C "$repo" checkout -q feat/W-001-search
  git -C "$repo" merge -q --no-ff --no-edit main
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "merge commits and base commits are not checked"
  stage "$repo" src/b.ts
  commit "$repo" "Add More Stuff."
  stage "$repo" src/c.ts
  commit "$repo" "feat(catalog): add other"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 1 "merge mode, bad subject: status"
  assert_contains "$ERR" "Add More Stuff." "merge mode, bad subject: quoted"
  assert_contains "$ERR" "header does not match" "merge mode, bad subject: reason"
  assert_not_contains "$ERR" "add other" "merge mode: stops at the first bad subject"
}
test_check_commits_uses_branch_id() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" "$MERGE_CONFIG"
  init_commit "$repo"
  git -C "$repo" checkout -q -b feat/W-001-search
  stage "$repo" src/a.ts
  commit "$repo" "feat(catalog): add search"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 1 "current branch carries an id, subject does not: status"
  assert_contains "$ERR" "missing id [W-001]" "current branch carries an id, subject does not: reason"
  git -C "$repo" checkout -q --detach
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "detached HEAD without a head branch: no id required"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main feat/W-001-search
  assert_status 1 "detached HEAD with the head branch given: status"
  assert_contains "$ERR" "missing id [W-001]" "detached HEAD with the head branch given: reason"
}
test_check_commits_skips_squash() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" $'tracker:\n  kind: local\n  key: W\ncode_host:\n  merge: squash'
  init_commit "$repo"
  git -C "$repo" checkout -q -b feat/W-001-search
  stage "$repo" src/a.ts
  commit "$repo" "Totally Bad Subject."
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "squash: status"
  assert_eq "" "$OUT$ERR" "squash: silent, the PR title is the commit"
  write_config "$repo" $'tracker:\n  kind: local\n  key: W'
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "no code_host.merge: the default squash applies"
  write_config "$repo" $'tracker:\n  kind: local\n  key: W\ncode_host:\n  merge: rebase'
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 1 "rebase merge: commits are checked"
}
test_check_commits_errors() {
  local repo
  repo=$(make_tmp_repo)
  write_config "$repo" "$MERGE_CONFIG"
  init_commit "$repo"
  run_cmd in_repo "$repo" "$HOOKS/check-commits"
  assert_status 2 "missing base ref: status"
  assert_contains "$ERR" "usage" "missing base ref: usage"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" --all
  assert_status 2 "base ref that looks like an option: status"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" no-such-ref
  assert_failed "unknown base ref is not a pass"
  write_config "$repo" $'architecture:\n  modules:\n    - catalog\ncode_host:\n  merge: merge'
  git -C "$repo" checkout -q -b feat/x
  stage "$repo" src/a.ts
  commit "$repo" "feat(catalog): add search"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 2 "block list: status"
  assert_contains "$ERR" "architecture.modules" "block list: message names the key"
}
test_check_commits_is_executable() {
  local mode
  mode=$(git -C "$RASTRO_TESTS_DIR/.." ls-files -s -- hooks/git/check-commits | cut -d' ' -f1)
  assert_eq 100755 "$mode" "hooks/git/check-commits is executable in the index"
}
test_hooks_noop_without_config() {
  local repo name
  repo=$(make_tmp_repo)
  init_commit "$repo"
  stage "$repo" .env
  printf 'not a valid header\n' >"$MSG"
  run_cmd in_repo "$repo" "$HOOKS/pre-commit"
  assert_status 0 "pre-commit without config: status"
  assert_eq "" "$OUT$ERR" "pre-commit without config: silent"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg" "$MSG"
  assert_status 0 "commit-msg without config: status"
  assert_eq "" "$OUT$ERR" "commit-msg without config: silent"
  run_cmd in_repo "$repo" "$HOOKS/commit-msg"
  assert_status 0 "commit-msg without config or argument: status"
  assert_eq "" "$OUT$ERR" "commit-msg without config or argument: silent"
  run_cmd in_repo "$repo" "$HOOKS/check-pr-title" "not valid" "feat/x"
  assert_status 0 "check-pr-title without config: status"
  assert_eq "" "$OUT$ERR" "check-pr-title without config: silent"
  run_cmd in_repo "$repo" "$HOOKS/check-changed-paths" main
  assert_status 0 "check-changed-paths without config: status"
  assert_eq "" "$OUT$ERR" "check-changed-paths without config: silent"
  run_cmd in_repo "$repo" "$HOOKS/check-commits" main
  assert_status 0 "check-commits without config: status"
  assert_eq "" "$OUT$ERR" "check-commits without config: silent"
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 0 "run-verify without config: status"
  assert_eq "" "$OUT$ERR" "run-verify without config: silent"
}
test_run_verify_unit() {
  local repo
  repo=$(new_repo)
  init_commit "$repo"
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 0 "verify.unit true: status"
  write_config "$repo" $'verify:\n  unit: "false"'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_failed "verify.unit false: non-zero"
  assert_contains "$ERR" "verify.unit" "verify.unit false: names the failing step"
}
test_run_verify_order_and_stop() {
  local repo log
  repo=$(new_repo)
  init_commit "$repo"
  log="$repo/order.log"
  write_config "$repo" $'verify:\n  lint: "echo lint >> order.log"\n  typecheck: "echo typecheck >> order.log"\n  unit: "echo unit >> order.log"\n  integration: "echo integration >> order.log"'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 0 "all green: status"
  assert_eq $'lint\ntypecheck\nunit' "$(cat "$log")" "all green: lint, typecheck, unit in order; integration not triggered"
  rm -f "$log"
  write_config "$repo" $'verify:\n  lint: "echo lint >> order.log"\n  typecheck: "echo typecheck >> order.log; exit 3"\n  unit: "echo unit >> order.log"'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 3 "typecheck red: exits with its status"
  assert_eq $'lint\ntypecheck' "$(cat "$log")" "typecheck red: unit does not run"
  assert_contains "$ERR" "verify.typecheck" "typecheck red: names the failing step"
  rm -f "$log"
  write_config "$repo" $'verify:\n  lint:\n  typecheck: ""\n  unit: "echo unit >> order.log"'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 0 "empty steps skipped: status"
  assert_eq "unit" "$(cat "$log")" "empty steps skipped: only unit ran"
}
test_run_verify_runs_at_repo_root() {
  local repo
  repo=$(new_repo)
  init_commit "$repo"
  mkdir -p "$repo/sub"
  write_config "$repo" $'verify:\n  unit: "pwd > where.txt"'
  run_cmd in_repo "$repo/sub" "$HOOKS/run-verify"
  assert_status 0 "from a subdirectory: status"
  assert_eq "yes" "$([ -f "$repo/where.txt" ] && echo yes || echo no)" "from a subdirectory: command ran at the repo root"
}
test_run_verify_no_commands() {
  local repo
  repo=$(new_repo)
  write_config "$repo" $'verify:\n  unit:'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 1 "no verify command: status"
  assert_contains "$ERR" "no verify command configured" "no verify command: says so"
  write_config "$repo" $'project:\n  name: bookstore'
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 1 "no verify key at all: status"
  assert_contains "$ERR" "verify.unit" "no verify key at all: names the keys to set"
}
test_run_verify_integration_when() {
  local repo log
  repo=$(new_repo)
  init_commit "$repo"
  log="$repo/order.log"
  write_config "$repo" $'verify:\n  unit: "true"\n  integration: "echo integration >> order.log"\n  integration_when: [db/**, "my dir/*.sql"]'
  git -C "$repo" checkout -q -b feat/W-001-x
  stage "$repo" README.md
  commit "$repo" "docs only"
  run_cmd in_repo "$repo" "$HOOKS/run-verify" main
  assert_status 0 "unrelated change: status"
  assert_eq "no" "$([ -f "$log" ] && echo yes || echo no)" "unrelated change: integration skipped"
  stage "$repo" "my dir/q.sql"
  commit "$repo" "add query"
  run_cmd in_repo "$repo" "$HOOKS/run-verify" main
  assert_status 0 "matching change: status"
  assert_eq "integration" "$(cat "$log")" "matching change with a space in the path: integration ran"
  rm -f "$log"
  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b feat/W-002-y
  stage "$repo" db/migrations/001.sql
  commit "$repo" "add migration"
  run_cmd in_repo "$repo" "$HOOKS/run-verify"
  assert_status 0 "default base from project.base_branch: status"
  assert_eq "integration" "$(cat "$log")" "default base from project.base_branch: integration ran"
  rm -f "$log"
  git -C "$repo" checkout -q main
  run_cmd in_repo "$repo" "$HOOKS/run-verify" main
  assert_eq "no" "$([ -f "$log" ] && echo yes || echo no)" "no change against the base: integration skipped"
  stage "$repo" db/new.sql
  run_cmd in_repo "$repo" "$HOOKS/run-verify" main
  assert_eq "integration" "$(cat "$log")" "staged but uncommitted matching file triggers integration"
}
test_run_verify_integration_without_globs_or_base() {
  local repo log
  repo=$(new_repo)
  init_commit "$repo"
  log="$repo/order.log"
  write_config "$repo" $'verify:\n  unit: "true"\n  integration: "echo integration >> order.log"\n  integration_when: []'
  git -C "$repo" checkout -q -b feat/W-001-x
  stage "$repo" db/a.sql
  commit "$repo" "add sql"
  run_cmd in_repo "$repo" "$HOOKS/run-verify" main
  assert_eq "no" "$([ -f "$log" ] && echo yes || echo no)" "empty integration_when never triggers"
  write_config "$repo" $'verify:\n  unit: "true"\n  integration: "echo integration >> order.log"\n  integration_when: [db/**]'
  run_cmd in_repo "$repo" "$HOOKS/run-verify" no-such-ref
  assert_status 0 "unknown base ref: status"
  assert_eq "integration" "$(cat "$log")" "unknown base ref: cannot tell what changed, so integration runs"
  assert_contains "$ERR" "no-such-ref" "unknown base ref: says why"
}
test_precommit_blocks_env; test_precommit_blocks_workspace; test_precommit_blocks_workspace_without_trailing_slash
test_precommit_allows_source
test_precommit_path_with_space; test_precommit_lists_every_forbidden_path; test_precommit_non_ascii_name
test_precommit_allows_deletion; test_precommit_first_commit_on_unborn_branch
test_precommit_defaults_when_keys_are_absent; test_precommit_explicit_empty_means_empty
test_readme_shortest_config_is_safe
test_precommit_unsupported_list_fails_closed; test_installed_layout; test_git_commit_through_hooks_path
test_commit_msg_reads_first_non_comment_line; test_commit_msg_uses_branch_id
test_commit_msg_detached_head; test_commit_msg_unsupported_list_fails_closed
test_commit_msg_missing_file_fails
test_check_pr_title_skips_without_squash; test_check_pr_title_squash; test_check_pr_title_draft_prefix
test_check_pr_title_checks_merge_and_autosquash_prefixes
test_check_changed_paths; test_check_changed_paths_ignores_deletions; test_check_changed_paths_errors
test_check_commits_with_merge; test_check_commits_uses_branch_id; test_check_commits_skips_squash
test_check_commits_errors; test_check_commits_is_executable
test_hooks_noop_without_config
test_run_verify_unit; test_run_verify_order_and_stop; test_run_verify_runs_at_repo_root
test_run_verify_no_commands; test_run_verify_integration_when
test_run_verify_integration_without_globs_or_base
finish
