# Reads the YAML-like frontmatter of a markdown file: the block between the first
# line (---) and the next --- line. Only top-level `key: value` lines are read.

# _rastro_fm_value FILE KEY: prints the trimmed raw value of KEY.
# Status: 0 found (value may be empty), 1 key absent, 2 no frontmatter.
_rastro_fm_value() {
  tr -d '\r' <"$1" | awk -v key="$2" '
    NR == 1 { if ($0 != "---") { bad = 1; exit } next }
    $0 == "---" { closed = 1; exit }
    !found && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      found = 1; val = v
    }
    END {
      if (bad || !closed) exit 2
      if (!found) exit 1
      print val
    }
  '
}

# rastro_frontmatter_get FILE KEY: prints the value, without one pair of
# surrounding quotes. Nothing after a # is dropped.
# Status: 0 found, 1 key absent, 2 no frontmatter (missing or unclosed).
rastro_frontmatter_get() {
  local v s
  v=$(_rastro_fm_value "$1" "$2"); s=$?
  [ "$s" -eq 0 ] || return "$s"
  case $v in
    \"?*\") v=${v#\"}; v=${v%\"} ;;
    \'?*\') v=${v#\'}; v=${v%\'} ;;
  esac
  printf '%s\n' "$v"
}

# rastro_frontmatter_list FILE KEY: prints the items of an inline list
# `[a, b]`, one per line, trimmed and unquoted.
# Status: 0 ok, 1 key absent, 2 no frontmatter, 3 value is not an inline list.
rastro_frontmatter_list() {
  local v s
  v=$(_rastro_fm_value "$1" "$2"); s=$?
  [ "$s" -eq 0 ] || return "$s"
  case $v in
    \[*\]) ;;
    *) return 3 ;;
  esac
  v=${v#\[}; v=${v%\]}
  printf '%s\n' "$v" | awk '
    {
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        s = a[i]
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
        if (s != "") print s
      }
    }
  '
}
