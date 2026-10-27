tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
block="$root/templates/agents-md-block.md"
BEGIN='<!-- rastro:begin -->'
END='<!-- rastro:end -->'

section() {
  awk -v heading="## $1" '
    $0 == heading { on = 1; next }
    /^## / { on = 0 }
    on
  ' "$block"
}

need() {
  local scope=$1 needle=$2 body=$3
  case $body in
    *"$needle"*) return 0 ;;
  esac
  _assert_fail "$scope lacks required text" "text: $needle"
}

test_block_exists() {
  [ -f "$block" ] && return 0
  _assert_fail "templates/agents-md-block.md does not exist"
  finish
}

test_markers_wrap_the_block() {
  local first last
  first=$(grep -m1 -v '^[[:space:]]*$' "$block")
  last=$(grep -v '^[[:space:]]*$' "$block" | tail -n 1)
  assert_eq "$BEGIN" "$first" "block opens with the begin marker"
  assert_eq "$END" "$last" "block closes with the end marker"
  assert_eq 1 "$(grep -cxF "$BEGIN" "$block")" "one begin marker"
  assert_eq 1 "$(grep -cxF "$END" "$block")" "one end marker"
}

test_placeholders() {
  local names name
  names=$(grep -o '{{[a-z_]*}}' "$block" | sort -u)
  for name in '{{tracker_item}}' '{{state_table_first_row}}'; do
    case $'\n'"$names"$'\n' in
      *$'\n'"$name"$'\n'*) ;;
      *) _assert_fail "block never uses $name" ;;
    esac
  done
  while IFS= read -r name; do
    case $name in
      '{{tracker_item}}' | '{{state_table_first_row}}' | '') ;;
      *) _assert_fail "block uses a placeholder the setup skill does not fill" "placeholder: $name" ;;
    esac
  done <<<"$names"
}

test_plugin_root_sentence() {
  grep -qF 'In rastro skills, `${CLAUDE_PLUGIN_ROOT}` means the rastro installation directory. Claude Code substitutes it; other agents read it from the environment variable `RASTRO_ROOT`.' "$block" ||
    _assert_fail "block does not say what \${CLAUDE_PLUGIN_ROOT} means, or does not name RASTRO_ROOT"
  grep -qF 'RASTRO_ROOT' "$block" || _assert_fail "block never names RASTRO_ROOT"
  ! grep -qF '{{rastro_root}}' "$block" ||
    _assert_fail "block still carries {{rastro_root}}; an absolute per-machine path does not belong in a committed file"
}

test_rules_section_is_preserved_by_setup() {
  grep -qF '`## Non-negotiable rules` belongs to the team and is preserved when setup runs again.' "$block" ||
    _assert_fail "block does not say that setup preserves the team's rules section"
  ! grep -qF 'overwrites everything between' "$block" ||
    _assert_fail "block says setup overwrites everything between the markers, but the rules section sits between them"
}

test_doctrine_line() {
  grep -qF 'Doctrine is not overridable' "$block" ||
    _assert_fail "block does not state that doctrine is not overridable"
}

test_state_table() {
  local rows first_row_line first_item_line
  # The row that sends a missing item to `breakdown` is the {{state_table_first_row}} placeholder, filled by setup.
  rows=$(grep -E '^\|' "$block")
  need "state table" '| What you observe | Next step |' "$rows"
  need "state table" '## Reconciliation' "$rows"
  need "state table" '`implement`' "$rows"
  need "state table" '`deliver`' "$rows"
  need "state table" 'no PR' "$rows"
  need "state table" 'review.kind' "$rows"
  first_row_line=$(grep -nxF '{{state_table_first_row}}' "$block" | head -n 1 | cut -d: -f1)
  first_item_line=$(grep -n '^|.*{{tracker_item}}' "$block" | head -n 1 | cut -d: -f1)
  if [ -z "$first_row_line" ] || [ -z "$first_item_line" ]; then
    _assert_fail "{{state_table_first_row}} must sit alone on its line, above the rows that use {{tracker_item}}"
  elif [ "$first_row_line" -ge "$first_item_line" ]; then
    _assert_fail "{{state_table_first_row}} must come before the first row that uses {{tracker_item}}"
  fi
}

test_flow_section() {
  local body
  body=$(section "Where you are in the flow")
  need "flow section" '`design-doc`' "$body"
  need "flow section" 'Publishing is not approving' "$body"
  need "flow section" 'Every gate stops by default' "$body"
}

test_rules_section() {
  local body
  body=$(section "Non-negotiable rules")
  if [ -z "$body" ]; then
    _assert_fail "block has no ## Non-negotiable rules section"
    return
  fi
  need "rules section" '**[module-public-api]**' "$body"
  need "rules section" '**Symptom:**' "$body"
  need "rules section" '**Why here:**' "$body"
  need "rules section" '**Ask the author:**' "$body"
  need "rules section" '**Known debt:**' "$body"
  need "rules section" 'Replace' "$body"
  need "rules section" 'by ID' "$body"
}

test_delivery_conventions() {
  local body
  body=$(section "Delivery conventions")
  if [ -z "$body" ]; then
    _assert_fail "block has no ## Delivery conventions section"
    return
  fi
  need "delivery conventions" '### Language' "$body"
  need "delivery conventions" '### Branch name' "$body"
  need "delivery conventions" '### Commit message' "$body"
  need "delivery conventions" '### Scope hygiene' "$body"
  need "delivery conventions" '### Comments in code' "$body"
  need "delivery conventions" 'git add -A' "$body"
  need "delivery conventions" 'git commit -a' "$body"
  need "delivery conventions" '--no-verify' "$body"
  need "delivery conventions" 'Co-Authored-By' "$body"
  need "delivery conventions" 'git diff --cached --name-only' "$body"
  need "delivery conventions" 'never translated' "$body"
  need "delivery conventions" 'no comment' "$body"
  need "delivery conventions" 'ticket' "$body"
}

test_source_precedence_order() {
  local body phrase prev=0 line
  body=$(section "Source precedence")
  if [ -z "$body" ]; then
    _assert_fail "block has no ## Source precedence section"
    return
  fi
  for phrase in 'Code and green tests' '`AGENTS.md`' 'ADRs' 'Golden paths and patterns' 'Current plan' 'Design doc'; do
    line=$(printf '%s\n' "$body" | grep -nF -e "$phrase" | head -n 1 | cut -d: -f1)
    if [ -z "$line" ]; then
      _assert_fail "source precedence lacks an entry" "entry: $phrase"
    elif [ "$line" -le "$prev" ]; then
      _assert_fail "source precedence is out of order" "entry: $phrase"
    else
      prev=$line
    fi
  done
  need "source precedence" 'never of how the code is today' "$body"
}

test_gate_anatomy() {
  local body
  body=$(section "Gate anatomy")
  if [ -z "$body" ]; then
    _assert_fail "block has no ## Gate anatomy section"
    return
  fi
  need "gate anatomy" 'The title is the question' "$body"
  need "gate anatomy" 'State' "$body"
  need "gate anatomy" 'Decision' "$body"
  need "gate anatomy" 'Fork' "$body"
  need "gate anatomy" 'Deliberation' "$body"
  need "gate anatomy" 'Never align by whitespace' "$body"
  need "gate anatomy" 'Never exceed the cell budget' "$body"
  need "gate anatomy" 'Never print the same question twice' "$body"
  need "gate anatomy" 'A subagent never asks the human.' "$body"
  need "gate anatomy" 'If there is no structured question tool, end the turn with the question.' "$body"
}

test_failing_test_verdict() {
  grep -qF 'VERDICT —' "$block" || _assert_fail "block lacks the verdict format"
  grep -qF 'Wrong artifact: test | code | design doc' "$block" || _assert_fail "block lacks the wrong-artifact line"
}

test_artifacts_not_versioned() {
  grep -qF 'Agent artifacts are not versioned' "$block" || _assert_fail "block lacks the unversioned-artifacts convention"
}

test_no_percentages() {
  local hits
  hits=$(grep -nE '[0-9]+([.,][0-9]+)?[[:space:]]*%' "$block")
  [ -z "$hits" ] || _assert_fail "block states a percentage" "$hits"
}

test_block_exists
test_markers_wrap_the_block
test_placeholders
test_plugin_root_sentence
test_rules_section_is_preserved_by_setup
test_doctrine_line
test_state_table
test_flow_section
test_rules_section
test_delivery_conventions
test_source_precedence_order
test_gate_anatomy
test_failing_test_verdict
test_artifacts_not_versioned
test_no_percentages
finish
