tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)

need_text() {
  local rel=$1 needle=$2
  [ -f "$root/$rel" ] || {
    _assert_fail "$rel does not exist"
    return
  }
  grep -qF -e "$needle" "$root/$rel" && return 0
  _assert_fail "$rel lacks required text" "text: $needle"
}

test_docs_adapters_render_collapsed_mark() {
  local rel
  for rel in adapters/docs/notion.md adapters/docs/repo.md; do
    need_text "$rel" '{collapsed}'
    need_text "$rel" 'Strip `{collapsed}` from the heading text.'
  done
}

test_optional_reading_phrase_is_one_phrase() {
  local rel
  for rel in adapters/docs/notion.md adapters/docs/repo.md adapters/code-host/none.md templates/design-doc.md; do
    need_text "$rel" ' (optional reading)'
  done
}

test_local_tracker_names_work_item_fields() {
  local key
  for key in id type parent created_on sources; do
    need_text adapters/tracker/local.md "\`$key\`"
    grep -q "^$key:" "$root/templates/work-item.md" ||
      _assert_fail "templates/work-item.md frontmatter lacks the key adapters/tracker/local.md names" "key: $key"
  done
  need_text adapters/tracker/local.md '## Acceptance criteria'
  need_text templates/work-item.md '## Acceptance criteria'
  need_text adapters/tracker/local.md 'git fetch'
  need_text adapters/tracker/local.md 'work/W-001-'
  if grep -qF -e 'local_dir>/' "$root/adapters/tracker/local.md"; then
    _assert_fail "adapters/tracker/local.md puts a slash after <tracker.local_dir>; the default value ends with one"
  fi
}

test_jira_item_url() {
  need_text adapters/tracker/jira.md '/browse/<id>'
  need_text adapters/tracker/jira.md 'built from the issue data `getJiraIssue` returns'
}

test_unverified_command_names_are_flagged() {
  local rel
  for rel in adapters/docs/notion.md adapters/code-host/github.md adapters/code-host/gitlab.md; do
    need_text "$rel" 'unverified against the live tool — verify before relying on it'
  done
}

test_adapters_name_no_plan_terms() {
  local file
  for file in "$root"/adapters/*.md "$root"/adapters/*/*.md; do
    [ -f "$file" ] || continue
    if grep -qE -e '(^|[^A-Za-z])V-[0-9]' "$file"; then
      _assert_fail "${file#"$root"/} mentions an internal plan term (V-n)"
    fi
  done
}

test_github_adapter_names_default_pr_template() {
  need_text adapters/code-host/github.md '.github/pull_request_template.md'
  need_text adapters/code-host/github.md '.github/PULL_REQUEST_TEMPLATE/'
  need_text adapters/code-host/github.md 'When `code_host.template` is set, it names the template instead.'
}

offset_of() {
  grep -boF -e "$2" "$root/$1" | head -n 1 | cut -d: -f1
}

push_before_open() {
  local rel=$1 push=$2 push_line open_line
  need_text "$rel" "$push"
  push_line=$(offset_of "$rel" "$push")
  open_line=$(offset_of "$rel" "pen a change request through the \`code_host\` port")
  if [ -z "$push_line" ] || [ -z "$open_line" ] || [ "$push_line" -gt "$open_line" ]; then
    _assert_fail "$rel does not push before it opens the change request" "push at byte: ${push_line:-none}" "open at byte: ${open_line:-none}"
  fi
}

test_callers_push_before_the_code_host_opens() {
  local rel
  push_before_open adapters/docs/repo.md 'git push -u origin docs/design-<slug>'
  need_text adapters/docs/repo.md 'authorizes this push'
  need_text adapters/docs/repo.md 'stop after the commit and do not push'
  push_before_open adapters/tracker/local.md 'git push -u origin chore/<id>-<slug>'
  need_text adapters/tracker/local.md 'authorizes this push'
  need_text adapters/tracker/local.md 'commit on the branch, do not push'
  for rel in adapters/code-host/github.md adapters/code-host/gitlab.md; do
    need_text "$rel" "Pushing is the caller's step"
  done
}

test_docs_adapters_render_collapsed_mark
test_optional_reading_phrase_is_one_phrase
test_callers_push_before_the_code_host_opens
test_local_tracker_names_work_item_fields
test_jira_item_url
test_unverified_command_names_are_flagged
test_adapters_name_no_plan_terms
test_github_adapter_names_default_pr_template
finish
