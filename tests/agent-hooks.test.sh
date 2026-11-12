. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/json.sh"
unset CLAUDE_PROJECT_DIR RASTRO_CONFIG RASTRO_LIB
HOOKS="$RASTRO_TESTS_DIR/../hooks/agents"
ADAPT="$HOOKS/adapt.sh"
FAKE_LINT="$RASTRO_TESTS_DIR/fixtures/fake-lint.sh"
write_config() {
  mkdir -p "$1/.rastro"
  printf '%s\n' "$2" >"$1/.rastro/config.yml"
}
full_config() {
  cat <<CFG
verify:
  lint_file: "bash $FAKE_LINT {file}"
  source_globs: [src/**/*.ts]
  typecheck: "npm run tc"
  unit: "npm test"
workspace: .agent/
CFG
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
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}
run_adapt() {
  local repo=$1 agent=$2 hook=$3 json=$4
  run_cmd env CLAUDE_PROJECT_DIR="$repo" bash "$ADAPT" "$agent" "$hook" <<<"$json"
}
test_unknown_agent_and_hook_are_refused() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" vim guard-git '{}'
  assert_status 64 "unknown agent"
  assert_contains "$ERR" "unknown agent" "says why"
  run_adapt "$repo" codex nope '{}'
  assert_status 64 "unknown hook"
  assert_contains "$ERR" "unknown hook" "says why"
}
test_codex_guard_denies_wildcard_add() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" codex guard-git '{"hook_event_name":"PreToolUse","cwd":"'"$repo"'","tool_name":"Bash","tool_input":{"command":"git add -A"}}'
  assert_status 2 "denied"
  assert_contains "$ERR" "git add -A" "reason reaches stderr"
}
test_codex_guard_allows_status() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" codex guard-git '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  assert_status 0 "allowed"
  assert_eq "" "$OUT$ERR" "in silence"
}
test_codex_apply_patch_lints_every_file() {
  local repo patch
  repo=$(new_repo)
  put "$repo" src/a.ts ok
  put "$repo" src/b.ts BAD
  patch='*** Begin Patch\n*** Update File: src/a.ts\n@@\n*** Add File: src/b.ts\n+BAD\n*** End Patch'
  run_adapt "$repo" codex lint-edited-file '{"cwd":"'"$repo"'","tool_name":"apply_patch","tool_input":{"command":"'"$patch"'"}}'
  assert_status 2 "second file fails the hook"
  assert_contains "$ERR" "src/b.ts" "names the file"
}
test_codex_apply_patch_clean_files_pass() {
  local repo patch
  repo=$(new_repo)
  put "$repo" src/a.ts ok
  put "$repo" src/b.ts fine
  patch='*** Begin Patch\n*** Update File: src/a.ts\n@@\n*** Add File: src/b.ts\n+fine\n*** End Patch'
  run_adapt "$repo" codex lint-edited-file '{"cwd":"'"$repo"'","tool_name":"apply_patch","tool_input":{"command":"'"$patch"'"}}'
  assert_status 0 "clean files pass"
  assert_eq "" "$OUT$ERR" "in silence"
}
test_codex_edit_tool_passes_file_path_through() {
  local repo
  repo=$(new_repo)
  put "$repo" src/b.ts BAD
  run_adapt "$repo" codex lint-edited-file '{"cwd":"'"$repo"'","tool_name":"Edit","tool_input":{"file_path":"'"$repo"'/src/b.ts"}}'
  assert_status 2 "an Edit payload with file_path is linted as is"
}
test_codex_session_start_is_plain_text() {
  local repo
  repo=$(make_tmp_repo)
  run_adapt "$repo" codex doctor '{"hook_event_name":"SessionStart","cwd":"'"$repo"'"}'
  assert_status 0 "doctor never blocks"
  assert_contains "$OUT" "no .rastro/config.yml found" "plain doctor text"
  assert_not_contains "$OUT" "additional_context" "not wrapped for codex"
}
test_codex_stop_passes_through() {
  local repo
  repo=$(new_repo)
  put "$repo" src/b.ts BAD
  run_adapt "$repo" codex stop-check '{"hook_event_name":"Stop","cwd":"'"$repo"'","stop_hook_active":false}'
  assert_status 2 "stop block passes through"
  assert_contains "$ERR" "src/b.ts" "reason on stderr"
  put "$repo" src/b.ts fine
  run_adapt "$repo" codex stop-check '{"stop_hook_active":false}'
  assert_status 0 "green stop"
  assert_contains "$OUT" "systemMessage" "informative JSON passes through"
}
test_cursor_guard_denies_as_json() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" cursor guard-git '{"command":"git commit --no-verify -m x","cwd":"'"$repo"'"}'
  assert_status 0 "cursor deny is a JSON answer"
  assert_contains "$OUT" '"permission":"deny"' "deny"
  assert_contains "$OUT" '"user_message"' "message for the person"
  assert_contains "$OUT" '"agent_message"' "message for the agent"
  assert_contains "$OUT" "--no-verify" "reason carried"
}
test_cursor_guard_allows_in_silence() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" cursor guard-git '{"command":"git status","cwd":"'"$repo"'"}'
  assert_status 0 "allowed"
  assert_eq "" "$OUT" "no output on allow"
}
test_cursor_after_file_edit_lints() {
  local repo
  repo=$(new_repo)
  put "$repo" src/b.ts BAD
  run_adapt "$repo" cursor lint-edited-file '{"file_path":"'"$repo"'/src/b.ts","edits":[]}'
  assert_status 2 "lint failure"
  assert_contains "$ERR" "src/b.ts" "names the file"
}
test_cursor_stop_blocks_as_followup() {
  local repo
  repo=$(new_repo)
  put "$repo" src/b.ts BAD
  run_adapt "$repo" cursor stop-check '{"status":"completed","loop_count":0}'
  assert_status 0 "cursor stop answers in JSON"
  assert_contains "$OUT" '"followup_message"' "follow-up"
  assert_contains "$OUT" "src/b.ts" "carries the reason"
}
test_cursor_stop_does_not_loop() {
  local repo
  repo=$(new_repo)
  put "$repo" src/b.ts BAD
  run_adapt "$repo" cursor stop-check '{"status":"completed","loop_count":1}'
  assert_status 0 "second pass"
  assert_eq "" "$OUT" "no follow-up on a second pass"
}
test_cursor_stop_drops_informative_output() {
  local repo
  repo=$(new_repo)
  put "$repo" src/a.ts fine
  run_adapt "$repo" cursor stop-check '{"status":"completed","loop_count":0}'
  assert_status 0 "green stop"
  assert_eq "" "$OUT" "the verify reminder is not sent as a follow-up"
}
test_cursor_session_start_wraps_doctor_text() {
  local repo
  repo=$(new_repo)
  run_adapt "$repo" cursor doctor '{"session_id":"s","is_background_agent":false}'
  assert_status 0 "doctor never blocks"
  assert_contains "$OUT" '"additional_context"' "wrapped"
  assert_contains "$OUT" "rastro doctor" "carries the doctor line"
}
test_adapt_marks_what_is_not_verified() {
  assert_contains "$(<"$ADAPT")" "NOT VERIFIED" "unconfirmed behaviour is marked in the shim header"
}
test_unknown_agent_and_hook_are_refused
test_codex_guard_denies_wildcard_add; test_codex_guard_allows_status
test_codex_apply_patch_lints_every_file; test_codex_apply_patch_clean_files_pass
test_codex_edit_tool_passes_file_path_through
test_codex_session_start_is_plain_text; test_codex_stop_passes_through
test_cursor_guard_denies_as_json; test_cursor_guard_allows_in_silence
test_cursor_after_file_edit_lints
test_cursor_stop_blocks_as_followup; test_cursor_stop_does_not_loop; test_cursor_stop_drops_informative_output
test_cursor_session_start_wraps_doctor_text
test_adapt_marks_what_is_not_verified
finish
