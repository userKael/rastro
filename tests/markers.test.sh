tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
. "$tests_dir/lib/exact.sh"
export LC_ALL=C.UTF-8
require_core=${RASTRO_REQUIRE_CORE:-}
if [ -z "$require_core" ]; then
  if [ $# -eq 0 ]; then require_core=1; else require_core=0; fi
fi
root=$(cd "${1:-$tests_dir/..}" && pwd)
markers_file="$root/templates/MARKERS.md"
CORE_MARKERS=(
  '## Reconciliation'
  'reconciliation.md'
  'NOT VERIFIED'
  '[HUMAN]'
  '[no PR]'
  '## Context'
  'Decided (<YYYY-MM-DD>):'
  'D-n'
  'DT-nn'
)

list_markers() {
  awk '
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^\|/) {
        sub(/^\|[ \t]*/, "", line)
        sub(/[ \t]*\|.*/, "", line)
      } else {
        sub(/^[-*][ \t]+/, "", line)
      }
      while (match(line, /^`[^`]+`/)) {
        print substr(line, 2, RLENGTH - 2)
        line = substr(line, RLENGTH + 1)
        if (!sub(/^[ \t]*,[ \t]*/, "", line)) break
      }
    }
  ' "$markers_file"
}

test_markers() {
  local markers marker dirs=() dir hits
  if ! exists_exact "$root" "templates/MARKERS.md"; then
    _assert_fail "templates/MARKERS.md does not exist"
    return
  fi
  markers=$(list_markers)
  if [ -z "$markers" ]; then
    _assert_fail "templates/MARKERS.md lists no marker (one per line, in backticks)"
    return
  fi
  if [ "$require_core" = 1 ]; then
    for marker in "${CORE_MARKERS[@]}"; do
      printf '%s\n' "$markers" | grep -qxF -e "$marker" ||
        _assert_fail "required marker missing from templates/MARKERS.md" "marker: $marker"
    done
  fi
  for dir in templates skills; do
    exists_exact "$root" "$dir/" && dirs+=("$root/$dir")
  done
  while IFS= read -r marker; do
    hits=$(grep -rlF -e "$marker" "${dirs[@]}" 2>/dev/null | grep -vxF "$markers_file")
    [ -n "$hits" ] || _assert_fail "marker appears in no file under templates/ or skills/ besides MARKERS.md" "marker: $marker"
  done <<<"$markers"
}

test_markers
finish
