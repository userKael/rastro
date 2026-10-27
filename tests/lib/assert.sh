ASSERT_FAILS=0
STATUS=""
OUT=""
ERR=""

_assert_fail() {
  ASSERT_FAILS=$((ASSERT_FAILS + 1))
  printf '  not ok - %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    printf '      %s\n' "$line" >&2
  done
  return 0
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    return 0
  fi
  _assert_fail "$3" "expected: $1" "actual:   $2"
}

assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
  esac
  _assert_fail "$3" "haystack: $1" "needle:   $2"
}

assert_not_contains() {
  case "$1" in
    *"$2"*) _assert_fail "$3" "haystack: $1" "needle:   $2 (should be absent)" ;;
  esac
  return 0
}

run_cmd() {
  local out_file err_file
  out_file=$(mktemp)
  err_file=$(mktemp)
  STATUS=0
  "$@" >"$out_file" 2>"$err_file" || STATUS=$?
  OUT=$(<"$out_file")
  ERR=$(<"$err_file")
  rm -f "$out_file" "$err_file"
}

assert_status() {
  assert_eq "$1" "$STATUS" "$2"
}

finish() {
  local name
  name=$(basename "$0")
  if [ "$ASSERT_FAILS" -eq 0 ]; then
    echo "PASS $name"
    exit 0
  fi
  echo "FAIL $name: $ASSERT_FAILS assertions"
  exit 1
}
