. "$(dirname "${BASH_SOURCE[0]}")/config.sh"

_RASTRO_FORBIDDEN_LOADED=0
_RASTRO_FORBIDDEN=()
_RASTRO_DEFAULT_FORBIDDEN=$'.env*\n*.bak'

rastro_path_matches() {
  local path=$1 pattern=$2 anywhere=0 anchored=0 rest segment
  if [[ $pattern == /* ]]; then
    pattern=${pattern#/}
    anchored=1
  fi
  while [[ $pattern == '**/'* ]]; do
    pattern=${pattern#'**/'}
    anywhere=1
  done
  [ -n "$pattern" ] || return 1
  if [ "$anywhere" -eq 0 ]; then
    case $pattern in
      */) [[ $path == $pattern* ]]; return ;;
      */*) _rastro_glob_or_under "$path" "$pattern"; return ;;
    esac
    if [ "$anchored" -eq 1 ]; then
      _rastro_glob_or_under "$path" "$pattern"
      return
    fi
  else
    case $pattern in
      */) pattern="$pattern*" ;;
    esac
    case $pattern in
      */*)
        _rastro_glob_or_under "$path" "$pattern" || _rastro_glob_or_under "$path" "*/$pattern"
        return
        ;;
    esac
  fi
  rest=$path
  while :; do
    segment=${rest%%/*}
    if [[ $segment == $pattern ]]; then
      return 0
    fi
    [[ $rest == */* ]] || return 1
    rest=${rest#*/}
  done
}

rastro_glob_match() {
  local glob=${2//'**/'/*}
  [[ $1 == $glob ]]
}

_rastro_glob_or_under() {
  rastro_glob_match "$1" "$2" || rastro_glob_match "$1" "$2/*"
}

rastro_forbidden_patterns() {
  local list workspace
  if rastro_config_has conventions.forbidden_paths; then
    list=$(rastro_config_list conventions.forbidden_paths) || return $?
  else
    list=$_RASTRO_DEFAULT_FORBIDDEN
  fi
  workspace=$(rastro_workspace) || return $?
  [ -z "$list" ] || printf '%s\n' "$list"
  [ -z "$workspace" ] || printf '%s\n' "${workspace%/}/"
  return 0
}

rastro_forbidden_load() {
  local patterns pattern
  patterns=$(rastro_forbidden_patterns) || return $?
  _RASTRO_FORBIDDEN=()
  while IFS= read -r pattern; do
    [ -z "$pattern" ] || _RASTRO_FORBIDDEN[${#_RASTRO_FORBIDDEN[@]}]=$pattern
  done <<<"$patterns"
  _RASTRO_FORBIDDEN_LOADED=1
}

rastro_path_forbidden() {
  local pattern
  [ "$_RASTRO_FORBIDDEN_LOADED" = 1 ] || rastro_forbidden_load || return 2
  for pattern in ${_RASTRO_FORBIDDEN[@]+"${_RASTRO_FORBIDDEN[@]}"}; do
    if rastro_path_matches "$1" "$pattern"; then
      return 0
    fi
  done
  return 1
}

rastro_report_forbidden() {
  local path found=0
  [ "$_RASTRO_FORBIDDEN_LOADED" = 1 ] || rastro_forbidden_load || return 2
  while IFS= read -r -d '' path; do
    if rastro_path_forbidden "$path"; then
      printf '%s: %s\n' "$1" "$path" >&2
      found=1
    fi
  done
  [ "$found" -eq 0 ]
}
