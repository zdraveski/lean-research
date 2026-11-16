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
agent=$1; shift; pat=""
[ "$1" = --grep ] && { pat=$2; shift 2; }
export agent
mkdir -p "$dir/pages"; [ -f "$dir/pages.csv" ] || echo "agent,url,start,seconds,bytes,status,reader" > "$dir/pages.csv"

one() {
  url=$1; h=$(printf '%s' "$url" | hash12); f="$dir/pages/$h.md"
  if [ -s "$f" ]; then echo "$agent,\"$url\",$(now),0,$(wc -c < "$f" | tr -d ' '),cache,cache" >> "$dir/pages.csv"; echo "cache 0s $f $url"; return; fi
  start=$(now); t0=$(date +%s)
  "$dir/webread" "$url" > "$f.tmp" 2> "$f.err"; code=$?
  reader=$(sed 's/^webread: //' "$f.err" | tr '\n,' '  ' | cut -c1-40)
  # webread hands PDFs back as raw binary; read them with pdftotext instead
  if [ "$(head -c4 "$f.tmp")" = "%PDF" ] || [[ "$url" == *.pdf ]]; then
    curl -sL -A "Mozilla/5.0" -o "$f.pdf" "$url" && pdftotext "$f.pdf" "$f.tmp" 2>/dev/null && code=0 && reader=pdftotext
    rm -f "$f.pdf"
  fi
  # embedded base64 images are never research text, and they hid Reddit's block message 87 KB down
  sed -E 's/data:[a-z/+.-]+;base64,[A-Za-z0-9+/=]+//g' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"
  real=$(tr -d '[:space:]' < "$f.tmp" | wc -c | tr -d ' ')
  if [ $code -ne 0 ]; then st=blocked
  elif head -c 3000 "$f.tmp" | grep -qiE 'blocked by network security|verify you are (a )?human|just a moment|enable javascript and cookies|captcha|access denied'; then st=blocked
  elif [ "$real" -lt 500 ]; then st=thin
  else st=ok; fi
  secs=$(( $(date +%s) - t0 ))
  bytes=$(wc -c < "$f.tmp" | tr -d ' ')
  if [ $st = ok ]; then mv "$f.tmp" "$f"; else rm -f "$f.tmp"; f=-; fi
  rm -f "$dir/pages/$h.md.err"
  echo "$agent,\"$url\",$start,$secs,$bytes,$st,$reader" >> "$dir/pages.csv"
  echo "$st ${secs}s $f $url"
  # blocks are often momentary
  if [ $st = blocked ] && [ -z "$RETRY" ]; then sleep 3; RETRY=1 one "$url"; fi
}
export -f one

# Cap: count this agent's real opens so far; pages already saved don't count (status is the second-last field: URLs may hold commas)
used=$(awk -F, -v a="$agent" '$1==a && $(NF-1)!="cache"' "$dir/pages.csv" | wc -l | tr -d ' ')
# Sites that block every open; skipped without an open (no wait, no cap use)
SKIP='trustpilot\.com|capterra\.com|g2\.com|getapp\.com|softwareadvice\.com|reddit\.com|justia\.com|play\.google\.com|developer\.apple\.com/forums'
todo=(); for u in "$@"; do
  if [[ "$u" =~ $SKIP ]]; then echo "skipped (site always blocks) $u"; continue; fi
  h=$(printf '%s' "$u" | hash12)
  if [ -s "$dir/pages/$h.md" ] || [ $used -lt $CAP ]; then todo+=("$u"); [ -s "$dir/pages/$h.md" ] || used=$((used+1))
  else echo "capped (agent $agent reached $CAP opens) $u"; fi
done
[ ${#todo[@]} -gt 0 ] && printf '%s\0' "${todo[@]}" | xargs -0 -P 6 -n 1 bash -c 'one "$1"' _

if [ -n "$pat" ]; then for u in "${todo[@]}"; do
  f="$dir/pages/$(printf '%s' "$u" | hash12).md"; [ -s "$f" ] || continue
  echo; echo "== $u"; grep -aiE -C1 "$pat" "$f" | tr -s ' ' | head -40
done; fi
