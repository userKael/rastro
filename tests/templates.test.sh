tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
tpl="$root/templates"

require_file() {
  [ -f "$tpl/$1" ] && return 0
  _assert_fail "templates/$1 does not exist"
  return 1
}

require_all() {
  local file=$1 needle
  shift
  require_file "$file" || return 0
  for needle in "$@"; do
    grep -qF -e "$needle" "$tpl/$file" ||
      _assert_fail "templates/$file lacks required text" "text: $needle"
  done
}

forbid_all() {
  local file=$1 needle
  shift
  require_file "$file" || return 0
  for needle in "$@"; do
    ! grep -qF -e "$needle" "$tpl/$file" ||
      _assert_fail "templates/$file contains forbidden text" "text: $needle"
  done
}

section() {
  awk -v heading="## $2" '
    $0 == heading { on = 1; next }
    /^## / { on = 0 }
    on
  ' "$tpl/$1"
}

test_markers_file() {
  require_all MARKERS.md \
    '`## Reconciliation`' '`reconciliation.md`' '`NOT VERIFIED`' '`[HUMAN]`' '`[no PR]`' \
    '`## Context`' '`Decided (<YYYY-MM-DD>):`' '`D-n`' '`DT-nn`' \
    '| `new` |' '| `changes` |' '| `exists` |' '| `## Acceptance criteria` |'
}

test_reconciliation() {
  require_all reconciliation.md \
    '# Reconciliation — <id>' 'Intent:' 'Reconciled on:' 'Declared scope:' \
    '## Divergences: intent vs code' '## Already delivered' '## Not sized' \
    '## Code behavior the intent does not mention' '## Decisions to close with the team' \
    '**Recommendation:**' 'executor: human' 'Rollback:' 'Verification after running:' \
    'Decided (' '`git log --oneline <sha>..<project.base_branch> -- <scope>`'
  forbid_all reconciliation.md '<sha>..HEAD'
}

test_reconciliation_has_five_sections() {
  local count
  require_file reconciliation.md || return 0
  count=$(awk '/^```/ { fenced = !fenced; next } !fenced && /^## / { n++ } END { print n + 0 }' "$tpl/reconciliation.md")
  assert_eq 5 "$count" "reconciliation.md has exactly five level-2 sections outside code fences"
}

test_reconciliation_not_sized_has_evidence() {
  local header='| Work needed | Why the intent did not foresee it | Evidence (file:line) | Cost in tasks and PRs |'
  require_file reconciliation.md || return 0
  section reconciliation.md "Not sized" | grep -qxF -e "$header" ||
    _assert_fail "templates/reconciliation.md: the Not sized table has no Evidence (file:line) column" "header: $header"
  grep -qxF -e "$header" "$tpl/work-item.md" ||
    _assert_fail "templates/work-item.md: the Not sized table does not repeat the reconciliation columns" "header: $header"
}

test_work_item() {
  require_all work-item.md \
    'id:' 'type:' 'parent:' 'created_on:' 'sources:' \
    '## Context' '## Observer and assertion' '## Scope' '## Acceptance criteria' '## Sources' '## Reconciliation' \
    'type: <story | task | bug | subtask>' 'id: W-007' 'id: W-008'
  forbid_all work-item.md 'status:'
}

test_work_item_carries_human_execution() {
  local verdict
  require_file work-item.md || return 0
  require_all work-item.md '| D-2 | <what has to happen, in one line> | human |' \
    'exempt from the 200-character budget' 'Artifact, verbatim from `reconciliation.md`:'
  verdict=$(section work-item.md Reconciliation | awk '
    $0 == "#### D-2 — human execution" { block = 1; next }
    block && /^#/ { block = 0 }
    block && /^\| (Executor|Environments|When|Rollback|Verification) \|/ { split($0, c, "|"); gsub(/ /, "", c[2]); seen[c[2]] = 1; last = NR }
    block && /^```[a-z]+$/ && last && !fence { fence = NR }
    END {
      n = 0
      for (k in seen) n++
      if (n != 5) print "fields " n
      else if (!fence || fence < last) print "no fence after the table"
      else print "ok"
    }
  ')
  assert_eq ok "$verdict" "templates/work-item.md: each human D-n carries executor, environments, when, rollback, verification, then the artifact in a fence"
}

test_design_doc() {
  require_all design-doc.md \
    '### DT-01 —' '**Decided:**' '**Consequence:**' '**Verifiable in:**' 'Why (b) lost' \
    '## Domain invariants and transaction boundaries' 'stateDiagram-v2' '## Code flows' \
    '## Candidate slicing' '> **Draft.**' '## Open questions'
}

test_design_doc_reading_counts() {
  local counts
  require_file design-doc.md || return 0
  counts=$(awk '
    /^```/ { fenced = !fenced; next }
    fenced || !/^## / { next }
    /\{collapsed\}[ \t]*$/ { optional++; next }
    { required++ }
    END { print required + 0, optional + 0 }
  ' "$tpl/design-doc.md")
  assert_eq "9 7" "$counts" "templates/design-doc.md: required and optional level-2 sections"
  require_all design-doc.md 'Nine sections are required reading' 'Seven are optional reading'
  grep -qF -e 'the nine required-reading sections' "$root/skills/design-doc/SKILL.md" ||
    _assert_fail "skills/design-doc/SKILL.md does not count nine required-reading sections"
}

test_plan() {
  require_all plan.md \
    '**Goal:**' '**Spec:**' '## Global Constraints' '## Expected test scenarios' \
    '**Given**' '**When**' '**Then**' '[HUMAN]' '**Executor:** human' '**Blocks:** Task' \
    '**Rollback:**'
}

test_config_names_the_env_example_trap() {
  require_all config.yml '.env* also refuses .env.example.' 'Negation is not supported'
}

test_pr_description() {
  require_all pr-description.md \
    '## Context' '## What this PR delivers' '## Closed decisions' '## Risks and rollback' \
    '## Verification' '## Next PRs' '## Divergences from the design doc' '## Recorded debt' \
    '## Agent rulings' '## Pending human execution' '<details>'
}

test_calibration() {
  require_all CALIBRATION.md \
    'How many stories have no subtask?' \
    'What is the cancellation rate among those stories?' \
    'What subtask summary format does the team already use?' \
    'measure' 'not measured'
}

test_stack_detection() {
  local manifest key body
  require_file stack-detection.md || return 0
  for manifest in package.json pyproject.toml go.mod; do
    body=$(section stack-detection.md "$manifest")
    if [ -z "$body" ]; then
      _assert_fail "templates/stack-detection.md has no section for $manifest"
      continue
    fi
    for key in verify.lint verify.typecheck verify.unit verify.lint_file verify.source_globs; do
      case $body in
        *"$key"*) ;;
        *) _assert_fail "templates/stack-detection.md section $manifest proposes no $key" ;;
      esac
    done
  done
}

test_no_origin_calibration_numbers() {
  local f hits
  for f in "$tpl"/*.md "$tpl"/ci/*; do
    [ -f "$f" ] || continue
    hits=$(grep -nE '[0-9]+([.,][0-9]+)?[[:space:]]*%' "$f")
    [ -z "$hits" ] || _assert_fail "$f states a percentage; calibration figures belong to the adopter" "$hits"
  done
}

test_markers_file
test_reconciliation
test_reconciliation_has_five_sections
test_reconciliation_not_sized_has_evidence
test_work_item
test_work_item_carries_human_execution
test_design_doc
test_design_doc_reading_counts
test_plan
test_config_names_the_env_example_trap
test_pr_description
test_calibration
test_stack_detection
test_no_origin_calibration_numbers
finish
