. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
unset RASTRO_ROOT
INSTALL="$RASTRO_TESTS_DIR/../scripts/install-agent.sh"
ADAPT="$RASTRO_TESTS_DIR/../hooks/agents/adapt.sh"
RASTRO_DIR=$(cd "$RASTRO_TESTS_DIR/.." && pwd)
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
  assert_contains "$OUT" "open /hooks in Codex" "says Codex asks to trust the hooks"
  assert_contains "$OUT" "do not commit" "warns about the absolute path"
  assert_contains "$OUT" "Add this line to .gitignore: .codex/hooks.json" "prints the gitignore line for the hook file"
  [ ! -e "$proj/.gitignore" ] || _assert_fail "the installer never writes .gitignore"
}
test_codex_hooks_map_each_event_to_a_shim_hook() {
  local proj body pair
  proj=$(new_project)
  run_install codex "$proj"
  body=$(<"$proj/.codex/hooks.json")
  assert_contains "$body" '"SessionStart"' "SessionStart"
  assert_contains "$body" 'codex doctor", "timeout": 30' "doctor on SessionStart"
  assert_contains "$body" '"matcher": "Bash"' "Bash matcher"
  assert_contains "$body" 'codex guard-git", "timeout": 10' "guard on PreToolUse"
  assert_contains "$body" 'codex lint-edited-file", "timeout": 60' "lint on PostToolUse"
  assert_contains "$body" 'codex stop-check", "timeout": 120' "stop-check on Stop"
  while IFS= read -r pair; do
    run_cmd env CLAUDE_PROJECT_DIR="$proj" bash "$ADAPT" $pair <<<'{}'
    [ "$STATUS" -ne 64 ] || _assert_fail "shim rejects generated command: $pair"
  done < <(grep -o 'adapt.sh\\" [a-z]* [a-z-]*' "$proj/.codex/hooks.json" | sed 's/.*" //')
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
  local shim="bash \\\"$RASTRO_DIR/hooks/agents/adapt.sh\\\""
  assert_contains "$body" "\"sessionStart\": [{\"command\": \"$shim cursor doctor\"}]" "sessionStart"
  assert_contains "$body" "\"beforeShellExecution\": [{\"command\": \"$shim cursor guard-git\"}]" "beforeShellExecution"
  assert_contains "$body" "\"afterFileEdit\": [{\"command\": \"$shim cursor lint-edited-file\"}]" "afterFileEdit"
  assert_contains "$body" "\"stop\": [{\"command\": \"$shim cursor stop-check\"}]" "stop"
  assert_not_contains "$OUT" "open /hooks in Codex" "no Codex warning for Cursor"
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
  assert_contains "$ERR" "unknown agent" "says why"
  [ -z "$(ls -A "$proj")" ] || _assert_fail "wrote into the project"
}
test_install_refuses_missing_project() {
  run_install codex "$RASTRO_TEST_TMP/nope"
  assert_status 2 "missing project"
  assert_contains "$ERR" "project directory not found" "says why"
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
test_install_refuses_missing_rastro_root() {
  local proj
  proj=$(new_project)
  FAKE_HOME=$(new_home)
  run_cmd env HOME="$FAKE_HOME" RASTRO_ROOT="$RASTRO_TEST_TMP/nope" bash "$INSTALL" codex "$proj"
  assert_status 2 "missing RASTRO_ROOT"
  assert_contains "$ERR" "RASTRO_ROOT" "says why"
  [ -z "$(ls -A "$proj")" ] || _assert_fail "wrote into the project"
}
test_install_never_deletes_a_foreign_skill() {
  local proj
  proj=$(new_project)
  put "$proj" .agents/skills/setup/SKILL.md "my own setup skill"
  put "$proj" .agents/skills/setup/notes.md "my notes"
  run_install codex "$proj"
  assert_status 3 "foreign skill blocks a clean exit"
  assert_contains "$ERR" ".agents/skills/setup" "names the skill left alone"
  assert_eq "my own setup skill" "$(<"$proj/.agents/skills/setup/SKILL.md")" "SKILL.md intact"
  assert_eq "my notes" "$(<"$proj/.agents/skills/setup/notes.md")" "notes.md intact"
  [ -f "$proj/.agents/skills/init/SKILL.md" ] || _assert_fail "other skills not installed"
  run_install codex "$proj"
  assert_status 3 "still refused on the second run"
  assert_eq "my notes" "$(<"$proj/.agents/skills/setup/notes.md")" "notes.md intact after rerun"
}
test_install_refuses_skills_folder_inside_rastro() {
  local proj fake
  proj=$(new_project)
  fake=$(mktemp -d "$RASTRO_TEST_TMP/rastro.XXXXXX")
  mkdir -p "$fake/skills/demo" "$fake/hooks/agents" "$proj/.agents"
  put "$fake" skills/demo/SKILL.md "demo"
  put "$fake" hooks/agents/adapt.sh "#"
  ln -s "$fake/skills" "$proj/.agents/skills" 2>/dev/null || true
  if [ ! -L "$proj/.agents/skills" ]; then
    return 0
  fi
  FAKE_HOME=$(new_home)
  run_cmd env HOME="$FAKE_HOME" RASTRO_ROOT="$fake" bash "$INSTALL" codex "$proj"
  assert_status 2 "refuses"
  assert_eq "demo" "$(<"$fake/skills/demo/SKILL.md")" "rastro skill intact"
}
test_install_refuses_project_inside_rastro() {
  local fake proj
  fake=$(mktemp -d "$RASTRO_TEST_TMP/rastro.XXXXXX")
  mkdir -p "$fake/skills/demo" "$fake/hooks/agents"
  put "$fake" skills/demo/SKILL.md "demo"
  put "$fake" hooks/agents/adapt.sh "#"
  proj="$fake/sub"
  mkdir -p "$proj/.agents/skills"
  FAKE_HOME=$(new_home)
  run_cmd env HOME="$FAKE_HOME" RASTRO_ROOT="$fake" bash "$INSTALL" codex "$proj"
  assert_status 2 "a skills folder under the rastro directory is refused"
  assert_eq "demo" "$(<"$fake/skills/demo/SKILL.md")" "rastro skill intact"
  proj="$fake/fresh"
  mkdir -p "$proj"
  run_cmd env HOME="$FAKE_HOME" RASTRO_ROOT="$fake" bash "$INSTALL" codex "$proj"
  assert_status 2 "a project under the rastro directory is refused before any skills folder exists"
  assert_contains "$ERR" "install into a project outside it" "says why"
  [ ! -e "$proj/.agents" ] || _assert_fail "wrote .agents inside the rastro directory"
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
test_codex_hooks_map_each_event_to_a_shim_hook
test_install_refuses_missing_rastro_root
test_install_never_deletes_a_foreign_skill
test_install_refuses_skills_folder_inside_rastro
test_install_refuses_project_inside_rastro
test_install_never_overwrites_foreign_hooks
test_install_link_makes_symlinks_or_says_it_could_not
test_install_does_not_touch_home
finish
