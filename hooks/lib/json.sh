_RASTRO_JSON_AWK='
function hexval(s,    i, n, d, v) {
  v = 0
  n = length(s)
  if (n != 4) return -1
  for (i = 1; i <= n; i++) {
    d = index("0123456789abcdef", tolower(substr(s, i, 1)))
    if (d == 0) return -1
    v = v * 16 + d - 1
  }
  return v
}

function utf8(cp) {
  if (cp == 0) return ""
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) return sprintf("%c%c", 192 + int(cp / 64), 128 + cp % 64)
  return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + int(cp / 64) % 64, 128 + cp % 64)
}

function read_string(i,    c, d, out, h) {
  out = ""
  i++
  while (i <= n) {
    c = substr(text, i, 1)
    if (c == "\"") { S = out; return i + 1 }
    if (c == "\\") {
      d = substr(text, i + 1, 1)
      i += 2
      if (d == "n") out = out "\n"
      else if (d == "t") out = out "\t"
      else if (d == "r") out = out "\r"
      else if (d == "b") out = out "\b"
      else if (d == "f") out = out "\f"
      else if (d == "u") {
        h = hexval(substr(text, i, 4))
        if (h >= 0) { out = out utf8(h); i += 4 }
        else out = out "u"
      }
      else out = out d
      continue
    }
    out = out c
    i++
  }
  S = out
  return i
}

function skip_space(j) {
  while (j <= n && substr(text, j, 1) ~ /[ \t\r\n]/) j++
  return j
}

function is_literal(j, word,    k) {
  if (substr(text, j, length(word)) != word) return 0
  k = substr(text, j + length(word), 1)
  return k == "" || k !~ /[A-Za-z0-9_]/
}

BEGIN { RS = "\001"; want = ENVIRON["RASTRO_JSON_FIELD"]; mode = ENVIRON["RASTRO_JSON_MODE"] }

{ text = text $0 }

END {
  n = length(text)
  i = 1
  while (i <= n) {
    if (substr(text, i, 1) != "\"") { i++; continue }
    i = read_string(i)
    if (S != want) continue
    j = skip_space(i)
    if (substr(text, j, 1) != ":") continue
    j = skip_space(j + 1)
    if (mode == "string") {
      if (substr(text, j, 1) == "\"") { read_string(j); printf "%s", S; exit }
    } else if (is_literal(j, "true")) { printf "true"; exit }
    else if (is_literal(j, "false")) { printf "false"; exit }
  }
}
'

rastro_json_string() {
  RASTRO_JSON_FIELD=$1 RASTRO_JSON_MODE=string LC_ALL=C awk "$_RASTRO_JSON_AWK"
}

rastro_json_bool() {
  RASTRO_JSON_FIELD=$1 RASTRO_JSON_MODE=bool LC_ALL=C awk "$_RASTRO_JSON_AWK"
}

rastro_json_escape() {
  local s=$1 i esc ch rep
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  if [[ $s == *[[:cntrl:]]* ]]; then
    for i in 1 2 3 4 5 6 7 8 11 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
      printf -v esc '\\x%02x' "$i"
      printf -v ch '%b' "$esc"
      printf -v rep '\\u%04x' "$i"
      s=${s//"$ch"/"$rep"}
    done
  fi
  printf '%s' "$s"
}
