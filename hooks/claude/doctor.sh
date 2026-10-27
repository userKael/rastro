#!/usr/bin/env bash
# A SessionStart hook must not fail the session: every path exits 0.
trap '[ -z "$errf" ] || rm -f "$errf"; exit 0' EXIT

CLOSING="Tell the human about each PROBLEM before starting work."
MCP_TAIL="not found by name. Connectors added through claude.ai use opaque ids; confirm before concluding it is missing."
checks=0
problems=0
errf=""
val=""
seen_mcp=""
mcp_loaded=0
mcp_project=""
mcp_user=""
k_tracker=""
k_docs=""
k_code_host=""
k_domain_state=""
k_review=""

problem() {
  printf -- '- PROBLEM: %s\n' "$1"
  problems=$((problems + 1))
}

info() {
  printf -- '- info: %s\n' "$1"
}

finish() {
  local line="rastro doctor: $checks checks, $problems problems."
  [ "$problems" -eq 0 ] || line="$line $CLOSING"
  printf '%s\n' "$line"
  exit 0
}

lib=${RASTRO_LIB:-$(dirname "$0")/../lib}
if ! . "$lib/config.sh" 2>/dev/null; then
  checks=1
  problem "could not check config: $lib/config.sh not found"
  finish
fi
framework=${RASTRO_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/../..}}

cfg=$(rastro_config_path) || {
  printf 'rastro doctor: no .rastro/config.yml found. Run the setup skill.\n'
  exit 0
}
RASTRO_CONFIG=$cfg
root=$(rastro_root)
root_fs=${root//\\//}
errf=$(mktemp 2>/dev/null) || errf=""

get() {
  local rc=0 msg=""
  if [ -n "$errf" ]; then
    val=$(rastro_config_get "$1" 2>"$errf") || rc=$?
  else
    val=$(rastro_config_get "$1" 2>/dev/null) || rc=$?
  fi
  [ "$rc" -ne 0 ] || return 0
  val=""
  [ -z "$errf" ] || IFS= read -r msg <"$errf" || true
  msg=${msg#rastro: }
  [ -n "$msg" ] || msg="config key $1 could not be read"
  problem "$msg"
  return 1
}

read_kind() {
  if get "$2"; then
    [ -n "$val" ] || val=$3
    printf -v "$1" '%s' "$val"
  else
    printf -v "$1" '%s' ""
  fi
}

norm_path() {
  local p=${1//\\//} rest seg out="" abs=0
  case $p in
    "$root_fs"/*) p=${p#"$root_fs"/} ;;
  esac
  case $p in
    /* | [A-Za-z]:/*) abs=1 ;;
  esac
  rest=$p
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    if [ "$seg" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    case $seg in
      '' | .) ;;
      ..)
        case $out in
          '' | .. | */..) out=${out:+$out/}.. ;;
          */*) out=${out%/*} ;;
          *) out="" ;;
        esac
        ;;
      *) out=${out:+$out/}$seg ;;
    esac
  done
  NORM=$out
  [ "$abs" -eq 0 ] || NORM=/$out
}

mcp_found() {
  local q='"'
  if [ "$mcp_loaded" -eq 0 ]; then
    mcp_loaded=1
    [ ! -r "$root/.mcp.json" ] || mcp_project=$(<"$root/.mcp.json")
    [ ! -r "${HOME:-}/.claude.json" ] || mcp_user=$(<"$HOME/.claude.json")
  fi
  [[ $mcp_project =~ "$q$1$q"[[:space:]]*: ]] && return 0
  [[ $mcp_user =~ "$q$1$q"[[:space:]]*: ]]
}

check_requirements() {
  local label=$1 file=$2 line item name rest ckey found=0 bad=0 clis="" mcps="" bt='`'
  local -a list
  if [ ! -r "$file" ]; then
    problem "could not check requirements of $label: $file is not readable"
    return
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line//$bt/}
    line=${line//\*\*/}
    line=${line#"${line%%[![:space:]]*}"}
    case $line in
      '- '* | '* '*)
        line=${line:2}
        line=${line#"${line%%[![:space:]]*}"}
        ;;
    esac
    case $line in
      'REQUIRED CLI:'*)
        found=1
        rest=${line#REQUIRED CLI:}
        [ -n "${rest//[[:space:],]/}" ] || bad=1
        clis="$clis,$rest"
        ;;
      'REQUIRED MCP:'*)
        found=1
        rest=${line#REQUIRED MCP:}
        [ -n "${rest//[[:space:],]/}" ] || bad=1
        mcps="$mcps,$rest"
        ;;
      'REQUIRED:'*)
        found=1
        rest=${line#REQUIRED:}
        rest=${rest#"${rest%%[![:space:]]*}"}
        rest=${rest%"${rest##*[![:space:]]}"}
        [ "$rest" = none ] || bad=1
        ;;
    esac
  done <"$file"
  if [ "$found" -eq 0 ]; then
    problem "could not check requirements of $label: the adapter has no REQUIRED line"
    return
  fi
  [ "$bad" -eq 0 ] || problem "could not check requirements of $label: a REQUIRED line is empty, or REQUIRED: is followed by something other than none"
  IFS=, read -ra list <<<"$clis"
  for item in "${list[@]}"; do
    name=${item#"${item%%[![:space:]]*}"}
    name=${name%%[[:space:]]*}
    [ -n "$name" ] || continue
    checks=$((checks + 1))
    command -v -- "$name" >/dev/null 2>&1 || problem "CLI not found: $name (required by $label)"
  done
  IFS=, read -ra list <<<"$mcps"
  for item in "${list[@]}"; do
    name=${item#"${item%%[![:space:]]*}"}
    case $name in
      'from config' | 'from config'[[:space:]]*)
        ckey=${name#from config}
        ckey=${ckey#"${ckey%%[![:space:]]*}"}
        ckey=${ckey%%[[:space:]]*}
        if [ -z "$ckey" ]; then
          problem "could not check requirements of $label: 'from config' names no config key"
          continue
        fi
        checks=$((checks + 1))
        get "$ckey" || continue
        if [ -z "$val" ]; then
          problem "config key $ckey is not set; $label reads its MCP server name from it"
          continue
        fi
        name=$val
        ;;
      *) name=${name%%[[:space:]]*} ;;
    esac
    [ -n "$name" ] || continue
    case $'\n'"$seen_mcp" in
      *$'\n'"$name"$'\n'*) continue ;;
    esac
    seen_mcp="$seen_mcp$name"$'\n'
    checks=$((checks + 1))
    mcp_found "$name" || info "MCP server $name $MCP_TAIL"
  done
}

dir_differs() {
  local f
  for f in "$1"/*; do
    [ -f "$f" ] || continue
    [ -f "$2/${f##*/}" ] || return 0
    [ "$(<"$f")" = "$(<"$2/${f##*/}")" ] || return 0
  done
  for f in "$2"/*; do
    [ -f "$f" ] || continue
    [ -f "$1/${f##*/}" ] || return 0
  done
  return 1
}

checks=$((checks + 1))
if [ ! -r "$cfg" ]; then
  problem "could not check config: $cfg is not readable"
  finish
fi

for key in project.name project.languages.human tracker.kind code_host.kind; do
  checks=$((checks + 1))
  if get "$key"; then
    [ -n "$val" ] || problem "missing required config key: $key"
  fi
  case $key in
    tracker.kind) k_tracker=$val ;;
    code_host.kind) k_code_host=$val ;;
  esac
done

checks=$((checks + 1))
verify_set=0
verify_unread=0
for key in verify.lint verify.typecheck verify.unit verify.integration; do
  if get "$key"; then
    [ -z "$val" ] || verify_set=1
  else
    verify_unread=1
  fi
done
if [ "$verify_set" -eq 0 ] && [ "$verify_unread" -eq 0 ]; then
  problem "no verify command configured; set at least one of verify.lint, verify.typecheck, verify.unit, verify.integration"
fi

if get verify.lint_file && [ -n "$val" ]; then
  checks=$((checks + 1))
  lint_bin=${val#"${val%%[![:space:]]*}"}
  lint_bin=${lint_bin%%[[:space:]]*}
  if ! (cd "$root" 2>/dev/null && command -v -- "$lint_bin" >/dev/null 2>&1); then
    problem "verify.lint_file runs $lint_bin, which is not on PATH; the lint hooks cannot lint an edited file until it is installed"
  fi
fi

read_kind k_docs docs.kind repo
read_kind k_domain_state domain_state.kind none
read_kind k_review review.kind none

for port in tracker:k_tracker docs:k_docs code-host:k_code_host domain-state:k_domain_state review:k_review; do
  dir=${port%%:*}
  var=${port#*:}
  kind=${!var}
  [ -n "$kind" ] || continue
  checks=$((checks + 1))
  adapter=""
  case $kind in
    */* | *\\*) ;;
    *)
      if [ -f "$root/.rastro/adapters/$dir/$kind.md" ]; then
        adapter=$root/.rastro/adapters/$dir/$kind.md
      elif [ -f "$framework/adapters/$dir/$kind.md" ]; then
        adapter=$framework/adapters/$dir/$kind.md
      fi
      ;;
  esac
  if [ -z "$adapter" ]; then
    problem "missing adapter $dir/$kind"
    continue
  fi
  check_requirements "$dir/$kind" "$adapter"
done

if [ "$k_tracker" = local ] && get tracker.local_dir; then
  local_dir=${val:-work/}
  if get workspace; then
    rastro_config_has workspace || val=.agent/
    checks=$((checks + 1))
    norm_path "$local_dir"
    ld=$NORM
    norm_path "$val"
    ws=$NORM
    if [ -n "$ws" ] && { [ "$ld" = "$ws" ] || [[ $ld == "$ws"/* ]]; }; then
      problem "tracker.local_dir is inside the workspace, which is never committed; work items must be versioned in git, so move tracker.local_dir out of it"
    fi
  fi
  if get tracker.key; then
    checks=$((checks + 1))
    key=$val
    if [ -z "$key" ]; then
      problem "could not check duplicate work item ids: tracker.key is not set"
    else
      scan=${local_dir//\\//}
      case $scan in
        /* | [A-Za-z]:/*) ;;
        *) scan=$root_fs/$scan ;;
      esac
      ids=""
      for f in "$scan"/*; do
        [ -f "$f" ] || continue
        name=${f##*/}
        case $name in
          "$key"-*) ;;
          *) continue ;;
        esac
        rest=${name#"$key"-}
        num=${rest%%-*}
        case $num in
          '' | *[!0-9]*) continue ;;
        esac
        [ "$rest" != "$num" ] || continue
        ids="$ids$key-$num"$'\n'
      done
      sorted=$(printf '%s' "$ids" | sort)
      prev=""
      reported=""
      while IFS= read -r id; do
        if [ -n "$id" ] && [ "$id" = "$prev" ] && [ "$id" != "$reported" ]; then
          problem "duplicate work item id $id"
          reported=$id
        fi
        prev=$id
      done <<<"$sorted"
    fi
  fi
fi

drift=0
for pair in lib:hooks/lib git-hooks:hooks/git; do
  installed=$root/.rastro/${pair%%:*}
  shipped=$framework/${pair#*:}
  [ -d "$installed" ] || continue
  checks=$((checks + 1))
  if [ ! -d "$shipped" ]; then
    problem "could not check installed git hooks: $shipped not found"
  elif dir_differs "$shipped" "$installed"; then
    drift=1
  fi
done
[ "$drift" -eq 0 ] || info "installed git hooks differ from this rastro version. Re-run setup."

checks=$((checks + 1))
superpowers=0
for dir in "${HOME:-}"/.claude/plugins/cache/*/superpowers; do
  [ -d "$dir" ] && superpowers=1
done
[ ! -f "${HOME:-}/.claude/skills/subagent-driven-development/SKILL.md" ] || superpowers=1
if [ "$superpowers" -eq 1 ]; then
  info "superpowers found"
else
  info "superpowers not found; rastro uses its built-in fallbacks"
fi

checks=$((checks + 1))
command -v git >/dev/null 2>&1 || problem "could not check git: not found on PATH"

finish
