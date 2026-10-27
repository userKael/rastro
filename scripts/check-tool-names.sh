#!/usr/bin/env bash
root=$(cd "$(dirname "$0")/.." && pwd)
dir="${1:-$root/skills}"

if [ ! -d "$dir" ]; then
  echo "check-tool-names: directory not found: $dir" >&2
  exit 2
fi

terms='jira atlassian notion confluence github gitlab bitbucket postgres postgresql mysql npm eslint jest tsc typeorm nestjs prisma'
pattern="($(printf '%s' "$terms" | tr ' ' '|'))"

hits=$(grep -rIniowE -e "$pattern" "$dir" | sed -E 's/^(.*):([0-9]+):([^:]*)$/\1:\2: \L\3/')
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  exit 1
fi
