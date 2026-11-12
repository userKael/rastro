. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT RASTRO_CONFIG RASTRO_LIB RASTRO_ROOT RASTRO_NOW
AUDIT="$RASTRO_TESTS_DIR/../hooks/git/audit-drift"
GP_FIXTURE="$RASTRO_TESTS_DIR/fixtures/golden-paths/processor.md"
GP="docs/golden-paths/processor.md"
INSTANCE="src/workers/send-receipt.processor.ts"
NOW=1800000000

new_repo() {
  local repo
  repo=$(make_tmp_repo) || return 1
  mkdir -p "$repo/.rastro"
  cat >"$repo/.rastro/config.yml" <<'CFG'
project:
  name: shelf
workspace: .agent/
architecture:
  layers: [processor, service]
CFG
  printf '%s\n' "$repo"
}
put() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}
commit_all() {
  local repo=$1 msg=$2 date=${3:-}
  git -C "$repo" add -A
  if [ -n "$date" ]; then
    GIT_AUTHOR_DATE=$date GIT_COMMITTER_DATE=$date git -C "$repo" commit -q -m "$msg"
  else
    git -C "$repo" commit -q -m "$msg"
  fi
}
run_audit() {
  local repo=$1
  shift
  run_cmd env CLAUDE_PROJECT_DIR="$repo" RASTRO_NOW="$NOW" bash "$AUDIT" "$@"
}
put_gp() {
  mkdir -p "$1/docs/golden-paths"
  cp "$GP_FIXTURE" "$1/$GP"
  put "$1" "$INSTANCE" "export class SendReceiptProcessor {}"
}
row() {
  printf '| %s | %s | %s |' "$1" "$2" "$3"
}

test_audit_without_config() {
  local repo
  repo=$(make_tmp_repo)
  run_audit "$repo"
  assert_status 2 "no config: status 2"
  assert_contains "$ERR" "no .rastro/config.yml" "no config: message"
}
test_audit_bad_option() {
  local repo
  repo=$(new_repo)
  run_audit "$repo" --nope
  assert_status 2 "bad option: status 2"
}
test_audit_no_golden_paths() {
  local repo
  repo=$(new_repo)
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "no golden paths: status 0"
  assert_contains "$OUT" "# Drift audit" "no golden paths: title"
  assert_contains "$OUT" "No golden paths." "no golden paths: message"
}
test_audit_clean() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "clean: status 0"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" ok)" "clean: instances-changed ok"
  assert_not_contains "$OUT" "| drift |" "clean: no drift"
  assert_contains "$OUT" "## Mechanical checks" "clean: section"
  assert_contains "$OUT" "| Check | Subject | Verdict | Detail |" "clean: table header"
}
test_audit_instance_changed() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  put "$repo" "$INSTANCE" "export class SendReceiptProcessor { run() {} }"
  commit_all "$repo" "evolve"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" drift) 1 commit" "changed: drift with count"
}
test_audit_instance_gone() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  git -C "$repo" rm -q "$INSTANCE"
  commit_all "$repo" "remove"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" drift) instance does not exist" "gone: drift"
}
test_audit_instance_path_with_space() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^instances:.*#instances: [src/my dir/a.processor.ts:1]#' "$GP_FIXTURE" >"$repo/$GP"
  put "$repo" "src/my dir/a.processor.ts" "x"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "space: status 0"
  assert_contains "$OUT" "$(row instances-changed "$GP:src/my dir/a.processor.ts" ok)" "space: ok"
}
test_audit_no_instance() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^instances:.*#instances: []#' "$GP_FIXTURE" >"$repo/$GP"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_contains "$OUT" "$(row no-instance "$GP" drift)" "no instance: drift"
}
test_audit_duplicate_type() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  cp "$GP_FIXTURE" "$repo/docs/golden-paths/second.md"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_contains "$OUT" "$(row duplicate-type docs/golden-paths/second.md drift) type processor already has golden path $GP" "duplicate: drift names the first"
  assert_contains "$OUT" "$(row duplicate-type "$GP" ok)" "duplicate: first is ok"
}
test_audit_boundary_security() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  printf 'project:\n  name: shelf\nworkspace: .agent/\narchitecture:\n  layers: [processor, service]\n  boundary_types: [processor]\n' >"$repo/.rastro/config.yml"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_contains "$OUT" "$(row boundary-security "$GP" drift)" "boundary: missing section is drift"
  printf '\n## Security\n\n- Replay of a message: idempotency key, verified by the integration test.\n' >>"$repo/$GP"
  commit_all "$repo" "add security"
  run_audit "$repo"
  assert_contains "$OUT" "$(row boundary-security "$GP" ok)" "boundary: filled section is ok"
}
test_audit_boundary_type_not_listed() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_not_contains "$OUT" "| boundary-security |" "boundary: no row for a type outside the list"
}
test_audit_under_review_age() {
  local repo old
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^status:.*#status: under-review#' "$GP_FIXTURE" >"$repo/$GP"
  put "$repo" "$INSTANCE" "x"
  old="$((NOW - 40 * 86400)) +0000"
  commit_all "$repo" "init" "$old"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" ok)" "age: ok without limit"
  assert_contains "$OUT" "age 40 days, no limit set" "age: no limit detail"
  printf 'audit:\n  under_review_days: 30\n' >>"$repo/.rastro/config.yml"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" drift) age 40 days, limit 30" "age: over the limit is drift"
  sed -i 's#under_review_days: 30#under_review_days: 45#' "$repo/.rastro/config.yml"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" ok) age 40 days, limit 45" "age: under the limit is ok"
  sed -i 's#under_review_days: 45#under_review_days: soon#' "$repo/.rastro/config.yml"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" ok) age 40 days, no limit set" "age: non numeric counts as empty"
}
test_audit_current_has_no_age_row() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_not_contains "$OUT" "| under-review-age |" "current: no age row"
}
test_audit_shallow_clone() {
  local repo clone
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^status:.*#status: under-review#' "$GP_FIXTURE" >"$repo/$GP"
  put "$repo" "$INSTANCE" "x"
  commit_all "$repo" "init"
  put "$repo" "$INSTANCE" "y"
  commit_all "$repo" "second"
  clone="$RASTRO_TEST_TMP/shallow-clone"
  git clone -q --depth 1 "file://$repo" "$clone" 2>/dev/null
  run_audit "$clone"
  assert_status 0 "shallow: status 0"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" "NOT VERIFIED") shallow clone" "shallow: instances-changed"
  assert_contains "$OUT" "$(row under-review-age "$GP" "NOT VERIFIED") shallow clone" "shallow: age"
  assert_not_contains "$OUT" "| drift |" "shallow: no invented drift"
}
test_audit_fail_on_drift() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo" --fail-on-drift
  assert_status 0 "no drift: option exits 0"
  put "$repo" "$INSTANCE" "changed"
  commit_all "$repo" "evolve"
  run_audit "$repo" --fail-on-drift
  assert_status 1 "drift: option exits 1"
  run_audit "$repo"
  assert_status 0 "drift: no option exits 0"
}
test_audit_first_run_has_no_previous() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_contains "$OUT" "## Changes since the previous audit" "first run: section"
  assert_contains "$OUT" "No previous audit." "first run: no previous"
  run_audit "$repo" --previous "$RASTRO_TEST_TMP/does-not-exist.md"
  assert_contains "$OUT" "No previous audit." "missing previous file"
}
test_audit_compare_previous() {
  local repo prev
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  put "$repo" "$INSTANCE" "changed"
  commit_all "$repo" "evolve"
  run_audit "$repo"
  prev="$RASTRO_TEST_TMP/prev.md"
  printf '%s\n' "$OUT" >"$prev"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" drift)" "previous run has drift"
  sed 's#^instances:.*#instances: []#' "$repo/$GP" >"$repo/gp.tmp"
  mv "$repo/gp.tmp" "$repo/$GP"
  commit_all "$repo" "drop the instance"
  run_audit "$repo" --previous "$prev"
  assert_contains "$OUT" "## Changes since the previous audit (" "compare: titled with the previous date"
  assert_contains "$OUT" "- resolved: instances-changed $GP:$INSTANCE" "compare: resolved"
  assert_contains "$OUT" "- new: no-instance $GP" "compare: new"
  assert_contains "$OUT" "- unchanged: 0 drift(s)" "compare: unchanged count"
}

test_audit_without_config
test_audit_bad_option
test_audit_no_golden_paths
test_audit_clean
test_audit_instance_changed
test_audit_instance_gone
test_audit_instance_path_with_space
test_audit_no_instance
test_audit_duplicate_type
test_audit_boundary_security
test_audit_boundary_type_not_listed
test_audit_under_review_age
test_audit_current_has_no_age_row
test_audit_shallow_clone
test_audit_fail_on_drift
test_audit_first_run_has_no_previous
test_audit_compare_previous
finish
