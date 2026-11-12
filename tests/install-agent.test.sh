. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
INSTALL="$RASTRO_TESTS_DIR/../scripts/install-agent.sh"
new_project() {
  mktemp -d "$RASTRO_TEST_TMP/proj.XXXXXX"
}
new_home() {
  mktemp -d "$RASTRO_TEST_TMP/home.XXXXXX"
}
put() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}
# Every run points HOME at an empty temporary directory, so nothing can reach
# the real agent configuration of the person running the tests.
run_install() {
  FAKE_HOME=$(new_home)
  run_cmd env HOME="$FAKE_HOME" USERPROFILE="$FAKE_HOME" bash "$INSTALL" "$@"
}
test_install_codex_writes_skills_and_hooks() {
  local proj
  proj=$(new_project)
  run_install codex "$proj"
  assert_status 0 "installs"
  [ -f "$proj/.agents/skills/setup/SKILL.md" ] || _assert_fail "setup skill not copied"
  assert_contains "$(<"$proj/.codex/hooks.json")" 'adapt.sh\" codex guard-git' "guard wired"
  assert_contains "$(<"$proj/.codex/hooks.json")" 'adapt.sh\" codex stop-check' "stop wired"
  assert_contains "$(<"$proj/.codex/hooks.json")" '"matcher": "apply_patch|Edit|Write"' "edit matcher"
  assert_contains "$OUT" "RASTRO_ROOT" "documents RASTRO_ROOT"
  assert_contains "$OUT" "/hooks" "says Codex asks to trust the hooks"
  assert_contains "$OUT" "do not commit" "warns about the absolute path"
}
test_install_cursor_writes_skills_and_hooks() {
  local proj body event
  proj=$(new_project)
  run_install cursor "$proj"
  assert_status 0 "installs"
  [ -f "$proj/.agents/skills/setup/SKILL.md" ] || _assert_fail "setup skill not copied"
  body=$(<"$proj/.cursor/hooks.json")
  assert_contains "$body" '"version": 1' "version 1"
  for event in sessionStart beforeShellExecution afterFileEdit stop; do
    assert_contains "$body" "\"$event\"" "event $event"
  done
  assert_contains "$body" 'adapt.sh\" cursor guard-git' "guard wired"
  [ ! -e "$proj/.codex" ] || _assert_fail "cursor install wrote .codex"
}
test_install_is_idempotent() {
  local proj first
  proj=$(new_project)
  run_install codex "$proj"
  first=$(find "$proj" -type f | sort | xargs cksum)
  run_install codex "$proj"
  assert_status 0 "second run"
  assert_eq "$first" "$(find "$proj" -type f | sort | xargs cksum)" "nothing changed"
}
test_install_refuses_unknown_agent() {
  local proj
  proj=$(new_project)
  run_install vim "$proj"
  assert_status 2 "unknown agent"
  [ -z "$(ls -A "$proj")" ] || _assert_fail "wrote into the project"
}
test_install_refuses_missing_project() {
  run_install codex "$RASTRO_TEST_TMP/nope"
  assert_status 2 "missing project"
  [ ! -e "$RASTRO_TEST_TMP/nope" ] || _assert_fail "created the project directory"
}
test_install_never_overwrites_foreign_hooks() {
  local proj
  proj=$(new_project)
  put "$proj" .codex/hooks.json '{"hooks":{}}'
  run_install codex "$proj"
  assert_status 3 "refuses to merge"
  assert_eq '{"hooks":{}}' "$(<"$proj/.codex/hooks.json")" "file untouched"
  assert_contains "$OUT" "adapt.sh" "prints the block to add"
}
test_install_link_makes_symlinks_or_says_it_could_not() {
  local proj
  proj=$(new_project)
  run_install --link codex "$proj"
  assert_status 0 "installs with --link"
  if [ -L "$proj/.agents/skills/setup" ]; then
    [ -f "$proj/.agents/skills/setup/SKILL.md" ] || _assert_fail "symlink does not resolve"
  else
    assert_contains "$OUT$ERR" "symlink" "says links were not possible"
    [ -f "$proj/.agents/skills/setup/SKILL.md" ] || _assert_fail "no fallback copy"
  fi
}
test_install_does_not_touch_home() {
  local proj
  proj=$(new_project)
  run_install cursor "$proj"
  [ -z "$(ls -A "$FAKE_HOME")" ] || _assert_fail "wrote into HOME" "$(ls -A "$FAKE_HOME")"
}
test_install_codex_writes_skills_and_hooks
test_install_cursor_writes_skills_and_hooks
test_install_is_idempotent
test_install_refuses_unknown_agent
test_install_refuses_missing_project
test_install_never_overwrites_foreign_hooks
test_install_link_makes_symlinks_or_says_it_could_not
test_install_does_not_touch_home
finish
