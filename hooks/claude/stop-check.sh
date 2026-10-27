#!/usr/bin/env bash
set -eu
lib=${RASTRO_LIB:-$(dirname "$0")/../lib}
. "$lib/config.sh"
. "$lib/paths.sh"
. "$lib/json.sh"
. "$lib/lint.sh"
RASTRO_CONFIG=$(rastro_config_path) || exit 0

input=$(cat)
[ "$(rastro_json_bool stop_hook_active <<<"$input")" != true ] || exit 0

root=$(rastro_root)
status_file=$(mktemp)
trap 'rm -f "$status_file"' EXIT
git -C "$root" status --porcelain -z --untracked-files=all >"$status_file" 2>/dev/null || exit 0

paths=()
while IFS= read -r -d '' entry; do
  case ${entry:0:2} in
    R? | C?) IFS= read -r -d '' _origin || true ;;
  esac
  [ -e "$root/${entry:3}" ] || continue
  paths[${#paths[@]}]=${entry:3}
done <"$status_file"
[ "${#paths[@]}" -gt 0 ] || exit 0

lint=$(rastro_config_get verify.lint_file)
globs=$(rastro_config_list verify.source_globs)
typecheck=$(rastro_config_get verify.typecheck)
unit=$(rastro_config_get verify.unit)
integration=$(rastro_config_get verify.integration)
when=""
[ -z "$integration" ] || when=$(rastro_config_list verify.integration_when)

matches_any() {
  local glob
  while IFS= read -r glob; do
    [ -n "$glob" ] || continue
    if rastro_glob_match "$1" "$glob"; then
      return 0
    fi
  done <<<"$2"
  return 1
}

sources=()
need_integration=0
for path in "${paths[@]}"; do
  if matches_any "$path" "$globs"; then
    sources[${#sources[@]}]=$path
  fi
  if [ "$need_integration" -eq 0 ] && matches_any "$path" "$when"; then
    need_integration=1
  fi
done

lint_note=""
if [ -n "$lint" ] && [ "${#sources[@]}" -gt 0 ]; then
  red=0
  report=""
  for path in "${sources[@]}"; do
    rc=0
    out=$(rastro_lint_file "$root" "$path" "$lint") || rc=$?
    case $rc in
      0) ;;
      126 | 127)
        lint_note="lint did not run: $(rastro_lint_not_run "$rc" "$out")"
        printf 'rastro: %s; no lint verdict\n' "$lint_note" >&2
        break
        ;;
      *)
        red=$((red + 1))
        report+=$out$'\n'
        ;;
    esac
  done
  if [ "$red" -gt 0 ]; then
    printf 'rastro: verify.lint_file failed on %s changed file(s); fix them before you stop\n%s' "$red" "$report" >&2
    printf 'rastro: do not turn off a rule to close the gate; fix the code, or take the rule to a human\n' >&2
    rastro_lint_hint >&2
    exit 2
  fi
fi

if [ "${#sources[@]}" -gt 0 ] || [ "$need_integration" -eq 1 ]; then
  lines=""
  [ -z "$lint_note" ] || lines+="  $lint_note"$'\n'
  [ -z "$typecheck" ] || lines+="  verify.typecheck: $typecheck"$'\n'
  [ -z "$unit" ] || lines+="  verify.unit: $unit"$'\n'
  if [ "$need_integration" -eq 1 ] && [ -n "$integration" ]; then
    lines+="  verify.integration: $integration"$'\n'
  fi
  if [ -n "$lines" ]; then
    message="rastro: changed files still need verification before you stop"$'\n'$lines
    printf '{"systemMessage":"%s"}\n' "$(rastro_json_escape "${message%$'\n'}")"
  fi
fi
exit 0
