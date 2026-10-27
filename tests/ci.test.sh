tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
github="$root/templates/ci/github.yml"
gitlab="$root/templates/ci/gitlab-ci.yml"

need() {
  local file=$1 needle=$2
  grep -qF -e "$needle" "$file" && return 0
  _assert_fail "${file#"$root"/} lacks required text" "text: $needle"
}

line_of() {
  grep -nF -e "$2" "$1" | head -n 1 | cut -d: -f1
}

assert_toolchain_before_verify() {
  local file=$1 marker verify
  marker=$(line_of "$file" '# toolchain:')
  verify=$(line_of "$file" '.rastro/git-hooks/run-verify')
  if [ -z "$marker" ]; then
    _assert_fail "${file#"$root"/} has no step marked # toolchain:"
  elif [ -n "$verify" ] && [ "$marker" -ge "$verify" ]; then
    _assert_fail "${file#"$root"/} puts # toolchain: after run-verify"
  fi
}

assert_no_tabs() {
  ! grep -q "$(printf '\t')" "$1" || _assert_fail "${1#"$root"/} contains a tab; YAML forbids tab indentation"
}

assert_called_scripts_ship() {
  local file=$1 name
  while IFS= read -r name; do
    [ -f "$root/hooks/git/$name" ] ||
      _assert_fail "${file#"$root"/} calls .rastro/git-hooks/$name, which hooks/git/ does not ship"
  done < <(grep -oE '\.rastro/git-hooks/[A-Za-z0-9_-]+' "$file" | sed 's#.*/##' | sort -u)
}

test_github() {
  local line
  [ -f "$github" ] || {
    _assert_fail "templates/ci/github.yml does not exist"
    return
  }
  need "$github" '.rastro/git-hooks/check-pr-title'
  need "$github" '.rastro/git-hooks/check-changed-paths'
  need "$github" '.rastro/git-hooks/run-verify'
  need "$github" 'bash .rastro/git-hooks/check-commits "$BASE_REF" "$HEAD_BRANCH"'
  need "$github" 'PR_TITLE:'
  need "$github" 'LC_ALL: C.UTF-8'
  need "$github" 'fetch-depth: 0'
  need "$github" 'origin/${{ github.base_ref }}'
  need "$github" 'pull_request:'
  need "$github" 'edited'
  if grep -nE '^[[:space:]]*(- )?run:.*\$\{\{[[:space:]]*github\.event' "$github" >/dev/null; then
    _assert_fail "github.yml interpolates github.event into a run: line"
  fi
  while IFS= read -r line; do
    case $line in
      *'${{'*)
        printf '%s\n' "$line" | grep -qE '^[[:space:]]+[A-Z][A-Z0-9_]*:[[:space:]]' ||
          _assert_fail "github.yml uses \${{ }} outside an env assignment" "line: $line"
        ;;
    esac
  done <"$github"
  assert_toolchain_before_verify "$github"
  assert_no_tabs "$github"
  assert_called_scripts_ship "$github"
}

assert_variables_in_job() {
  local file=$1 var owner
  ! grep -q '^variables:' "$file" ||
    _assert_fail "${file#"$root"/} sets variables globally; a merged file would change every other job"
  for var in 'LC_ALL:' 'GIT_DEPTH:'; do
    owner=$(awk -v var="$var" '
      /^[^ #]/ { top = $0 }
      $1 == var { print top; exit }
    ' "$file")
    [ "$owner" = 'rastro-checks:' ] ||
      _assert_fail "${file#"$root"/}: $var is not under the rastro-checks job" "found under: ${owner:-nothing}"
  done
}

test_gitlab() {
  [ -f "$gitlab" ] || {
    _assert_fail "templates/ci/gitlab-ci.yml does not exist"
    return
  }
  need "$gitlab" '.rastro/git-hooks/check-pr-title'
  need "$gitlab" '.rastro/git-hooks/check-changed-paths'
  need "$gitlab" '.rastro/git-hooks/run-verify'
  need "$gitlab" 'bash .rastro/git-hooks/check-commits "origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"'
  need "$gitlab" '"$CI_MERGE_REQUEST_TITLE"'
  need "$gitlab" '$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME'
  need "$gitlab" '$CI_MERGE_REQUEST_TARGET_BRANCH_NAME'
  need "$gitlab" 'origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME'
  need "$gitlab" 'rules:'
  need "$gitlab" '- if: $CI_PIPELINE_SOURCE == "merge_request_event"'
  need "$gitlab" 'LC_ALL: C.UTF-8'
  need "$gitlab" 'GIT_DEPTH: "0"'
  assert_variables_in_job "$gitlab"
  assert_toolchain_before_verify "$gitlab"
  assert_no_tabs "$gitlab"
  assert_called_scripts_ship "$gitlab"
}

test_github
test_gitlab
finish
