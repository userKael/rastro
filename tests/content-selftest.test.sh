. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
FIXTURE="$RASTRO_TESTS_DIR/fixtures/content/valid"

fresh() {
  local d
  d=$(mktemp -d "$RASTRO_TEST_TMP/content.XXXXXX") || return 1
  cp -R "$FIXTURE/." "$d/"
  printf '%s\n' "$d"
}
edit() {
  sed -i "$3" "$1/$2"
}
append() {
  printf '%s\n' "$3" >>"$1/$2"
}
run_suite() {
  case ${SUITE_MODE:-explicit} in
    core) run_cmd env RASTRO_REQUIRE_CORE=1 bash "$RASTRO_TESTS_DIR/$1.test.sh" "$2" ;;
    default) run_cmd bash "$2/tests/$1.test.sh" ;;
    *) run_cmd bash "$RASTRO_TESTS_DIR/$1.test.sh" "$2" ;;
  esac
}
with_mode() {
  local SUITE_MODE=$1
  shift
  "$@"
}
plugin_copy() {
  local d
  d=$(fresh) || return 1
  mkdir -p "$d/hooks" "$d/scripts"
  cp "$RASTRO_TESTS_DIR/skills.test.sh" "$RASTRO_TESTS_DIR/adapters.test.sh" "$RASTRO_TESTS_DIR/markers.test.sh" "$d/tests/"
  cp -R "$RASTRO_TESTS_DIR/lib" "$d/tests/lib"
  cp -R "$RASTRO_TESTS_DIR/../hooks/lib" "$d/hooks/lib"
  cp "$RASTRO_TESTS_DIR/../scripts/check-tool-names.sh" "$d/scripts/"
  printf '%s\n' "$d"
}
add_core_skills() {
  local s
  for s in setup design-doc breakdown reconcile domain-context implement deliver; do
    mkdir -p "$1/skills/$s"
    sed "s/^name: alpha/name: $s/" "$1/skills/alpha/SKILL.md" >"$1/skills/$s/SKILL.md"
    cp "$1/tests/anchors/alpha.txt" "$1/tests/anchors/$s.txt"
  done
}
write_core_markers() {
  cat >"$1/templates/MARKERS.md" <<'MARKERS'
# Markers

| Marker | Written by |
|---|---|
| `## Reconciliation` | breakdown |
| `reconciliation.md` | reconcile |
| `NOT VERIFIED` | domain-context |
| `[HUMAN]` | implement |
| `[no PR]` | breakdown |
| `## Context` | domain-context |
| `Decided (<YYYY-MM-DD>):` | gate |
| `D-n`, `DT-nn` | none |
MARKERS
  cat >"$1/templates/core-markers.md" <<'BODY'
## Reconciliation
reconciliation.md NOT VERIFIED [HUMAN] [no PR]
## Context
Decided (<YYYY-MM-DD>): D-n DT-nn
BODY
}
expect_pass() {
  run_suite "$2" "$3"
  assert_status 0 "$1: passes"
  assert_eq "PASS $2.test.sh" "$OUT" "$1: reports PASS"
}
expect_fail() {
  local name=$1 suite=$2 root=$3 needle
  shift 3
  run_suite "$suite" "$root"
  assert_status 1 "$name: fails"
  for needle in "$@"; do
    assert_contains "$ERR" "$needle" "$name: reports '$needle'"
  done
}

test_fixture_is_valid() {
  expect_pass "valid fixture" skills "$FIXTURE"
  expect_pass "valid fixture" adapters "$FIXTURE"
  expect_pass "valid fixture" markers "$FIXTURE"
}

test_skills_missing_file() {
  local r
  r=$(fresh)
  rm "$r/skills/alpha/SKILL.md"
  expect_fail "missing SKILL.md" skills "$r" "skills/alpha/SKILL.md does not exist"
}
test_skills_frontmatter_name() {
  local r
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/^name: alpha/name: beta/'
  expect_fail "wrong name" skills "$r" "frontmatter name is not 'alpha'" "name: beta"
}
test_skills_frontmatter_missing() {
  local r
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md '1d'
  expect_fail "no opening ---" skills "$r" "frontmatter missing or not closed"
  r=$(fresh)
  awk 'seen == 1 && $0 == "---" { seen = 2; next } $0 == "---" && !seen { seen = 1 } { print }' "$r/skills/alpha/SKILL.md" >"$r/x" && mv "$r/x" "$r/skills/alpha/SKILL.md"
  expect_fail "no closing ---" skills "$r" "frontmatter missing or not closed"
}
test_skills_description() {
  local r long
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/^description:.*/description:/'
  expect_fail "empty description" skills "$r" "description is empty"
  long=$(printf '%1025s' '' | tr ' ' x)
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md "s/^description:.*/description: $long/"
  expect_fail "1025 characters" skills "$r" "has 1025 characters, limit is 1024"
  long=$(printf '%1024s' '' | tr ' ' x)
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md "s/^description:.*/description: $long/"
  expect_pass "1024 characters" skills "$r"
  long=$(printf 'ã%.0s' $(seq 1 1000))
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md "s/^description:.*/description: $long/"
  expect_pass "1000 two-byte characters count as 1000" skills "$r"
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md $'s/^description:.*/description: >\\n  first part\\n  second part/'
  expect_pass "folded multi-line description" skills "$r"
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md $'s/^description:.*/description: >\\n/'
  expect_fail "folded description with no text" skills "$r" "description is empty"
}
test_skills_headings() {
  local r
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/^## Precedence$/## Order/'
  expect_fail "missing ## Precedence" skills "$r" "heading missing" "## Precedence"
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/^## What this skill does NOT do$/## What this skill does not do/'
  expect_fail "heading case differs" skills "$r" "## What this skill does NOT do"
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/^## Requirements$/### Requirements/'
  expect_fail "wrong heading level" skills "$r" "## Requirements"
}
test_skills_doctrine() {
  local r
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md '/^Doctrine is not overridable/d'
  expect_fail "doctrine line removed" skills "$r" "doctrine line missing"
  r=$(fresh)
  edit "$r" skills/alpha/SKILL.md 's/not by a profile/not by a plugin/'
  expect_fail "doctrine line altered" skills "$r" "doctrine line missing"
}
test_skills_anchors() {
  local r
  r=$(fresh)
  append "$r" tests/anchors/alpha.txt "an anchor the skill lacks"
  expect_fail "missing anchor" skills "$r" "anchor missing" "anchor: an anchor the skill lacks"
  r=$(fresh)
  printf 'Read ${CLAUDE_PLUGIN_ROOT}/templates/note.md before starting.\r\n\r\nverify.lint\r\n' >"$r/tests/anchors/alpha.txt"
  expect_pass "CRLF anchors file" skills "$r"
  r=$(fresh)
  append "$r" tests/anchors/alpha.txt "-leading dash is literal"
  expect_fail "anchor starting with a dash" skills "$r" "anchor: -leading dash is literal"
}
test_skills_anchor_coverage() {
  local r
  r=$(fresh)
  rm "$r/tests/anchors/alpha.txt"
  expect_fail "no anchors at all" skills "$r" "tests/anchors/ has no <skill>.txt file" "skills/alpha has no tests/anchors/alpha.txt"
  r=$(fresh)
  mkdir -p "$r/skills/beta"
  cp "$r/skills/alpha/SKILL.md" "$r/skills/beta/SKILL.md"
  expect_fail "skill without anchors" skills "$r" "skills/beta has no tests/anchors/beta.txt"
  r=$(fresh)
  cp "$r/tests/anchors/alpha.txt" "$r/tests/anchors/ghost.txt"
  expect_fail "anchors without a skill" skills "$r" "skills/ghost/SKILL.md does not exist"
}
test_skills_plugin_paths() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/missing.md now.'
  expect_fail "file that does not exist" skills "$r" "cited framework path does not exist" 'path: ${CLAUDE_PLUGIN_ROOT}/templates/missing.md'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/missing.md.'
  expect_fail "missing file at the end of a sentence" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/templates/missing.md'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/adaptors/<kind>.md now.'
  expect_fail "placeholder path with a typo in the directory" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/adaptors/'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/note-<name>.md now.'
  expect_pass "placeholder inside a file name" skills "$r"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/../outside.md now.'
  expect_fail "path leaving the plugin root" skills "$r" "path leaves the plugin root"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/missing-dir/ now.'
  expect_fail "directory that does not exist" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/missing-dir/'
}
test_skills_bare_paths() {
  local r line lineno
  for line in 'Read templates/note.md first.' 'See (adapters/CONTRACT.md) first.' 'Run `hooks/claude/doctor.sh` first.' 'Open "profiles/examples" first.' "Open 'templates/note.md' first." 'profiles/examples/writing.md opens the line.'; do
    r=$(fresh)
    append "$r" skills/alpha/SKILL.md "$line"
    lineno=$(wc -l <"$r/skills/alpha/SKILL.md")
    expect_fail "bare path: $line" skills "$r" "skills/alpha/SKILL.md:$lineno: framework path cited without the "
  done
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Copy to .rastro/templates/x.md, .rastro/hooks/y and my-templates/z.'
  expect_pass "adopter paths and longer names are not framework paths" skills "$r"
}
test_skills_config_keys() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Reads `verify.bogus` before anything.'
  expect_fail "unknown key in a known section" skills "$r" "config key is not in templates/config.yml" "key: verify.bogus"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Reads `project.languages.nothing` before anything.'
  expect_fail "unknown nested key" skills "$r" "key: project.languages.nothing"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Reads `workspace.nested` before anything.'
  expect_fail "key below the top-level workspace key" skills "$r" "key: workspace.nested"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Not keys: `verify.*`, `verify.lint.*`, `tracker.kind: local`, `some.file` and a verify.unknown outside backticks.'
  expect_pass "wildcards, assignments, other prefixes and unquoted text" skills "$r"
}
test_skills_tool_names() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Open the issue in Jira.'
  expect_fail "tool name in a skill" skills "$r" "names a tool product or stack" "SKILL.md:"
}

test_adapters_missing_files() {
  local r
  r=$(fresh)
  rm "$r/adapters/CONTRACT.md"
  expect_fail "no CONTRACT.md" adapters "$r" "adapters/CONTRACT.md does not exist"
  r=$(fresh)
  rm "$r/adapters/review/none.md" "$r/adapters/tracker/jira.md"
  expect_fail "required adapters missing" adapters "$r" "adapters/review/none.md does not exist" "adapters/tracker/jira.md does not exist"
}
test_adapters_title() {
  local r
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md 's|^# Adapter: tracker/jira|# Adapter: tracker/jra|'
  expect_fail "wrong title" adapters "$r" "adapters/tracker/jira.md: title is not '# Adapter: tracker/jira'"
}
test_adapters_requirements() {
  local r
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md 's/^REQUIRED MCP: fixture-server/Needs the server/'
  expect_fail "no marker line" adapters "$r" "adapters/tracker/jira.md: ## Requirements has no line starting with"
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md 's/^REQUIRED MCP: fixture-server/Needs the server/'
  append "$r" adapters/tracker/jira.md 'REQUIRED: none'
  expect_fail "marker outside ## Requirements" adapters "$r" "adapters/tracker/jira.md: ## Requirements has no line starting with"
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md 's/^REQUIRED MCP: fixture-server/REQUIRED: something/'
  expect_fail "REQUIRED: with a value other than none" adapters "$r" "adapters/tracker/jira.md: ## Requirements has no line starting with"
}
test_adapters_sections() {
  local r
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md '/^## Known limits$/d'
  expect_fail "no ## Known limits" adapters "$r" "adapters/tracker/jira.md: heading missing" "heading: ## Known limits"
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md '/^## Capabilities$/d'
  expect_fail "no ## Capabilities" adapters "$r" "adapters/tracker/jira.md: heading missing" "heading: ## Capabilities"
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md '/^### read_item$/d'
  expect_fail "capability heading removed" adapters "$r" "adapters/tracker/jira.md: capability heading missing" "heading: ### read_item"
  r=$(fresh)
  edit "$r" adapters/tracker/jira.md 's/^### read_item$/read_item/'
  append "$r" adapters/tracker/jira.md '### read_item'
  expect_fail "capability heading outside ## Capabilities" adapters "$r" "heading: ### read_item"
}
test_adapters_contract_is_the_source() {
  local r
  r=$(fresh)
  edit "$r" adapters/CONTRACT.md 's/^- `read_item`$/&\n- `new_capability`/'
  expect_fail "capability added to the contract" adapters "$r" \
    "adapters/tracker/jira.md: capability heading missing" "adapters/tracker/none.md: capability heading missing" "heading: ### new_capability"
  r=$(fresh)
  edit "$r" adapters/CONTRACT.md '/^- `read_item`$/d'
  expect_pass "capability removed from the contract" adapters "$r"
  r=$(fresh)
  mkdir -p "$r/adapters/extra"
  cp "$r/adapters/review/none.md" "$r/adapters/extra/thing.md"
  expect_fail "adapter directory without a port" adapters "$r" "adapters/extra/thing.md: no '## Port: extra (config: <key>)' section"
}
test_adapters_contract_format() {
  local r
  r=$(fresh)
  edit "$r" adapters/CONTRACT.md 's/^## Port: docs (config: docs)$/## Port: docs/'
  expect_fail "port heading without config key" adapters "$r" "malformed port heading" "found: ## Port: docs"
  r=$(fresh)
  edit "$r" adapters/CONTRACT.md '/^- `fetch`$/d'
  expect_fail "port without capability bullets" adapters "$r" "port docs lists no capability bullet"
  r=$(fresh)
  edit "$r" adapters/CONTRACT.md '/^## Port:/d'
  expect_fail "contract without ports" adapters "$r" "declares no '## Port: <dir> (config: <key>)' section"
}

test_markers_file() {
  local r
  r=$(fresh)
  rm "$r/templates/MARKERS.md"
  expect_fail "no MARKERS.md" markers "$r" "templates/MARKERS.md does not exist"
  r=$(fresh)
  printf '# Markers\n\nNothing listed.\n' >"$r/templates/MARKERS.md"
  expect_fail "no marker lines" markers "$r" "lists no marker"
}
test_markers_must_appear_elsewhere() {
  local r
  r=$(fresh)
  append "$r" templates/MARKERS.md '- `ONLY-HERE`'
  expect_fail "marker only in MARKERS.md" markers "$r" "appears in no file under templates/ or skills/ besides MARKERS.md" "marker: ONLY-HERE"
  r=$(fresh)
  append "$r" templates/MARKERS.md '| `ROW-ONLY-HERE` | alpha |'
  expect_fail "table marker only in MARKERS.md" markers "$r" "marker: ROW-ONLY-HERE"
  r=$(fresh)
  append "$r" templates/MARKERS.md '- `TEMPLATE-ONLY`'
  append "$r" templates/note.md 'TEMPLATE-ONLY'
  expect_pass "marker found in a template" markers "$r"
  r=$(fresh)
  append "$r" templates/MARKERS.md '- `SKILL-ONLY`'
  append "$r" skills/alpha/SKILL.md 'SKILL-ONLY'
  expect_pass "marker found in a skill" markers "$r"
  r=$(fresh)
  rm -r "$r/skills"
  expect_fail "skills/ is searched too" markers "$r" "marker: DT-xx"
}
test_markers_parsing() {
  local r
  r=$(fresh)
  append "$r" templates/MARKERS.md 'Use `NOT-A-MARKER` inside a sentence.'
  append "$r" templates/MARKERS.md '- `ALPHA-FLAG` is explained with `NOT-INNER`'
  append "$r" templates/MARKERS.md '| `ALPHA-FLAG` | `NOT-IN-SECOND-CELL` |'
  expect_pass "only leading backtick spans are markers" markers "$r"
  r=$(fresh)
  sed -i 's/$/\r/' "$r/templates/MARKERS.md"
  expect_pass "CRLF MARKERS.md" markers "$r"
  r=$(fresh)
  append "$r" templates/MARKERS.md '| `ZZ-ONE`, `ZZ-TWO` | alpha |'
  expect_fail "two markers in one cell" markers "$r" "marker: ZZ-ONE" "marker: ZZ-TWO"
}

test_exact_case_paths() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/adapters/contract.md now.'
  expect_fail "file name differs in case" skills "$r" "cited framework path does not exist" 'path: ${CLAUDE_PLUGIN_ROOT}/adapters/contract.md'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/Templates/ now.'
  expect_fail "directory name differs in case" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/Templates/'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/Note.md now.'
  expect_fail "last component differs in case" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/templates/Note.md'
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/note.md and ${CLAUDE_PLUGIN_ROOT}/adapters/CONTRACT.md now.'
  expect_pass "exact case" skills "$r"
  r=$(fresh)
  mv "$r/skills/alpha" "$r/skills/tmp-name" && mv "$r/skills/tmp-name" "$r/skills/Alpha"
  expect_fail "skill directory differs in case" skills "$r" "skills/alpha/SKILL.md does not exist"
  r=$(fresh)
  mv "$r/adapters/tracker/jira.md" "$r/adapters/tracker/tmp-name.md" && mv "$r/adapters/tracker/tmp-name.md" "$r/adapters/tracker/Jira.md"
  expect_fail "required adapter differs in case" adapters "$r" "adapters/tracker/jira.md does not exist"
  r=$(fresh)
  mv "$r/adapters/CONTRACT.md" "$r/adapters/tmp-name.md" && mv "$r/adapters/tmp-name.md" "$r/adapters/Contract.md"
  expect_fail "contract differs in case" adapters "$r" "adapters/CONTRACT.md does not exist"
  r=$(fresh)
  mv "$r/templates/MARKERS.md" "$r/templates/tmp-name.md" && mv "$r/templates/tmp-name.md" "$r/templates/Markers.md"
  expect_fail "markers file differs in case" markers "$r" "templates/MARKERS.md does not exist"
}
test_skills_unbraced_variable() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read $CLAUDE_PLUGIN_ROOT/templates/missing.md now.'
  expect_fail "unbraced form, file that does not exist" skills "$r" "cited framework path does not exist" "templates/missing.md"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read $CLAUDE_PLUGIN_ROOT/Templates/note.md now.'
  expect_fail "unbraced form, wrong case" skills "$r" "Templates/note.md"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Read $CLAUDE_PLUGIN_ROOT/templates/note.md and $CLAUDE_PLUGIN_ROOT/adapters/CONTRACT.md now.'
  expect_pass "unbraced form, existing files, not a bare path" skills "$r"
}
test_skills_bare_path_boundary() {
  local r line lineno
  for line in '[templates/x.md](x)' '**adapters/y.md**' $'\ttemplates/x.md' './hooks/z.sh' '- templates/x.md' 'see <adapters/y.md> now'; do
    r=$(fresh)
    append "$r" skills/alpha/SKILL.md "$line"
    lineno=$(wc -l <"$r/skills/alpha/SKILL.md")
    expect_fail "bare path: $line" skills "$r" "skills/alpha/SKILL.md:$lineno: framework path cited without the "
  done
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Both profiles/adapters are meant here, and so are adapters/templates.'
  expect_pass "prose naming two framework directories" skills "$r"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Not paths: my_templates/x, a.templates/x, ../hooks/x, dir-adapters/y.'
  expect_pass "names that merely end in a framework directory" skills "$r"
}
test_skills_bare_paths_in_fences() {
  local r lineno
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md '```text'
  append "$r" skills/alpha/SKILL.md '.rastro/'
  append "$r" skills/alpha/SKILL.md '  adapters/'
  append "$r" skills/alpha/SKILL.md '  profiles/'
  append "$r" skills/alpha/SKILL.md '```'
  expect_pass "tree listing rooted at .rastro/ inside a fence" skills "$r"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md '~~~bash'
  append "$r" skills/alpha/SKILL.md 'cp templates/note.md .'
  append "$r" skills/alpha/SKILL.md '~~~'
  expect_pass "tilde fence" skills "$r"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md '```'
  append "$r" skills/alpha/SKILL.md 'templates/inside.md'
  append "$r" skills/alpha/SKILL.md '```'
  append "$r" skills/alpha/SKILL.md 'templates/outside.md'
  lineno=$(wc -l <"$r/skills/alpha/SKILL.md")
  expect_fail "scanning resumes after the fence" skills "$r" "skills/alpha/SKILL.md:$lineno: framework path cited without the "
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md '```'
  append "$r" skills/alpha/SKILL.md 'Read ${CLAUDE_PLUGIN_ROOT}/templates/missing.md in a fence.'
  append "$r" skills/alpha/SKILL.md '```'
  expect_fail "cited paths are still checked inside a fence" skills "$r" 'path: ${CLAUDE_PLUGIN_ROOT}/templates/missing.md'
}
test_skills_config_key_lookalikes() {
  local r
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Files, not keys: `docs.md`, `review.md`, `review.yml`, `docs.yaml`, `verify.sh`, `tracker.json`, `project.config.yml`.'
  expect_pass "file names that start with a section name" skills "$r"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Keys: `verify.bogus` and `docs.md`.'
  expect_fail "a real unknown key next to a file name" skills "$r" "key: verify.bogus"
  r=$(fresh)
  append "$r" skills/alpha/SKILL.md 'Not an extension: `verify.mdx` and `verify.shell`.'
  expect_fail "other last segments are still keys" skills "$r" "key: verify.mdx" "key: verify.shell"
}
test_required_skills() {
  local r c
  r=$(fresh)
  with_mode core expect_fail "core skills required by flag" skills "$r" \
    "required skill 'setup' is missing" "required skill 'design-doc' is missing" "required skill 'breakdown' is missing" \
    "required skill 'reconcile' is missing" "required skill 'domain-context' is missing" "required skill 'implement' is missing" \
    "required skill 'deliver' is missing"
  r=$(plugin_copy)
  with_mode default expect_fail "default root requires all seven" skills "$r" "required skill 'setup' is missing" "required skill 'deliver' is missing"
  add_core_skills "$r"
  with_mode default expect_pass "default root with all seven" skills "$r"
  rm -r "$r/skills/deliver"
  with_mode default expect_fail "default root, SKILL.md missing" skills "$r" "required skill 'deliver' is missing"
  c=$(plugin_copy)
  add_core_skills "$c"
  rm "$c/tests/anchors/implement.txt"
  with_mode default expect_fail "default root, anchors file missing" skills "$c" "required skill 'implement' is missing"
  c=$(plugin_copy)
  add_core_skills "$c"
  mv "$c/skills/setup" "$c/skills/tmp-name" && mv "$c/skills/tmp-name" "$c/skills/Setup"
  with_mode default expect_fail "default root, skill directory differs in case" skills "$c" "required skill 'setup' is missing"
  c=$(plugin_copy)
  with_mode default expect_fail "no argument means all seven are required" skills "$c" "required skill 'implement' is missing"
}
test_required_markers() {
  local r
  r=$(fresh)
  with_mode core expect_fail "core markers required by flag" markers "$r" \
    "required marker missing from templates/MARKERS.md" "marker: ## Reconciliation" "marker: reconciliation.md" "marker: NOT VERIFIED" \
    "marker: [HUMAN]" "marker: [no PR]" "marker: ## Context" "marker: Decided (<YYYY-MM-DD>):" "marker: D-n" "marker: DT-nn"
  r=$(plugin_copy)
  with_mode default expect_fail "default root requires the section 6.11 set" markers "$r" "marker: [no PR]"
  write_core_markers "$r"
  with_mode default expect_pass "default root with the whole set" markers "$r"
  edit "$r" templates/MARKERS.md '/^| `\[no PR\]`/d'
  with_mode default expect_fail "default root, one marker removed" markers "$r" "required marker missing from templates/MARKERS.md" "marker: [no PR]"
  r=$(plugin_copy)
  write_core_markers "$r"
  edit "$r" templates/MARKERS.md 's/YYYY-MM-DD/AAAA-MM-DD/'
  edit "$r" templates/core-markers.md 's/YYYY-MM-DD/AAAA-MM-DD/'
  with_mode default expect_fail "default root, marker spelled differently" markers "$r" "marker: Decided (<YYYY-MM-DD>):"
  r=$(plugin_copy)
  write_core_markers "$r"
  append "$r" templates/MARKERS.md '- `EXTRA-MARKER`'
  append "$r" templates/core-markers.md 'EXTRA-MARKER'
  with_mode default expect_pass "default root, extra markers are allowed" markers "$r"
}

test_fixture_is_valid
test_skills_missing_file
test_skills_frontmatter_name
test_skills_frontmatter_missing
test_skills_description
test_skills_headings
test_skills_doctrine
test_skills_anchors
test_skills_anchor_coverage
test_skills_plugin_paths
test_skills_bare_paths
test_skills_config_keys
test_skills_tool_names
test_adapters_missing_files
test_adapters_title
test_adapters_requirements
test_adapters_sections
test_adapters_contract_is_the_source
test_adapters_contract_format
test_markers_file
test_markers_must_appear_elsewhere
test_markers_parsing
test_exact_case_paths
test_skills_unbraced_variable
test_skills_bare_path_boundary
test_skills_bare_paths_in_fences
test_skills_config_key_lookalikes
test_required_skills
test_required_markers
finish
