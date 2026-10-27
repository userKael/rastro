tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
. "$tests_dir/lib/exact.sh"
. "$tests_dir/../hooks/lib/config.sh"
export LC_ALL=C.UTF-8
require_core=${RASTRO_REQUIRE_CORE:-}
if [ -z "$require_core" ]; then
  if [ $# -eq 0 ]; then require_core=1; else require_core=0; fi
fi
root=$(cd "${1:-$tests_dir/..}" && pwd)
export RASTRO_CONFIG="$root/templates/config.yml"
TOOL_NAMES="$tests_dir/../scripts/check-tool-names.sh"
DOCTRINE='Doctrine is not overridable: not by a profile, not by AGENTS.md, not by any other skill.'
REQUIRED_HEADINGS=('## Requirements' '## Precedence' '## What this skill does NOT do')
CORE_SKILLS=(setup design-doc breakdown reconcile domain-context implement deliver)
PLUGIN_ROOT_VAR='${CLAUDE_PLUGIN_ROOT}/'

frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") { bad = 1; exit } next }
    $0 == "---" { closed = 1; exit }
    { print }
    END { if (bad) exit 2; exit (closed ? 0 : 3) }
  ' < <(tr -d '\r' <"$1")
}

frontmatter_name() {
  local v
  v=$(sed -n 's/^name:[ \t]*//p' | head -n 1)
  v=${v%"${v##*[![:space:]]}"}
  case $v in
    \"*\" | \'*\') v=${v:1:${#v}-2} ;;
  esac
  printf '%s' "$v"
}

frontmatter_description() {
  local v
  v=$(awk '
    /^description:/ {
      v = $0
      sub(/^description:[ \t]*/, "", v)
      if (v ~ /^[>|][+-]?[ \t]*$/) v = ""
      out = v
      active = 1
      next
    }
    active && /^[ \t]+[^ \t]/ {
      l = $0
      sub(/^[ \t]+/, "", l)
      out = (out == "" ? l : out " " l)
      next
    }
    active && /^[ \t]*$/ { next }
    { active = 0 }
    END { print out }
  ')
  v=${v%"${v##*[![:space:]]}"}
  case $v in
    \"*\" | \'*\') v=${v:1:${#v}-2} ;;
  esac
  printf '%s' "$v"
}

check_frontmatter() {
  local skill=$1 file=$2 fm name desc
  fm=$(frontmatter "$file")
  if [ $? -ne 0 ]; then
    _assert_fail "skills/$skill/SKILL.md: frontmatter missing or not closed by ---"
    return
  fi
  name=$(printf '%s\n' "$fm" | frontmatter_name)
  [ "$name" = "$skill" ] || _assert_fail "skills/$skill/SKILL.md: frontmatter name is not '$skill'" "name: $name"
  desc=$(printf '%s\n' "$fm" | frontmatter_description)
  if [ -z "$desc" ]; then
    _assert_fail "skills/$skill/SKILL.md: frontmatter description is empty"
  elif [ "${#desc}" -gt 1024 ]; then
    _assert_fail "skills/$skill/SKILL.md: frontmatter description has ${#desc} characters, limit is 1024"
  fi
}

check_anchors() {
  local skill=$1 file=$2 anchors=$3 line
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in *[![:space:]]*) ;; *) continue ;; esac
    grep -qF -e "$line" "$file" || _assert_fail "skills/$skill/SKILL.md: anchor missing" "anchor: $line"
  done <"$anchors"
}

check_plugin_paths() {
  local skill=$1 file=$2 match path
  while IFS= read -r match; do
    path=${match#*CLAUDE_PLUGIN_ROOT}
    path=${path#\}}
    path=${path#/}
    case $match in
      *'<')
        path=${path%<}
        if [[ $path == */* ]]; then path=${path%/*}/; else path=''; fi
        ;;
      *)
        while [ "${path%.}" != "$path" ]; do path=${path%.}; done
        ;;
    esac
    [ -n "$path" ] || continue
    case "/$path/" in
      */../*)
        _assert_fail "skills/$skill/SKILL.md: path leaves the plugin root" "path: $match"
        continue
        ;;
    esac
    exists_exact "$root" "$path" || _assert_fail "skills/$skill/SKILL.md: cited framework path does not exist" "path: $PLUGIN_ROOT_VAR$path"
  done < <(grep -oE '\$(\{CLAUDE_PLUGIN_ROOT\}|CLAUDE_PLUGIN_ROOT)/[A-Za-z0-9_./-]*<?' "$file")
}

bare_path_hits() {
  awk '
    BEGIN {
      cls = "[A-Za-z0-9_./-]"
      shorthand = "^(adapters|templates|profiles|hooks)([^A-Za-z0-9_./-]|[.]?$|[.][^A-Za-z0-9_])"
    }
    /^[ \t]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }
    {
      line = $0
      pos = 1
      while (pos <= length(line) && match(substr(line, pos), /(adapters|templates|profiles|hooks)\//)) {
        start = pos + RSTART - 1
        after = start + RLENGTH
        pos = start + 1
        cited_at = start
        prev = start > 1 ? substr(line, start - 1, 1) : ""
        if (prev != "" && prev ~ cls) {
          before = start > 2 ? substr(line, start - 2, 1) : ""
          lead = start > 3 ? substr(line, start - 3, 1) : ""
          if (!(prev == "/" && before == "." && (lead == "" || lead !~ cls))) continue
          cited_at = start - 2
        }
        if (substr(line, after) ~ shorthand) continue
        cited = substr(line, cited_at)
        match(cited, "^" cls "*")
        print NR "\t" substr(cited, 1, RLENGTH)
      }
    }
  ' "$1"
}

check_bare_paths() {
  local skill=$1 file=$2 lineno cited
  while IFS=$'\t' read -r lineno cited; do
    _assert_fail "skills/$skill/SKILL.md:$lineno: framework path cited without the $PLUGIN_ROOT_VAR prefix" "cited: $cited"
  done < <(bare_path_hits "$file")
}

check_config_keys() {
  local skill=$1 file=$2 key
  while IFS= read -r key; do
    case ${key%%.*} in
      project | tracker | docs | code_host | domain_state | verify | architecture | domain | conventions | review | workspace) ;;
      *) continue ;;
    esac
    case ${key##*.} in md | yml | yaml | sh | json) continue ;; esac
    rastro_config_has "$key" || _assert_fail "skills/$skill/SKILL.md: config key is not in templates/config.yml" "key: $key"
  done < <(grep -oE '`[a-z_]+(\.[a-z_]+)+`' "$file" | tr -d '`' | sort -u)
}

check_skill() {
  local skill=$1 anchors=$2 file="$root/skills/$1/SKILL.md" heading
  if ! exists_exact "$root" "skills/$skill/SKILL.md"; then
    _assert_fail "skills/$skill/SKILL.md does not exist"
    return
  fi
  check_frontmatter "$skill" "$file"
  for heading in "${REQUIRED_HEADINGS[@]}"; do
    grep -qxF -e "$heading" "$file" || _assert_fail "skills/$skill/SKILL.md: heading missing" "heading: $heading"
  done
  grep -qF -e "$DOCTRINE" "$file" || _assert_fail "skills/$skill/SKILL.md: doctrine line missing" "line: $DOCTRINE"
  check_anchors "$skill" "$file" "$anchors"
  check_plugin_paths "$skill" "$file"
  check_bare_paths "$skill" "$file"
  check_config_keys "$skill" "$file"
}

test_skills() {
  local anchors skill dir seen=0
  for anchors in "$root"/tests/anchors/*.txt; do
    [ -f "$anchors" ] || continue
    seen=$((seen + 1))
    skill=$(basename "$anchors" .txt)
    check_skill "$skill" "$anchors"
  done
  [ "$seen" -gt 0 ] || _assert_fail "tests/anchors/ has no <skill>.txt file"
  for dir in "$root"/skills/*/; do
    [ -d "$dir" ] || continue
    skill=$(basename "$dir")
    exists_exact "$root" "tests/anchors/$skill.txt" || _assert_fail "skills/$skill has no tests/anchors/$skill.txt"
  done
  [ "$require_core" = 1 ] || return 0
  for skill in "${CORE_SKILLS[@]}"; do
    if ! exists_exact "$root" "skills/$skill/SKILL.md" || ! exists_exact "$root" "tests/anchors/$skill.txt"; then
      _assert_fail "required skill '$skill' is missing" "needs: skills/$skill/SKILL.md and tests/anchors/$skill.txt"
    fi
  done
}

test_tool_names() {
  run_cmd bash "$TOOL_NAMES" "$root/skills"
  [ "$STATUS" -eq 0 ] || _assert_fail "skills/ names a tool product or stack (check-tool-names exit $STATUS)" "$OUT" "$ERR"
}

test_skills
test_tool_names
finish
