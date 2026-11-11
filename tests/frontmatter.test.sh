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
TAB=$'\t'
test_dump_scalar() {
  printf -- '---\nid: processor\nversion: 1.0.0\nempty:\n---\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_status 0 "dump scalar: status 0"
  assert_eq "id${TAB}processor"$'\n'"version${TAB}1.0.0"$'\n'"empty${TAB}" "$OUT" "dump scalar: key tab value per line"
}
test_dump_quotes() {
  printf -- '---\ntype: "service"\nstatus: '"'current'"'\nlone: "\nnone: ""\n---\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_eq "type${TAB}service"$'\n'"status${TAB}current"$'\n'"lone${TAB}\""$'\n'"none${TAB}" "$OUT" "dump quotes: one pair removed, lone quote kept"
}
test_dump_keeps_hash() {
  printf -- '---\norigin: W-012, PR #34, 2026-11-20\n---\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_eq "origin${TAB}W-012, PR #34, 2026-11-20" "$OUT" "dump: hash and text after it kept"
}
test_dump_crlf() {
  printf -- '---\r\nid: processor\r\nstatus:   current  \r\n---\r\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_status 0 "dump crlf: status 0"
  assert_eq "id${TAB}processor"$'\n'"status${TAB}current" "$OUT" "dump crlf: no carriage return, value trimmed"
}
test_dump_body_ignored() {
  printf -- '---\nid: processor\n  nested: x\n---\nid: other\nbody: y\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_eq "id${TAB}processor" "$OUT" "dump: body and indented lines ignored"
}
test_dump_first_key_wins() {
  printf -- '---\nid: first\nid: second\n---\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_eq "id${TAB}first" "$OUT" "dump: a repeated key keeps its first value, as get does"
}
test_dump_no_frontmatter() {
  printf -- '# Title\n\nid: processor\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_status 2 "dump no frontmatter: status 2"
  assert_eq "" "$OUT" "dump no frontmatter: no output"
  printf -- '---\nid: processor\n' >"$F"
  run_cmd rastro_frontmatter_dump "$F"
  assert_status 2 "dump unclosed: status 2"
}
test_split_items() {
  rastro_frontmatter_split '[a.ts:1, "b c.ts:2",  c.ts ]'
  assert_eq "3" "${#RASTRO_FM_ITEMS[@]}" "split: three items"
  assert_eq "a.ts:1" "${RASTRO_FM_ITEMS[0]}" "split: first item"
  assert_eq "b c.ts:2" "${RASTRO_FM_ITEMS[1]}" "split: quoted item with a space, quotes removed"
  assert_eq "c.ts" "${RASTRO_FM_ITEMS[2]}" "split: item trimmed"
}
test_split_status() {
  local s
  rastro_frontmatter_split '[a, b]' && s=0 || s=$?
  assert_eq 0 "$s" "split: status 0"
  rastro_frontmatter_split '[a.ts]' && s=0 || s=$?
  assert_eq 0 "$s" "split single: status 0"
  assert_eq "a.ts" "${RASTRO_FM_ITEMS[0]}" "split single: item"
}
test_split_empty() {
  local s
  rastro_frontmatter_split '[]' && s=0 || s=$?
  assert_eq 0 "$s" "split empty: status 0"
  assert_eq "0" "${#RASTRO_FM_ITEMS[@]}" "split empty: no item"
  rastro_frontmatter_split '[ ,  , ]' && s=0 || s=$?
  assert_eq "0" "${#RASTRO_FM_ITEMS[@]}" "split blanks: no item"
}
test_split_not_inline() {
  local s
  rastro_frontmatter_split 'a.ts' && s=0 || s=$?
  assert_eq 3 "$s" "split not inline: status 3"
  rastro_frontmatter_split '' && s=0 || s=$?
  assert_eq 3 "$s" "split empty value: status 3"
  assert_eq "0" "${#RASTRO_FM_ITEMS[@]}" "split not inline: no item left from an earlier call"
}
test_dump_scalar; test_dump_quotes; test_dump_keeps_hash; test_dump_crlf; test_dump_body_ignored; test_dump_first_key_wins; test_dump_no_frontmatter
test_split_items; test_split_status; test_split_empty; test_split_not_inline
test_get_scalar; test_get_keeps_hash; test_get_strips_quotes; test_get_empty_quotes; test_get_absent; test_no_frontmatter
test_unclosed_frontmatter; test_crlf; test_body_ignored; test_list; test_list_empty; test_list_not_inline
finish
