_RASTRO_CONFIG_AWK='
function clean(v,    i, n, c, q, prev) {
  sub(/^[ \t]+/, "", v)
  q = ""
  prev = ""
  n = length(v)
  for (i = 1; i <= n; i++) {
    c = substr(v, i, 1)
    if (q != "") {
      if (q == DQ && c == "\\") i++
      else if (c == q) { q = ""; prev = c }
      continue
    }
    if ((c == DQ || c == SQ) && (prev == "" || prev == "[" || prev == ",")) {
      q = c
      prev = c
      continue
    }
    if (c == "#" && (i == 1 || substr(v, i - 1, 1) ~ /[ \t]/)) {
      v = substr(v, 1, i - 1)
      break
    }
    if (c !~ /[ \t]/) prev = c
  }
  sub(/[ \t]+$/, "", v)
  return v
}

function unquote(v,    n, f, l, i, c, out) {
  n = length(v)
  if (n < 2) return v
  f = substr(v, 1, 1)
  l = substr(v, n, 1)
  if (f == DQ && l == DQ) {
    v = substr(v, 2, n - 2)
    n = length(v)
    out = ""
    for (i = 1; i <= n; i++) {
      c = substr(v, i, 1)
      if (c == "\\" && i < n && index(DQ "\\", substr(v, i + 1, 1))) {
        i++
        c = substr(v, i, 1)
      }
      out = out c
    }
    return out
  }
  if (f == SQ && l == SQ) {
    v = substr(v, 2, n - 2)
    gsub(SQ SQ, SQ, v)
  }
  return v
}

function emit_item(item) {
  sub(/^[ \t]+/, "", item)
  sub(/[ \t]+$/, "", item)
  if (item != "") print unquote(item)
}

function emit_list(v,    n, i, c, q, started, item, inner) {
  n = length(v)
  if (substr(v, 1, 1) != "[" || substr(v, n, 1) != "]") {
    if (v != "") print unquote(v)
    return
  }
  inner = substr(v, 2, n - 2)
  n = length(inner)
  q = ""
  started = 0
  item = ""
  for (i = 1; i <= n; i++) {
    c = substr(inner, i, 1)
    if (q != "") {
      item = item c
      if (q == DQ && c == "\\" && i < n) { i++; item = item substr(inner, i, 1) }
      else if (c == q) q = ""
      continue
    }
    if (c == ",") {
      emit_item(item)
      item = ""
      started = 0
      continue
    }
    if ((c == DQ || c == SQ) && !started) q = c
    if (c !~ /[ \t]/) started = 1
    item = item c
  }
  emit_item(item)
}

BEGIN { DQ = "\""; SQ = "\047"; depth = 0; found = 0; bad = 0; pending = 0 }

pending {
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ ]*(#|$)/) next
  match(line, /^[ ]*/)
  if (RLENGTH >= pindent && line ~ /^[ ]*-([ ]|$)/) { bad = 1; exit }
  pending = 0
  if (mode == "get") print ""
  exit
}

{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ ]*(#|$)/) next
  if (!match(line, /^[ ]*[A-Za-z_][A-Za-z0-9_-]*:([ ]|$)/)) next
  head = substr(line, 1, RLENGTH)
  rest = substr(line, RLENGTH + 1)
  indent = length(head)
  sub(/^[ ]+/, "", head)
  indent -= length(head)
  sub(/:[ ]?$/, "", head)
  while (depth > 0 && ind[depth] >= indent) depth--
  depth++
  ind[depth] = indent
  key[depth] = head
  path = key[1]
  for (i = 2; i <= depth; i++) path = path "." key[i]
  if (path != want) next
  found = 1
  if (mode == "has") exit
  v = clean(rest)
  if (substr(v, 1, 1) == "[" && substr(v, length(v), 1) != "]") { bad = 1; exit }
  if (v == "") { pending = 1; pindent = indent; next }
  if (mode == "get") print unquote(v)
  else emit_list(v)
  exit
}

END {
  if (bad) exit 2
  if (pending && mode == "get") print ""
  exit (found ? 0 : 1)
}
'

rastro_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s\n' "$CLAUDE_PROJECT_DIR"
  elif git rev-parse --show-toplevel 2>/dev/null; then
    :
  else
    pwd
  fi
}

rastro_config_path() {
  local p="${RASTRO_CONFIG:-$(rastro_root)/.rastro/config.yml}"
  [ -f "$p" ] || return 1
  printf '%s\n' "$p"
}

_rastro_config_scan() {
  local file
  file=$(rastro_config_path) || return 1
  awk -v mode="$1" -v want="$2" "$_RASTRO_CONFIG_AWK" "$file"
}

rastro_config_has() {
  _rastro_config_scan has "$1" >/dev/null
}

_rastro_config_read() {
  local rc=0
  _rastro_config_scan "$1" "$2" || rc=$?
  if [ "$rc" -eq 2 ]; then
    printf 'rastro: config key %s uses an unsupported list form; write it inline as [a, b]\n' "$2" >&2
    return 2
  fi
  return 0
}

rastro_config_get() {
  _rastro_config_read get "$1"
}

rastro_config_list() {
  _rastro_config_read list "$1"
}

rastro_workspace() {
  if rastro_config_has workspace; then
    rastro_config_get workspace
  else
    printf '%s\n' .agent/
  fi
}

rastro_merge_mode() {
  local mode=""
  if rastro_config_has code_host.merge; then
    mode=$(rastro_config_get code_host.merge) || return $?
  fi
  printf '%s\n' "${mode:-squash}"
}
