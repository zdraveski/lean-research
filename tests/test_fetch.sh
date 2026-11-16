#!/bin/bash
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
T=$(mktempdir); trap 'rm -rf "$T"' EXIT
good=$(head -c 2000 /dev/zero | tr '\0' 'a'); small=$(head -c 300 /dev/zero | tr '\0' 'a')
mkdir -p "$T/pages src"; printf 'line one\nthe needle is here\nline three\n%s\n' "$good" > "$T/pages src/a.test"
export STUB_PAGES="$T/pages src"

newdir() { # copies fetch.sh and the stub into a fresh folder with a space in its name
  N="$T/$1/dir with space"; mkdir -p "$N"
  cp "$here/../skills/lean-research/fetch.sh" "$here/stubs/webread" "$N/"
}
rows() { grep -c . "$N/pages.csv"; }

newdir ok
OUT=$(STUB_BODY=$good bash "$N/fetch.sh" ag http://a.test/p)
assert_contains "$OUT" "ok " "good page: ok"
assert_eq 1 "$(ls "$N/pages" | grep -c '^[0-9a-f]\{12\}\.md$')" "good page: saved"
assert_eq 2 "$(rows)" "good page: header plus one row"
assert_contains "$(tail -1 "$N/pages.csv")" ',ok,stub' "good page: status and reader"
assert_eq 7 "$(tail -1 "$N/pages.csv" | awk -F, '{print NF}')" "no stray commas"
OUT=$(STUB_BODY=$good bash "$N/fetch.sh" ag http://a.test/p)
assert_contains "$OUT" "cache 0s" "again: cache"
assert_contains "$(tail -1 "$N/pages.csv")" ',cache,cache' "again: cache row"
case "$(tail -1 "$N/pages.csv")" in *" "*) fail "csv row has a space";; esac

newdir skip
OUT=$(STUB_BODY=$good bash "$N/fetch.sh" ag https://www.reddit.com/r/x)
assert_contains "$OUT" "skipped (site always blocks) https://www.reddit.com/r/x" "reddit skipped"
assert_eq 1 "$(rows)" "skipped: no csv row"

newdir cap
OUT=$(CAP=2 STUB_BODY=$good bash "$N/fetch.sh" ag http://a.test/1 http://a.test/2 http://a.test/3)
assert_contains "$OUT" "capped (agent ag reached 2 opens) http://a.test/3" "third capped"

newdir wall
OUT=$(STUB_BODY="Just a moment... $good" bash "$N/fetch.sh" ag http://a.test/w)
assert_eq 2 "$(grep -c ',blocked,' "$N/pages.csv")" "wall: two blocked rows"
assert_contains "$OUT" "blocked " "wall: blocked line"

newdir thin
OUT=$(STUB_BODY=$small bash "$N/fetch.sh" ag http://a.test/t)
assert_contains "$OUT" "thin " "thin line"
assert_eq 0 "$(ls "$N/pages" | wc -l | tr -d ' ')" "thin: nothing saved"

newdir grep
OUT=$(bash "$N/fetch.sh" ag --grep 'needle' http://a.test)
assert_contains "$OUT" "== http://a.test" "grep: header"
assert_contains "$OUT" "the needle is here" "grep: match"

newdir odd
U="https://x.test/a?b=1&c='d',e%20f"
OUT=$(STUB_BODY=$good bash "$N/fetch.sh" ag "$U")
assert_contains "$OUT" "ok " "odd: ok"
assert_eq 1 "$(grep -cF "\"$U\"" "$N/pages.csv")" "odd: one quoted row"
OUT=$(STUB_BODY=$good bash "$N/fetch.sh" ag "$U")
assert_contains "$OUT" "cache " "odd: cache"
finish
