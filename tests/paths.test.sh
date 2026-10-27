. "$(dirname "$0")/lib/assert.sh"
. "$(dirname "$0")/lib/tmprepo.sh"
. "$(dirname "$0")/../hooks/lib/config.sh"
. "$(dirname "$0")/../hooks/lib/paths.sh"
unset CLAUDE_PROJECT_DIR
FIXTURES="$RASTRO_TESTS_DIR/fixtures/config"
export RASTRO_CONFIG="$FIXTURES/hooks.yml"
test_path_matches() {
  local path pattern want
  while IFS='|' read -r path pattern want; do
    rastro_path_matches "$path" "$pattern"
    assert_eq "$want" $? "path_matches '$path' '$pattern'"
  done <<'EOF'
.env|.env*|0
config/.env.local|.env*|0
src/env.ts|.env*|1
a/b/old.bak|*.bak|0
coverage/lcov.info|coverage/|0
pkg/coverage/x|coverage/|1
.agent/plan.md|.agent/|0
.agent|.agent/|1
notes/my old.bak|*.bak|0
my dir/.env|.env*|0
my dir/a.txt|my dir/|0
src/gen/a.ts|src/*/a.ts|0
lib/gen/a.ts|src/*/a.ts|1
src/a.ts||1
coverage/x|coverage|0
a/b/coverage/x|coverage|0
coverage|coverage|0
src/coveragex/y|coverage|1
.env|**/.env|0
a/.env|**/.env|0
server.pem|**/*.pem|0
a/b/server.pem|**/*.pem|0
src/env.ts|**/.env|1
src/gen/a.ts|**/src/gen/*.ts|0
x/y/src/gen/a.ts|**/src/gen/*.ts|0
lib/gen/a.ts|**/src/gen/*.ts|1
coverage/x|**/coverage/|0
a/coverage/x|**/coverage/|0
a/coveragex/y|**/coverage/|1
.env|/.env|0
a/.env|/.env|1
coverage/x|/coverage/|0
pkg/coverage/x|/coverage/|1
src/a.ts|/src/*.ts|0
lib/src/a.ts|/src/*.ts|1
.env|/|1
coverage/x|/coverage|0
coverage/x/y|/coverage|0
coverage|/coverage|0
pkg/coverage/x|/coverage|1
build/out/x|build/out|0
build/out|build/out|0
build/outer|build/out|1
a/build/out/x|build/out|1
a/build/out/x|**/build/out|0
build/out/x|**/build/out|0
build/outer|**/build/out|1
EOF
}
test_glob_match() {
  local path glob want
  while IFS='|' read -r path glob want; do
    rastro_glob_match "$path" "$glob"
    assert_eq "$want" $? "glob_match '$path' '$glob'"
  done <<'EOF'
src/a.ts|src/**/*.ts|0
src/a/b.ts|src/**/*.ts|0
lib/a.ts|src/**/*.ts|1
a.ts|**/*.ts|0
lib/my dir/x.ts|lib/my dir/*.ts|0
src/a.js|src/**/*.ts|1
EOF
}
test_forbidden_patterns() {
  assert_eq $'.env*\n*.bak\ncoverage/\n.agent/' "$(rastro_forbidden_patterns)" "config list plus workspace"
}
test_path_forbidden() {
  rastro_forbidden_load
  rastro_path_forbidden ".env.local"; assert_eq 0 $? "env file forbidden"
  rastro_path_forbidden ".agent/plan.md"; assert_eq 0 $? "workspace forbidden"
  rastro_path_forbidden "x/coverage/y"; assert_eq 1 $? "nested coverage allowed"
  rastro_path_forbidden "src/a.ts"; assert_eq 1 $? "source allowed"
  rastro_path_forbidden "notes/my old.bak"; assert_eq 0 $? "path with space forbidden"
}
test_directory_and_double_star_patterns_are_not_fail_open() {
  local cfg="$RASTRO_TEST_TMP/config.yml"
  printf 'conventions:\n  forbidden_paths: [coverage, "**/.env", "**/*.pem"]\nworkspace: .agent\n' >"$cfg"
  RASTRO_CONFIG="$cfg"
  assert_eq $'coverage\n**/.env\n**/*.pem\n.agent/' "$(rastro_forbidden_patterns)" "workspace without a slash gets one"
  rastro_forbidden_load
  rastro_path_forbidden ".agent/plan.md"; assert_eq 0 $? "workspace without a trailing slash blocks its files"
  rastro_path_forbidden "coverage/x"; assert_eq 0 $? "bare directory name blocks files under it"
  rastro_path_forbidden "a/coverage/x"; assert_eq 0 $? "bare directory name blocks it at depth"
  rastro_path_forbidden ".env"; assert_eq 0 $? "leading **/ matches the root file"
  rastro_path_forbidden "server.pem"; assert_eq 0 $? "**/*.pem matches the root file"
  rastro_path_forbidden "src/a.ts"; assert_eq 1 $? "source still allowed"
  printf 'conventions:\n  forbidden_paths: []\nworkspace: work/agent\n' >"$cfg"
  assert_eq "work/agent/" "$(rastro_forbidden_patterns)" "workspace with an inner slash still gets a trailing one"
  printf 'conventions:\n  forbidden_paths: []\nworkspace: .agent/\n' >"$cfg"
  assert_eq ".agent/" "$(rastro_forbidden_patterns)" "workspace with a trailing slash is unchanged"
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
test_leading_slash_anchor_is_forbidden() {
  local cfg="$RASTRO_TEST_TMP/config.yml"
  printf 'conventions:\n  forbidden_paths: ["/.env", "/coverage/"]\n' >"$cfg"
  RASTRO_CONFIG="$cfg"
  rastro_forbidden_load
  rastro_path_forbidden ".env"; assert_eq 0 $? "anchored file at the root blocked"
  rastro_path_forbidden "coverage/x"; assert_eq 0 $? "anchored directory at the root blocked"
  rastro_path_forbidden "a/.env"; assert_eq 1 $? "anchored file at depth allowed"
  rastro_path_forbidden "pkg/coverage/x"; assert_eq 1 $? "anchored directory at depth allowed"
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
test_forbidden_without_workspace() {
  local cfg
  cfg="$RASTRO_TEST_TMP/config.yml"
  printf 'conventions:\n  forbidden_paths: [".env*"]\n' >"$cfg"
  RASTRO_CONFIG="$cfg"
  assert_eq $'.env*\n.agent/' "$(rastro_forbidden_patterns)" "no workspace key: the configured list plus the default workspace .agent/"
  printf 'conventions:\n  forbidden_paths: [".env*"]\nworkspace: ""\n' >"$cfg"
  assert_eq ".env*" "$(rastro_forbidden_patterns)" "workspace set to empty: only the configured list"
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
test_forbidden_defaults_when_keys_are_absent() {
  local cfg
  cfg="$RASTRO_TEST_TMP/config.yml"
  printf 'project:\n  name: bookstore\n' >"$cfg"
  RASTRO_CONFIG="$cfg"
  assert_eq $'.env*\n*.bak\n.agent/' "$(rastro_forbidden_patterns)" "no forbidden_paths and no workspace: both defaults"
  rastro_forbidden_load
  rastro_path_forbidden ".env"; assert_eq 0 $? "default .env* blocks .env"
  rastro_path_forbidden ".env.example"; assert_eq 0 $? "default .env* also blocks .env.example"
  rastro_path_forbidden "notes/old.bak"; assert_eq 0 $? "default *.bak blocks a backup at depth"
  rastro_path_forbidden ".agent/plan.md"; assert_eq 0 $? "default workspace blocks its files"
  rastro_path_forbidden "src/a.ts"; assert_eq 1 $? "defaults leave source allowed"
  printf 'conventions:\n  forbidden_paths: []\nworkspace: .agent/\n' >"$cfg"
  assert_eq ".agent/" "$(rastro_forbidden_patterns)" "forbidden_paths: [] means no pattern, not the default"
  printf 'conventions:\n  forbidden_paths:\nworkspace: .agent/\n' >"$cfg"
  assert_eq ".agent/" "$(rastro_forbidden_patterns)" "forbidden_paths with no value means no pattern, not the default"
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
test_unsupported_list_fails_closed() {
  local cfg
  cfg="$RASTRO_TEST_TMP/config.yml"
  printf 'conventions:\n  forbidden_paths:\n    - .env*\n    - "*.bak"\nworkspace: .agent/\n' >"$cfg"
  RASTRO_CONFIG="$cfg"
  run_cmd rastro_forbidden_patterns
  assert_status 2 "block list: status 2"
  assert_eq "" "$OUT" "block list: no partial patterns on stdout"
  assert_contains "$ERR" "conventions.forbidden_paths" "block list: message names the key"
  run_cmd rastro_forbidden_load
  assert_status 2 "load: status 2"
  RASTRO_CONFIG="$FIXTURES/hooks.yml"
}
test_path_matches; test_glob_match; test_forbidden_patterns; test_path_forbidden
test_directory_and_double_star_patterns_are_not_fail_open; test_leading_slash_anchor_is_forbidden
test_forbidden_without_workspace; test_forbidden_defaults_when_keys_are_absent; test_unsupported_list_fails_closed
finish
