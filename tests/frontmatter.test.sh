. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/frontmatter.sh"
F="$RASTRO_TEST_TMP/gp.md"

test_get_scalar() {
  printf -- '---\nid: processor\n---\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" id
  assert_status 0 "get scalar: status 0"
  assert_eq "processor" "$OUT" "get scalar: value"
}
test_get_keeps_hash() {
  printf -- '---\norigin: W-012, PR #34, 2026-11-20\n---\n' >"$F"
  assert_eq "W-012, PR #34, 2026-11-20" "$(rastro_frontmatter_get "$F" origin)" "hash and text after it kept"
}
test_get_strips_quotes() {
  printf -- '---\ntype: "service"\n---\n' >"$F"
  assert_eq "service" "$(rastro_frontmatter_get "$F" type)" "surrounding quotes removed"
}
test_get_empty_quotes() {
  printf -- '---\nsuperseded_by: ""\nstatus: '"''"'\nlone: "\n---\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" superseded_by
  assert_status 0 "empty double quotes: status 0"
  assert_eq "" "$OUT" "empty double quotes: empty value"
  run_cmd rastro_frontmatter_get "$F" status
  assert_status 0 "empty single quotes: status 0"
  assert_eq "" "$OUT" "empty single quotes: empty value"
  assert_eq '"' "$(rastro_frontmatter_get "$F" lone)" "lone quote left as is"
}
test_get_absent() {
  printf -- '---\nid: processor\n---\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" status
  assert_status 1 "absent key: status 1"
  assert_eq "" "$OUT" "absent key: empty stdout"
}
test_no_frontmatter() {
  printf -- '# Title\n\nid: processor\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" id
  assert_status 2 "no frontmatter: status 2"
}
test_unclosed_frontmatter() {
  printf -- '---\nid: processor\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" id
  assert_status 2 "unclosed frontmatter: status 2"
}
test_crlf() {
  printf -- '---\r\nid: processor\r\n---\r\n' >"$F"
  run_cmd rastro_frontmatter_get "$F" id
  assert_status 0 "crlf: status 0"
  assert_eq "processor" "$OUT" "crlf: no carriage return"
}
test_body_ignored() {
  printf -- '---\nid: processor\n---\nid: other\n' >"$F"
  assert_eq "processor" "$(rastro_frontmatter_get "$F" id)" "body after closing --- ignored"
}
test_list() {
  printf -- '---\ninstances: [a.ts:1, "b c.ts:2"]\n---\n' >"$F"
  run_cmd rastro_frontmatter_list "$F" instances
  assert_status 0 "list: status 0"
  assert_eq $'a.ts:1\nb c.ts:2' "$OUT" "list: one item per line, quotes removed"
}
test_list_empty() {
  printf -- '---\ninstances: []\n---\n' >"$F"
  run_cmd rastro_frontmatter_list "$F" instances
  assert_status 0 "empty list: status 0"
  assert_eq "" "$OUT" "empty list: no output"
}
test_list_not_inline() {
  printf -- '---\ninstances: a.ts\n---\n' >"$F"
  run_cmd rastro_frontmatter_list "$F" instances
  assert_status 3 "non-inline list: status 3"
}
test_get_scalar; test_get_keeps_hash; test_get_strips_quotes; test_get_empty_quotes; test_get_absent; test_no_frontmatter
test_unclosed_frontmatter; test_crlf; test_body_ignored; test_list; test_list_empty; test_list_not_inline
finish
