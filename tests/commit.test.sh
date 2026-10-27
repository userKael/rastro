. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/config.sh"
. "$(dirname "$0")/../hooks/lib/commit.sh"
unset CLAUDE_PROJECT_DIR
FIXTURES="$RASTRO_TESTS_DIR/fixtures/config"
export RASTRO_CONFIG="$FIXTURES/hooks.yml"
CFG_TMP="$RASTRO_TEST_TMP/config.yml"
set_config() {
  printf '%s\n' "$1" >"$CFG_TMP"
  RASTRO_CONFIG="$CFG_TMP"
}
reset_config() {
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
check() {
  run_cmd rastro_check_header "$2" "$1"
  assert_status "$3" "header '$2' on '$1': status"
  if [ -n "${4-}" ]; then
    assert_contains "$ERR" "$4" "header '$2' on '$1': reason"
  else
    assert_eq "" "$ERR" "header '$2' on '$1': silent when valid"
  fi
}
test_header_table() {
  local long
  long=$(printf '%073d' 0 | tr 0 a)
  local branch header status text
  while IFS='|' read -r branch header status text; do
    check "$branch" "$header" "$status" "$text"
  done <<'EOF'
feat/W-001-search|feat(catalog): [W-001] add search by author|0|
feat/W-001-search|feat(catalog): add search by author|1|missing id [W-001]
feat/W-001-search|feat(catalog): [W-002] add search|1|id differs from branch (W-001)
feat/W-001-search|feat(shipping): [W-001] add search|1|scope not allowed
feat/W-001-search|feature(catalog): [W-001] add search|1|type not allowed
feat/W-001-search|feat(catalog): [W-001] Add search|1|subject must start lowercase
feat/W-001-search|feat(catalog): [W-001] add search.|1|subject must not end with a period
docs/design-search|docs(docs): add design for search|0|
docs/design-search|docs(docs): [W-003] add design for search|0|
feat/W-001-search|Merge branch 'main' into feat/W-001-search|0|
feat/W-001-search|Revert "feat(catalog): [W-001] add search"|0|
feat/W-001-search|fixup! feat(catalog): [W-001] add search|0|
feat/W-001-search|squash! feat(catalog): [W-001] add search|0|
feat/W-001-search|add search by author|1|header does not match {type}({scope}): [{id}] {subject}
feat/W-001-search|feat(catalog): [W-001] |1|header does not match
feat/W-001-search|feat(catalog): [W-001] 2fa support|0|
feat/W-12-search|feat(inventory): [W-12] add stock count|0|
feat/X-001-search|feat(catalog): add search|0|
feat/W-001-search|feat(shared): [W-001] extract helper|0|
feat/W-001-search|feat(infra): [W-001] add client|0|
feat/W-001-search|feat(ci): [W-001] add job|0|
feat/W-001-search|Feat(catalog): [W-001] add search|1|type not allowed
EOF
  check "feat/W-001-search" "feat(catalog): [W-001] $long" 1 "subject longer than 72 characters"
  check "feat/W-001-search" "feat(catalog): [W-001] ${long%a}" 0 ""
}
test_commit_msg_detached_head() {
  check "HEAD" "fix(orders): fix total" 0 ""
}
test_header_cr_and_trailing_space() {
  check "feat/W-001-search" $'feat(catalog): [W-001] add search\r' 0 ""
  check "feat/W-001-search" "feat(catalog): [W-001] add search  " 0 ""
  check "feat/W-001-search" $'feat(catalog): [W-001] add search.\r' 1 "subject must not end with a period"
}
in_repo() {
  ( cd "$1" && shift && "$@" )
}
test_header_default_branch() {
  local repo
  repo=$(make_tmp_repo)
  git -C "$repo" checkout -q -b feat/W-007-thing
  run_cmd in_repo "$repo" rastro_check_header "feat(catalog): add thing"
  assert_status 1 "unborn branch carries the id: status"
  assert_contains "$ERR" "missing id [W-007]" "unborn branch carries the id: reason"
  git -C "$repo" commit -q --allow-empty -m "init"
  run_cmd in_repo "$repo" rastro_check_header "feat(catalog): add thing"
  assert_status 1 "born branch carries the id: status"
  assert_contains "$ERR" "missing id [W-007]" "born branch carries the id: reason"
  run_cmd in_repo "$repo" rastro_check_header "feat(catalog): [W-007] add thing"
  assert_status 0 "current branch id accepted"
  git -C "$repo" checkout -q --detach
  run_cmd in_repo "$repo" rastro_check_header "feat(catalog): add thing"
  assert_status 0 "detached HEAD needs no id"
  assert_eq "" "$OUT$ERR" "detached HEAD is silent"
  run_cmd in_repo "$repo" rastro_branch_id
  assert_eq "" "$OUT" "detached HEAD has no branch id"
}
test_branch_id() {
  assert_eq "W-001" "$(rastro_branch_id feat/W-001-search)" "id from branch"
  assert_eq "W-12" "$(rastro_branch_id fix/W-12-x-y)" "id with two digits"
  assert_eq "" "$(rastro_branch_id docs/design-search)" "branch without id"
  assert_eq "" "$(rastro_branch_id feat/X-001-search)" "other key"
  assert_eq "" "$(rastro_branch_id feat/W-001)" "no trailing slug"
  assert_eq "" "$(rastro_branch_id W-001-search)" "no type segment"
  assert_eq "" "$(rastro_branch_id HEAD)" "detached HEAD"
  set_config $'tracker:\n  kind: none\n  key: W'
  assert_eq "" "$(rastro_branch_id feat/W-001-search)" "tracker none"
  set_config $'tracker:\n  kind: local\n  key:'
  assert_eq "" "$(rastro_branch_id feat/W-001-search)" "empty key"
  set_config $'tracker:\n  kind: local\n  key: "A.B"'
  assert_eq "A.B-5" "$(rastro_branch_id feat/A.B-5-x)" "key with a regex metacharacter, literal"
  assert_eq "" "$(rastro_branch_id feat/AxB-5-x)" "key metacharacter is not a wildcard"
  reset_config
}
test_tracker_none_and_empty_key() {
  set_config $'tracker:\n  kind: none\n  key: W\narchitecture:\n  modules: [catalog]'
  check "feat/W-001-search" "feat(catalog): add search" 0 ""
  check "feat/W-001-search" "feat(catalog): [W-001] add search" 0 ""
  set_config $'tracker:\n  kind: none\n  key:\narchitecture:\n  modules: [catalog]'
  check "feat/search" "feat(catalog): add search" 0 ""
  check "feat/search" "feat(catalog): [FOO-1] add search" 0 ""
  check "feat/search" "feat(catalog): [FOO-1] Add search" 1 "subject must start lowercase"
  reset_config
}
test_custom_format_and_types() {
  set_config $'tracker:\n  key: W\narchitecture:\n  modules: [catalog]\nconventions:\n  commit: "{type}: {subject} ({id})"\n  types: [feat, fix]'
  check "feat/W-001-x" "feat: add search (W-001)" 0 ""
  check "feat/W-001-x" "feat: add search" 1 "missing id [W-001]"
  check "feat/W-001-x" "feat: add search (W-002)" 1 "id differs from branch (W-001)"
  check "docs/design" "feat: add search" 0 ""
  check "docs/design" "feat: add search (W-009)" 0 ""
  check "feat/W-001-x" "docs: add search (W-001)" 1 "type not allowed"
  check "feat/W-001-x" "feat(catalog): add search (W-001)" 1 "header does not match {type}: {subject} ({id})"
  set_config $'tracker:\n  key: W\nconventions:\n  commit: "[{id}] {type}: {subject}"'
  check "feat/W-001-x" "[W-001] fix: add search" 0 ""
  check "feat/W-001-x" "fix: add search" 1 "missing id [W-001]"
  check "docs/design" "fix: add search" 0 ""
  set_config $'conventions:\n  commit: "{type}({scope}): {subject}"\narchitecture:\n  modules: [catalog]'
  check "feat/W-001-x" "feat(catalog): add search" 0 ""
  reset_config
}
test_unsupported_list_fails_closed() {
  set_config $'architecture:\n  modules:\n    - catalog\n    - orders\ntracker:\n  key: W'
  run_cmd rastro_check_header "feat(catalog): [W-001] add search" "feat/W-001-x"
  assert_status 2 "block list for modules: status 2"
  assert_contains "$ERR" "architecture.modules" "block list for modules: message names the key"
  set_config $'conventions:\n  types: [feat,\n    fix]\ntracker:\n  key: W'
  run_cmd rastro_check_header "feat(catalog): [W-001] add search" "feat/W-001-x"
  assert_status 2 "multi-line types: status 2"
  assert_contains "$ERR" "conventions.types" "multi-line types: message names the key"
  reset_config
}
test_no_config_is_valid() {
  RASTRO_CONFIG=/nonexistent/config.yml
  run_cmd rastro_check_header "anything goes" "feat/W-001-x"
  assert_status 0 "no config: status 0"
  assert_eq "" "$OUT$ERR" "no config: silent"
  reset_config
}
test_header_table; test_commit_msg_detached_head; test_header_cr_and_trailing_space; test_header_default_branch; test_branch_id
test_tracker_none_and_empty_key; test_custom_format_and_types; test_unsupported_list_fails_closed
test_no_config_is_valid
finish
