exists_exact() {
  local dir=$1 rest=$2 name entry found
  while [ -n "$rest" ]; do
    name=${rest%%/*}
    case $rest in
      */*) rest=${rest#*/} ;;
      *) rest='' ;;
    esac
    case $name in '' | .) continue ;; esac
    found=0
    for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
      [ -e "$entry" ] || continue
      if [ "${entry##*/}" = "$name" ]; then
        found=1
        break
      fi
    done
    [ "$found" -eq 1 ] || return 1
    dir="$dir/$name"
  done
  case $2 in
    */) [ -d "$dir" ] ;;
    *) [ -e "$dir" ] ;;
  esac
}
