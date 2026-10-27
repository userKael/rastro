#!/usr/bin/env bash
set -eu
lib=${RASTRO_LIB:-$(dirname "$0")/../lib}
. "$lib/config.sh"
. "$lib/json.sh"
RASTRO_CONFIG=$(rastro_config_path) || exit 0

_GUARD_AWK='
function deny(msg) {
  if (index(reason, msg) == 0) reason = reason msg "\n"
}

function plain(s) {
  gsub(PH, "", s)
  return s
}

function unesc(s,    out, i, n, c, esc) {
  esc = ps ? "`" : "\\"
  out = ""
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == esc && i < n) { i++; c = substr(s, i, 1) }
    out = out c
  }
  return out
}

function endtok(d) {
  if (!have[d]) return
  if (redir[d]) redir[d] = 0
  else { ntok[d]++; seg[d, ntok[d]] = tokv[d]; raw[d, ntok[d]] = rawv[d] }
  tokv[d] = ""
  rawv[d] = ""
  have[d] = 0
}

function hookpath(v) {
  if (tolower(v) ~ /^core\.hookspath(=|$)/) deny(MSG_HOOKS_OVERRIDE)
}

function check_config(d, from, nt,    k, a, dd, np, p, sc, unset, get, name, val) {
  dd = 0; np = 0; unset = 0; get = 0
  for (k = from; k <= nt; k++) {
    a = raw[d, k]
    if (!dd && a == "--") { dd = 1; continue }
    if (!dd && a ~ /^-/) {
      if (a ~ /^--unset(-all)?$/) unset = 1
      else if (a ~ /^(--get(-all|-regexp|-urlmatch)?|-l|--list|-e|--edit)$/) get = 1
      else if (a ~ /^(-f|--file|--blob|--type|--default|--comment|--value)$/) k++
      continue
    }
    p[++np] = a
  }
  if (np == 0) return
  sc = ""
  if (p[1] ~ /^(set|unset|get|list|edit|rename-section|remove-section|get-color|get-colorbool)$/) {
    sc = p[1]
    name = p[2]
    val = p[3]
    if (sc == "unset") unset = 1
    else if (sc != "set") return
  } else {
    name = p[1]
    val = p[2]
  }
  if (tolower(name) != "core.hookspath") return
  if (unset) { deny(MSG_HOOKS_SET); return }
  if (get || (sc == "" && np < 2)) return
  if (ps) gsub(/\\/, "/", val)
  sub(/^\.\//, "", val)
  sub(/\/+$/, "", val)
  if (val != ".rastro/git-hooks") deny(MSG_HOOKS_SET)
}

function endseg(d) {
  endtok(d)
  if (ntok[d] > 0) analyze(d)
  ntok[d] = 0
  redir[d] = 0
}

function cites(a,    p) {
  if (ws == "") return
  p = a
  if (ps) gsub(/\\/, "/", p)
  sub(/^\.\//, "", p)
  if (p == ws || index(p, ws "/") == 1) deny("the workspace " ws "/ never goes into a commit; leave it out of git add and git commit")
}

function check_add(d, from, nt,    k, a, dd) {
  dd = 0
  for (k = from; k <= nt; k++) {
    a = plain(seg[d, k])
    if (a == "") continue
    if (!dd && a == "--") { dd = 1; continue }
    if (!dd && a ~ /^--/) {
      if (a == "--all" || a == "--no-ignore-removal") deny(MSG_ADD)
      continue
    }
    if (!dd && a ~ /^-[A-Za-z]+$/) {
      if (index(a, "A")) deny(MSG_ADD)
      continue
    }
    if (a ~ /^(\.|\.\/|\*|\.\/\*)$/) deny(MSG_ADD)
    cites(a)
  }
}

function check_commit(d, from, nt,    k, t, a, dd, p, ch) {
  dd = 0
  for (k = from; k <= nt; k++) {
    t = seg[d, k]
    a = plain(t)
    if (a == "") continue
    if (!dd && a == "--") { dd = 1; continue }
    if (!dd && a ~ /^--/) {
      if (a == "--all") deny(MSG_COMMIT)
      else if (a == "--no-verify") deny(MSG_VERIFY)
      else if (a ~ /^--(message|file|reuse-message|reedit-message|author|date|template|fixup|squash|cleanup|trailer|pathspec-from-file)$/) k++
      continue
    }
    if (!dd && t ~ /^-[A-Za-z]/) {
      for (p = 2; p <= length(t); p++) {
        ch = substr(t, p, 1)
        if (ch == "a") deny(MSG_COMMIT)
        else if (ch == "n") deny(MSG_VERIFY)
        else if (index("mFCct", ch) > 0) { if (p == length(t)) k++; break }
        else if (ch == "S" || ch == "u") break
        else if (ch !~ /[A-Za-z]/) break
      }
      continue
    }
    cites(a)
  }
}

function analyze(d,    nt, i, t, b, wrapped, sc) {
  nt = ntok[d]
  wrapped = 0
  for (i = 1; i <= nt; i++) {
    t = seg[d, i]
    if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    if (t in SKIP) { if (t in WRAP) wrapped = 1; continue }
    if (wrapped && t ~ /^-/) continue
    break
  }
  if (i > nt) return
  b = seg[d, i]
  sub(/^.*\//, "", b)
  if (b != "git" && b != "git.exe") return
  for (i++; i <= nt; i++) {
    t = plain(seg[d, i])
    if ((t == "-c" || t == "--config-env") && i < nt) hookpath(raw[d, i + 1])
    else if (t ~ /^--config-env=/) hookpath(substr(raw[d, i], 14))
    if (t ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--super-prefix|--config-env)$/) { i++; continue }
    if (t ~ /^-/) continue
    break
  }
  if (i > nt) return
  sc = plain(seg[d, i])
  if (sc == "add") check_add(d, i + 1, nt)
  else if (sc == "commit") check_commit(d, i + 1, nt)
  else if (sc == "config") check_config(d, i + 1, nt)
}

function heredoc(d,    p, dash, hw, ch, e) {
  p = pos + 2
  dash = 0
  if (substr(text, p, 1) == "-") { dash = 1; p++ }
  while (substr(text, p, 1) == " " || substr(text, p, 1) == "\t") p++
  hw = ""
  while (p <= len) {
    ch = substr(text, p, 1)
    if (ch == SQ || ch == DQ) {
      e = index(substr(text, p + 1), ch)
      if (e == 0) break
      hw = hw substr(text, p + 1, e - 1)
      p += e + 1
    } else if (ch == "\\") {
      hw = hw substr(text, p + 1, 1)
      p += 2
    } else if (ch ~ /[ \t\r\n;|&()<>]/) break
    else { hw = hw ch; p++ }
  }
  if (hw !~ /^[A-Za-z_][A-Za-z0-9_.-]*$/) return 0
  endtok(d)
  nhd[d]++
  hdw[d, nhd[d]] = hw
  hdd[d, nhd[d]] = dash
  pos = p
  return 1
}

function heredoc_bodies(d,    k, line, e) {
  for (k = 1; k <= nhd[d]; k++) {
    while (pos <= len) {
      e = index(substr(text, pos), NL)
      if (e == 0) { line = substr(text, pos); pos = len + 1 }
      else { line = substr(text, pos, e - 1); pos += e }
      sub(/\r$/, "", line)
      if (hdd[d, k]) sub(/^\t+/, "", line)
      if (line == hdw[d, k]) break
    }
  }
  nhd[d] = 0
}

function dquote(d,    c, e) {
  while (pos <= len) {
    c = substr(text, pos, 1)
    if (c == "\\" && !ps) { pos += 2; continue }
    if (c == "`" && ps) { pos += 2; continue }
    if (c == DQ) { pos++; return }
    if (c == "$" && substr(text, pos + 1, 1) == "(") { pos += 2; lex(d + 1); continue }
    if (c == "`") {
      pos++
      e = index(substr(text, pos), "`")
      if (e == 0) pos = len + 1
      else pos += e
      continue
    }
    pos++
  }
}

function herestring(d,    q, p, e) {
  q = substr(text, pos + 1, 1)
  p = pos + 2
  while (substr(text, p, 1) == " " || substr(text, p, 1) == "\t" || substr(text, p, 1) == "\r") p++
  if (substr(text, p, 1) != NL) return 0
  e = index(substr(text, p), NL q "@")
  if (e == 0) pos = len + 1
  else pos = p + e + 2
  tokv[d] = tokv[d] PH; have[d] = 1
  return 1
}

function lex(d,    c, e, x, s) {
  ntok[d] = 0; tokv[d] = ""; rawv[d] = ""; have[d] = 0; redir[d] = 0; pd[d] = 0; nhd[d] = 0
  while (pos <= len) {
    c = substr(text, pos, 1)
    if (c == "\\" && !ps) {
      x = substr(text, pos + 1, 1)
      pos += 2
      if (x != NL) { tokv[d] = tokv[d] x; rawv[d] = rawv[d] x; have[d] = 1 }
      continue
    }
    if (c == "`" && ps) {
      x = substr(text, pos + 1, 1)
      pos += 2
      if (x == "\r" && substr(text, pos, 1) == NL) pos++
      if (x == NL || x == "\r") endtok(d)
      else if (x != "") { tokv[d] = tokv[d] x; rawv[d] = rawv[d] x; have[d] = 1 }
      continue
    }
    if (c == "@" && ps && (substr(text, pos + 1, 1) == SQ || substr(text, pos + 1, 1) == DQ) && herestring(d)) continue
    if (c == SQ) {
      pos++
      s = pos
      e = index(substr(text, pos), SQ)
      if (e == 0) { rawv[d] = rawv[d] substr(text, s); pos = len + 1 }
      else { rawv[d] = rawv[d] substr(text, s, e - 1); pos += e }
      tokv[d] = tokv[d] PH; have[d] = 1
      continue
    }
    if (c == DQ) {
      pos++
      s = pos
      dquote(d)
      rawv[d] = rawv[d] unesc(substr(text, s, pos - s - 1))
      tokv[d] = tokv[d] PH; have[d] = 1
      continue
    }
    if (c == " " || c == "\t" || c == "\r") { endtok(d); pos++; continue }
    if (c == NL) { pos++; endseg(d); heredoc_bodies(d); continue }
    if (c == ";" || c == "|" || c == "&" || c == "`") { pos++; endseg(d); continue }
    if (c == "(") { pos++; endseg(d); pd[d]++; continue }
    if (c == ")") {
      pos++
      endseg(d)
      if (pd[d] > 0) pd[d]--
      else if (d > 0) return
      continue
    }
    if (c == "#" && !have[d]) {
      e = index(substr(text, pos), NL)
      if (e == 0) pos = len + 1
      else pos += e - 1
      continue
    }
    if (c == "<" || c == ">") {
      if (c == "<" && substr(text, pos + 1, 1) == "<") {
        if (substr(text, pos + 2, 1) == "<") { endtok(d); pos += 3; redir[d] = 1; continue }
        if (!ps && heredoc(d)) continue
      }
      endtok(d)
      pos++
      redir[d] = 1
      continue
    }
    tokv[d] = tokv[d] c; rawv[d] = rawv[d] c; have[d] = 1; pos++
  }
  endseg(d)
}

BEGIN {
  RS = "\001"
  SQ = "\047"; DQ = "\""; NL = "\n"; PH = "\002"
  ps = (ENVIRON["RASTRO_SHELL"] == "powershell")
  ws = ENVIRON["RASTRO_WORKSPACE"]
  sub(/^\.\//, "", ws)
  sub(/\/+$/, "", ws)
  MSG_ADD = "git add -A, --all, . and * stage everything; name each path instead: git add <path> ..."
  MSG_COMMIT = "git commit -a and --all stage every tracked change; stage each path with git add <path>, then run git commit"
  MSG_VERIFY = "git commit --no-verify (-n) skips the commit hooks; fix what the hook reported and commit again"
  MSG_HOOKS_OVERRIDE = "a core.hooksPath override on the git command line skips the rastro hooks; fix what the hook reported and run the command again"
  MSG_HOOKS_SET = "core.hooksPath stays .rastro/git-hooks, where setup installs the rastro hooks; git config may set it to that value only"
  nk = split("{ ! if then else elif do while until time command env sudo exec nohup nice xargs builtin", kw, " ")
  for (i = 1; i <= nk; i++) SKIP[kw[i]] = 1
  nk = split("command env sudo exec nohup nice xargs time builtin", kw, " ")
  for (i = 1; i <= nk; i++) WRAP[kw[i]] = 1
}

{ text = text $0 }

END {
  len = length(text)
  pos = 1
  lex(0)
  printf "%s", reason
}
'

input=$(cat)
cmd=$(rastro_json_string command <<<"$input")
case $cmd in
  *git*) ;;
  *) exit 0 ;;
esac
shell=bash
[ "$(rastro_json_string tool_name <<<"$input")" != PowerShell ] || shell=powershell
workspace=$(rastro_workspace)
reason=$(printf '%s' "$cmd" | RASTRO_WORKSPACE=$workspace RASTRO_SHELL=$shell LC_ALL=C awk "$_GUARD_AWK")
if [ -n "$reason" ]; then
  printf 'rastro: git command blocked\n%s\n' "$reason" >&2
  exit 2
fi
