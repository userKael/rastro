. "$(dirname "$0")/lib/assert.sh"
run_cmd bash -c 'echo out; echo err >&2; exit 3'
assert_status 3 "captures exit status"
assert_eq "out" "$OUT" "captures stdout"
assert_eq "err" "$ERR" "captures stderr"
assert_contains "abc" "b" "contains"
assert_not_contains "abc" "z" "not contains"
( . "$(dirname "$0")/lib/assert.sh"; assert_eq a b "deliberate"; finish ) >/dev/null 2>&1
assert_eq 1 $? "finish exits 1 after a failed assertion"
finish
