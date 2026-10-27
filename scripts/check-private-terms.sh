#!/usr/bin/env bash
export LC_ALL=C.UTF-8

refuse() {
  printf '%s; refusing to report clean\n' "$1" >&2
  exit 2
}

terms_file="${1:-}"
if [ -z "$terms_file" ] || [ ! -f "$terms_file" ]; then
  refuse "terms file not found"
fi

upper=$(printf '\303\207')
lower=$(printf '\303\247')
[ "$(printf '%s\n' "$upper" | grep -ci -e "$lower")" = 1 ] || refuse "UTF-8 case folding is unavailable"

top=$(git rev-parse --show-toplevel 2>/dev/null) || refuse "not inside a git repository"
cd "$top" || exit 2
[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" != true ] || refuse "repository is shallow, older history is not available"

work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT

[ "$(LC_ALL=C tr -d '\000' <"$terms_file" | wc -c)" = "$(wc -c <"$terms_file")" ] || refuse "terms file contains NUL bytes, it is probably UTF-16"
bom=$(printf '\357\273\277')
patterns="$work/patterns"
tr -d '\r' <"$terms_file" | LC_ALL=C sed "1s/^$bom//" | grep -vE '^[[:space:]]*(#|$)' >"$patterns"
[ -s "$patterns" ] || refuse "terms file has no patterns"

while IFS= read -r pat; do
  grep -E -e "$pat" </dev/null >/dev/null 2>&1
  [ $? -ne 2 ] || refuse "invalid pattern in terms file: $pat"
done <"$patterns"

git log -p --all --no-color --no-decorate --no-ext-diff --no-textconv >"$work/log" 2>"$work/log.err" ||
  refuse "git log failed: $(head -n 1 "$work/log.err")"
awk '/^commit [0-9a-f]+/ { c = substr($2, 1, 7) } { print c }' "$work/log" >"$work/commit-of-line"

git ls-files -z | LC_ALL=C xargs -0 -r grep -sIlZ -e '' -- >"$work/text-files"

scan_tracked() {
  xargs -0 -r -a "$work/text-files" grep -saHniE "$@" --
}

if [ -z "$(scan_tracked -f "$patterns" | head -n 1)" ] && ! grep -aqiE -f "$patterns" "$work/log"; then
  exit 0
fi

found=0
while IFS= read -r pat; do
  content=$(scan_tracked -e "$pat" | PAT="$pat" awk -F: '{ print $1 ":" $2 ": " ENVIRON["PAT"] }')
  history=$(grep -aniE -e "$pat" "$work/log" | cut -d: -f1 |
    PAT="$pat" awk 'NR == FNR { c[FNR] = $0; next } !seen[c[$1]]++ { print "commit " c[$1] ": " ENVIRON["PAT"] }' "$work/commit-of-line" -)
  for out in "$content" "$history"; do
    [ -z "$out" ] && continue
    printf '%s\n' "$out"
    found=1
  done
done <"$patterns"

exit "$found"
