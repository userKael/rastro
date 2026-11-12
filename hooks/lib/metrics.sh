# Lint metrics shared by the lint hook (writer) and the drift audit (reader).
# Bash 3.2 compatible. The log is <workspace>/metrics/lint.log, one line per verdict:
# <epoch><TAB><session><TAB><path><TAB><pass|fail>. It lives in the gitignored workspace.

# rastro_metrics_lint_record ROOT REL RESULT SESSION: appends one verdict. Needs
# hooks/lib/config.sh sourced and RASTRO_CONFIG set. Any failure is swallowed
# and the status is always 0: losing a metric must never change a verdict.
rastro_metrics_lint_record() {
  local root=$1 rel=$2 result=$3 session=${4:--} ws dir
  {
    ws=$(rastro_workspace) || ws=.agent/
    ws=${ws%/}
    dir=$root/${ws:-.agent}/metrics
    mkdir -p "$dir" || return 0
    printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$session" "$rel" "$result" >>"$dir/lint.log"
  } 2>/dev/null || true
  return 0
}

# rastro_metrics_lint_summary FILE: prints the first-pass and self-heal lines.
# A file is a (session, path) pair. First-pass: the first lint of the pair
# passed. Self-heal: of the pairs whose first lint failed, those that passed later.
rastro_metrics_lint_summary() {
  local file=$1
  if [ ! -f "$file" ]; then
    printf 'first-pass: no data\nself-heal: no data\n'
    return 0
  fi
  tr -d '\r' <"$file" | awk -F'\t' '
    NF >= 4 && ($4 == "pass" || $4 == "fail") {
      k = $2 "\t" $3
      if (!(k in first)) { first[k] = $4; n++; if ($4 == "pass") p++; else f++ }
      else if ($4 == "pass" && first[k] == "fail" && !(k in healed)) { healed[k] = 1; h++ }
    }
    END {
      if (n == 0) printf "first-pass: no data\n"
      else printf "first-pass: %d of %d files (%d%%)\n", p, n, int(p * 100 / n)
      if (f == 0) printf "self-heal: no data\n"
      else printf "self-heal: %d of %d files (%d%%)\n", h, f, int(h * 100 / f)
    }
  '
}
