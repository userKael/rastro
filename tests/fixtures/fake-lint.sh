#!/usr/bin/env bash
if grep -q BAD "$1" 2>/dev/null; then
  printf '%s:1: BAD found\n' "$1"
  exit 1
fi
