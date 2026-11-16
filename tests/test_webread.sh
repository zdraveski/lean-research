#!/bin/bash
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
WR="$here/../skills/lean-research/webread"
T=$(mktempdir); trap 'rm -rf "$T"' EXIT
mkpath "$T/bin" bash grep mktemp rm cat sleep
export STUB_LOG="$T/log"
good=$(head -c 2000 /dev/zero | tr '\0' 'a'); small=$(head -c 300 /dev/zero | tr '\0' 'a')
wall="Just a moment... $good"

run() { # run STUBDIR: sets OUT, ERR, RC
  : > "$STUB_LOG"
  OUT=$(PATH="$T/bin:$1" "$BASH" "$WR" http://x.test 2>"$T/err"); RC=$?; ERR=$(cat "$T/err")
}

STUB_MOLI_OUT=$good STUB_OBSCURA_OUT= run "$here/stubs"
assert_eq 0 "$RC" "moli good: exit"; assert_eq "$good" "$OUT" "moli good: stdout"; assert_eq "webread: moli" "$ERR" "moli good: stderr"
assert_contains "$(cat "$STUB_LOG")" "moli fetch --dump markdown http://x.test" "moli args"

STUB_MOLI_OUT=$small STUB_OBSCURA_OUT=$good run "$here/stubs"
assert_eq "webread: obscura" "$ERR" "small moli falls to obscura"
assert_contains "$(cat "$STUB_LOG")" "obscura --stealth fetch --dump markdown http://x.test" "obscura args"

STUB_MOLI_OUT=$wall STUB_OBSCURA_OUT=$good run "$here/stubs"
assert_eq "webread: obscura" "$ERR" "bot wall falls to obscura"

STUB_MOLI_OUT=$wall STUB_OBSCURA_OUT=$wall run "$here/stubs"
assert_eq 1 "$RC" "all walled: exit"; assert_contains "$ERR" "webread: blocked" "all walled: stderr"
assert_contains "$(cat "$STUB_LOG")" "obscura --stealth fetch --wait 25 --dump markdown http://x.test" "long-wait call"

STUB_MOLI_OUT=$good run "$here/stubs-exe"
assert_eq "webread: moli" "$ERR" ".exe stubs found"

STUB_MOLI_OUT=$good run ""; assert_eq 1 "$RC" "no browsers: exit"

OUT=$(PATH="$T/bin:$here/stubs" "$BASH" "$WR" 2>/dev/null); assert_eq 2 "$?" "no argument: exit"

start=$(date +%s)
STUB_MOLI_SLEEP=30 STUB_MOLI_OUT=$good STUB_OBSCURA_OUT=$good run "$here/stubs"
took=$(( $(date +%s) - start ))
assert_eq "webread: obscura" "$ERR" "slow moli falls to obscura"
[ "$took" -lt 25 ] || fail "slow moli took ${took}s"
finish
