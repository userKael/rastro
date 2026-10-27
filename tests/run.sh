#!/usr/bin/env bash
root=$(cd "$(dirname "$0")" && pwd)
files=0
failed=0
for f in "$root"/*.test.sh; do
  [ -e "$f" ] || continue
  files=$((files + 1))
  if ! bash "$f"; then
    failed=$((failed + 1))
  fi
done
echo "$files files, $failed failed"
[ "$failed" -eq 0 ] || exit 1
