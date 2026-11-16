# Helpers for tests/test_*.sh. Source this file.
FAILED=0
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (expected '$1', got '$2')"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "$3 (missing '$2')";; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "$3 (found '$2')";; esac; }
# mktemp -d without a template differs between GNU and BSD, so give it one.
mktempdir() { mktemp -d "${TMPDIR:-/tmp}/lr.XXXXXX"; }
finish() { exit "$FAILED"; }
