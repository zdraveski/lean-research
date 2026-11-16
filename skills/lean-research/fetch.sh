#!/usr/bin/env bash
# fetch.sh <agent> [--grep 'regex'] <url>...
# Opens the pages 6 at a time, saves each readable one to pages/<md5>.md and logs every open to pages.csv
# (agent,url,start,seconds,bytes,status,reader). A saved page is reused (status cache, no new open).
# PDFs are turned into text; block pages that webread lets through are caught; each agent stops at CAP opens.
# A blocked page is retried once; sites on the SKIP list are never opened.
# With --grep, prints the matching lines of every readable page, so one call fetches and extracts.
dir="$(cd "$(dirname "$0")" && pwd)"; export dir
hash12() { if command -v md5sum >/dev/null; then md5sum; else md5 -q; fi | cut -c1-12; }; export -f hash12
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }; export -f now
CAP=${CAP:-25}
[ $# -ge 2 ] || { echo "usage: fetch.sh <agent> [--grep 'regex'] <url>..." >&2; exit 2; }
agent=$1; shift; pat=""
[ "$1" = --grep ] && { pat=$2; shift 2; }
export agent
mkdir -p "$dir/pages"; [ -f "$dir/pages.csv" ] || echo "agent,url,start,seconds,bytes,status,reader" > "$dir/pages.csv"

one() {
  url=$1; h=$(printf '%s' "$url" | hash12); f="$dir/pages/$h.md"
  q=$(printf '%s' "$url" | sed 's/"/""/g') # a " in a URL is doubled in the csv
  t="$f.$$" # temp names per process, so two agents opening one URL don't clobber each other
  if [ -s "$f" ]; then echo "$agent,\"$q\",$(now),0,$(wc -c < "$f" | tr -d ' '),cache,cache" >> "$dir/pages.csv"; echo "cache 0s $f $url"; return; fi
  start=$(now); t0=$(date +%s)
  "$dir/webread" "$url" > "$t.tmp" 2> "$t.err"; code=$?
  reader=$(sed 's/^webread: //' "$t.err" | tr '\n,' '  ' | cut -c1-40)
  # webread hands PDFs back as raw binary; read them with pdftotext instead. Text written to .txt, so a failure never damages .tmp
  raw=; [ "$(head -c4 "$t.tmp")" = "%PDF" ] && raw=1
  if [ -n "$raw" ] || [[ "$url" == *.pdf ]]; then
    if curl -sL --proto '=http,https' --max-time 60 --max-filesize 50000000 -A "Mozilla/5.0" -o "$t.pdf" "$url" && pdftotext "$t.pdf" "$t.txt" 2>/dev/null; then mv "$t.txt" "$t.tmp"; code=0; reader=pdftotext
    elif [ -n "$raw" ]; then code=1  # raw PDF bytes without text are never "ok"; a .pdf URL that served text keeps webread's text
    fi
    rm -f "$t.pdf" "$t.txt"
  fi
  # embedded base64 images are never research text, and they hid Reddit's block message 87 KB down
  LC_ALL=C sed -E 's#data:[a-z/+.-]+;base64,[A-Za-z0-9+/=]+##g' "$t.tmp" > "$t.tmp2" && mv "$t.tmp2" "$t.tmp"
  real=$(tr -d '[:space:]' < "$t.tmp" | wc -c | tr -d ' ')
  if [ $code -ne 0 ]; then st=blocked
  elif head -c 3000 "$t.tmp" | grep -qiE 'blocked by network security|verify you are (a )?human|just a moment|enable javascript and cookies|captcha|access denied'; then st=blocked
  elif [ "$real" -lt 500 ]; then st=thin
  else st=ok; fi
  secs=$(( $(date +%s) - t0 ))
  bytes=$(wc -c < "$t.tmp" | tr -d ' ')
  if [ $st = ok ]; then mv "$t.tmp" "$f"; else rm -f "$t.tmp"; f=-; fi
  rm -f "$t.err" "$t.tmp2"
  echo "$agent,\"$q\",$start,$secs,$bytes,$st,$reader" >> "$dir/pages.csv"
  echo "$st ${secs}s $f $url"
  # blocks are often momentary
  if [ $st = blocked ] && [ -z "$RETRY" ]; then sleep 3; RETRY=1 one "$url"; fi
}
export -f one

# Cap: count this agent's real opens so far; pages already saved don't count (status is the second-last field: URLs may hold commas)
# A URL that blocked and was retried counts once (the url is fields 2..NF-5; the last five are start,seconds,bytes,status,reader)
# shortcut: a URL that blocked once is free to retry in later calls; the researcher's turn budget bounds it
used=$(awk -F, -v a="$agent" '$1==a && $(NF-1)!="cache" { u=$2; for (i=3;i<=NF-5;i++) u=u "," $i; if (!(u in b)) n++; if ($(NF-1)=="blocked") b[u]=1 } END {print n+0}' "$dir/pages.csv")
# Sites that block every open; skipped without an open (no wait, no cap use)
SKIP='^https?://([^/?#]*\.)?(trustpilot\.com|capterra\.com|g2\.com|getapp\.com|softwareadvice\.com|reddit\.com|justia\.com|play\.google\.com|developer\.apple\.com/forums)([/:?#]|$)'
todo=(); seen=" "; for u in "$@"; do
  lc=$(printf '%s' "$u" | tr A-Z a-z) # hosts are case-insensitive
  if [[ "$lc" =~ $SKIP ]]; then echo "skipped (site always blocks) $u"; continue; fi
  h=$(printf '%s' "$u" | hash12)
  case "$seen" in *" $h "*) continue;; esac; seen="$seen$h " # a URL repeated in one call opens once
  if [ -s "$dir/pages/$h.md" ] || [ $used -lt $CAP ]; then todo+=("$u"); [ -s "$dir/pages/$h.md" ] || used=$((used+1))
  else echo "capped (agent $agent reached $CAP opens) $u"; fi
done
[ ${#todo[@]} -gt 0 ] && printf '%s\0' "${todo[@]}" | xargs -0 -P 6 -n 1 bash -c 'one "$1"' _

if [ -n "$pat" ]; then for u in "${todo[@]}"; do
  f="$dir/pages/$(printf '%s' "$u" | hash12).md"; [ -s "$f" ] || continue
  echo; echo "== $u"; grep -aiE -C1 -e "$pat" "$f" | tr -s ' ' | head -40
done; fi
