# Helpers for tests/test_*.sh. Source this file.
FAILED=0
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (expected '$1', got '$2')"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "$3 (missing '$2')";; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "$3 (found '$2')";; esac; }
# mktemp -d without a template differs between GNU and BSD, so give it one.
mktempdir() { mktemp -d "${TMPDIR:-/tmp}/lr.XXXXXX"; }
finish() { exit "$FAILED"; }
# mkpath DIR TOOL...: a bin dir holding wrappers for exactly those tools, so a test's PATH is not the real one.
mkpath() {
  mkdir -p "$1"; local d=$1 t p; shift
  for t in "$@"; do
    p=$(command -v "$t") || continue
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" > "$d/$t"; chmod +x "$d/$t"
  done
}
