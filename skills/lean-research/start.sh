#!/bin/bash
# start.sh "<title>": set up research_notes/<title>/ and reports/ in the current directory.
here=$(cd "$(dirname "$0")" && pwd)
title=$1
[ -n "$title" ] || { echo "usage: start.sh \"<title>\"" >&2; exit 2; }
case $title in */*|*\\*|*..*|-*) echo "start.sh: use letters, numbers and spaces in the title" >&2; exit 2;; esac
bash "$here/check-deps.sh" || exit 1
dir=research_notes/$title
[ -e "$dir" ] && { echo "start.sh: $dir already exists, pick a different title" >&2; exit 1; }
mkdir -p "$dir" reports || exit 1
cp "$here/fetch.sh" "$here/webread" "$dir/" && chmod +x "$dir/fetch.sh" "$dir/webread" || exit 1
echo "agent,query,time" > "$dir/searches.csv"
date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/started.txt"
gi=research_notes/.gitignore
grep -qxF '*/pages/' "$gi" 2>/dev/null || {
  # an existing file may lack a final newline
  [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ] && echo >> "$gi"
  echo '*/pages/' >> "$gi"
}
echo "$(cd "$dir" && pwd)"
