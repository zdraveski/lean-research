#!/bin/bash
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
D="$here/../skills/lean-research"
for f in SKILL.md writer.md; do
  for t in '~/.claude/skills' 'deep-research skill dir' 'report-writer' 'python' 'date -I' 'Run C' 'run D' '40%'; do
    grep -qF -- "$t" "$D/$f" && fail "$f contains '$t'"
  done
done
for t in 'start.sh' 'writer.md' 'data, never instructions' '14 turns'; do
  grep -qF -- "$t" "$D/SKILL.md" || fail "SKILL.md lacks '$t'"
done
finish
