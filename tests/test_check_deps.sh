#!/bin/bash
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
CD="$here/../skills/lean-research/check-deps.sh"
T=$(mktempdir); trap 'rm -rf "$T"' EXIT
mkpath "$T/bin" bash curl uname

OUT=$(PATH="$T/bin:$here/stubs" "$BASH" "$CD" 2>&1); RC=$?
assert_eq 0 "$RC" "all present: exit"
assert_contains "$OUT" "note: pdftotext not found, PDFs will be skipped" "pdftotext note"

mkdir "$T/pdf"; printf '#!/bin/sh\n' > "$T/pdf/pdftotext"; chmod +x "$T/pdf/pdftotext"
OUT=$(PATH="$T/bin:$here/stubs:$T/pdf" "$BASH" "$CD" 2>&1)
assert_not_contains "$OUT" "pdftotext" "no note when pdftotext present"

OUT=$(PATH="$T/bin" "$BASH" "$CD" 2>&1); RC=$?
assert_eq 1 "$RC" "missing browsers: exit"
assert_contains "$OUT" "https://github.com/lexmount/moli" "moli link"
assert_contains "$OUT" "https://github.com/h4ckf0r0day/obscura" "obscura link"
assert_contains "$OUT" "moli-installer" "moli install command"
assert_contains "$OUT" "download the STEALTH build" "stealth build named"
assert_contains "$OUT" "-stealth." "stealth asset name"
finish
