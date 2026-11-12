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
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" review) 1 commit" "changed: review with count"
  assert_not_contains "$OUT" "| drift |" "changed: not drift"
}
test_audit_review_baseline_is_version_change() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  put "$repo" "$INSTANCE" "export class SendReceiptProcessor { run() {} }"
  commit_all "$repo" "evolve"
  printf '\nA typo fixed.\n' >>"$repo/$GP"
  commit_all "$repo" "typo in the golden path"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" review) 1 commit" "baseline: a typo commit does not reset it"
  sed -i 's#^version: 1.0.0#version: 1.1.0#' "$repo/$GP"
  commit_all "$repo" "new version"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" ok)" "baseline: a version change resets it"
}
test_audit_added_instance_baseline() {
  local repo second="src/workers/send-invoice.processor.ts"
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  put "$repo" "$second" "export class SendInvoiceProcessor {}"
  sed -i "s#^instances: \[\(.*\)\]#instances: [\1, $second:1]#" "$repo/$GP"
  commit_all "$repo" "add a follows instance"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$second" ok)" "added instance: ok from the day it is added"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" ok)" "added instance: the first one is unaffected"
  put "$repo" "$second" "export class SendInvoiceProcessor { run() {} }"
  commit_all "$repo" "change the added instance"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$second" review) 1 commit" "added instance: a later change is review"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" ok)" "added instance: the other stays ok"
}
test_audit_invalid_status() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^status:.*#status: Current#' "$GP_FIXTURE" >"$repo/$GP"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_contains "$OUT" "$(row status "$GP" drift) status Current is not current, under-review or retired" "status typo: drift"
}
test_audit_quoted_verified_by() {
  local repo plain
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^verified_by:.*#verified_by: automated: true#' "$GP_FIXTURE" >"$repo/$GP"
  put "$repo" "$INSTANCE" "x"
  commit_all "$repo" "init"
  run_audit "$repo"
  plain=$OUT
  sed -i 's#^verified_by:.*#verified_by: "automated: true"#' "$repo/$GP"
  commit_all "$repo" "quote it"
  run_audit "$repo"
  assert_status 0 "quoted verified_by: status 0"
  assert_eq "$(printf '%s\n' "$plain" | grep '^| ' | cut -d'|' -f2-4)" "$(printf '%s\n' "$OUT" | grep '^| ' | cut -d'|' -f2-4)" "quoted verified_by: same rows as the unquoted form"
}
test_audit_instance_not_committed() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  git -C "$repo" add "$GP" .rastro
  git -C "$repo" commit -q -m "golden path only"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" "NOT VERIFIED") instance not committed yet" "uncommitted instance: not verified"
}
test_audit_no_frontmatter() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  printf '# Golden path: processor\n\nNo frontmatter here.\n' >"$repo/$GP"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "no frontmatter: status"
  assert_contains "$OUT" "$(row frontmatter "$GP" "NOT VERIFIED") no frontmatter; not audited" "no frontmatter: row"
  assert_not_contains "$OUT" "No golden paths." "no frontmatter: it is a golden path"
}
test_audit_old_list_form() {
  local repo
  repo=$(new_repo)
  printf 'project:\n  name: shelf\nworkspace: .agent/\narchitecture:\n  layers: [processor]\n  golden_paths: [docs/a.md]\n' >"$repo/.rastro/config.yml"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "list form: status"
  assert_contains "$OUT" "$(row config architecture.golden_paths "NOT VERIFIED") old list form" "list form: row"
  assert_not_contains "$OUT" "No golden paths." "list form: not no golden paths"
}
test_audit_outside_git() {
  local repo
  repo="$RASTRO_TEST_TMP/no-git"
  mkdir -p "$repo/.rastro"
  cp "$(new_repo)/.rastro/config.yml" "$repo/.rastro/config.yml"
  put_gp "$repo"
  run_audit "$repo"
  assert_status 0 "outside git: status"
  assert_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" "NOT VERIFIED") not a git repository" "outside git: instances"
  assert_not_contains "$OUT" "| drift |" "outside git: no invented drift"
  assert_not_contains "$OUT" "$(row instances-changed "$GP:$INSTANCE" ok)" "outside git: nothing claimed ok from history"
}
test_audit_instance_gone() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  git -C "$repo" rm -q "$INSTANCE"
  commit_all "$repo" "remove"
  run_audit "$repo"
  assert_contains "$OUT" "$(row instance-missing "$GP:$INSTANCE" drift) instance does not exist" "gone: drift"
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
  sed -i 's#under_review_days: 45#under_review_days: 40#' "$repo/.rastro/config.yml"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" ok) age 40 days, limit 40" "age: equal to the limit is ok"
  sed -i 's#under_review_days: 40#under_review_days: 45#' "$repo/.rastro/config.yml"
  sed -i 's#under_review_days: 45#under_review_days: soon#' "$repo/.rastro/config.yml"
  run_audit "$repo"
  assert_contains "$OUT" "$(row under-review-age "$GP" "NOT VERIFIED") audit.under_review_days is not a whole number (soon); age not checked" "age: non numeric is not verified"
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
  assert_status 0 "review only: option exits 0"
  assert_contains "$OUT" "| review |" "review only: the row is there"
  sed 's#^instances:.*#instances: []#' "$repo/$GP" >"$repo/gp.tmp"
  mv "$repo/gp.tmp" "$repo/$GP"
  commit_all "$repo" "drop the instance"
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
test_audit_previous_needs_a_file() {
  local repo
  repo=$(new_repo)
  run_audit "$repo" --previous
  assert_status 2 "--previous alone: status 2"
  assert_contains "$ERR" "--previous needs a file" "--previous alone: message"
}
test_audit_previous_resolved_from_project_root() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  printf '%s\n' "$OUT" >"$repo/prev.md"
  run_audit "$repo" --previous prev.md
  assert_contains "$OUT" "## Changes since the previous audit (" "relative previous: found from the project root"
}
test_audit_compare_previous() {
  local repo prev
  repo=$(new_repo)
  mkdir -p "$repo/docs/golden-paths"
  sed 's#^instances:.*#instances: []#' "$GP_FIXTURE" >"$repo/$GP"
  put "$repo" "$INSTANCE" "x"
  commit_all "$repo" "init"
  run_audit "$repo"
  prev="$RASTRO_TEST_TMP/prev.md"
  printf '%s\n' "$OUT" >"$prev"
  assert_contains "$OUT" "$(row no-instance "$GP" drift)" "previous run has drift"
  cp "$GP_FIXTURE" "$repo/$GP"
  commit_all "$repo" "list the instance"
  put "$repo" "$INSTANCE" "changed"
  commit_all "$repo" "evolve the instance"
  run_audit "$repo" --previous "$prev"
  assert_contains "$OUT" "## Changes since the previous audit (" "compare: titled with the previous date"
  assert_contains "$OUT" "- resolved: no-instance $GP" "compare: resolved"
  assert_contains "$OUT" "- new review: instances-changed $GP:$INSTANCE" "compare: new review"
  assert_contains "$OUT" "- unchanged: 0 drift(s), 0 review(s)" "compare: unchanged counts"
  printf '%s\n' "$OUT" >"$prev"
  run_audit "$repo" --previous "$prev"
  assert_not_contains "$OUT" "- new review:" "compare: a review seen before is not new"
  assert_contains "$OUT" "- unchanged: 0 drift(s), 1 review(s)" "compare: review unchanged"
  sed -i 's#^version: 1.0.0#version: 1.1.0#' "$repo/$GP"
  commit_all "$repo" "new version"
  run_audit "$repo" --previous "$prev"
  assert_contains "$OUT" "- resolved review: instances-changed $GP:$INSTANCE" "compare: review resolved"
}
test_audit_compare_never_resolves_unverified() {
  local repo prev
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  put "$repo" "$INSTANCE" "changed"
  commit_all "$repo" "evolve"
  run_audit "$repo"
  prev="$RASTRO_TEST_TMP/prev-nv.md"
  sed 's#| review |#| drift |#' <<<"$OUT" >"$prev"
  git -C "$repo" clone -q --depth 1 "file://$repo" "$RASTRO_TEST_TMP/shallow-cmp" 2>/dev/null
  run_audit "$RASTRO_TEST_TMP/shallow-cmp" --previous "$prev"
  assert_contains "$OUT" "- not verified: instances-changed $GP:$INSTANCE" "unverified: reported as not verified"
  assert_not_contains "$OUT" "- resolved:" "unverified: never resolved"
}
test_audit_compare_no_longer_checked() {
  local repo prev
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  prev="$RASTRO_TEST_TMP/prev-gone.md"
  printf '%s\n' "$OUT" >"$prev"
  git -C "$repo" rm -q "$GP"
  commit_all "$repo" "remove the golden path"
  run_audit "$repo" --previous "$prev"
  assert_contains "$OUT" "- no longer checked: instances-changed $GP:$INSTANCE" "gone: no longer checked"
  assert_not_contains "$OUT" "- resolved:" "gone: not resolved"
}

put_history() {
  local repo=$1
  shift
  { printf '\n## History\n\n| Version | Date | Item | Change |\n|---|---|---|---|\n'; printf '%s\n' "$@"; } >>"$repo/$GP"
}
test_audit_history_placeholder_and_extra_cells() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  printf '\n## History  \n\n| Version | Date | Item | Change |\n|---|---|---|---|\n| 1.0.0 | 2026-01-01 | <item id> | Created |\n| 1.1.0 | 2026-02-01 | W-004 | Added | extra |\n' >>"$repo/$GP"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_not_contains "$OUT" "| <item id> |" "history: placeholder item skipped"
  assert_contains "$OUT" "| processor | 1 | 0 |" "history: placeholder row not counted, heading with trailing spaces read"
  assert_contains "$OUT" "| W-004 | 0 | 1 |" "history: a row with extra cells counts"
}
test_metrics_summary() {
  local log out
  . "$RASTRO_TESTS_DIR/../hooks/lib/metrics.sh"
  log=$(make_tmp_repo)/lint.log
  printf '1\ts1\ta\tfail\n2\ts1\ta\tpass\n3\ts1\tb\tpass\n4\ts1\tc\tfail\n5\ts2\ta\tpass\n' >"$log"
  out=$(rastro_metrics_lint_summary "$log")
  assert_eq $'first-pass: 2 of 4 files (50%)\nself-heal: 1 of 2 files (50%)' "$out" "summary: first-pass and self-heal"
  out=$(rastro_metrics_lint_summary "$log.missing")
  assert_eq $'first-pass: no data\nself-heal: no data' "$out" "summary: missing file"
  printf '1\ts1\ta\tpass\n' >"$log"
  out=$(rastro_metrics_lint_summary "$log")
  assert_eq $'first-pass: 1 of 1 files (100%)\nself-heal: no data' "$out" "summary: nothing failed first"
}
test_audit_metrics_without_data() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "no data: status"
  assert_contains "$OUT" "- first-pass: no data" "no data: first-pass"
  assert_contains "$OUT" "- self-heal: no data" "no data: self-heal"
  assert_not_contains "$OUT" "%" "no data: no percentage"
  assert_contains "$OUT" "All numbers are cumulative: the lint figures since the log began" "no data: cumulative note"
}
test_audit_metrics_golden_path_lifecycle() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  put_history "$repo" "| 1.0.0 | 2026-01-01 | W-001 | Created |" "| 1.1.0 | 2026-02-01 | W-004 | Added a field |" "| 2.0.0 | 2026-03-01 | W-009 | Incompatible change |"
  commit_all "$repo" "init"
  printf '\nMore.\n' >>"$repo/$GP"
  commit_all "$repo" "touch the golden path"
  run_audit "$repo"
  assert_status 0 "lifecycle: status"
  assert_contains "$OUT" "| Golden path | Versions | Contradictions | Commits |" "lifecycle: table header"
  assert_contains "$OUT" "| processor | 3 | 1 | 2 |" "lifecycle: processor row"
  assert_contains "$OUT" "| Item | Golden paths created | Golden paths evolved |" "lifecycle: item header"
  assert_contains "$OUT" "| W-001 | 1 | 0 |" "lifecycle: W-001"
  assert_contains "$OUT" "| W-004 | 0 | 1 |" "lifecycle: W-004"
  assert_contains "$OUT" "| W-009 | 0 | 1 |" "lifecycle: W-009"
  assert_contains "$OUT" "Contradictions counts golden path changes decided as incompatible (a major version). A contradiction settled by changing the code leaves no trace in the repository and is not counted." "lifecycle: note"
}
test_audit_metrics_ignores_malformed_history() {
  local repo
  repo=$(new_repo)
  put_gp "$repo"
  put_history "$repo" "| 1.0.0 | 2026-01-01 | W-001 |" "| v2 | 2026-02-01 | W-004 | Bad version |" "| 1.1.0 | 2026-03-01 | W-005 | Valid |"
  commit_all "$repo" "init"
  run_audit "$repo"
  assert_status 0 "malformed history: status"
  assert_contains "$OUT" "| processor | 1 | 0 | 1 |" "malformed history: only the valid line counts"
  assert_contains "$OUT" "| W-005 | 0 | 1 |" "malformed history: valid item"
  assert_not_contains "$OUT" "| W-004 |" "malformed history: bad version ignored"
  assert_not_contains "$OUT" "| W-001 |" "malformed history: short line ignored"
}
test_audit_metrics_section_position() {
  local repo mech metrics changes
  repo=$(new_repo)
  put_gp "$repo"
  commit_all "$repo" "init"
  run_audit "$repo"
  mech=$(printf '%s\n' "$OUT" | grep -n '^## Mechanical checks$' | cut -d: -f1)
  metrics=$(printf '%s\n' "$OUT" | grep -n '^## Metrics$' | cut -d: -f1)
  changes=$(printf '%s\n' "$OUT" | grep -n '^## Changes since the previous audit' | cut -d: -f1)
  assert_eq yes "$([ -n "$metrics" ] && [ "$mech" -lt "$metrics" ] && [ "$metrics" -lt "$changes" ] && echo yes || echo no)" "section order: mechanical, metrics, changes"
}

test_audit_without_config
test_audit_bad_option
test_audit_no_golden_paths
test_audit_clean
test_audit_instance_changed
test_audit_review_baseline_is_version_change
test_audit_added_instance_baseline
test_audit_invalid_status
test_audit_quoted_verified_by
test_audit_instance_not_committed
test_audit_no_frontmatter
test_audit_old_list_form
test_audit_outside_git
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
test_audit_previous_needs_a_file
test_audit_previous_resolved_from_project_root
test_audit_compare_previous
test_audit_compare_never_resolves_unverified
test_audit_compare_no_longer_checked
test_audit_history_placeholder_and_extra_cells
test_metrics_summary
test_audit_metrics_without_data
test_audit_metrics_golden_path_lifecycle
test_audit_metrics_ignores_malformed_history
test_audit_metrics_section_position
finish
