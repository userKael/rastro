tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
readme="$root/README.md"
SECTIONS=(
  'What rastro is'
  'The flow'
  'What is not configurable'
  'Install'
  'Configure'
  'Working without an issue tracker or a docs tool'
  'Bring your own adapter'
  'Hooks in three layers'
  'Agent support'
  'License'
)

section_body() {
  awk -v want="## $1" '
    { sub(/\r$/, "") }
    $0 == want { on = 1; next }
    /^## / { on = 0 }
    on
  ' "$readme"
}

need_in_section() {
  local section=$1 needle=$2 body
  body=$(section_body "$section")
  case $body in
    *"$needle"*) return 0 ;;
  esac
  _assert_fail "README.md section '## $section' lacks required text" "text: $needle"
}

test_readme_has_every_section() {
  local name
  [ -f "$readme" ] || {
    _assert_fail "README.md does not exist"
    return
  }
  for name in "${SECTIONS[@]}"; do
    grep -qxF -e "## $name" "$readme" || _assert_fail "README.md lacks the section heading" "heading: ## $name"
  done
}

test_agent_support_is_honest() {
  [ -f "$readme" ] || return 0
  need_in_section 'Agent support' 'Claude Code'
  need_in_section 'Agent support' 'Other agents that read AGENTS.md and SKILL.md: compatible by design, not tested.'
  need_in_section 'Agent support' 'RASTRO_ROOT'
  local line
  while IFS= read -r line; do
    case $line in
      *'not tested'*) ;;
      *) _assert_fail "README.md names Codex without saying it is not tested" "line: $line" ;;
    esac
  done < <(grep -F -e 'Codex' "$readme")
}

test_install_and_configure_name_the_real_commands() {
  [ -f "$readme" ] || return 0
  need_in_section 'Install' 'claude plugin marketplace add userKael/rastro'
  need_in_section 'Install' 'claude plugin install rastro@rastro'
  need_in_section 'Install' 'claude --plugin-dir'
  need_in_section 'Install' '/rastro:'
  need_in_section 'Configure' '/rastro:setup'
  need_in_section 'Configure' '.rastro/config.yml'
  need_in_section 'Configure' '.rastro/profiles/'
  need_in_section 'Configure' '.rastro/profiles/writing.md'
}

test_modes_without_a_tool_are_tabled() {
  [ -f "$readme" ] || return 0
  local needle
  for needle in 'tracker: local' 'tracker: none' 'docs: repo' 'code_host: none' 'domain_state: none' 'superpowers' 'NOT VERIFIED' 'docs/design-<slug>'; do
    need_in_section 'Working without an issue tracker or a docs tool' "$needle"
  done
  section_body 'Working without an issue tracker or a docs tool' | grep -q '^|' ||
    _assert_fail "README.md: the section on working without a tool has no table"
}

test_doctrine_is_listed_and_not_configurable() {
  [ -f "$readme" ] || return 0
  local needle
  for needle in 'file:line' 'D-n' 'DT-nn' 'verdict' 'state table' 'reconcil' 'human executor' 'never disables'; do
    need_in_section 'What is not configurable' "$needle"
  done
}

test_golden_paths_are_documented() {
  [ -f "$readme" ] || return 0
  need_in_section 'What is not configurable' 'golden-path checkpoint'
  need_in_section 'Configure' 'docs/golden-paths/'
  need_in_section 'Configure' 'the doctor reports the list form'
}

test_hooks_section_states_what_ci_checks() {
  [ -f "$readme" ] || return 0
  need_in_section 'Hooks in three layers' 'squash'
  need_in_section 'Hooks in three layers' 'commit-msg'
  need_in_section 'Hooks in three layers' 'not by CI'
  need_in_section 'Hooks in three layers' 'bash and git'
  need_in_section 'Hooks in three layers' 'guard-git.sh'
  need_in_section 'Hooks in three layers' '`check-commits` validates every commit message of the branch in CI'
  need_in_section 'Hooks in three layers' 'Layer 3 starts once `setup` has written `.rastro/config.yml`.'
  need_in_section 'Hooks in three layers' 'any `core.hooksPath` other than `.rastro/git-hooks`'
  if section_body 'Hooks in three layers' | grep -qF -e 'A commit made in a clone without the hook is not checked.'; then
    _assert_fail "README.md still says CI checks no commit message"
  fi
}

test_configure_states_defaults_and_env_example() {
  [ -f "$readme" ] || return 0
  need_in_section 'Configure' 'A key left out takes that default'
  need_in_section 'Configure' 'An explicit empty list, `[]`, stays empty.'
  need_in_section 'Configure' 'The default pattern `.env*` also refuses `.env.example`.'
  need_in_section 'Configure' 'Negation is not supported'
}

test_adapter_section_points_to_the_contract() {
  [ -f "$readme" ] || return 0
  need_in_section 'Bring your own adapter' 'adapters/CONTRACT.md'
  need_in_section 'Bring your own adapter' '.rastro/adapters/'
  need_in_section 'Bring your own adapter' 'not verified against live tools'
}

test_readme_describes_stack_profiles() {
  local needle
  [ -f "$readme" ] || return 0
  for needle in 'profiles/stacks/node-nestjs-typescript/' 'A stack profile teaches how to verify'; do
    grep -qF -e "$needle" "$readme" || _assert_fail "README.md lacks required text" "text: $needle"
  done
}

test_readme_has_no_internal_plan_terms() {
  [ -f "$readme" ] || return 0
  if grep -qE -e '(^|[^A-Za-z])V-[0-9]|Plan [0-9]|Task [0-9]' "$readme"; then
    _assert_fail "README.md mentions an internal plan term (V-n, Plan n or Task n)"
  fi
}

test_marketplace_manifest_is_exact() {
  local file="$root/.claude-plugin/marketplace.json" got want
  want='{"name":"rastro","owner":{"name":"userKael"},"plugins":[{"name":"rastro","source":"."}]}'
  if [ ! -f "$file" ]; then
    _assert_fail ".claude-plugin/marketplace.json does not exist"
    return
  fi
  got=$(tr -d ' \t\r\n' <"$file")
  assert_eq "$want" "$got" ".claude-plugin/marketplace.json differs from the required manifest"
}

test_execution_mode_is_documented() {
  [ -f "$readme" ] || return 0
  need_in_section 'The flow' 'stop at every gate, the default, or continuous'
  need_in_section 'The flow' 'ask how their gates behave'
  need_in_section 'Working without an issue tracker or a docs tool' 'in a continuous run, `deliver` opens the PR'
  need_in_section 'What is not configurable' 'chosen at the start of each run'
  need_in_section 'What is not configurable' 'never a config key'
}

test_golden_path_checks_are_documented() {
  [ -f "$readme" ] || return 0
  need_in_section 'Configure' 'exits non-zero'
  need_in_section 'Configure' 'make `verify.lint` run it'
  need_in_section 'Configure' 'and never runs it'
  need_in_section 'Configure' 'two or more instances'
  need_in_section 'Configure' 'architecture.boundary_types'
  need_in_section 'Configure' 'OWASP API Security Top 10'
  need_in_section 'Configure' 'without mocks'
  need_in_section 'Configure' 'asks for the threats and `implement` writes both'
  need_in_section 'Configure' 'is not in `architecture.layers`'
}

test_init_is_documented() {
  [ -f "$readme" ] || return 0
  need_in_section 'What rastro is' 'rastro is nine skills'
  need_in_section 'What rastro is' '| `init` |'
  need_in_section 'What rastro is' 'the nine skills'
  need_in_section 'The flow' '| No source code yet, and no item for the walking skeleton | `init` |'
  need_in_section 'The flow' 'empty by construction'
  need_in_section 'Install' '/rastro:init'
  need_in_section 'Configure' 'the CI workflow files'
  need_in_section 'Configure' '### Starting from an empty directory'
  need_in_section 'Configure' 'would be fabricated'
  need_in_section 'Configure' '`init` writes no golden path'
  need_in_section 'Working without an issue tracker or a docs tool' 'The state table has no item rows.'
  ! grep -qiF 'eight skills' "$readme" || _assert_fail "README.md still counts eight skills"
}

test_readme_describes_drift_audit() {
  local needle
  [ -f "$readme" ] || return 0
  for needle in '### Drift audit' '.rastro/git-hooks/audit-drift' 'audit.under_review_days' 'audit-github.yml' '<workspace>/audit/<YYYY-MM-DD>.md' 'before/after probe' '| `audit` | the golden paths and the code |' 'a `review` row' 'cumulative since the log began'; do
    grep -qF -e "$needle" "$readme" || _assert_fail "README.md lacks required text" "text: $needle"
  done
}

test_readme_adapter_table_lists_new_adapters() {
  [ -f "$readme" ] || return 0
  section_body 'Bring your own adapter' | grep -qF '`jira`, `github`, `github-projects`' ||
    _assert_fail "README.md adapter table lacks github-projects on the tracker row"
  section_body 'Bring your own adapter' | grep -qF '`notion`, `repo`, `claude-docs`' ||
    _assert_fail "README.md adapter table lacks claude on the docs row"
}

test_readme_has_every_section
test_agent_support_is_honest
test_install_and_configure_name_the_real_commands
test_modes_without_a_tool_are_tabled
test_doctrine_is_listed_and_not_configurable
test_golden_paths_are_documented
test_hooks_section_states_what_ci_checks
test_configure_states_defaults_and_env_example
test_adapter_section_points_to_the_contract
test_readme_has_no_internal_plan_terms
test_marketplace_manifest_is_exact
test_execution_mode_is_documented
test_golden_path_checks_are_documented
test_init_is_documented
test_readme_describes_stack_profiles
test_readme_describes_drift_audit
test_readme_adapter_table_lists_new_adapters
finish
