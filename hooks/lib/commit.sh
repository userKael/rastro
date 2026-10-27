. "$(dirname "${BASH_SOURCE[0]}")/config.sh"

_RASTRO_FIXED_SCOPES="shared infra ci docs"
_RASTRO_DEFAULT_TYPES="feat fix refactor chore docs ci perf"
_RASTRO_DEFAULT_COMMIT_FORMAT='{type}({scope}): [{id}] {subject}'
_RASTRO_OUT=""

_rastro_re_escape() {
  local s=$1 i c
  _RASTRO_OUT=""
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case $c in
      '\'|'.'|'['|']'|'*'|'+'|'?'|'^'|'$'|'|'|'('|')'|'{'|'}') _RASTRO_OUT="$_RASTRO_OUT\\$c" ;;
      *) _RASTRO_OUT="$_RASTRO_OUT$c" ;;
    esac
  done
}

_rastro_current_branch() {
  local branch
  if branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
    printf '%s\n' "$branch"
  else
    git symbolic-ref --short -q HEAD 2>/dev/null || true
  fi
}

_rastro_id_from_branch() {
  local re
  _RASTRO_OUT=""
  [ -n "$1" ] && [ "$1" != HEAD ] && [ -n "$2" ] || return 0
  _rastro_re_escape "$2"
  re="^[^/]+/($_RASTRO_OUT-[0-9]+)-"
  if [[ $1 =~ $re ]]; then
    _RASTRO_OUT=${BASH_REMATCH[1]}
  else
    _RASTRO_OUT=""
  fi
}

rastro_branch_id() {
  local branch key kind
  if [ $# -ge 1 ]; then
    branch=$1
  else
    branch=$(_rastro_current_branch)
  fi
  [ -n "$branch" ] && [ "$branch" != HEAD ] || return 0
  key=$(rastro_config_get tracker.key) || return $?
  [ -n "$key" ] || return 0
  kind=$(rastro_config_get tracker.kind) || return $?
  [ "$kind" != none ] || return 0
  _rastro_id_from_branch "$branch" "$key"
  [ -z "$_RASTRO_OUT" ] || printf '%s\n' "$_RASTRO_OUT"
}

_rastro_in_list() {
  local item
  while IFS= read -r item; do
    [ "$item" != "$1" ] || return 0
  done <<<"$2"
  return 1
}

# Writes re and rx_* (the BASH_REMATCH index of each token) into the caller's locals.
# With optional=1, the word holding {id} and one adjacent space become an optional group.
_rastro_build_regex() {
  local fmt=$1 optional=$2 idre=$3
  local n=${#fmt} i=0 g=0 s=-1 e=-1 before ws we c
  re="^"
  rx_type=0
  rx_scope=0
  rx_id=0
  rx_subject=0
  if [ "$optional" = 1 ] && [[ $fmt == *"{id}"* ]]; then
    before=${fmt%%"{id}"*}
    ws=${#before}
    while [ "$ws" -gt 0 ] && [ "${fmt:ws-1:1}" != " " ]; do
      ws=$((ws - 1))
    done
    we=$((${#before} + 4))
    while [ "$we" -lt "$n" ] && [ "${fmt:we:1}" != " " ]; do
      we=$((we + 1))
    done
    s=$ws
    e=$we
    if [ "$we" -lt "$n" ]; then
      e=$((we + 1))
    elif [ "$ws" -gt 0 ]; then
      s=$((ws - 1))
    fi
  fi
  while [ "$i" -le "$n" ]; do
    if [ "$i" -eq "$s" ]; then
      g=$((g + 1))
      re="$re("
    fi
    [ "$i" -ne "$e" ] || re="$re)?"
    [ "$i" -lt "$n" ] || break
    case ${fmt:i} in
      "{type}"*)
        g=$((g + 1)); rx_type=$g
        re="$re([A-Za-z0-9_-]+)"
        i=$((i + 6))
        ;;
      "{scope}"*)
        g=$((g + 1)); rx_scope=$g
        re="$re([A-Za-z0-9_./-]+)"
        i=$((i + 7))
        ;;
      "{id}"*)
        g=$((g + 1)); rx_id=$g
        re="$re($idre)"
        i=$((i + 4))
        ;;
      "{subject}"*)
        g=$((g + 1)); rx_subject=$g
        re="$re(.+)"
        i=$((i + 9))
        ;;
      *)
        c=${fmt:i:1}
        case $c in
          '\'|'.'|'['|']'|'*'|'+'|'?'|'^'|'$'|'|'|'('|')'|'{'|'}') re="$re\\$c" ;;
          *) re="$re$c" ;;
        esac
        i=$((i + 1))
        ;;
    esac
  done
  re="$re\$"
}

_rastro_header_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

rastro_check_header() {
  local header=$1 trailing
  trailing=${header##*[![:space:]]}
  header=${header%"$trailing"}
  case $header in
    "Merge "*|'Revert "'*|"fixup! "*|"squash! "*) return 0 ;;
  esac
  rastro_check_header_strict "$@"
}

rastro_check_header_strict() {
  local header=$1 trailing cfg fmt types="" modules="" scopes key kind branch bid="" idre
  local re rx_type rx_scope rx_id rx_subject
  local got_type="" got_scope="" got_id="" got_subject="" matched=0 mode
  trailing=${header##*[![:space:]]}
  header=${header%"$trailing"}
  cfg=$(rastro_config_path) || return 0
  local RASTRO_CONFIG=$cfg
  fmt=$(rastro_config_get conventions.commit) || return $?
  [ -n "$fmt" ] || fmt=$_RASTRO_DEFAULT_COMMIT_FORMAT
  if [[ $fmt == *"{type}"* ]]; then
    types=$(rastro_config_list conventions.types) || return $?
    [ -n "$types" ] || types=${_RASTRO_DEFAULT_TYPES// /$'\n'}
  fi
  if [[ $fmt == *"{scope}"* ]]; then
    modules=$(rastro_config_list architecture.modules) || return $?
    scopes=${_RASTRO_FIXED_SCOPES// /$'\n'}
    [ -z "$modules" ] || scopes="$modules"$'\n'"$scopes"
  fi
  key=$(rastro_config_get tracker.key) || return $?
  kind=""
  if [ -n "$key" ]; then
    kind=$(rastro_config_get tracker.kind) || return $?
    _rastro_re_escape "$key"
    idre="$_RASTRO_OUT-[0-9]+"
  else
    idre="[A-Za-z][A-Za-z0-9_]*-[0-9]+"
  fi
  if [ $# -ge 2 ]; then
    branch=$2
  else
    branch=$(_rastro_current_branch)
  fi
  if [ "$kind" != none ]; then
    _rastro_id_from_branch "$branch" "$key"
    bid=$_RASTRO_OUT
  fi

  mode=1
  [ -z "$bid" ] || mode=0
  _rastro_build_regex "$fmt" "$mode" "$idre"
  if [[ $header =~ $re ]]; then
    matched=1
  elif [ "$mode" = 0 ]; then
    _rastro_build_regex "$fmt" 1 "$idre"
    if [[ $header =~ $re ]]; then
      matched=1
    fi
  fi
  [ "$matched" = 1 ] || { _rastro_header_fail "header does not match $fmt"; return 1; }

  [ "$rx_type" -eq 0 ] || got_type=${BASH_REMATCH[$rx_type]}
  [ "$rx_scope" -eq 0 ] || got_scope=${BASH_REMATCH[$rx_scope]}
  [ "$rx_id" -eq 0 ] || got_id=${BASH_REMATCH[$rx_id]}
  [ "$rx_subject" -eq 0 ] || got_subject=${BASH_REMATCH[$rx_subject]}

  if [ "$rx_type" -gt 0 ] && ! _rastro_in_list "$got_type" "$types"; then
    _rastro_header_fail "type not allowed"
    return 1
  fi
  if [ "$rx_scope" -gt 0 ] && ! _rastro_in_list "$got_scope" "$scopes"; then
    _rastro_header_fail "scope not allowed"
    return 1
  fi
  if [ "$rx_id" -gt 0 ] && [ -n "$bid" ]; then
    if [ -z "$got_id" ]; then
      if [[ $header == *"$bid"* ]]; then
        _rastro_header_fail "header does not match $fmt"
      else
        _rastro_header_fail "missing id [$bid]"
      fi
      return 1
    fi
    if [ "$got_id" != "$bid" ]; then
      _rastro_header_fail "id differs from branch ($bid)"
      return 1
    fi
  fi
  if [ "$rx_subject" -gt 0 ]; then
    if [[ $got_subject == [[:upper:]]* ]]; then
      _rastro_header_fail "subject must start lowercase"
      return 1
    fi
    if [[ $got_subject == *. ]]; then
      _rastro_header_fail "subject must not end with a period"
      return 1
    fi
    if [ "${#got_subject}" -gt 72 ]; then
      _rastro_header_fail "subject longer than 72 characters"
      return 1
    fi
  fi
  return 0
}
