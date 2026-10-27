#!/usr/bin/env bash
set -eu
lib=${RASTRO_LIB:-$(dirname "$0")/../lib}
. "$lib/config.sh"
. "$lib/paths.sh"
. "$lib/json.sh"
. "$lib/lint.sh"
RASTRO_CONFIG=$(rastro_config_path) || exit 0

relative_to_root() {
  local root=${1//\\//} path=${2//\\//} rel=""
  [[ $root =~ ^([A-Za-z]):/(.*)$ ]] && root=/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}
  [[ $path =~ ^([A-Za-z]):/(.*)$ ]] && path=/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}
  root=${root%/}
  shopt -s nocasematch
  case $path in
    "$root"/*) rel=${path:${#root}+1} ;;
    /*) ;;
    *) rel=${path#./} ;;
  esac
  shopt -u nocasematch
  [ -n "$rel" ] || return 1
  printf '%s' "$rel"
}

file=$(rastro_json_string file_path)
[ -n "$file" ] || exit 0
lint=$(rastro_config_get verify.lint_file)
[ -n "$lint" ] || exit 0
globs=$(rastro_config_list verify.source_globs)
root=$(rastro_root)
rel=$(relative_to_root "$root" "$file") || exit 0

matched=0
while IFS= read -r glob; do
  [ -n "$glob" ] || continue
  if rastro_glob_match "$rel" "$glob"; then
    matched=1
    break
  fi
done <<<"$globs"
[ "$matched" -eq 1 ] || exit 0
[ -f "$root/$rel" ] || exit 0

rc=0
out=$(rastro_lint_file "$root" "$rel" "$lint") || rc=$?
case $rc in
  0) exit 0 ;;
  126 | 127)
    printf 'rastro: lint did not run on %s: %s\nThere is no lint verdict for this edit. Install the linter, or fix verify.lint_file in .rastro/config.yml.\n' "$rel" "$(rastro_lint_not_run "$rc" "$out")" >&2
    exit 2
    ;;
esac
printf 'rastro: verify.lint_file failed on %s\n%s\n' "$rel" "$out" >&2
rastro_lint_hint >&2
exit 2
