#!/bin/bash
# Online smoke test: needs network, Moli, Obscura (stealth) and, for the PDF check, pdftotext.
# Not run by tests/run.sh (that only takes test_*.sh).
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d) || exit 1; trap 'rm -rf "$tmp"' EXIT
cp -R "$root/skills/lean-research/." "$tmp/"   # fetch.sh writes pages/ and pages.csv next to itself
rm -rf "$tmp/pages" "$tmp/pages.csv"   # a local cache would answer "cache" instead of "ok"
fails=0
check() { if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails+1)); fi; }

bash "$tmp/check-deps.sh"; check "check-deps exits 0" $?

page=https://en.wikipedia.org/wiki/Markdown
bash "$tmp/webread" "$page" > "$tmp/w.out" 2> "$tmp/w.err"; check "webread exits 0" $?
n=$(wc -c < "$tmp/w.out" | tr -d ' ')
[ "$n" -ge 1000 ]; check "webread returns >= 1000 bytes ($n)" $?
grep -q '^webread: ' "$tmp/w.err"; check "webread names a reader ($(head -1 "$tmp/w.err"))" $?

pdf=https://www.rfc-editor.org/rfc/rfc2616.pdf
if command -v pdftotext >/dev/null; then urls="$page $pdf"; else urls=$page; echo "SKIP pdf: pdftotext not installed"; fi
# shellcheck disable=SC2086
bash "$tmp/fetch.sh" smoke $urls; echo
status() { awk -F, -v u="\"$1\"" '$2==u {print $(NF-1)}' "$tmp/pages.csv" | tail -1; }
reader() { awk -F, -v u="\"$1\"" '$2==u {print $NF}' "$tmp/pages.csv" | tail -1; }
[ "$(status $page)" = ok ]; check "fetch.sh: wikipedia ok" $?
if command -v pdftotext >/dev/null; then
  [ "$(status $pdf)" = ok ]; check "fetch.sh: pdf ok" $?
  [ "$(reader $pdf)" = pdftotext ]; check "fetch.sh: pdf reader pdftotext" $?
fi
exit $((fails > 0))
