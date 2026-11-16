#!/bin/bash
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
S="$here/../skills/lean-research/start.sh"
T=$(mktempdir); trap 'rm -rf "$T"' EXIT
mkpath "$T/bin" bash curl uname mkdir cp chmod date grep tail cat dirname pwd
mkdir "$T/work dir"; cd "$T/work dir" || exit 1
P="$T/bin:$here/stubs"

OUT=$(PATH="$P" "$BASH" "$S" "My title" 2>&1); RC=$?
assert_eq 0 "$RC" "new title: exit"
D="$PWD/research_notes/My title"
assert_eq "$D" "$(echo "$OUT" | tail -n 1)" "last line is the absolute folder"
[ -x "$D/fetch.sh" ] || fail "fetch.sh copied and executable"
[ -x "$D/webread" ] || fail "webread copied and executable"
[ -d reports ] || fail "reports/ created"
assert_eq "agent,query,time" "$(cat "$D/searches.csv")" "searches.csv header"
case $(cat "$D/started.txt") in 20??-??-??T??:??:??Z) ;; *) fail "started.txt format";; esac

PATH="$P" "$BASH" "$S" "My title" >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "same title again: exit"

PATH="$T/bin" "$BASH" "$S" "Other" >/dev/null 2>&1; RC=$?
assert_eq 1 "$RC" "deps missing: exit"
[ -e "research_notes/Other" ] && fail "deps missing: no folder"

rm -rf research_notes; mkdir research_notes; printf 'notes.txt\n' > research_notes/.gitignore
PATH="$P" "$BASH" "$S" "A" >/dev/null 2>&1; PATH="$P" "$BASH" "$S" "B" >/dev/null 2>&1
assert_eq "notes.txt
*/pages/" "$(cat research_notes/.gitignore)" ".gitignore kept and one */pages/"
finish
