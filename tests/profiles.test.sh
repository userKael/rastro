tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
. "$tests_dir/../hooks/lib/frontmatter.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
ex="$root/profiles/examples"
arch="$ex/architecture-services"
rules="$arch/rules.md"
paths="$arch/golden-paths"
writing="$ex/writing.md"
stack="$root/profiles/stacks/node-nestjs-typescript"
STACK_FILES=(README verification testing security-questions)
STACK_SENTENCE_1='This file teaches how to verify in this stack.'
STACK_SENTENCE_2="It imposes no pattern: which patterns the project uses is the team's decision."
RULE_IDS=(module-public-api no-service-cycle pure-domain no-sensitive-log migration-via-tool)
GOLDEN_PATHS=(handler service migration external-client)

require_file() {
  [ -f "$1" ] && return 0
  _assert_fail "${1#"$root"/} does not exist"
  return 1
}

rule_block() {
  awk -v id="$1" '
    index($0, "- **[" id "]**") == 1 { on = 1; print; next }
    on && (/^- / || /^#/ || /^[[:space:]]*$/) { on = 0 }
    on
  ' "$rules"
}

check_rule_block() {
  local id=$1 block labels
  block=$(rule_block "$id")
  if [ -z "$block" ]; then
    _assert_fail "rules.md has no rule [$id]"
    return
  fi
  labels=$(printf '%s\n' "$block" | sed -n 's/^  \*\*\([A-Za-z ]*\):\*\*.*/\1/p' | tr '\n' '|')
  case $labels in
    'Symptom|Why here|Ask the author|' | 'Symptom|Why here|Ask the author|Known debt|') ;;
    *) _assert_fail "rules.md rule [$id] must carry Symptom, Why here, Ask the author, then an optional Known debt, each indented two spaces" "labels found: $labels" ;;
  esac
}

test_rules_file() {
  local id ids dup
  require_file "$rules" || return 0
  for id in "${RULE_IDS[@]}"; do
    check_rule_block "$id"
  done
  ids=$(sed -n 's/^- \*\*\[\([^]]*\)\]\*\*.*/\1/p' "$rules")
  for id in $ids; do
    case $id in
      *[!a-z0-9-]* | -* | *-) _assert_fail "rules.md rule id is not kebab-case: $id" ;;
    esac
    check_rule_block "$id"
  done
  dup=$(printf '%s\n' "$ids" | sort | uniq -d)
  [ -z "$dup" ] || _assert_fail "rules.md repeats a rule id" "$dup"
}

test_rules_layers() {
  local layer
  require_file "$rules" || return 0
  for layer in handler service repository domain external-client migration; do
    grep -qF -e "\`$layer\`" "$rules" || _assert_fail "rules.md does not name the layer \`$layer\`"
  done
}

test_rules_cycle_is_advisory() {
  local block
  require_file "$rules" || return 0
  block=$(rule_block no-service-cycle)
  case $block in
    *"cycle detector"*) ;;
    *) _assert_fail "rules.md [no-service-cycle] does not mention a cycle detector" ;;
  esac
  case $block in
    *advisory*) ;;
    *) _assert_fail "rules.md [no-service-cycle] does not say the rule is advisory without a detector" ;;
  esac
}

test_golden_paths() {
  local name file fences key value heading
  for name in "${GOLDEN_PATHS[@]}"; do
    file="$paths/$name.md"
    require_file "$file" || continue
    grep -qxF '## Checklist' "$file" || _assert_fail "$name.md lacks the heading: ## Checklist"
    grep -qE '^- \[ \] ' "$file" || _assert_fail "$name.md has no checklist item"
    grep -qxF '```ts' "$file" || _assert_fail "$name.md has no \`\`\`ts block"
    grep -qE '<stack: [^>]+>' "$file" || _assert_fail "$name.md has no <stack: ...> gap"
    grep -qE 'catalog|orders|inventory' "$file" || _assert_fail "$name.md cites none of catalog, orders, inventory"
    fences=$(grep -c '^```' "$file")
    [ $((fences % 2)) -eq 0 ] || _assert_fail "$name.md has an unclosed code fence"
    for key in id type version status verified_by instances origin; do
      rastro_frontmatter_get "$file" "$key" >/dev/null || _assert_fail "$name.md lacks the frontmatter key: $key"
    done
    value=$(rastro_frontmatter_get "$file" id)
    [ "$value" = "$name" ] || _assert_fail "$name.md has id '$value', not the file name"
    value=$(rastro_frontmatter_get "$file" type)
    [ "$value" = "$name" ] || _assert_fail "$name.md has type '$value', not the file name: the file is <type>.md"
    value=$(rastro_frontmatter_get "$file" status)
    [ "$value" = current ] || _assert_fail "$name.md has status '$value', not current"
    value=$(rastro_frontmatter_get "$file" verified_by)
    [ "$value" = review ] || _assert_fail "$name.md has verified_by '$value', not review"
    for heading in '## When to use' '## Decisions' '## Security' '## Verification' '## Known debt' '## History'; do
      grep -qxF "$heading" "$file" || _assert_fail "$name.md lacks the heading: $heading"
    done
    grep -qE '^- \*\*.*\*\* Why: .*Revisit if: ' "$file" || _assert_fail "$name.md has no decision with Why and Revisit if"
    grep -qF 'not one to adopt' "$file" || _assert_fail "$name.md does not say it is not one to adopt"
    ! grep -qF 'list this file in' "$file" || _assert_fail "$name.md still tells adopters to list it in the config"
  done
}

test_service_cycle_detector() {
  local file="$paths/service.md"
  require_file "$file" || return 0
  grep -qF 'cycle detector' "$file" || _assert_fail "service.md does not mention a cycle detector"
  grep -qiE 'without a cycle detector.*`no-service-cycle`.*advisory|`no-service-cycle`.*advisory.*without a cycle detector' "$file" ||
    _assert_fail "service.md does not say, in one sentence, that without a cycle detector no-service-cycle is advisory"
}

test_writing_profile() {
  local needle
  require_file "$writing" || return 0
  for needle in \
    'Measured vs hypothesis' \
    'Number instead of qualifier' \
    'Never cut: uncertainty, caveat, limit, anchor'; do
    grep -qF -e "$needle" "$writing" || _assert_fail "writing.md lacks required text" "text: $needle"
  done
}

test_writing_names_its_destination() {
  require_file "$writing" || return 0
  grep -qF -e '`.rastro/profiles/writing.md`' "$writing" ||
    _assert_fail "writing.md does not name its destination, .rastro/profiles/writing.md"
}

test_writing_has_no_origin_measurement() {
  local hits
  require_file "$writing" || return 0
  hits=$(grep -nE '[0-9]{1,3}[.,][0-9]{3}([^0-9]|$)' "$writing")
  [ -z "$hits" ] || _assert_fail "writing.md states a thousands-separated count" "$hits"
  hits=$(grep -nE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$writing")
  [ -z "$hits" ] || _assert_fail "writing.md states a calendar date; use a <YYYY-MM-DD> placeholder" "$hits"
  hits=$(grep -nEi '[0-9]+ +(parenthes[a-z]*|facts?|lines of [a-z]+|%)' "$writing")
  [ -z "$hits" ] || _assert_fail "writing.md states a count of things measured elsewhere" "$hits"
}

test_profiles_are_english_lf_and_neutral() {
  local f hits
  for f in "$rules" "$paths"/*.md "$writing"; do
    [ -f "$f" ] || continue
    hits=$(grep -nE '[ÀÁÂÃÇÉÊÍÓÔÕÚàáâãçéêíóôõú]' "$f")
    [ -z "$hits" ] || _assert_fail "${f#"$root"/} has non-English letters" "$hits"
    [ -z "$(tr -cd '\r' <"$f")" ] || _assert_fail "${f#"$root"/} has CRLF line endings"
    hits=$(grep -nwiE 'cards?|credit|refunds?' "$f")
    [ -z "$hits" ] || _assert_fail "${f#"$root"/} leaves the bookstore domain" "$hits"
  done
}

section_of() {
  awk -v want="## $2" '
    { sub(/\r$/, "") }
    $0 == want { on = 1; next }
    /^## / { on = 0 }
    on
  ' "$1"
}

test_boundary_golden_paths() {
  local name file sec ver label
  for name in handler external-client; do
    file="$paths/$name.md"
    require_file "$file" || continue
    sec=$(section_of "$file" Security)
    ver=$(section_of "$file" Verification)
    case $sec in *'OWASP API Security Top 10'*) ;; *) _assert_fail "$name.md: ## Security names no public reference" ;; esac
    printf '%s\n' "$sec" | grep -qE 'API[0-9]+:2023' || _assert_fail "$name.md: ## Security cites no item of the reference"
    printf '%s\n' "$sec" | grep -qF 'Verified by:' || _assert_fail "$name.md: ## Security says no Verified by"
    ! printf '%s\n' "$sec" | grep -qi 'none identified' || _assert_fail "$name.md: a boundary type says none identified"
    for label in '### Scenario:' '- Context:' '- Steps:' '- Success:' '- When blocked:'; do
      case $ver in *"$label"*) ;; *) _assert_fail "$name.md: ## Verification lacks $label" ;; esac
    done
  done
  grep -qF 'architecture.boundary_types' "$rules" || _assert_fail "rules.md does not name architecture.boundary_types"
}

test_stack_profile_files() {
  local name
  for name in "${STACK_FILES[@]}"; do
    require_file "$stack/$name.md"
  done
}

test_stack_profile_no_golden_paths() {
  local f hits
  [ ! -e "$stack/golden-paths" ] || _assert_fail "the stack profile has a golden-paths folder: a profile never ships patterns"
  for f in "$stack"/*.md; do
    [ -f "$f" ] || continue
    [ "$(head -n 1 "$f")" != '---' ] || _assert_fail "${f#"$root"/} starts with frontmatter: it looks like a golden path"
    hits=$(grep -nE '^(id|type|version|status|verified_by|instances|origin|superseded_by):' "$f")
    [ -z "$hits" ] || _assert_fail "${f#"$root"/} has golden path frontmatter keys" "$hits"
    hits=$(grep -nxE '## (Decisions|Checklist|Known debt|When to use)' "$f")
    [ -z "$hits" ] || _assert_fail "${f#"$root"/} has golden path headings" "$hits"
  done
}

test_stack_profile_teaches_verification_only() {
  local f
  for f in "$stack"/*.md; do
    [ -f "$f" ] || continue
    grep -qF -e "$STACK_SENTENCE_1" "$f" || _assert_fail "${f#"$root"/} does not say it teaches how to verify"
    grep -qF -e "$STACK_SENTENCE_2" "$f" || _assert_fail "${f#"$root"/} does not say it imposes no pattern"
  done
}

test_stack_profile_english_and_lf() {
  local f hits
  for f in "$stack"/*.md; do
    [ -f "$f" ] || continue
    hits=$(grep -nE '[ÀÁÂÃÇÉÊÍÓÔÕÚàáâãçéêíóôõú]' "$f")
    [ -z "$hits" ] || _assert_fail "${f#"$root"/} has non-English letters" "$hits"
    [ -z "$(tr -cd '\r' <"$f")" ] || _assert_fail "${f#"$root"/} has CRLF line endings"
  done
}

test_stack_profile_readme() {
  local needle
  require_file "$stack/README.md" || return 0
  for needle in 'verification.md' 'testing.md' 'security-questions.md' 'profiles/stacks/node-nestjs-typescript/' \
    'is read where it is' '`@nestjs/core`' '`nest-cli.json`'; do
    grep -qF -e "$needle" "$stack/README.md" || _assert_fail "stack profile README.md lacks required text" "text: $needle"
  done
}

test_stack_profile_verification_recipe() {
  local needle f="$stack/verification.md"
  require_file "$f" || return 0
  for needle in 'dependency-cruiser' 'eslint-plugin-boundaries' '.dependency-cruiser.js' 'depcruise' \
    'verified_by: automated:' '`verify.lint`' 'exits non-zero' 'Breaks' 'Fix:' \
    'plant' 'undo' 'a check that never fails' '## Not verified' \
    'npx dependency-cruiser --init' 'npx depcruise <source folder> --config .dependency-cruiser.js' \
    'must resolve on PATH' '`npm run lint && npx depcruise' 'may call the rule `boundaries/element-types`' \
    'follows from the documented exit code'; do
    grep -qF -e "$needle" "$f" || _assert_fail "stack profile verification.md lacks required text" "text: $needle"
  done
  ! grep -qF -e 'and creates `.dependency-cruiser.js`' "$f" || _assert_fail "stack profile verification.md states outside ## Not verified that --init creates .dependency-cruiser.js"
}

test_stack_profile_testing_scenarios() {
  local needle f="$stack/testing.md"
  require_file "$f" || return 0
  for needle in 'Test.createTestingModule' 'overrideProvider' 'createNestApplication' 'supertest' '.e2e-spec' \
    '`test:e2e`' '`verify.unit`' '`verify.integration`' '### Scenario:' '- Context:' '- Steps:' '- Success:' \
    '- When blocked:' 'real system' 'never production' 'placeholder'; do
    grep -qF -e "$needle" "$f" || _assert_fail "stack profile testing.md lacks required text" "text: $needle"
  done
}

test_stack_profile_security_questions() {
  local needle f="$stack/security-questions.md" questions
  require_file "$f" || return 0
  for needle in 'These are questions, not rules.' '`ValidationPipe`' 'whitelist' 'forbidNonWhitelisted' 'class-validator' \
    'APP_GUARD' '@nestjs/throttler' '@nestjs/config' 'timeout' '@nestjs/axios' 'retries' 'helmet' 'logging' \
    'rate limiting' 'headers' '## Not verified'; do
    grep -qF -e "$needle" "$f" || _assert_fail "stack profile security-questions.md lacks required text" "text: $needle"
  done
  questions=$(grep -c '?$' "$f")
  [ "$questions" -ge 14 ] || _assert_fail "security-questions.md has $questions questions, expected at least 14"
}

test_rules_file
test_rules_layers
test_rules_cycle_is_advisory
test_golden_paths
test_service_cycle_detector
test_writing_profile
test_writing_names_its_destination
test_writing_has_no_origin_measurement
test_profiles_are_english_lf_and_neutral
test_boundary_golden_paths
test_stack_profile_files
test_stack_profile_no_golden_paths
test_stack_profile_teaches_verification_only
test_stack_profile_english_and_lf
test_stack_profile_readme
test_stack_profile_verification_recipe
test_stack_profile_testing_scenarios
test_stack_profile_security_questions
finish
