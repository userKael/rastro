#!/usr/bin/env bash
# Translation layer between the hook protocols of Codex and Cursor and the
# hook scripts in hooks/claude. The hook logic is not duplicated: this shim
# reshapes the agent's payload on the way in and the hook's answer on the way
# out.
#
# Usage: bash adapt.sh <codex|cursor> <doctor|guard-git|lint-edited-file|stop-check>
# The agent's payload arrives on stdin. Exit 64 for an unknown agent or hook.
#
# Source: the hook documentation of each agent, as consulted when this shim was
# written. Anything those pages did not confirm is marked NOT VERIFIED.
#
#   codex  PreToolUse   guard-git         payload passes through; deny is exit 2 + stderr
#   codex  PostToolUse  lint-edited-file  apply_patch: one file_path per file in the patch
#   codex  SessionStart doctor            plain text on stdout
#   codex  Stop         stop-check        passes through. NOT VERIFIED: that the
#                                         systemMessage JSON printed on exit 0 is accepted;
#                                         NOT VERIFIED: that the Codex Stop payload carries
#                                         stop_hook_active, and that exit 2 on Stop continues
#                                         the turn
#   cursor beforeShellExecution guard-git exit 2 becomes {"permission":"deny",...}, exit 0
#   cursor afterFileEdit        lint-edited-file passes through (stderr + exit 2).
#                                         NOT VERIFIED: that the agent sees this output,
#                                         because the documentation defines none for this event
#   cursor (all hooks)                    NOT VERIFIED: that Cursor payloads carry session_id;
#                                         without it, lint metrics are recorded under session -
#   cursor sessionStart         doctor    text wrapped as {"additional_context":...}
#   cursor stop                 stop-check exit 2 becomes {"followup_message":...};
#                                         informative output is dropped; loop_count > 0 is
#                                         passed on as stop_hook_active so it never loops
set -eu

abs_dir() { (cd "$1" && pwd); }

agent=${1:-}
hook=${2:-}
base=$(abs_dir "$(dirname "$0")")
hook_dir=$base/../claude
lib=${RASTRO_LIB:-$base/../lib}
. "$lib/json.sh"

case $agent in
  codex | cursor) ;;
  *)
    printf 'rastro: unknown agent %s (expected codex or cursor)\n' "$agent" >&2
    exit 64
    ;;
esac
case $hook in
  doctor | guard-git | lint-edited-file | stop-check) ;;
  *)
    printf 'rastro: unknown hook %s (expected doctor, guard-git, lint-edited-file or stop-check)\n' "$hook" >&2
    exit 64
    ;;
esac

input=$(cat)
cwd=$(rastro_json_string cwd <<<"$input")
if [ "$agent" = codex ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  cd "$cwd"
fi

out_file=$(mktemp)
err_file=$(mktemp)
trap 'rm -f "$out_file" "$err_file"' EXIT
out=""
err=""
rc=0

run_hook() {
  rc=0
  bash "$hook_dir/$1.sh" <<<"$2" >"$out_file" 2>"$err_file" || rc=$?
  out=$(<"$out_file")
  err=$(<"$err_file")
}

emit_and_exit() {
  [ -z "$out" ] || printf '%s\n' "$out"
  [ -z "$err" ] || printf '%s\n' "$err" >&2
  exit "$rc"
}

patch_files() {
  local line pending=""
  while IFS= read -r line; do
    line=${line%$'\r'}
    case $line in
      '*** Add File: '*)
        [ -z "$pending" ] || printf '%s\n' "$pending"
        pending=${line#'*** Add File: '}
        ;;
      '*** Update File: '*)
        [ -z "$pending" ] || printf '%s\n' "$pending"
        pending=${line#'*** Update File: '}
        ;;
      # A rename: the old path no longer exists, only the new one is linted.
      '*** Move to: '*) pending=${line#'*** Move to: '} ;;
    esac
  done <<<"$1"
  [ -z "$pending" ] || printf '%s\n' "$pending"
}

is_absolute() {
  case $1 in
    /* | [A-Za-z]:[/\\]* | \\\\*) return 0 ;;
  esac
  return 1
}

codex_lint() {
  local patch path files session session_json=""
  patch=$(rastro_json_string command <<<"$input")
  session=$(rastro_json_string session_id <<<"$input")
  [ -z "$session" ] || session_json='"session_id":"'"$(rastro_json_escape "$session")"'",'
  files=$(patch_files "$patch")
  if [ -z "$files" ]; then
    run_hook "$hook" "$input"
    emit_and_exit
  fi
  # Lint every file so each one gets a verdict, then report all failures.
  local failed_rc=0 failed_err=""
  while IFS= read -r path; do
    is_absolute "$path" || path=${cwd:-$(pwd)}/$path
    run_hook "$hook" '{'"$session_json"'"tool_input":{"file_path":"'"$(rastro_json_escape "$path")"'"}}'
    [ "$rc" -eq 0 ] && continue
    [ "$failed_rc" -eq 0 ] && failed_rc=$rc
    failed_err=${failed_err:+$failed_err$'\n'}$err
  done <<<"$files"
  [ "$failed_rc" -eq 0 ] && exit 0
  [ -z "$failed_err" ] || printf '%s\n' "$failed_err" >&2
  exit "$failed_rc"
}

cursor_stop_input() {
  local rest
  if grep -Eq '"loop_count"[[:space:]]*:[[:space:]]*[1-9]' <<<"$input"; then
    rest=${input#*\{}
    if [[ $rest =~ ^[[:space:]]*\} ]]; then
      printf '{"stop_hook_active":true%s' "$rest"
    else
      printf '{"stop_hook_active":true,%s' "$rest"
    fi
  else
    printf '%s' "$input"
  fi
}

cursor_deny() {
  printf '{"permission":"deny","user_message":"%s","agent_message":"%s"}\n' \
    "$(rastro_json_escape "${err%%$'\n'*}")" "$(rastro_json_escape "$err")"
}

case $agent:$hook in
  codex:lint-edited-file) codex_lint ;;
  codex:*)
    run_hook "$hook" "$input"
    emit_and_exit
    ;;
  cursor:guard-git)
    run_hook "$hook" "$input"
    if [ "$rc" -eq 2 ]; then
      cursor_deny
      exit 0
    fi
    emit_and_exit
    ;;
  cursor:lint-edited-file)
    run_hook "$hook" "$input"
    emit_and_exit
    ;;
  cursor:doctor)
    run_hook "$hook" "$input"
    [ -z "$out" ] || printf '{"additional_context":"%s"}\n' "$(rastro_json_escape "$out")"
    exit 0
    ;;
  cursor:stop-check)
    run_hook "$hook" "$(cursor_stop_input)"
    if [ "$rc" -eq 2 ]; then
      printf '{"followup_message":"%s"}\n' "$(rastro_json_escape "$err")"
    fi
    exit 0
    ;;
esac
