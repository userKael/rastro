# Golden path helpers shared by the doctor and the drift audit.
# Bash 3.2 compatible. Needs hooks/lib/config.sh sourced and RASTRO_CONFIG set.

# rastro_gp_folder: prints the golden path folder with a trailing slash
# (docs/golden-paths/ when the key is empty). Status 2, nothing printed, when
# the value is the old list form.
rastro_gp_folder() {
  local dir
  dir=$(rastro_config_get architecture.golden_paths 2>/dev/null) || dir=""
  dir=${dir:-docs/golden-paths/}
  case $dir in
    '['*) return 2 ;;
  esac
  case $dir in */) ;; *) dir=$dir/ ;; esac
  printf '%s\n' "$dir"
}

# rastro_gp_files ROOT FOLDER: prints the absolute path of each *.md in the
# folder except README.md, one per line, in alphabetical order.
rastro_gp_files() {
  local f
  for f in "$1/$2"*.md; do
    [ -f "$f" ] || continue
    [ "${f##*/}" != README.md ] || continue
    printf '%s\n' "$f"
  done
}

# rastro_gp_security FILE: prints missing, empty, none or ok for the ## Security section.
# A section whose lines are all unfilled template placeholders counts as empty.
rastro_gp_security() {
  awk '
    { sub(/\r$/, "") }
    !found && /^## Security[ \t]*$/ { found = 1; on = 1; next }
    on && /^##? / { exit }
    on && /[^ \t]/ {
      if ($0 !~ /^[ \t]*</ && index($0, "<threat>") == 0) text = 1
      if (index(tolower($0), "none identified")) { text = 1; none = 1 }
    }
    END { print (!found ? "missing" : !text ? "empty" : none ? "none" : "ok") }
  ' "$1"
}

# rastro_gp_seen_find SEEN TYPE: SEEN has one <type><TAB><rel> line per golden
# path already seen. Prints the rel of the first with that type (status 0), or
# nothing (status 1).
rastro_gp_seen_find() {
  local seen_t seen_rel
  while IFS=$'\t' read -r seen_t seen_rel; do
    if [ "$seen_t" = "$2" ]; then
      printf '%s\n' "$seen_rel"
      return 0
    fi
  done <<<"$1"
  return 1
}

# rastro_gp_instance_path ITEM: prints the path without a :<digits> suffix.
rastro_gp_instance_path() {
  local path=$1 v
  case $path in
    *:*[0-9])
      v=${path##*:}
      case $v in *[!0-9]*) ;; *) path=${path%:*} ;; esac
      ;;
  esac
  printf '%s\n' "$path"
}

# rastro_gp_list_has LIST ITEM: LIST is newline-separated text; status 0 when
# ITEM is a whole line of it.
rastro_gp_list_has() {
  case $'\n'"$1"$'\n' in
    *$'\n'"$2"$'\n'*) return 0 ;;
  esac
  return 1
}
