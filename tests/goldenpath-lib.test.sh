. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/config.sh"
. "$(dirname "$0")/../hooks/lib/goldenpath.sh"
RASTRO_CONFIG="$RASTRO_TEST_TMP/config.yml"
F="$RASTRO_TEST_TMP/gp.md"

test_folder_default() {
  printf 'workspace: .agent/\n' >"$RASTRO_CONFIG"
  run_cmd rastro_gp_folder
  assert_status 0 "default folder: status 0"
  assert_eq "docs/golden-paths/" "$OUT" "default folder: docs/golden-paths/"
  printf 'architecture:\n  golden_paths: docs/gp\n' >"$RASTRO_CONFIG"
  run_cmd rastro_gp_folder
  assert_eq "docs/gp/" "$OUT" "configured folder gets a trailing slash"
}
test_folder_list_form() {
  printf 'architecture:\n  golden_paths: [a.md, b.md]\n' >"$RASTRO_CONFIG"
  run_cmd rastro_gp_folder
  assert_status 2 "list form: status 2"
  assert_eq "" "$OUT" "list form: no output"
}
test_files_skips_readme() {
  local d="$RASTRO_TEST_TMP/files"
  mkdir -p "$d/docs/gp"
  : >"$d/docs/gp/README.md"
  : >"$d/docs/gp/b.md"
  : >"$d/docs/gp/a.md"
  run_cmd rastro_gp_files "$d" docs/gp/
  assert_status 0 "files: status 0"
  assert_eq "$d/docs/gp/a.md"$'\n'"$d/docs/gp/b.md" "$OUT" "files: README skipped, alphabetical"
}
test_security_states() {
  printf -- '---\nid: processor\n---\n# Title\n' >"$F"
  assert_eq "missing" "$(rastro_gp_security "$F")" "no section: missing"
  printf -- '# Title\n\n## Security\n\n   \n\n## Other\ntext\n' >"$F"
  assert_eq "empty" "$(rastro_gp_security "$F")" "blank section: empty"
  printf -- '# Title\n\n## Security\n\nnone identified\n' >"$F"
  assert_eq "none" "$(rastro_gp_security "$F")" "none identified: none"
  printf -- '# Title\n\n## Security\n\n- Injection: parameterised queries\n' >"$F"
  assert_eq "ok" "$(rastro_gp_security "$F")" "a threat: ok"
  printf -- '# Title\r\n\r\n## Security\r\n\r\n- Injection: parameterised queries\r\n' >"$F"
  assert_eq "ok" "$(rastro_gp_security "$F")" "CRLF heading counts as the section"
}
test_seen_find() {
  local SEEN=$'processor\tdocs/a.md\nservice\tdocs/b.md\n'
  run_cmd rastro_gp_seen_find "$SEEN" processor
  assert_status 0 "seen found: status 0"
  assert_eq "docs/a.md" "$OUT" "seen found: rel of the first match"
  run_cmd rastro_gp_seen_find "$SEEN" client
  assert_status 1 "seen absent: status 1"
  assert_eq "" "$OUT" "seen absent: no output"
}
test_instance_path() {
  assert_eq "src/a.ts" "$(rastro_gp_instance_path 'src/a.ts:12')" "line suffix removed"
  assert_eq "src/a.ts:x" "$(rastro_gp_instance_path 'src/a.ts:x')" "non-numeric suffix kept"
  assert_eq "src/my dir/a.ts" "$(rastro_gp_instance_path 'src/my dir/a.ts')" "path with a space and no suffix unchanged"
}
test_list_has() {
  local LIST=$'a\nb c\n' s
  rastro_gp_list_has "$LIST" "b c" && s=0 || s=$?
  assert_eq 0 "$s" "whole line with a space: 0"
  rastro_gp_list_has "$LIST" b && s=0 || s=$?
  assert_eq 1 "$s" "partial line: 1"
  rastro_gp_list_has "$LIST" a && s=0 || s=$?
  assert_eq 0 "$s" "first line: 0"
}
test_folder_default; test_folder_list_form; test_files_skips_readme; test_security_states
test_seen_find; test_instance_path; test_list_has
finish
