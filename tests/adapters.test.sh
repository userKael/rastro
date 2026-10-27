tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$tests_dir/lib/assert.sh"
. "$tests_dir/lib/exact.sh"
export LC_ALL=C.UTF-8
root=$(cd "${1:-$tests_dir/..}" && pwd)
contract="$root/adapters/CONTRACT.md"
REQUIRED_ADAPTERS=(
  tracker/jira tracker/github tracker/local tracker/none
  docs/notion docs/repo
  code-host/github code-host/gitlab code-host/none
  domain-state/db-mcp domain-state/schema-files domain-state/none
  review/none
)

contract_model() {
  awk '
    { sub(/\r$/, "") }
    /^## Port:/ {
      port = ""
      if (match($0, /^## Port: [^ ]+ \(config: [^)]+\)[ \t]*$/)) {
        port = $3
        print "PORT " port
      } else {
        print "BADPORT " $0
      }
      next
    }
    /^## / { port = ""; next }
    port != "" && /^- `[^`]+`/ {
      cap = $0
      sub(/^- `/, "", cap)
      sub(/`.*/, "", cap)
      print "CAP " port " " cap
    }
  ' "$contract"
}

adapter_problems() {
  CAPS="$3" awk -v dir="$1" -v kind="$2" '
    BEGIN { n = split(ENVIRON["CAPS"], caps, "\n") }
    { sub(/\r$/, "") }
    $0 == "# Adapter: " dir "/" kind { title = 1 }
    /^## / { section = $0 }
    section == "## Requirements" && /^(REQUIRED MCP:|REQUIRED CLI:|REQUIRED: none)/ { requirement = 1 }
    $0 == "## Capabilities" { has_capabilities = 1 }
    section == "## Capabilities" && /^### / { headings[$0] = 1 }
    $0 == "## Known limits" { has_limits = 1 }
    END {
      if (!title) print "title"
      if (!requirement) print "requirement"
      if (!has_capabilities) print "capabilities"
      else for (i = 1; i <= n; i++) if (caps[i] != "" && !(("### " caps[i]) in headings)) print "capability " caps[i]
      if (!has_limits) print "limits"
    }
  ' "$4"
}

check_adapter() {
  local dir=$1 kind=$2 file=$3 caps=$4 rel="adapters/$1/$2.md" problem
  while IFS= read -r problem; do
    case $problem in
      title) _assert_fail "$rel: title is not '# Adapter: $dir/$kind'" ;;
      requirement) _assert_fail "$rel: ## Requirements has no line starting with REQUIRED MCP:, REQUIRED CLI: or REQUIRED: none" ;;
      capabilities) _assert_fail "$rel: heading missing" "heading: ## Capabilities" ;;
      capability\ *) _assert_fail "$rel: capability heading missing under ## Capabilities" "heading: ### ${problem#capability }" ;;
      limits) _assert_fail "$rel: heading missing" "heading: ## Known limits" ;;
    esac
  done < <(adapter_problems "$dir" "$kind" "$caps" "$file")
}

test_contract() {
  local line tag rest port ports=' ' capped=' ' has_ports=0
  if ! exists_exact "$root" "adapters/CONTRACT.md"; then
    _assert_fail "adapters/CONTRACT.md does not exist"
    return
  fi
  CONTRACT_MODEL=$(contract_model)
  while IFS= read -r line; do
    tag=${line%% *}
    rest=${line#* }
    case $tag in
      PORT)
        ports+="$rest "
        has_ports=1
        ;;
      CAP) capped+="${rest%% *} " ;;
      BADPORT) _assert_fail "adapters/CONTRACT.md: malformed port heading, expected '## Port: <dir> (config: <key>)'" "found: $rest" ;;
    esac
  done <<<"$CONTRACT_MODEL"
  [ "$has_ports" -eq 1 ] || _assert_fail "adapters/CONTRACT.md declares no '## Port: <dir> (config: <key>)' section"
  for port in $ports; do
    case $capped in
      *" $port "*) ;;
      *) _assert_fail "adapters/CONTRACT.md: port $port lists no capability bullet" "expected: - \`<capability>\`" ;;
    esac
  done
  CONTRACT_PORTS=$ports
}

test_adapters() {
  local file rel dir kind rest tag port cap caps
  for rel in "${REQUIRED_ADAPTERS[@]}"; do
    exists_exact "$root" "adapters/$rel.md" || _assert_fail "adapters/$rel.md does not exist"
  done
  for file in "$root"/adapters/*/*.md; do
    [ -f "$file" ] || continue
    rest=${file#"$root/adapters/"}
    dir=${rest%%/*}
    kind=${rest##*/}
    kind=${kind%.md}
    case ${CONTRACT_PORTS:- } in
      *" $dir "*) ;;
      *)
        _assert_fail "adapters/$dir/$kind.md: no '## Port: $dir (config: <key>)' section in adapters/CONTRACT.md"
        continue
        ;;
    esac
    caps=''
    while IFS=' ' read -r tag port cap; do
      [ "$tag" = CAP ] && [ "$port" = "$dir" ] && caps+="$cap"$'\n'
    done <<<"$CONTRACT_MODEL"
    check_adapter "$dir" "$kind" "$file" "$caps"
  done
}

test_contract
test_adapters
finish
