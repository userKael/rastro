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
    \"*\") v=${v#\"}; v=${v%\"} ;;
    \'*\') v=${v#\'}; v=${v%\'} ;;
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

# rastro_frontmatter_dump FILE: reads the frontmatter once and prints
# `key<TAB>value` for each top-level key, the value processed as
# rastro_frontmatter_get does it (CR removed, trimmed, one pair of surrounding
# quotes removed, nothing after a # dropped). A repeated key keeps its first
# value. Status: 0 ok, 2 no frontmatter (missing or unclosed).
rastro_frontmatter_dump() {
  tr -d '\r' <"$1" | awk '
    NR == 1 { if ($0 != "---") { bad = 1; exit } next }
    $0 == "---" { closed = 1; exit }
    {
      i = index($0, ":")
      if (i < 2) next
      k = substr($0, 1, i - 1)
      if (k ~ /[ \t]/ || (k in seen)) next
      seen[k] = 1
      v = substr($0, i + 1)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      n = length(v)
      if (n >= 2) {
        c = substr(v, 1, 1)
        if ((c == "\"" || c == "\047") && substr(v, n, 1) == c) v = substr(v, 2, n - 2)
      }
      out = out k "\t" v "\n"
    }
    END {
      if (bad || !closed) exit 2
      printf "%s", out
    }
  '
}

# rastro_frontmatter_split VALUE: splits the value of an inline list `[a, b]`
# into the array RASTRO_FM_ITEMS, items trimmed and unquoted, with the same
# item rules as rastro_frontmatter_list. It starts no process, so the caller
# must not run it in a subshell. Status: 0 ok, 3 VALUE is not an inline list.
rastro_frontmatter_split() {
  local v=$1 item
  local -a raw
  RASTRO_FM_ITEMS=()
  case $v in
    \[*\]) ;;
    *) return 3 ;;
  esac
  v=${v#\[}; v=${v%\]}
  raw=()
  IFS=, read -r -a raw <<<"$v"
  for item in ${raw[@]+"${raw[@]}"}; do
    item=${item#"${item%%[![:space:]]*}"}
    item=${item%"${item##*[![:space:]]}"}
    case $item in
      \"*\" | \'*\') item=${item#?}; item=${item%?} ;;
    esac
    [ -z "$item" ] || RASTRO_FM_ITEMS[${#RASTRO_FM_ITEMS[@]}]=$item
  done
  return 0
}
