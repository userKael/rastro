. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT RASTRO_CONFIG RASTRO_LIB RASTRO_ROOT
DOCTOR="$RASTRO_TESTS_DIR/../hooks/claude/doctor.sh"
FIXTURE_ROOT="$RASTRO_TESTS_DIR/fixtures"
EMPTY_HOME="$RASTRO_TEST_TMP/home"
mkdir -p "$EMPTY_HOME"
CLOSING="Tell the human about each PROBLEM before starting work."
MCP_INFO_TAIL="not found by name. Connectors added through claude.ai use opaque ids; confirm before concluding it is missing."
LIB_INFO="- info: installed git hooks differ from this rastro version. Re-run setup."
LOCAL_DIR_PROBLEM="tracker.local_dir is inside the workspace, which is never committed; work items must be versioned in git"

new_repo() {
  local repo
  repo=$(make_tmp_repo) || return 1
  use_config "$repo" "$1" || return 1
  printf '%s\n' "$repo"
}
edit_config() {
  local file="$1/.rastro/config.yml"
  sed "$2" "$file" >"$file.new" && mv "$file.new" "$file"
}
put() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}
run_doctor() {
  run_cmd env CLAUDE_PROJECT_DIR="$1" RASTRO_ROOT="${DOCTOR_ROOT:-$FIXTURE_ROOT}" HOME="${DOCTOR_HOME:-$EMPTY_HOME}" bash "$DOCTOR"
}
last_line() {
  printf '%s' "${1##*$'\n'}"
}
assert_closing() {
  local last
  last=$(last_line "$OUT")
  case $last in
    "rastro doctor: "*" checks, $1 problems."*) ;;
    *) _assert_fail "$2: last line has $1 problems" "last line: $last" ;;
  esac
  if [ "$1" = 0 ]; then
    assert_not_contains "$last" "$CLOSING" "$2: no closing instruction at 0 problems"
  else
    assert_contains "$last" " problems. $CLOSING" "$2: closing instruction ends the last line"
  fi
}
count_lines_containing() {
  local n=0 line
  while IFS= read -r line; do
    case $line in *"$2"*) n=$((n + 1)) ;; esac
  done <<<"$1"
  printf '%s' "$n"
}
fake_framework() {
  local root
  root=$(mktemp -d "$RASTRO_TEST_TMP/fw.XXXXXX") || return 1
  mkdir -p "$root/hooks/lib"
  cp -R "$FIXTURE_ROOT/adapters" "$root/adapters"
  printf '%s\n' "$root"
}

put_gp() {
  mkdir -p "$1/docs/golden-paths" "$1/src/workers"
  cp "$FIXTURE_ROOT/golden-paths/processor.md" "$1/docs/golden-paths/processor.md"
  printf 'x\n' >"$1/src/workers/send-receipt.processor.ts"
}
gp_config() {
  printf '\narchitecture:\n  %s\n' "$2" >>"$1/.rastro/config.yml"
}
gp_sed() {
  local file="$1/docs/golden-paths/processor.md"
  sed "$2" "$file" >"$file.new" && mv "$file.new" "$file"
}
GP_FILE=docs/golden-paths/processor.md

test_doctor_golden_paths_absent_is_silent() {
  local repo
  repo=$(new_repo doctor-ok)
  run_doctor "$repo"
  assert_closing 0 "gp absent"
  assert_not_contains "$OUT" "golden path" "gp absent: silent"
}
test_doctor_golden_path_ok() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  run_doctor "$repo"
  assert_closing 0 "gp ok"
}
test_doctor_golden_path_missing_key() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" '/^verified_by:/d'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: missing verified_by" "gp missing key"
  assert_closing 1 "gp missing key"
}
test_doctor_golden_path_bad_status() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/^status: .*/status: draft/'
  run_doctor "$repo"
  assert_contains "$OUT" "golden path $GP_FILE: status draft is not current, under-review or retired" "gp bad status"
}
test_doctor_golden_path_retired_needs_successor() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/^status: .*/status: retired/'
  run_doctor "$repo"
  assert_contains "$OUT" "retired without superseded_by" "gp retired"
}
test_doctor_golden_path_id_mismatch() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/^id: .*/id: worker/'
  run_doctor "$repo"
  assert_contains "$OUT" "id worker does not match the file name" "gp id mismatch"
}
test_doctor_golden_path_verified_by() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/^verified_by: .*/verified_by: lint/'
  run_doctor "$repo"
  assert_contains "$OUT" "verified_by is neither review nor automated: <command>" "gp verified_by lint"
  gp_sed "$repo" 's/^verified_by: .*/verified_by: automated: bash scripts\/arch.sh/'
  run_doctor "$repo"
  assert_not_contains "$OUT" "verified_by is neither" "gp verified_by automated"
  assert_closing 0 "gp verified_by automated"
}
test_doctor_golden_path_missing_instance() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  rm "$repo/src/workers/send-receipt.processor.ts"
  run_doctor "$repo"
  assert_contains "$OUT" "instance src/workers/send-receipt.processor.ts does not exist" "gp missing instance"
}
test_doctor_golden_path_instance_with_spaces() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  put "$repo" "src/my dir/a.ts" x
  gp_sed "$repo" 's|^instances: .*|instances: ["src/my dir/a.ts:4"]|'
  run_doctor "$repo"
  assert_closing 0 "gp spaces"
}
test_doctor_golden_path_type_not_a_layer() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "layers: [handler, service]"
  run_doctor "$repo"
  assert_contains "$OUT" "type processor is not in architecture.layers" "gp layer"
}
test_doctor_golden_path_current_without_instance() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/^instances: .*/instances: []/'
  run_doctor "$repo"
  assert_contains "$OUT" "current with no instance" "gp no instance"
}
test_doctor_golden_paths_folder_without_slash() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "golden_paths: docs/golden-paths"
  gp_sed "$repo" 's/^status: .*/status: draft/'
  run_doctor "$repo"
  assert_contains "$OUT" "status draft" "gp no slash"
}
test_doctor_golden_paths_skip_readme() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  put "$repo" docs/golden-paths/README.md "# Golden paths"
  run_doctor "$repo"
  assert_closing 0 "gp readme"
}
test_doctor_golden_paths_list_form() {
  local repo
  repo=$(new_repo doctor-ok)
  gp_config "$repo" "golden_paths: [a.md, b.md]"
  run_doctor "$repo"
  assert_eq 1 "$(count_lines_containing "$OUT" "golden_paths")" "gp list form: one line"
  assert_closing 1 "gp list form"
  assert_contains "$OUT" "it now names one folder" "gp list form"
}
test_doctor_golden_path_crlf() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's/$/\r/'
  run_doctor "$repo"
  assert_closing 0 "gp crlf"
}

test_doctor_golden_path_without_frontmatter() {
  local repo
  repo=$(new_repo doctor-ok)
  put "$repo" docs/golden-paths/processor.md "# Golden path: processor"
  run_doctor "$repo"
  assert_status 0 "gp no frontmatter: status"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: no frontmatter" "gp no frontmatter"
  assert_eq 1 "$(count_lines_containing "$OUT" "golden path")" "gp no frontmatter: one line"
}
test_doctor_golden_path_instances_not_a_list() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^instances: .*|instances: a.ts|'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: instances is not an inline list" "gp instances not a list"
}
test_doctor_golden_path_lib_missing_never_blocks() {
  local repo lib
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  lib="$RASTRO_TEST_TMP/lib-no-frontmatter"
  mkdir -p "$lib"
  cp "$RASTRO_TESTS_DIR/../hooks/lib/"*.sh "$lib/"
  rm -f "$lib/frontmatter.sh"
  run_cmd env CLAUDE_PROJECT_DIR="$repo" RASTRO_ROOT="$FIXTURE_ROOT" RASTRO_LIB="$lib" HOME="$EMPTY_HOME" bash "$DOCTOR"
  assert_status 0 "gp lib missing: status"
  assert_contains "$OUT" "- PROBLEM: could not check golden paths: $lib/frontmatter.sh not found" "gp lib missing: reported"
  assert_closing 1 "gp lib missing"
}
test_doctor_golden_path_shared_lib_missing_never_blocks() {
  local repo lib
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  lib="$RASTRO_TEST_TMP/lib-no-goldenpath"
  mkdir -p "$lib"
  cp "$RASTRO_TESTS_DIR/../hooks/lib/"*.sh "$lib/"
  rm -f "$lib/goldenpath.sh"
  run_cmd env CLAUDE_PROJECT_DIR="$repo" RASTRO_ROOT="$FIXTURE_ROOT" RASTRO_LIB="$lib" HOME="$EMPTY_HOME" bash "$DOCTOR"
  assert_status 0 "goldenpath lib missing: status"
  assert_contains "$OUT" "- PROBLEM: could not check golden paths: $lib/goldenpath.sh not found" "goldenpath lib missing: reported"
  assert_closing 1 "goldenpath lib missing"
}
test_doctor_golden_path_type_in_layers() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "layers: [handler, processor]"
  run_doctor "$repo"
  assert_not_contains "$OUT" "architecture.layers" "gp type in layers: no layer problem"
  assert_closing 0 "gp type in layers"
}
test_doctor_golden_path_duplicate_type() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  cp "$repo/$GP_FILE" "$repo/docs/golden-paths/worker.md"
  sed 's/^id: .*/id: worker/' "$repo/docs/golden-paths/worker.md" >"$repo/docs/golden-paths/worker.new"
  mv "$repo/docs/golden-paths/worker.new" "$repo/docs/golden-paths/worker.md"
  run_doctor "$repo"
  assert_status 0 "gp duplicate type: status"
  assert_contains "$OUT" "- PROBLEM: golden path docs/golden-paths/worker.md: type processor already has golden path $GP_FILE" "gp duplicate type"
  assert_eq 1 "$(count_lines_containing "$OUT" "already has golden path")" "gp duplicate type: reported once"
  assert_closing 1 "gp duplicate type"
}
test_doctor_golden_path_duplicate_type_retired_ignored() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  sed -e 's/^id: .*/id: worker/' -e 's/^status: .*/status: retired/' -e 's/^instances: .*/instances: []/' \
    -e 's/^origin: /superseded_by: processor\'$'\n''origin: /' "$repo/$GP_FILE" >"$repo/docs/golden-paths/worker.md"
  run_doctor "$repo"
  assert_not_contains "$OUT" "already has golden path" "gp retired later: not counted"
  assert_closing 0 "gp retired later"
  # a retired golden path that sorts first does not make the current one a duplicate
  mv "$repo/docs/golden-paths/worker.md" "$repo/docs/golden-paths/archive.md"
  sed -i.bak 's/^id: worker/id: archive/' "$repo/docs/golden-paths/archive.md"
  rm -f "$repo/docs/golden-paths/archive.md.bak"
  run_doctor "$repo"
  assert_not_contains "$OUT" "already has golden path" "gp retired earlier: not counted"
  assert_closing 0 "gp retired earlier"
}
test_doctor_golden_path_check_not_on_path() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: automated: rastro-no-such-check --all|'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: verified_by runs rastro-no-such-check, which is not on PATH; deliver cannot run the check until it is installed" "gp check not on path"
  assert_closing 1 "gp check not on path"
}
test_doctor_golden_path_check_relative_path() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  mkdir -p "$repo/scripts"
  printf '#!/bin/sh\nexit 0\n' >"$repo/scripts/check-gp.sh"
  chmod +x "$repo/scripts/check-gp.sh"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: automated: ./scripts/check-gp.sh --all|'
  run_doctor "$repo"
  assert_closing 0 "gp check relative path"
}
test_doctor_golden_path_check_env_prefix() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: automated: CHECK_MODE=strict bash scripts/arch.sh|'
  run_doctor "$repo"
  assert_closing 0 "gp check env prefix"
}
test_doctor_golden_path_check_path_not_executable() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  mkdir -p "$repo/scripts"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: automated: ./scripts/check-gp.sh --all|'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: verified_by runs ./scripts/check-gp.sh, which is not an executable file; deliver cannot run the check until it is installed" "gp check path not executable"
  assert_not_contains "$OUT" "which is not on PATH" "gp check path not executable: not the PATH message"
  assert_closing 1 "gp check path not executable"
}
test_doctor_golden_path_check_never_runs() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: automated: touch doctor-ran-the-check|'
  run_doctor "$repo"
  [ ! -e "$repo/doctor-ran-the-check" ] || _assert_fail "gp check never runs: not in the repository" "doctor-ran-the-check exists in $repo"
  [ ! -e "$PWD/doctor-ran-the-check" ] || _assert_fail "gp check never runs: not in the working directory" "doctor-ran-the-check exists in $PWD"
  assert_closing 0 "gp check never runs"
}
test_doctor_golden_path_check_retired_skipped() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^status: .*|status: retired|
s|^origin: |superseded_by: worker\
origin: |
s|^verified_by: .*|verified_by: automated: rastro-no-such-check|'
  run_doctor "$repo"
  assert_not_contains "$OUT" "which is not on PATH" "gp check retired skipped"
  assert_closing 0 "gp check retired skipped"
}

test_doctor_golden_path_check_quoted_command() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" "s|^verified_by: .*|verified_by: automated: 'bash' scripts/arch.sh|"
  run_doctor "$repo"
  assert_closing 0 "gp check quoted command on PATH"
  gp_sed "$repo" "s|^verified_by: .*|verified_by: automated: \"my tool\" --x|"
  run_doctor "$repo"
  assert_closing 0 "gp check quoted command with a space is skipped"
  gp_sed "$repo" "s|^verified_by: .*|verified_by: automated: \"NAME=a b\" bash x|"
  run_doctor "$repo"
  assert_closing 0 "gp check quoted assignment with a space is skipped"
  gp_sed "$repo" "s|^verified_by: .*|verified_by: automated: 'rastro-no-such-check' --all|"
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: verified_by runs rastro-no-such-check, which is not on PATH" "gp check quoted command not on path: quotes stripped"
  assert_closing 1 "gp check quoted command not on path"
}

gp_append() {
  printf '%s\n' "$2" >>"$1/$GP_FILE"
}
SEC_TAIL="list the threats considered, the control for each and how each control is verified"
OK_SEC=$'\n## Security\n\n- Unbounded retries, from OWASP API Security Top 10 API4:2023. Control: a retry limit. Verified by: the retry test.'
NONE_SEC=$'\n## Security\n\nNone identified: the processor reads no outside input.'

test_doctor_boundary_security_ok() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" "$OK_SEC"
  run_doctor "$repo"
  assert_closing 0 "boundary security ok"
}
test_doctor_boundary_security_missing() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: processor is a boundary type and has no ## Security section; $SEC_TAIL" "boundary security missing"
  assert_closing 1 "boundary security missing"
}
test_doctor_boundary_security_empty() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" $'\n## Security\n\n   \n## Verification\n\nThe checklist in review.'
  run_doctor "$repo"
  assert_contains "$OUT" "processor is a boundary type and its ## Security section is empty" "boundary security empty"
  assert_closing 1 "boundary security empty"
}
test_doctor_boundary_security_none_identified() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" "$NONE_SEC"
  run_doctor "$repo"
  assert_contains "$OUT" "its ## Security section says \"none identified\"" "boundary security none identified"
  assert_closing 1 "boundary security none identified"
}
test_doctor_boundary_security_subsection_at_end() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" $'\n## Security\n\n### Threats\n\n- Unbounded retries, from OWASP API Security Top 10 API4:2023. Control: a retry limit. Verified by: the retry test.'
  run_doctor "$repo"
  assert_closing 0 "boundary security subsection at end"
}
test_doctor_boundary_security_crlf() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" $'\n## Security  \n\n- Unbounded retries, from OWASP API Security Top 10 API4:2023. Control: a retry limit. Verified by: the retry test.'
  gp_sed "$repo" 's/$/\r/'
  run_doctor "$repo"
  assert_closing 0 "boundary security crlf"
}
test_doctor_boundary_security_placeholders_only() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_append "$repo" $'\n## Security\n\n<A type in the list crosses a trust boundary. Draw its threats from a public reference.>\n\n- <threat>, from <reference and item>. Control: <the control>. Verified by: <how>.'
  run_doctor "$repo"
  assert_contains "$OUT" "processor is a boundary type and its ## Security section is empty" "boundary security placeholders only"
  assert_closing 1 "boundary security placeholders only"
}
test_doctor_boundary_security_not_a_boundary() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_append "$repo" "$NONE_SEC"
  run_doctor "$repo"
  assert_not_contains "$OUT" "boundary type" "boundary security not a boundary"
  assert_closing 0 "boundary security not a boundary"
}
test_doctor_boundary_security_retired_skipped() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_config "$repo" "boundary_types: [processor]"
  gp_sed "$repo" 's|^status: .*|status: retired|
s|^origin: |superseded_by: worker\
origin: |'
  run_doctor "$repo"
  assert_not_contains "$OUT" "boundary type" "boundary security retired skipped"
  assert_closing 0 "boundary security retired skipped"
}
test_doctor_boundary_types_not_a_layer() {
  local repo
  repo=$(new_repo doctor-ok)
  gp_config "$repo" $'layers: [handler, processor]\n  boundary_types: [external_client]'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: architecture.boundary_types names external_client, which is not in architecture.layers" "boundary types not a layer"
  assert_closing 1 "boundary types not a layer"
}
test_doctor_boundary_types_without_layers() {
  local repo
  repo=$(new_repo doctor-ok)
  gp_config "$repo" "boundary_types: [external-client]"
  run_doctor "$repo"
  assert_closing 0 "boundary types without layers"
}
test_doctor_boundary_types_block_list() {
  local repo
  repo=$(new_repo doctor-ok)
  printf '\narchitecture:\n  boundary_types:\n    - processor\n' >>"$repo/.rastro/config.yml"
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: config key architecture.boundary_types uses an unsupported list form" "boundary types block list"
  assert_eq 1 "$(count_lines_containing "$OUT" "boundary_types")" "boundary types block list: reported once"
}

test_doctor_projects_without_project_number() {
  local repo
  repo=$(new_repo doctor-ok)
  put "$repo" .rastro/adapters/tracker/github-projects.md $'# Adapter: tracker/github-projects\n\n## Requirements\n\nREQUIRED: none'
  edit_config "$repo" 's/kind: fake/kind: github-projects/'
  run_doctor "$repo"
  assert_status 0 "projects without number: status"
  assert_contains "$OUT" "- PROBLEM: tracker.project is not set; the github-projects tracker needs the number of the Project" "projects without number: problem"
  assert_closing 1 "projects without number"
  edit_config "$repo" 's/^  key: W/  key: W\n  project: 7/'
  run_doctor "$repo"
  assert_not_contains "$OUT" "tracker.project is not set" "projects with a number: silent"
  assert_closing 0 "projects with a number"
  edit_config "$repo" 's/kind: github-projects/kind: fake/'
  edit_config "$repo" '/^  project: 7/d'
  run_doctor "$repo"
  assert_not_contains "$OUT" "tracker.project" "other tracker kind: silent"
}
test_doctor_under_review_days_not_a_number() {
  local repo
  repo=$(new_repo doctor-ok)
  gp_config "$repo" "layers: [processor]"
  printf 'audit:\n  under_review_days: 30d\n' >>"$repo/.rastro/config.yml"
  run_doctor "$repo"
  assert_status 0 "under_review_days 30d: status"
  assert_contains "$OUT" "- PROBLEM: audit.under_review_days must be a whole number of days, not 30d" "under_review_days 30d: problem"
  assert_closing 1 "under_review_days 30d"
  edit_config "$repo" 's/under_review_days: 30d/under_review_days: 30/'
  run_doctor "$repo"
  assert_not_contains "$OUT" "audit.under_review_days" "under_review_days 30: silent"
  assert_closing 0 "under_review_days 30"
}
test_doctor_golden_path_check_quoted_verified_by() {
  local repo
  repo=$(new_repo doctor-ok)
  put_gp "$repo"
  gp_sed "$repo" 's|^verified_by: .*|verified_by: "automated: rastro-no-such-check --all"|'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: golden path $GP_FILE: verified_by runs rastro-no-such-check, which is not on PATH" "quoted verified_by: read like the unquoted form"
  assert_not_contains "$OUT" "neither review nor automated" "quoted verified_by: not rejected"
  assert_closing 1 "quoted verified_by"
}

test_doctor_without_config() {
  local repo
  repo=$(make_tmp_repo)
  run_doctor "$repo"
  assert_status 0 "no config: status"
  assert_eq "rastro doctor: no .rastro/config.yml found. Run the setup skill, or rastro:init in a directory with no source code." "$OUT" "no config: single line"
  assert_eq "" "$ERR" "no config: silent stderr"
}
test_doctor_ok() {
  local repo
  repo=$(new_repo doctor-ok)
  DOCTOR_HOME=$HOME run_doctor "$repo"
  assert_status 0 "ok: status"
  assert_contains "$OUT" "0 problems" "ok: reports 0 problems"
  assert_not_contains "$OUT" "PROBLEM" "ok: no problem line"
  assert_not_contains "$OUT" "installed git hooks differ" "ok: no hooks note without .rastro/lib"
  assert_eq 1 "$(( $(count_lines_containing "$OUT" "- info: superpowers found") + $(count_lines_containing "$OUT" "- info: superpowers not found; rastro uses its built-in fallbacks") ))" "ok: exactly one superpowers line, whichever this machine has"
  assert_closing 0 "ok"
  assert_eq "" "$ERR" "ok: silent stderr"
}
test_doctor_missing_required_key() {
  local repo
  repo=$(new_repo doctor-bad)
  run_doctor "$repo"
  assert_status 0 "missing key: status"
  assert_contains "$OUT" "- PROBLEM: missing required config key: tracker.kind" "missing key: names the key"
  assert_not_contains "$OUT" "missing adapter tracker/" "missing key: no adapter lookup for an empty kind"
  assert_closing 1 "missing key"
  repo=$(new_repo doctor-ok)
  edit_config "$repo" '/human:/d'
  run_doctor "$repo"
  assert_status 0 "missing nested key: status"
  assert_contains "$OUT" "missing required config key: project.languages.human" "missing nested key: 3 levels"
}
test_doctor_requires_a_verify_command() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" '/unit:/d'
  run_doctor "$repo"
  assert_status 0 "no verify: status"
  assert_contains "$OUT" "- PROBLEM: no verify command configured" "no verify: problem"
  assert_contains "$OUT" "verify.integration" "no verify: lists the keys"
  edit_config "$repo" 's/^verify:$/verify:\n  typecheck: "true"/'
  run_doctor "$repo"
  assert_not_contains "$OUT" "no verify command" "one verify command is enough"
}
test_doctor_missing_adapter() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: jria/'
  run_doctor "$repo"
  assert_status 0 "missing adapter: status"
  assert_contains "$OUT" "- PROBLEM: missing adapter tracker/jria" "missing adapter: reported"
  assert_closing 1 "missing adapter"
}
test_doctor_resolves_every_port_with_defaults() {
  local repo empty
  repo=$(new_repo doctor-ok)
  empty=$(fake_framework)
  rm -rf "$empty/adapters"
  mkdir -p "$empty/adapters"
  DOCTOR_ROOT=$empty run_doctor "$repo"
  assert_status 0 "empty framework: status"
  assert_contains "$OUT" "- PROBLEM: missing adapter tracker/fake" "port tracker"
  assert_contains "$OUT" "- PROBLEM: missing adapter docs/repo" "port docs, default repo"
  assert_contains "$OUT" "- PROBLEM: missing adapter code-host/none" "port code-host"
  assert_contains "$OUT" "- PROBLEM: missing adapter domain-state/none" "port domain-state, default none"
  assert_contains "$OUT" "- PROBLEM: missing adapter review/none" "port review, default none"
}
test_doctor_rejects_path_in_kind() {
  local repo
  repo=$(new_repo doctor-ok)
  put "$repo" .rastro/outside.md "REQUIRED: none"
  put "$repo" .rastro/adapters/tracker/placeholder.md "REQUIRED: none"
  edit_config "$repo" 's#kind: fake#kind: ../../outside#'
  run_doctor "$repo"
  assert_status 0 "kind with a path: status"
  assert_contains "$OUT" "missing adapter tracker/../../outside" "kind with a path is not resolved"
}
test_doctor_local_adapter_wins() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: trello/'
  put "$repo" .rastro/adapters/tracker/trello.md $'## Requirements\n\nREQUIRED: none'
  run_doctor "$repo"
  assert_status 0 "local adapter: status"
  assert_not_contains "$OUT" "missing adapter tracker/trello" "local adapter found"
  assert_closing 0 "local adapter"
  put "$repo" .rastro/adapters/tracker/fake.md $'## Requirements\n\nREQUIRED CLI: local-wins-xyz'
  edit_config "$repo" 's/kind: trello/kind: fake/'
  run_doctor "$repo"
  assert_contains "$OUT" "CLI not found: local-wins-xyz (required by tracker/fake)" "local adapter overrides the framework one"
}
test_doctor_missing_cli() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: needscli/'
  put "$repo" .rastro/adapters/tracker/needscli.md $'## Requirements\n\nREQUIRED CLI: bash, definitely-not-a-cli-xyz'
  run_doctor "$repo"
  assert_status 0 "missing cli: status"
  assert_contains "$OUT" "- PROBLEM: CLI not found: definitely-not-a-cli-xyz (required by tracker/needscli)" "missing cli: reported"
  assert_not_contains "$OUT" "CLI not found: bash" "present cli is not reported"
  assert_closing 1 "missing cli"
}
test_doctor_marker_formatting() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: styled/'
  put "$repo" .rastro/adapters/tracker/styled.md $'## Requirements\r\n\r\n- **REQUIRED CLI:** `bash`, `styled-missing-xyz` (for tests)\r\n* REQUIRED CLI: other-missing-xyz\r\nA sentence that mentions REQUIRED CLI: prose-xyz in the middle.'
  run_doctor "$repo"
  assert_status 0 "marker formatting: status"
  assert_contains "$OUT" "CLI not found: styled-missing-xyz (required by tracker/styled)" "bold, backticks, bullet and CRLF"
  assert_contains "$OUT" "CLI not found: other-missing-xyz (required by tracker/styled)" "second marker line"
  assert_not_contains "$OUT" "CLI not found: bash" "present cli is not reported"
  assert_not_contains "$OUT" "prose-xyz" "a marker in the middle of a sentence is prose"
  assert_not_contains "$OUT" "for tests" "text after the name is dropped"
}
test_doctor_adapter_without_marker() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: silent/'
  put "$repo" .rastro/adapters/tracker/silent.md $'## Requirements\n\nNothing declared here.'
  run_doctor "$repo"
  assert_status 0 "no marker: status"
  assert_contains "$OUT" "- PROBLEM: could not check requirements of tracker/silent" "no marker: cannot claim clean"
  assert_closing 1 "no marker"
}
test_doctor_mcp_lookup() {
  local repo home
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: mcptool/'
  put "$repo" .rastro/adapters/tracker/mcptool.md $'## Requirements\n\nREQUIRED MCP: acme-tracker, other-one'
  run_doctor "$repo"
  assert_status 0 "mcp: status"
  assert_contains "$OUT" "- info: MCP server acme-tracker $MCP_INFO_TAIL" "mcp: acme-tracker not found"
  assert_contains "$OUT" "- info: MCP server other-one $MCP_INFO_TAIL" "mcp: other-one not found"
  assert_closing 0 "mcp: info only"
  put "$repo" .mcp.json '{"enabledServers": ["acme-tracker"], "mcpServers": {"x": {}}}'
  run_doctor "$repo"
  assert_contains "$OUT" "MCP server acme-tracker" "mcp: a value is not a server key"
  put "$repo" .mcp.json '{"mcpServers": {"acme-tracker": {"command": "x"}}}'
  run_doctor "$repo"
  assert_not_contains "$OUT" "MCP server acme-tracker" "mcp: found in .mcp.json"
  assert_contains "$OUT" "MCP server other-one" "mcp: other-one still missing"
  home="$RASTRO_TEST_TMP/home-mcp"
  mkdir -p "$home"
  printf '{"mcpServers":{"other-one":{}}}\n' >"$home/.claude.json"
  DOCTOR_HOME=$home run_doctor "$repo"
  assert_not_contains "$OUT" "MCP server" "mcp: found in ~/.claude.json"
}
test_doctor_mcp_reported_once() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: mcptool/; s/kind: none/kind: mcphost/'
  put "$repo" .rastro/adapters/tracker/mcptool.md $'REQUIRED MCP: shared-one'
  put "$repo" .rastro/adapters/code-host/mcphost.md $'REQUIRED MCP: shared-one'
  run_doctor "$repo"
  assert_eq 1 "$(count_lines_containing "$OUT" "MCP server shared-one")" "same server reported once"
}
use_dbmcp() {
  printf 'domain_state:\n  kind: dbmcp\n  server: %s\n' "$2" >>"$1/.rastro/config.yml"
  put "$1" .rastro/adapters/domain-state/dbmcp.md $'## Requirements\n\nREQUIRED MCP: from config domain_state.server'
}
test_doctor_mcp_from_config() {
  local repo
  repo=$(new_repo doctor-ok)
  use_dbmcp "$repo" acme-db
  run_doctor "$repo"
  assert_status 0 "from config: status"
  assert_contains "$OUT" "- info: MCP server acme-db $MCP_INFO_TAIL" "from config: the server name is the config value"
  assert_not_contains "$OUT" "from config" "from config: the marker text is never taken for a server name"
  assert_not_contains "$OUT" "PROBLEM" "from config: a set value is clean"
  assert_closing 0 "from config"
  put "$repo" .mcp.json '{"mcpServers": {"acme-db": {"command": "x"}}}'
  run_doctor "$repo"
  assert_not_contains "$OUT" "MCP server" "from config: found by the resolved name"
  repo=$(new_repo doctor-ok)
  use_dbmcp "$repo" '"quoted-db"'
  run_doctor "$repo"
  assert_contains "$OUT" "- info: MCP server quoted-db $MCP_INFO_TAIL" "from config: a quoted value is unquoted"
}
test_doctor_mcp_from_config_empty() {
  local repo
  repo=$(new_repo doctor-ok)
  use_dbmcp "$repo" ""
  run_doctor "$repo"
  assert_status 0 "from config, empty: status"
  assert_contains "$OUT" "- PROBLEM: config key domain_state.server is not set; domain-state/dbmcp reads its MCP server name from it" "from config, empty: names the key"
  assert_not_contains "$OUT" "- info: MCP server" "from config, empty: no server is looked up"
  assert_closing 1 "from config, empty"
  repo=$(new_repo doctor-ok)
  put "$repo" .rastro/adapters/domain-state/dbmcp.md $'REQUIRED MCP: from config domain_state.server'
  printf 'domain_state:\n  kind: dbmcp\n' >>"$repo/.rastro/config.yml"
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: config key domain_state.server is not set; domain-state/dbmcp reads its MCP server name from it" "from config, key absent: names the key"
  put "$repo" .rastro/adapters/domain-state/dbmcp.md $'REQUIRED MCP: from config'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: could not check requirements of domain-state/dbmcp" "from config without a key: cannot claim clean"
}
test_doctor_required_accepts_only_none() {
  local repo body
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: bare/'
  for body in $'REQUIRED: none' $'REQUIRED: none\r' $'- **REQUIRED:** `none`'; do
    put "$repo" .rastro/adapters/tracker/bare.md "$body"
    run_doctor "$repo"
    assert_not_contains "$OUT" "could not check requirements" "REQUIRED: none is accepted: $body"
    assert_closing 0 "REQUIRED: none: $body"
  done
  for body in 'REQUIRED: git' 'REQUIRED: none (for now)' 'REQUIRED: none, git' 'REQUIRED:' 'REQUIRED: None'; do
    put "$repo" .rastro/adapters/tracker/bare.md "$body"
    run_doctor "$repo"
    assert_contains "$OUT" "- PROBLEM: could not check requirements of tracker/bare" "not accepted: $body"
    assert_closing 1 "REQUIRED: $body"
  done
}
test_doctor_empty_marker_list() {
  local repo body
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: hollow/'
  for body in 'REQUIRED CLI:' 'REQUIRED MCP:' 'REQUIRED CLI: , ,' $'REQUIRED MCP:\r'; do
    put "$repo" .rastro/adapters/tracker/hollow.md "$body"
    run_doctor "$repo"
    assert_contains "$OUT" "- PROBLEM: could not check requirements of tracker/hollow" "empty list: $body"
    assert_closing 1 "empty list: $body"
  done
  put "$repo" .rastro/adapters/tracker/hollow.md $'REQUIRED CLI: bash, hollow-missing-xyz\nREQUIRED MCP:'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: could not check requirements of tracker/hollow" "empty MCP line next to a CLI line: reported"
  assert_contains "$OUT" "CLI not found: hollow-missing-xyz (required by tracker/hollow)" "empty MCP line next to a CLI line: the CLI line is still checked"
}
test_doctor_reads_every_shipped_adapter() {
  local repo file rel dir kind real
  real=$(cd "$RASTRO_TESTS_DIR/.." && pwd)
  for file in "$real"/adapters/*/*.md; do
    [ -f "$file" ] || continue
    rel=${file#"$real/adapters/"}
    dir=${rel%%/*}
    kind=${rel##*/}
    kind=${kind%.md}
    repo=$(new_repo doctor-ok)
    edit_config "$repo" "/^tracker:/{n;s/kind: .*/kind: none/;}"
    case $dir in
      tracker) edit_config "$repo" "/^tracker:/{n;s/kind: .*/kind: $kind/;}" ;;
      docs) edit_config "$repo" "/^docs:/{n;s/kind: .*/kind: $kind/;}" ;;
      code-host) edit_config "$repo" "/^code_host:/{n;s/kind: .*/kind: $kind/;}" ;;
      domain-state) printf 'domain_state:\n  kind: %s\n  server: acme-db\n' "$kind" >>"$repo/.rastro/config.yml" ;;
      review) printf 'review:\n  kind: %s\n' "$kind" >>"$repo/.rastro/config.yml" ;;
    esac
    DOCTOR_ROOT=$real run_doctor "$repo"
    assert_status 0 "shipped $rel: status"
    assert_not_contains "$OUT" "missing adapter" "shipped $rel: found"
    assert_not_contains "$OUT" "could not check" "shipped $rel: requirements are readable"
    assert_not_contains "$OUT" "is not set" "shipped $rel: no empty config value"
    [ "$rel" != domain-state/db-mcp ] || assert_contains "$OUT" "MCP server acme-db" "shipped $rel: resolves the server from config"
  done
}
test_doctor_local_tracker_ok() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: local/'
  put "$repo" work/W-001-first.md "x"
  put "$repo" work/W-002-second.md "x"
  run_doctor "$repo"
  assert_status 0 "local tracker: status"
  assert_closing 0 "local tracker"
  assert_not_contains "$OUT" "PROBLEM" "local tracker: clean"
}
test_doctor_local_dir_in_workspace() {
  local repo dir
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: local/'
  for dir in '.agent/work/' './.agent' 'work/../.agent/x' '.agent\work'; do
    edit_config "$repo" "s#local_dir: .*#local_dir: ${dir//\\/\\\\}#"
    run_doctor "$repo"
    assert_status 0 "local_dir $dir: status"
    assert_contains "$OUT" "- PROBLEM: $LOCAL_DIR_PROBLEM" "local_dir $dir: reported"
    assert_contains "$OUT" "work items must be versioned in git" "local_dir $dir: says in plain words why"
    assert_not_contains "$OUT" "(R-" "local_dir $dir: no internal rule number"
  done
  for dir in '.agentx/work/' 'src/.agent/work'; do
    edit_config "$repo" "s#local_dir: .*#local_dir: $dir#"
    run_doctor "$repo"
    assert_not_contains "$OUT" "$LOCAL_DIR_PROBLEM" "local_dir $dir: not inside the workspace"
  done
}
test_doctor_local_dir_in_default_workspace() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: local/; s#local_dir: .*#local_dir: .agent/work/#; /^workspace:/d'
  run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: $LOCAL_DIR_PROBLEM" "no workspace key: local_dir inside the default .agent/ is reported"
  edit_config "$repo" 's#local_dir: .*#local_dir: work/#'
  run_doctor "$repo"
  assert_not_contains "$OUT" "$LOCAL_DIR_PROBLEM" "no workspace key: local_dir outside .agent/ is clean"
}
test_doctor_local_dir_ignored_for_other_trackers() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's#local_dir: work/#local_dir: .agent/work/#'
  put "$repo" work/W-001-a.md x
  put "$repo" work/W-001-b.md x
  run_doctor "$repo"
  assert_not_contains "$OUT" "$LOCAL_DIR_PROBLEM" "non-local tracker: no workspace check"
  assert_not_contains "$OUT" "duplicate work item id" "non-local tracker: no duplicate scan"
}
test_doctor_lint_file_command() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's#^  unit: "true"#  unit: "true"\n  lint_file: "rastro-no-such-linter --fix {file}"#'
  run_doctor "$repo"
  assert_status 0 "linter missing: status"
  assert_contains "$OUT" "- PROBLEM: verify.lint_file runs rastro-no-such-linter, which is not on PATH" "linter missing: names the command"
  assert_closing 1 "linter missing"
  repo=$(new_repo doctor-ok)
  printf '#!/bin/sh\nexit 0\n' >"$repo/lint.sh"
  chmod +x "$repo/lint.sh"
  edit_config "$repo" 's#^  unit: "true"#  unit: "true"\n  lint_file: "./lint.sh {file}"#'
  run_doctor "$repo"
  assert_not_contains "$OUT" "verify.lint_file runs" "linter given by a path relative to the repository: found"
  edit_config "$repo" 's#lint_file: .*#lint_file: "  bash {file}"#'
  run_doctor "$repo"
  assert_not_contains "$OUT" "verify.lint_file runs" "linter on PATH, after leading spaces: found"
  assert_closing 0 "linter on PATH"
}
test_doctor_duplicate_ids() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: local/; s#local_dir: .*#local_dir: "my items/"#'
  put "$repo" "my items/W-001-a.md" x
  put "$repo" "my items/W-001-b.md" x
  put "$repo" "my items/W-001-c.md" x
  put "$repo" "my items/W-002-a.md" x
  put "$repo" "my items/X-009-a.md" x
  put "$repo" "my items/X-009-b.md" x
  put "$repo" "my items/W-3x-a.md" x
  put "$repo" "my items/W-3x-b.md" x
  put "$repo" "my items/W-004.md" x
  put "$repo" "my items/W-004.txt" x
  run_doctor "$repo"
  assert_status 0 "duplicate ids: status"
  assert_contains "$OUT" "- PROBLEM: duplicate work item id W-001" "duplicate ids: reported"
  assert_eq 1 "$(count_lines_containing "$OUT" "duplicate work item id")" "duplicate ids: only W-001, once"
  assert_closing 1 "duplicate ids"
}
test_doctor_duplicate_ids_need_a_key() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: local/; /key: W/d'
  put "$repo" work/W-001-a.md x
  run_doctor "$repo"
  assert_status 0 "no key: status"
  assert_contains "$OUT" "- PROBLEM: could not check duplicate work item ids" "no key: cannot claim clean"
  assert_closing 1 "no key"
}
test_doctor_installed_hooks_drift() {
  local repo fw
  repo=$(new_repo doctor-ok)
  fw=$(fake_framework)
  put "$fw" hooks/lib/a.sh "echo a"
  put "$fw" hooks/lib/b.sh "echo b"
  put "$repo" .rastro/lib/a.sh "echo a"
  put "$repo" .rastro/lib/b.sh "echo b"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_status 0 "same libs: status"
  assert_not_contains "$OUT" "installed git hooks differ" "same libs: silent"
  assert_closing 0 "same libs"
  put "$repo" .rastro/lib/b.sh "echo changed"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "$LIB_INFO" "changed file: reported"
  assert_closing 0 "changed file: info only"
  put "$repo" .rastro/lib/b.sh "echo b"
  put "$repo" .rastro/lib/old.sh "echo old"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "$LIB_INFO" "stale extra file: reported"
  rm "$repo/.rastro/lib/old.sh" "$repo/.rastro/lib/a.sh"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "$LIB_INFO" "missing file: reported"
  rm -rf "$repo/.rastro/lib"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_not_contains "$OUT" "installed git hooks differ" "no .rastro/lib: silent"
}
test_doctor_installed_git_hooks_drift() {
  local repo fw
  repo=$(new_repo doctor-ok)
  fw=$(fake_framework)
  put "$fw" hooks/lib/a.sh "echo a"
  put "$repo" .rastro/lib/a.sh "echo a"
  put "$fw" hooks/git/pre-commit "echo pre"
  put "$fw" hooks/git/check-commits "echo commits"
  put "$repo" .rastro/git-hooks/pre-commit "echo pre"
  put "$repo" .rastro/git-hooks/check-commits "echo commits"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_not_contains "$OUT" "installed git hooks differ" "same git hooks: silent"
  assert_closing 0 "same git hooks"
  put "$repo" .rastro/git-hooks/pre-commit "echo old pre"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "$LIB_INFO" "changed git hook, same lib: reported"
  assert_closing 0 "changed git hook: info only"
  put "$repo" .rastro/git-hooks/pre-commit "echo pre"
  rm "$repo/.rastro/git-hooks/check-commits"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "$LIB_INFO" "git hook added by a newer rastro and not installed: reported"
  put "$repo" .rastro/git-hooks/check-commits "echo commits"
  put "$repo" .rastro/lib/a.sh "echo changed"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_eq 1 "$(count_lines_containing "$OUT" "installed git hooks differ")" "lib and git hooks both checked, reported once"
  rm -rf "$fw/hooks/git"
  put "$repo" .rastro/lib/a.sh "echo a"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_contains "$OUT" "- PROBLEM: could not check installed git hooks: $fw/hooks/git not found" "no shipped git hooks: cannot claim clean"
}
test_doctor_installed_hooks_unverifiable() {
  local repo fw
  repo=$(new_repo doctor-ok)
  fw=$(fake_framework)
  rm -rf "$fw/hooks"
  put "$repo" .rastro/lib/a.sh "echo a"
  DOCTOR_ROOT=$fw run_doctor "$repo"
  assert_status 0 "no framework libs: status"
  assert_contains "$OUT" "- PROBLEM: could not check installed git hooks" "no framework libs: cannot claim clean"
  assert_closing 1 "no framework libs"
}
test_doctor_superpowers_info() {
  local repo home
  repo=$(new_repo doctor-ok)
  run_doctor "$repo"
  assert_contains "$OUT" "- info: superpowers not found; rastro uses its built-in fallbacks" "empty home: not found"
  home="$RASTRO_TEST_TMP/home-sp"
  mkdir -p "$home/.claude/plugins/cache/some-marketplace/superpowers/1.0.0"
  DOCTOR_HOME=$home run_doctor "$repo"
  assert_contains "$OUT" "- info: superpowers found" "cache entry: found"
  assert_not_contains "$OUT" "superpowers not found" "cache entry: not also reported missing"
  assert_closing 0 "superpowers: info only"
}
test_doctor_superpowers_personal_skill() {
  local repo home
  repo=$(new_repo doctor-ok)
  home="$RASTRO_TEST_TMP/home-sp-personal"
  mkdir -p "$home/.claude/skills/subagent-driven-development"
  DOCTOR_HOME=$home run_doctor "$repo"
  assert_contains "$OUT" "- info: superpowers not found; rastro uses its built-in fallbacks" "directory without SKILL.md: not found"
  printf '%s
' "---" >"$home/.claude/skills/subagent-driven-development/SKILL.md"
  DOCTOR_HOME=$home run_doctor "$repo"
  assert_contains "$OUT" "- info: superpowers found" "personal skill install: found"
  assert_not_contains "$OUT" "superpowers not found" "personal skill install: not also reported missing"
  assert_closing 0 "personal skill install: info only"
}
test_doctor_unsupported_list_form() {
  local repo
  repo=$(new_repo doctor-ok)
  edit_config "$repo" 's/kind: fake/kind: jria/; s/unit: "true"/lint: [a, b\n  unit: "true"/'
  run_doctor "$repo"
  assert_status 0 "unsupported list: status"
  assert_contains "$OUT" "- PROBLEM: config key verify.lint uses an unsupported list form; write it inline as [a, b]" "unsupported list: reader message"
  assert_contains "$OUT" "missing adapter tracker/jria" "unsupported list: later checks still run"
  assert_closing 2 "unsupported list"
}
test_doctor_unreadable_config() {
  local repo
  repo=$(new_repo doctor-ok)
  chmod 000 "$repo/.rastro/config.yml"
  if [ -r "$repo/.rastro/config.yml" ]; then
    chmod 644 "$repo/.rastro/config.yml"
    return 0
  fi
  run_doctor "$repo"
  chmod 644 "$repo/.rastro/config.yml"
  assert_status 0 "unreadable config: status"
  assert_contains "$OUT" "- PROBLEM: could not check config" "unreadable config: reported"
  assert_closing 1 "unreadable config"
}
test_doctor_without_git() {
  local repo bin tool path
  repo=$(new_repo doctor-ok)
  bin="$RASTRO_TEST_TMP/nogit-bin"
  mkdir -p "$bin"
  for tool in awk mktemp sort dirname rm bash; do
    path=$(command -v "$tool") || continue
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$path" >"$bin/$tool"
    chmod +x "$bin/$tool"
  done
  run_cmd env PATH="$bin" CLAUDE_PROJECT_DIR="$repo" RASTRO_ROOT="$FIXTURE_ROOT" HOME="$EMPTY_HOME" "$BASH" "$DOCTOR"
  assert_status 0 "no git: status"
  assert_contains "$OUT" "- PROBLEM: could not check git" "no git: cannot claim clean"
  assert_closing 1 "no git"
}
test_doctor_missing_lib_never_blocks() {
  local repo
  repo=$(new_repo doctor-ok)
  run_cmd env CLAUDE_PROJECT_DIR="$repo" RASTRO_ROOT="$FIXTURE_ROOT" RASTRO_LIB="$RASTRO_TEST_TMP/no-such-lib" HOME="$EMPTY_HOME" bash "$DOCTOR"
  assert_status 0 "missing lib: status"
  assert_contains "$OUT" "- PROBLEM: could not check config" "missing lib: reported"
  assert_closing 1 "missing lib"
}

test_doctor_without_config
test_doctor_ok
test_doctor_projects_without_project_number
test_doctor_under_review_days_not_a_number
test_doctor_golden_path_check_quoted_verified_by
test_doctor_missing_required_key
test_doctor_requires_a_verify_command
test_doctor_missing_adapter
test_doctor_resolves_every_port_with_defaults
test_doctor_rejects_path_in_kind
test_doctor_local_adapter_wins
test_doctor_missing_cli
test_doctor_marker_formatting
test_doctor_adapter_without_marker
test_doctor_mcp_lookup
test_doctor_mcp_reported_once
test_doctor_mcp_from_config
test_doctor_mcp_from_config_empty
test_doctor_required_accepts_only_none
test_doctor_empty_marker_list
test_doctor_reads_every_shipped_adapter
test_doctor_local_tracker_ok
test_doctor_local_dir_in_workspace
test_doctor_local_dir_in_default_workspace
test_doctor_lint_file_command
test_doctor_local_dir_ignored_for_other_trackers
test_doctor_duplicate_ids
test_doctor_duplicate_ids_need_a_key
test_doctor_installed_hooks_drift
test_doctor_installed_git_hooks_drift
test_doctor_installed_hooks_unverifiable
test_doctor_superpowers_info
test_doctor_superpowers_personal_skill
test_doctor_unsupported_list_form
test_doctor_unreadable_config
test_doctor_without_git
test_doctor_missing_lib_never_blocks
test_doctor_golden_paths_absent_is_silent
test_doctor_golden_path_ok
test_doctor_golden_path_missing_key
test_doctor_golden_path_bad_status
test_doctor_golden_path_retired_needs_successor
test_doctor_golden_path_id_mismatch
test_doctor_golden_path_verified_by
test_doctor_golden_path_missing_instance
test_doctor_golden_path_instance_with_spaces
test_doctor_golden_path_type_not_a_layer
test_doctor_golden_path_current_without_instance
test_doctor_golden_paths_folder_without_slash
test_doctor_golden_paths_skip_readme
test_doctor_golden_paths_list_form
test_doctor_golden_path_crlf
test_doctor_golden_path_without_frontmatter
test_doctor_golden_path_instances_not_a_list
test_doctor_golden_path_lib_missing_never_blocks
test_doctor_golden_path_shared_lib_missing_never_blocks
test_doctor_golden_path_type_in_layers
test_doctor_golden_path_duplicate_type
test_doctor_golden_path_duplicate_type_retired_ignored
test_doctor_golden_path_check_not_on_path
test_doctor_golden_path_check_relative_path
test_doctor_golden_path_check_env_prefix
test_doctor_golden_path_check_path_not_executable
test_doctor_golden_path_check_never_runs
test_doctor_golden_path_check_retired_skipped
test_doctor_golden_path_check_quoted_command
test_doctor_boundary_security_ok
test_doctor_boundary_security_missing
test_doctor_boundary_security_empty
test_doctor_boundary_security_none_identified
test_doctor_boundary_security_subsection_at_end
test_doctor_boundary_security_crlf
test_doctor_boundary_security_placeholders_only
test_doctor_boundary_security_not_a_boundary
test_doctor_boundary_security_retired_skipped
test_doctor_boundary_types_not_a_layer
test_doctor_boundary_types_without_layers
test_doctor_boundary_types_block_list
finish
