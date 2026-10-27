. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/../hooks/lib/json.sh"
FIXTURES="$(dirname "$0")/fixtures/json"
str() {
  rastro_json_string "$1" <<<"$2"
}
bool() {
  rastro_json_bool "$1" <<<"$2"
}
test_string_windows_path() {
  assert_eq 'C:\Users\me\My Project\src\a.ts' \
    "$(str file_path '{"tool_input":{"file_path":"C:\\Users\\me\\My Project\\src\\a.ts"}}')" "windows path with space"
}
test_string_escapes() {
  assert_eq 'say "hi"' "$(str a '{"a":"say \"hi\""}')" "escaped quote"
  assert_eq 'a/b' "$(str a '{"a":"a\/b"}')" "escaped slash"
  assert_eq $'one\ntwo' "$(str a '{"a":"one\ntwo"}')" "newline escape"
  assert_eq $'a\tb' "$(str a '{"a":"a\tb"}')" "tab escape"
  assert_eq 'dir\new' "$(str a '{"a":"dir\\new"}')" "escaped backslash before n is not a newline"
  assert_eq 'caf'$'\303\251' "$(str a '{"a":"caf\u00e9"}')" "unicode escape becomes UTF-8"
  assert_eq 'A' "$(str a '{"a":"\u0041"}')" "ASCII unicode escape"
}
test_string_absent_or_wrong_type() {
  assert_eq "" "$(str file_path '{"tool_input":{"command":"ls"}}')" "absent field"
  assert_eq "" "$(str a '{"a":5}')" "number is not a string"
  assert_eq "" "$(str a '{"a":null}')" "null is not a string"
  assert_eq "" "$(str a '')" "empty input"
  assert_eq "" "$(str a '{"b":"a"}')" "field name appearing only as a value"
}
test_string_lookup_is_by_key() {
  assert_eq "yes" "$(str file_path '{"file_path_x":"no","file_path":"yes"}')" "longer key is not a match"
  assert_eq "real" "$(str a '{"b":"a","a":"real"}')" "value equal to the field name is skipped"
  assert_eq "inner" "$(str a '{"x":{"a":"inner"}}')" "nested key"
  assert_eq "v" "$(str a '{ "a" : "v" }')" "whitespace around the colon"
  assert_eq "" "$(str a '{"x":"\"a\":\"fake\""}')" "key text inside an escaped string"
}
test_string_multiline_input() {
  assert_eq "v" "$(str a $'{\n  "a": "v"\n}')" "pretty-printed input"
}
test_bool() {
  assert_eq "true" "$(bool stop_hook_active '{"stop_hook_active": true}')" "true"
  assert_eq "false" "$(bool stop_hook_active '{"stop_hook_active":false}')" "false"
  assert_eq "" "$(bool stop_hook_active '{"a":1}')" "absent"
  assert_eq "" "$(bool stop_hook_active '{"stop_hook_active":"true"}')" "string is not a boolean"
  assert_eq "" "$(bool stop_hook_active '{"stop_hook_active":trueish}')" "not a bare literal"
}
test_fixtures() {
  local json
  json=$(<"$FIXTURES/pretooluse-bash.json")
  assert_eq $'git commit -m "say \\"hi\\""\nls' "$(str command "$json")" "bash payload: command"
  json=$(<"$FIXTURES/posttooluse-write.json")
  assert_eq 'C:\Users\me\My Project\src\a.ts' "$(str file_path "$json")" "write payload: tool_input.file_path, not filePath or content"
  assert_eq "true" "$(bool stop_hook_active "$(<"$FIXTURES/stop-active.json")")" "stop payload: active"
  assert_eq "false" "$(bool stop_hook_active "$(<"$FIXTURES/stop-idle.json")")" "stop payload: idle"
}
test_escape() {
  assert_eq 'say \"hi\"' "$(rastro_json_escape 'say "hi"')" "escape: quotes"
  assert_eq 'a\\b' "$(rastro_json_escape 'a\b')" "escape: backslash"
  assert_eq 'one\ntwo' "$(rastro_json_escape $'one\ntwo')" "escape: newline"
  assert_eq 'C:\\Users\\me\\My Project\\src\\a.ts' "$(rastro_json_escape 'C:\Users\me\My Project\src\a.ts')" "escape: windows path"
  local tab_cr=$'a\tb\rc'
  assert_eq 'a\tb\rc' "$(rastro_json_escape "$tab_cr")" "escape: tab and carriage return"
  assert_eq 'x\u0001y\u001bz\u001f' "$(rastro_json_escape $'x\001y\033z\037')" "escape: other control characters"
  assert_eq "" "$(rastro_json_escape '')" "escape: empty"
  assert_eq 'plain text: ok' "$(rastro_json_escape 'plain text: ok')" "escape: nothing to escape"
}
test_escape_round_trips() {
  local original='npm test -- --grep "a b" C:\x\new'$'\n''second'$'\t''line \u00e9 \\ end'
  assert_eq "$original" "$(str a "{\"a\":\"$(rastro_json_escape "$original")\"}")" "escaped text decodes to the original"
}
test_string_windows_path; test_string_escapes; test_string_absent_or_wrong_type
test_string_lookup_is_by_key; test_string_multiline_input; test_bool; test_fixtures
test_escape; test_escape_round_trips
finish
