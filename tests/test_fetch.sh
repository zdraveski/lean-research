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
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag http://a.test/p)
assert_contains "$OUT" "ok " "good page: ok"
assert_eq 1 "$(ls "$N/pages" | grep -c '^[0-9a-f]\{12\}\.md$')" "good page: saved"
assert_eq 2 "$(rows)" "good page: header plus one row"
assert_contains "$(tail -1 "$N/pages.csv")" ',ok,stub' "good page: status and reader"
assert_eq 7 "$(tail -1 "$N/pages.csv" | awk -F, '{print NF}')" "no stray commas"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag http://a.test/p)
assert_contains "$OUT" "cache 0s" "again: cache"
assert_contains "$(tail -1 "$N/pages.csv")" ',cache,cache' "again: cache row"
case "$(tail -1 "$N/pages.csv")" in *" "*) fail "csv row has a space";; esac

newdir skip
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag https://www.reddit.com/r/x)
assert_contains "$OUT" "skipped (site always blocks) https://www.reddit.com/r/x" "reddit skipped"
assert_eq 1 "$(rows)" "skipped: no csv row"

newdir cap
OUT=$(CAP=2 STUB_BODY=$good "$N/fetch.sh" ag http://a.test/1 http://a.test/2 http://a.test/3)
assert_contains "$OUT" "capped (agent ag reached 2 opens) http://a.test/3" "third capped"

newdir wall
OUT=$(STUB_BODY="Just a moment... $good" "$N/fetch.sh" ag http://a.test/w)
assert_eq 2 "$(grep -c ',blocked,stub' "$N/pages.csv")" "wall: two blocked rows"
assert_contains "$OUT" "blocked " "wall: blocked line"

newdir thin
OUT=$(STUB_BODY=$small "$N/fetch.sh" ag http://a.test/t)
assert_contains "$OUT" "thin " "thin line"
assert_eq 0 "$(ls "$N/pages" | wc -l | tr -d ' ')" "thin: nothing saved"

newdir grep
OUT=$("$N/fetch.sh" ag --grep 'needle' http://a.test)
assert_contains "$OUT" "== http://a.test" "grep: header"
assert_contains "$OUT" "the needle is here" "grep: match"

newdir odd
U="https://x.test/a?b=1&c='d',e%20f"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "$U")
assert_contains "$OUT" "ok " "odd: ok"
assert_eq 1 "$(grep -cF "\"$U\"" "$N/pages.csv")" "odd: one quoted row"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "$U")
assert_contains "$OUT" "cache " "odd: cache"

# PDF branch: webread hands back raw %PDF bytes; curl and pdftotext are stubs
mkdir -p "$T/pdfbin"; PDFBODY="%PDF$good"
cat > "$T/pdfbin/curl" <<'STUB'
#!/bin/sh
while [ $# -gt 1 ]; do [ "$1" = -o ] && o=$2; shift; done
printf '%s' "%PDF-stub" > "$o"
STUB
printf '#!/bin/sh\nexit 1\n' > "$T/pdfbin/pdftotext"
chmod +x "$T/pdfbin/curl" "$T/pdfbin/pdftotext"
newdir pdfbad
OUT=$(PATH="$T/pdfbin:$PATH" STUB_BODY=$PDFBODY "$N/fetch.sh" ag http://a.test/x.pdf)
assert_contains "$OUT" "blocked " "pdf without text: blocked"
assert_eq 0 "$(grep -c ',ok,' "$N/pages.csv")" "pdf without text: never ok"
assert_eq 0 "$(ls "$N/pages" | wc -l | tr -d ' ')" "pdf without text: nothing saved"
printf '#!/bin/sh\nprintf %%s "%s" > "$2"\n' "$good" > "$T/pdfbin/pdftotext"
newdir pdfok
OUT=$(PATH="$T/pdfbin:$PATH" STUB_BODY=$PDFBODY "$N/fetch.sh" ag http://a.test/x.pdf)
assert_contains "$OUT" "ok " "pdf with text: ok"
assert_contains "$(tail -1 "$N/pages.csv")" ',ok,pdftotext' "pdf with text: reader"

# the same URL twice in one call opens once
newdir dup
STUB_BODY=$good "$N/fetch.sh" ag http://a.test/d http://a.test/d >/dev/null
assert_eq 2 "$(rows)" "dup url: header plus one row"

# SKIP matches host names only
newdir skiphost
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "http://www.leg2.com/x" "http://a.test/p?ref=g2.com")
assert_not_contains "$OUT" skipped "skip is anchored to the host"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "http://x.test/a//reddit.com/")
assert_not_contains "$OUT" skipped "skip ignores // inside a path"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "HTTPS://WWW.Reddit.com/x")
assert_contains "$OUT" skipped "skip ignores host case"
OUT=$(STUB_BODY=$good "$N/fetch.sh" ag "https://foo.test?x=a.reddit.com/" "https://foo.test#a.reddit.com/y")
assert_not_contains "$OUT" skipped "skip: ? and # end the host"

# a grep pattern that starts with -
newdir dash
OUT=$(STUB_BODY="x -dash y $good" "$N/fetch.sh" ag --grep -dash http://a.test/m)
assert_contains "$OUT" "x -dash y" "grep: pattern starting with -"
# a " in a URL is doubled in the csv; no URL is a usage error
newdir quote
STUB_BODY=$good "$N/fetch.sh" ag 'http://a.test/q"x' >/dev/null
assert_eq 1 "$(grep -cF '"http://a.test/q""x"' "$N/pages.csv")" "quote: doubled in csv"
"$N/fetch.sh" >/dev/null 2>&1; assert_eq 2 "$?" "no args: usage, exit 2"
"$N/fetch.sh" ag >/dev/null 2>&1; assert_eq 2 "$?" "no urls: usage, exit 2"
# a .pdf URL that serves text: webread's text survives when curl or pdftotext fails
newdir pdftext
printf '#!/bin/sh
exit 1
' > "$T/pdfbin/pdftotext"
OUT=$(PATH="$T/pdfbin:$PATH" STUB_BODY=$good "$N/fetch.sh" ag http://a.test/html.pdf)
assert_contains "$OUT" "ok " "pdf url serving text: ok"
assert_contains "$(tail -1 "$N/pages.csv")" ',ok,stub' "pdf url serving text: webread reader kept"
assert_eq "$good" "$(cat "$N"/pages/*.md)" "pdf url serving text: text intact"
printf '#!/bin/sh
exit 22
' > "$T/pdfbin/curl"
newdir pdfcurl
OUT=$(PATH="$T/pdfbin:$PATH" STUB_BODY=$good "$N/fetch.sh" ag http://a.test/html.pdf)
assert_contains "$OUT" "ok " "pdf url, curl fails: ok"

# a blocked page that is retried uses one cap slot
newdir retrycap
STUB_BODY="Just a moment... $good" "$N/fetch.sh" ag http://a.test/w >/dev/null
OUT=$(CAP=3 STUB_BODY=$good "$N/fetch.sh" ag http://a.test/1 http://a.test/2)
assert_not_contains "$OUT" capped "retry counts once against CAP"
# CAP counts opens even when URLs hold commas; cached pages cost nothing
newdir capcomma
CAP=2 STUB_BODY=$good "$N/fetch.sh" ag "http://a.test/a,b" "http://a.test/c,d,e" >/dev/null
OUT=$(CAP=2 STUB_BODY=$good "$N/fetch.sh" ag http://a.test/f)
assert_contains "$OUT" "capped (agent ag reached 2 opens) http://a.test/f" "comma urls count against CAP"
OUT=$(CAP=2 STUB_BODY=$good "$N/fetch.sh" ag "http://a.test/a,b" "http://a.test/c,d,e")
assert_not_contains "$OUT" capped "cached pages are free at the cap"
assert_contains "$OUT" "cache 0s" "cached pages still answer"
finish
