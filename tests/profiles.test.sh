tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
ex="$root/profiles/examples"
arch="$ex/architecture-services"
rules="$arch/rules.md"
paths="$arch/golden-paths"
writing="$ex/writing.md"
RULE_IDS=(module-public-api no-service-cycle pure-domain no-sensitive-log migration-via-tool)
GOLDEN_PATHS=(creating-an-endpoint creating-a-service creating-a-migration creating-an-external-client)

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
  for layer in handler service repository domain; do
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
  local name file fences
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
  done
}

test_service_cycle_detector() {
  local file="$paths/creating-a-service.md"
  require_file "$file" || return 0
  grep -qF 'cycle detector' "$file" || _assert_fail "creating-a-service.md does not mention a cycle detector"
  grep -qiE 'without a cycle detector.*`no-service-cycle`.*advisory|`no-service-cycle`.*advisory.*without a cycle detector' "$file" ||
    _assert_fail "creating-a-service.md does not say, in one sentence, that without a cycle detector no-service-cycle is advisory"
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

test_rules_file
test_rules_layers
test_rules_cycle_is_advisory
test_golden_paths
test_service_cycle_detector
test_writing_profile
test_writing_names_its_destination
test_writing_has_no_origin_measurement
test_profiles_are_english_lf_and_neutral
finish
