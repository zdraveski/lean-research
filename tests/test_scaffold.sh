#!/bin/bash
. "$(dirname "$0")/lib.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"
py=; for c in python3 python; do # a Windows Store or Xcode stub is on PATH but cannot run
  if command -v "$c" >/dev/null && "$c" -c 'import json' >/dev/null 2>&1; then py=$c; break; fi
done
if [ -z "$py" ]; then echo "  skip: no python"; exit 0; fi
for f in plugin marketplace; do
  out=$("$py" -I -m json.tool "$root/.claude-plugin/$f.json" 2>&1) || fail "$f.json does not parse: $out"
done
get() { "$py" -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$root/.claude-plugin/$1.json" "$2" 2>&1; }
assert_eq lean-research "$(get plugin 'd["name"]')" "plugin name"
assert_eq lean-research "$(get marketplace 'd["name"]')" "marketplace name"
assert_eq ./ "$(get marketplace 'd["plugins"][0]["source"]')" "marketplace source"
assert_eq MIT "$(get plugin 'd["license"]')" "plugin license"
assert_eq zdraveski "$(get plugin 'd["author"]["name"]')" "plugin author"
assert_eq zdraveski "$(get marketplace 'd["owner"]["name"]')" "marketplace owner"
assert_eq lean-research "$(get marketplace 'd["plugins"][0]["name"]')" "marketplace plugin name"
ga=$(cat "$root/.gitattributes" 2>&1)
assert_contains "$ga" "eol=lf" ".gitattributes eol=lf"
finish
