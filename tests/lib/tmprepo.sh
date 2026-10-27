RASTRO_TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ -z "${RASTRO_TEST_TMP:-}" ]; then
  RASTRO_TEST_TMP=$(mktemp -d)
  trap 'rm -rf "$RASTRO_TEST_TMP"' EXIT
fi

make_tmp_repo() {
  local dir
  dir=$(mktemp -d "$RASTRO_TEST_TMP/repo.XXXXXX") || return 1
  git init -q -b main "$dir" >/dev/null || return 1
  git -C "$dir" config user.name "Rastro Test"
  git -C "$dir" config user.email "test@rastro.invalid"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" config core.autocrlf false
  printf '%s\n' "$dir"
}

use_config() {
  mkdir -p "$1/.rastro" || return 1
  cp "$RASTRO_TESTS_DIR/fixtures/config/$2.yml" "$1/.rastro/config.yml"
}
