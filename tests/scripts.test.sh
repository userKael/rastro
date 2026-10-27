. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
TOOL_NAMES="$RASTRO_TESTS_DIR/../scripts/check-tool-names.sh"
PRIVATE_TERMS="$RASTRO_TESTS_DIR/../scripts/check-private-terms.sh"

new_dir() {
  mktemp -d "$RASTRO_TEST_TMP/dir.XXXXXX"
}
put() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}
write_terms() {
  local f
  f=$(mktemp "$RASTRO_TEST_TMP/terms.XXXXXX") || return 1
  printf '%s\n' "$1" >"$f"
  printf '%s\n' "$f"
}
commit_path() {
  git -C "$1" add -- "$2" && git -C "$1" commit -q -m "$3"
}
terms_in() {
  # The caller's locale is forced to C: the script must pick its own.
  (cd "$1" && LC_ALL=C bash "$PRIVATE_TERMS" "$2")
}

test_tool_names_flags() {
  local dir
  dir=$(new_dir)
  put "$dir" a.md "uses Jira for issues"
  run_cmd bash "$TOOL_NAMES" "$dir"
  assert_status 1 "tool name found"
  assert_contains "$OUT" "jira" "reports the term in lower case"
}
test_tool_names_word_boundary() {
  local dir
  dir=$(new_dir)
  put "$dir" a.md "the jester said npmish things about prismatic jestering"
  run_cmd bash "$TOOL_NAMES" "$dir"
  assert_status 0 "substrings are not tool names"
  assert_eq "" "$OUT" "nothing printed"
}
test_tool_names_every_term() {
  local dir term n=0 lower='' upper=''
  local terms="jira atlassian notion confluence github gitlab bitbucket postgres postgresql mysql npm eslint jest tsc typeorm nestjs prisma"
  for term in $terms; do
    lower+="we rely on $term here"$'\n'
    upper+="We rely on $(printf '%s' "$term" | tr 'a-z' 'A-Z') here"$'\n'
  done
  dir=$(new_dir)
  put "$dir" lower.md "${lower%$'\n'}"
  put "$dir" upper.md "${upper%$'\n'}"
  run_cmd bash "$TOOL_NAMES" "$dir"
  assert_status 1 "terms found"
  for term in $terms; do
    n=$((n + 1))
    assert_contains "$OUT" "lower.md:$n: $term" "$term reported with file and line"
    assert_contains "$OUT" "upper.md:$n: $term" "$term flagged in upper case"
  done
}
test_tool_names_location_format() {
  local dir
  dir=$(new_dir)
  put "$dir" one/a.md $'clean line\nuse GitLab, then Notion\nclean again'
  put "$dir" two/b.md "run npm test"
  run_cmd bash "$TOOL_NAMES" "$dir"
  assert_status 1 "findings in nested files"
  assert_contains "$OUT" "one/a.md:2: gitlab" "first term on line 2"
  assert_contains "$OUT" "one/a.md:2: notion" "second term on the same line"
  assert_contains "$OUT" "two/b.md:1: npm" "second file"
  assert_not_contains "$OUT" "one/a.md:1:" "clean line not reported"
}
test_tool_names_allowed_names() {
  local dir
  dir=$(new_dir)
  put "$dir" a.md $'Ask with AskUserQuestion. Read .mcp.json and ~/.claude.json.\nFall back to superpowers:finishing-a-development-branch.\nLinear flow, tracker kind <kind>, code host, docs tool.'
  run_cmd bash "$TOOL_NAMES" "$dir"
  assert_status 0 "harness concepts and generic words pass"
}
test_tool_names_missing_dir() {
  run_cmd bash "$TOOL_NAMES" "$RASTRO_TEST_TMP/no-such-dir"
  assert_status 2 "missing directory is not reported clean"
  assert_contains "$ERR" "not found" "says why"
}

test_private_terms_missing_file() {
  local repo
  repo=$(make_tmp_repo)
  run_cmd terms_in "$repo" "$RASTRO_TEST_TMP/no-such-terms.txt"
  assert_status 2 "missing terms file refuses"
  assert_contains "$ERR" "terms file not found; refusing to report clean" "message"
  run_cmd bash -c 'cd "$1" && bash "$2"' _ "$repo" "$PRIVATE_TERMS"
  assert_status 2 "no argument refuses"
}
test_private_terms_content() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" src/a.txt $'first line\nsecret context acme-core here'
  git -C "$repo" add -- src/a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "term in staged content"
  assert_contains "$OUT" "src/a.txt:2: acme-core" "file, line and pattern"
  assert_not_contains "$OUT" "secret context" "surrounding text is not echoed"
}
test_private_terms_content_case_insensitive() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "ACME-Core"
  git -C "$repo" add -- a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "pattern is case-insensitive"
}
test_private_terms_content_with_space_in_name() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" "my notes.txt" "acme-core"
  git -C "$repo" add -- "my notes.txt"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "file name with a space"
  assert_contains "$OUT" "my notes.txt:1: acme-core" "whole name reported"
}
test_private_terms_history() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "clean"
  commit_path "$repo" a.txt "chore: migrate acme-core data"
  put "$repo" a.txt "still clean"
  commit_path "$repo" a.txt "chore: second change"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "term only in an old commit message"
  assert_contains "$OUT" "commit" "reported as a commit"
  assert_contains "$OUT" "acme-core" "with the pattern"
  assert_eq "1" "$(printf '%s\n' "$OUT" | grep -c '^commit ')" "one line for the one commit"
}
test_private_terms_history_diff() {
  local repo terms sha
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "acme-core"
  commit_path "$repo" a.txt "chore: add file"
  sha=$(git -C "$repo" rev-parse --short=7 HEAD)
  put "$repo" a.txt "removed"
  commit_path "$repo" a.txt "chore: remove it again"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "term only in a removed line of an old commit"
  assert_contains "$OUT" "commit $sha: acme-core" "attributed to the commit that added it"
}
test_private_terms_history_other_branch() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "clean"
  commit_path "$repo" a.txt "chore: base"
  git -C "$repo" checkout -q -b side
  put "$repo" b.txt "acme-core"
  commit_path "$repo" b.txt "chore: side work"
  git -C "$repo" checkout -q main
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "term on a branch that is not checked out"
}
test_private_terms_clean() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "nothing to see"
  commit_path "$repo" a.txt "chore: add a"
  run_cmd terms_in "$repo" "$terms"
  assert_status 0 "clean repository"
  assert_eq "" "$OUT" "nothing printed"
}
test_private_terms_empty_repository() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  run_cmd terms_in "$repo" "$terms"
  assert_status 0 "repository without commits or files"
}
test_private_terms_skips_blank_and_comment_lines() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms $'# acme-core is a comment here\n\n   \nzzz-never-present\n')
  put "$repo" a.txt "acme-core and anything else"
  commit_path "$repo" a.txt "chore: add a"
  run_cmd terms_in "$repo" "$terms"
  assert_status 0 "comment is not a pattern and a blank line does not match everything"
}
test_private_terms_no_patterns_refused() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms $'# only a comment\n\n')
  put "$repo" a.txt "text"
  commit_path "$repo" a.txt "chore: add a"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "a terms file with no patterns is not a clean report"
  assert_contains "$ERR" "refusing to report clean" "says so"
}
test_private_terms_uppercase_accented() {
  local repo terms lower upper
  lower='acme-ação'
  upper='ACME-AÇÃO'
  repo=$(make_tmp_repo)
  terms=$(write_terms "$lower")
  put "$repo" a.txt "see $upper here"
  git -C "$repo" add -- a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "uppercase accented form of a lowercase accented pattern, content"
  repo=$(make_tmp_repo)
  put "$repo" a.txt "clean"
  commit_path "$repo" a.txt "docs: mention $upper"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "uppercase accented form in a commit message"
}
test_private_terms_alternation_with_accents() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms 'acme-a(ç|c)(ã|a)o')
  put "$repo" a.txt "ACME-ACAO and ACME-AÇÃO"
  git -C "$repo" add -- a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "ERE alternation"
}
test_private_terms_crlf_terms_file() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(mktemp "$RASTRO_TEST_TMP/terms.XXXXXX")
  printf '# comment\r\nacme-core\r\n' >"$terms"
  put "$repo" a.txt "acme-core"
  git -C "$repo" add -- a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "CRLF terms file"
}
test_private_terms_invalid_pattern() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms 'acme-(core')
  put "$repo" a.txt "text"
  commit_path "$repo" a.txt "chore: add a"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "an invalid pattern is not a clean report"
  assert_contains "$ERR" "refusing to report clean" "says so"
}
test_private_terms_not_a_repository() {
  local dir terms
  dir=$(new_dir)
  terms=$(write_terms "acme-core")
  run_cmd terms_in "$dir" "$terms"
  assert_status 2 "outside a git repository"
  assert_contains "$ERR" "refusing to report clean" "says so"
}
test_private_terms_from_subdirectory() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" top.txt "acme-core"
  put "$repo" sub/deep.txt "clean"
  git -C "$repo" add -- top.txt sub/deep.txt
  run_cmd terms_in "$repo/sub" "$terms"
  assert_status 1 "scans the whole repository, not the current directory"
  assert_contains "$OUT" "top.txt:1: acme-core" "path relative to the repository root"
}
test_private_terms_bom_terms_file() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(mktemp "$RASTRO_TEST_TMP/terms.XXXXXX")
  printf '\357\273\277acme-core\n' >"$terms"
  put "$repo" a.txt "acme-core"
  git -C "$repo" add -- a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "terms file with a UTF-8 BOM still catches the term"
  assert_contains "$OUT" "a.txt:1: acme-core" "pattern is reported without the BOM"
  printf '\357\273\277# a comment first\nacme-core\n' >"$terms"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "BOM in front of a comment line"
}
test_private_terms_utf16_terms_file() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(mktemp "$RASTRO_TEST_TMP/terms.XXXXXX")
  put "$repo" a.txt "acme-core"
  git -C "$repo" add -- a.txt
  printf '\377\376a\0c\0m\0e\0-\0c\0o\0r\0e\0\n\0' >"$terms"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "UTF-16LE terms file with a BOM"
  assert_contains "$ERR" "refusing to report clean" "says so"
  printf 'a\0c\0m\0e\0-\0c\0o\0r\0e\0\n\0' >"$terms"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "UTF-16LE terms file without a BOM"
  printf '\376\377\0a\0c\0m\0e\0-\0c\0o\0r\0e\0\n' >"$terms"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "UTF-16BE terms file with a BOM"
  printf 'acme-core\n\0' >"$terms"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "a NUL byte anywhere in the terms file"
  assert_contains "$ERR" "refusing to report clean" "says so"
}
test_private_terms_shallow_clone() {
  local src dst terms
  src=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$src" a.txt "one"
  commit_path "$src" a.txt "chore: one"
  put "$src" a.txt "two"
  commit_path "$src" a.txt "chore: two"
  dst="$RASTRO_TEST_TMP/shallow.clone"
  git clone -q --depth 1 "file://$src" "$dst" 2>/dev/null
  run_cmd terms_in "$dst" "$terms"
  assert_status 2 "shallow clone: older history is not available"
  assert_contains "$ERR" "shallow" "names the reason"
  assert_contains "$ERR" "refusing to report clean" "says so"
  dst="$RASTRO_TEST_TMP/full.clone"
  git clone -q "file://$src" "$dst" 2>/dev/null
  run_cmd terms_in "$dst" "$terms"
  assert_status 0 "full clone is scanned"
}
test_private_terms_unreadable_history() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  put "$repo" a.txt "clean"
  commit_path "$repo" a.txt "chore: add a"
  printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' >"$repo/.git/refs/heads/broken"
  run_cmd terms_in "$repo" "$terms"
  assert_status 2 "a ref pointing at a missing object"
  assert_contains "$ERR" "git log failed" "names the reason"
  assert_contains "$ERR" "refusing to report clean" "says so"
}
test_private_terms_non_utf8_content() {
  local repo terms sha
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  printf 'caf\351 acme-core\n' >"$repo/latin1.txt"
  git -C "$repo" add -- latin1.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "Latin-1 file in the index"
  assert_contains "$OUT" "latin1.txt:1: acme-core" "reported with file and line"
  commit_path "$repo" latin1.txt "chore: add latin1"
  sha=$(git -C "$repo" rev-parse --short=7 HEAD)
  printf 'clean\n' >"$repo/latin1.txt"
  commit_path "$repo" latin1.txt "chore: clean latin1"
  run_cmd terms_in "$repo" "$terms"
  assert_status 1 "Latin-1 line in an old commit"
  assert_contains "$OUT" "commit $sha: acme-core" "attributed to the commit that added it"
}
test_private_terms_skips_binary_files() {
  local repo terms
  repo=$(make_tmp_repo)
  terms=$(write_terms "acme-core")
  printf 'xx\0acme-core\0xx\n' >"$repo/blob.bin"
  put "$repo" a.txt "clean"
  git -C "$repo" add -- blob.bin a.txt
  run_cmd terms_in "$repo" "$terms"
  assert_status 0 "a file with NUL bytes is binary and is not scanned"
}

test_tool_names_flags
test_tool_names_word_boundary
test_tool_names_every_term
test_tool_names_location_format
test_tool_names_allowed_names
test_tool_names_missing_dir
test_private_terms_missing_file
test_private_terms_content
test_private_terms_content_case_insensitive
test_private_terms_content_with_space_in_name
test_private_terms_history
test_private_terms_history_diff
test_private_terms_history_other_branch
test_private_terms_clean
test_private_terms_empty_repository
test_private_terms_skips_blank_and_comment_lines
test_private_terms_no_patterns_refused
test_private_terms_uppercase_accented
test_private_terms_alternation_with_accents
test_private_terms_crlf_terms_file
test_private_terms_invalid_pattern
test_private_terms_not_a_repository
test_private_terms_from_subdirectory
test_private_terms_bom_terms_file
test_private_terms_utf16_terms_file
test_private_terms_shallow_clone
test_private_terms_unreadable_history
test_private_terms_non_utf8_content
test_private_terms_skips_binary_files
finish
