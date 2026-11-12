#!/usr/bin/env bash
# Installs rastro for Codex CLI or Cursor in one project.
#
# Usage: bash scripts/install-agent.sh [--link] <codex|cursor> <project dir>
#
# Writes <project>/.agents/skills/<skill>/ (a copy, or a symlink with --link)
# and the agent's hook file: <project>/.codex/hooks.json or
# <project>/.cursor/hooks.json. A hook file that already exists and differs
# from the generated one is never merged or overwritten: the block is printed
# and the script exits 3.
#
# Exit 0: installed or nothing to do. 2: unknown agent or missing project
# directory (nothing written). 3: the hook file exists and differs.
set -eu

usage() {
  printf 'usage: install-agent.sh [--link] <codex|cursor> <project dir>\n' >&2
}

link=0
if [ "${1:-}" = "--link" ]; then
  link=1
  shift
fi
agent=${1:-}
project=${2:-}

case $agent in
  codex | cursor) ;;
  *)
    printf 'rastro: unknown agent %s (expected codex or cursor)\n' "$agent" >&2
    usage
    exit 2
    ;;
esac
if [ -z "$project" ] || [ ! -d "$project" ]; then
  printf 'rastro: project directory not found: %s\n' "$project" >&2
  usage
  exit 2
fi
project=$(cd "$project" && pwd)

if [ -n "${RASTRO_ROOT:-}" ]; then
  R=$(cd "$RASTRO_ROOT" && pwd)
else
  R=$(cd "$(dirname "$0")/.." && pwd)
fi
if [ ! -d "$R/skills" ] || [ ! -f "$R/hooks/agents/adapt.sh" ]; then
  printf 'rastro: %s is not a rastro directory (no skills/ or hooks/agents/adapt.sh)\n' "$R" >&2
  exit 2
fi

# The path goes into a JSON string inside a shell command: escape backslashes
# and double quotes for the JSON layer.
json_path=${R//\\/\\\\}
json_path=${json_path//\"/\\\"}
shim="bash \\\"$json_path/hooks/agents/adapt.sh\\\""

codex_hooks() {
  cat <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"type": "command", "command": "$shim codex doctor", "timeout": 30}
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "$shim codex guard-git", "timeout": 10}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "apply_patch|Edit|Write",
        "hooks": [
          {"type": "command", "command": "$shim codex lint-edited-file", "timeout": 60}
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "$shim codex stop-check", "timeout": 120}
        ]
      }
    ]
  }
}
EOF
}

cursor_hooks() {
  cat <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [{"command": "$shim cursor doctor"}],
    "beforeShellExecution": [{"command": "$shim cursor guard-git"}],
    "afterFileEdit": [{"command": "$shim cursor lint-edited-file"}],
    "stop": [{"command": "$shim cursor stop-check"}]
  }
}
EOF
}

install_skills() {
  local dir name dest linked
  mkdir -p "$project/.agents/skills"
  for dir in "$R"/skills/*/; do
    name=$(basename "$dir")
    dest=$project/.agents/skills/$name
    rm -rf "$dest"
    linked=0
    if [ "$link" -eq 1 ]; then
      ln -s "${dir%/}" "$dest" 2>/dev/null || true
      if [ -L "$dest" ]; then
        linked=1
      else
        rm -rf "$dest"
        if [ -z "${link_warned:-}" ]; then
          printf 'rastro: could not create symlinks here, copying the skills instead\n'
          link_warned=1
        fi
      fi
    fi
    [ "$linked" -eq 1 ] || cp -R "${dir%/}" "$dest"
  done
}

install_skills

case $agent in
  codex)
    hooks_file=$project/.codex/hooks.json
    expected=$(codex_hooks)
    ;;
  cursor)
    hooks_file=$project/.cursor/hooks.json
    expected=$(cursor_hooks)
    ;;
esac

status=0
if [ ! -e "$hooks_file" ]; then
  mkdir -p "$(dirname "$hooks_file")"
  printf '%s\n' "$expected" >"$hooks_file"
  printf 'rastro: wrote %s\n' "$hooks_file"
elif [ "$(<"$hooks_file")" = "$expected" ]; then
  :
else
  status=3
  printf 'rastro: %s already exists and differs from the rastro hooks, so it was not touched.\n' "$hooks_file"
  printf 'The skills were installed (that copy is harmless to repeat). Add this block to the file by hand:\n\n'
  printf '%s\n\n' "$expected"
fi

printf '\nSkills are in %s/.agents/skills/.\n' "$project"
printf 'Point the agent at the rastro directory, in the shell that starts it:\n\n'
printf 'export RASTRO_ROOT=%s\n\n' "$R"
if [ "$agent" = codex ]; then
  printf 'Codex runs a project hook only when the .codex/ layer is trusted and the hook is reviewed: open /hooks in Codex and review them.\n'
fi
printf 'The hook file holds an absolute path to this machine, so do not commit it; run this script again in each clone.\n'
exit "$status"
