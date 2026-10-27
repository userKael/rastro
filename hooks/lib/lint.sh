rastro_lint_file() {
  local root=$1 rel=$2 template=$3 sq="'\\''" quoted cmd rest
  quoted="'${rel//\'/$sq}'"
  cmd=""
  rest=$template
  while [[ $rest == *'{file}'* ]]; do
    cmd+=${rest%%'{file}'*}$quoted
    rest=${rest#*'{file}'}
  done
  cmd+=$rest
  (cd "$root" && bash -c "$cmd" 2>&1)
}

rastro_lint_not_run() {
  local rc=$1 first=${2%%$'\n'*}
  if [ "$rc" -eq 127 ]; then
    printf 'verify.lint_file exited 127, command not found'
  else
    printf 'verify.lint_file exited %s, command not executable' "$rc"
  fi
  [ -z "$first" ] || printf ' (%s)' "$first"
  printf '\n'
}

rastro_lint_hint() {
  local rules
  rules=$(rastro_config_get architecture.rules)
  [ -z "$rules" ] ||
    printf 'rastro: a finding from an architecture rule has no auto-fix; the rules are described in %s\n' "$rules"
  return 0
}
