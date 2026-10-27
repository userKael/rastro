. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/../hooks/lib/config.sh"
export RASTRO_CONFIG="$(dirname "$0")/fixtures/config/basic.yml"
test_scalars() {
  assert_eq "shelf" "$(rastro_config_get project.name)" "nested scalar"
  assert_eq "pt-BR" "$(rastro_config_get project.languages.human)" "3 levels, comment stripped"
  assert_eq "local" "$(rastro_config_get tracker.kind)" "tracker.kind"
  assert_eq "repo" "$(rastro_config_get docs.kind)" "docs.kind not confused with tracker.kind"
  assert_eq ".agent/" "$(rastro_config_get workspace)" "top-level scalar"
  assert_eq "{type}({scope}): [{id}] {subject}" "$(rastro_config_get conventions.commit)" "quotes removed"
  assert_eq "a#b" "$(rastro_config_get conventions.note)" "hash inside quotes kept"
  assert_eq "" "$(rastro_config_get tracker.absent)" "absent key is empty"
}
test_lists() {
  assert_eq $'src/**/*.ts\nlib/my dir/*.ts' "$(rastro_config_list verify.source_globs)" "inline list with quoted item"
  assert_eq $'.env*\n*.bak\ncoverage/' "$(rastro_config_list conventions.forbidden_paths)" "inline list"
}
test_has() {
  rastro_config_has docs.kind; assert_eq 0 $? "has existing key"
  rastro_config_has docs.location; assert_eq 1 $? "has absent key"
}
test_crlf_config() {
  RASTRO_CONFIG="$(dirname "$0")/fixtures/config/basic-crlf.yml"
  assert_eq "local" "$(rastro_config_get tracker.kind)" "CRLF stripped"
  assert_eq $'.env*\n*.bak\ncoverage/' "$(rastro_config_list conventions.forbidden_paths)" "CRLF list"
}
test_missing_file() {
  RASTRO_CONFIG=/nonexistent/config.yml rastro_config_path >/dev/null; assert_eq 1 $? "missing config returns 1"
}
test_template_parses() {
  RASTRO_CONFIG="$(dirname "$0")/../templates/config.yml"
  for k in project.name project.base_branch project.languages.machine project.languages.human \
           tracker.kind tracker.key tracker.hierarchy tracker.local_dir docs.kind docs.location docs.public_portal \
           code_host.kind code_host.merge code_host.template domain_state.kind domain_state.server domain_state.schema_files \
           verify.lint verify.typecheck verify.unit verify.integration verify.integration_when verify.lint_file verify.source_globs \
           architecture.modules architecture.layers architecture.rules architecture.golden_paths architecture.contract_sources architecture.sensitive_data \
           domain.stateful_entities conventions.branch conventions.commit conventions.types conventions.co_author_trailer conventions.forbidden_paths \
           workspace review.kind review.rules; do
    rastro_config_has "$k"; assert_eq 0 $? "template has $k"
  done
  assert_eq "main" "$(rastro_config_get project.base_branch)" "default base_branch"
  assert_eq "squash" "$(rastro_config_get code_host.merge)" "default merge"
  assert_eq ".agent/" "$(rastro_config_get workspace)" "default workspace"
  assert_eq ".review-rules.md" "$(rastro_config_get review.rules)" "default review.rules is markdown"
  assert_eq $'feat\nfix\nrefactor\nchore\ndocs\nci\nperf' "$(rastro_config_list conventions.types)" "default types"
}
test_unsupported_lists() {
  RASTRO_CONFIG="$(dirname "$0")/fixtures/config/unsupported-lists.yml"
  local k msg
  for k in lists.multi_line lists.unterminated lists.block lists.same_indent; do
    msg="rastro: config key $k uses an unsupported list form; write it inline as [a, b]"
    run_cmd rastro_config_list "$k"
    assert_status 2 "list $k: status 2"
    assert_eq "" "$OUT" "list $k: empty stdout"
    assert_eq "$msg" "$ERR" "list $k: stderr message"
    run_cmd rastro_config_get "$k"
    assert_status 2 "get $k: status 2"
    assert_eq "" "$OUT" "get $k: empty stdout"
    assert_eq "$msg" "$ERR" "get $k: stderr message"
  done
  run_cmd rastro_config_list lists.valid
  assert_status 0 "valid list after unsupported ones: status 0"
  assert_eq $'x\ny z' "$OUT" "valid list after unsupported ones: items"
  assert_eq "" "$ERR" "valid list after unsupported ones: silent"
  run_cmd rastro_config_get lists.absent
  assert_status 0 "absent key stays status 0"
  assert_eq "" "$OUT$ERR" "absent key stays silent"
  RASTRO_CONFIG="$(dirname "$0")/fixtures/config/basic.yml"
  run_cmd rastro_config_get project.languages
  assert_status 0 "parent map key stays status 0"
  assert_eq "" "$OUT$ERR" "parent map key stays silent"
  RASTRO_CONFIG="$(dirname "$0")/../templates/config.yml"
  run_cmd rastro_config_get tracker.key
  assert_status 0 "empty key followed by a comment stays status 0"
  assert_eq "" "$OUT$ERR" "empty key followed by a comment stays silent"
  RASTRO_CONFIG=/nonexistent/config.yml
  run_cmd rastro_config_list conventions.forbidden_paths
  assert_status 0 "missing file stays status 0"
  assert_eq "" "$OUT$ERR" "missing file stays silent"
}
test_scalars; test_lists; test_has; test_crlf_config; test_missing_file; test_template_parses; test_unsupported_lists
finish
