# Benchmark protocol

How lean-research is compared with Anthropic's `deep-research` skill. One run per side per question, not two: the results are one sample each, not an average.

## Questions

1. "What does the EU AI Act require of a small software company selling in the EU in 2026: obligations by risk level, deadlines, penalties?"
2. "Compare 1Password, Bitwarden and Proton Pass for a 10-person team: price, admin features, security audits, user complaints."

## Setup

- Clean profile: a new, empty config folder, so no hooks, other plugins, output styles or CLAUDE.md change the token counts. Start it with
  - bash: `export CLAUDE_CONFIG_DIR="$HOME/.claude-bench"; claude`
  - PowerShell: `$env:CLAUDE_CONFIG_DIR = "$HOME\.claude-bench"; claude`
- In it: log in, add this repo as a marketplace, run `/plugin install lean-research@lean-research`, and confirm `deep-research` is listed in `/skills`. If it is not, install it into this profile.
- Both sides run on the same main model and effort.
- Default permissions, not auto mode. Every permission prompt the person answers is written down, and the allow rules that would remove them go in the README.

## Runs

- Each run is one fresh session in a new empty folder, with nothing else asked in it.
- For each question: one `deep-research` run with its defaults, then one `lean-research` run.
- A run's main session file is the newest `.jsonl` in `$CLAUDE_CONFIG_DIR/projects/<folder slug>/`.

## Measure

```
python -I eval/measure.py "<notes folder>" <label> "<main session .jsonl>"
```

It reads the main session and its subagent transcripts, and `pages.csv` and the notes if present. It prints one row and appends it to `eval/results.csv`: turns, fresh input, cache writes, cache reads, output, wall time, and the share of report URLs that were opened.

The whole session is the run, so no `started.txt` or time window is needed: each run gets a fresh session with nothing else asked in it.

## Judge

Described in `eval/judge.md`. A blind Sonnet agent, run in the main profile, gets the two reports in random order as X and Y and is told only which is the reference. The reference's key findings are written once from the `deep-research` report and reused for every later judge of that question (`eval/keyfindings-<question>.md`). The judge replies with the key findings, FOUND / DEMOTED / MISSING / CONTRADICTED for each, extra conclusions marked SUPPORTED or UNSUPPORTED, ERRORS, and a SCORE line:

`coverage=<FOUND+DEMOTED>/<key findings> found=<n> demoted=<n> missing=<n> contradicted=<n> extra_supported=<n> extra_unsupported=<n>`

## Bar

- Coverage at or above 0.85.
- Nothing contradicted.
- No errors against the candidate (lean-research).
- At least 95% of report URLs opened.
- Fewer input tokens or less wall time than `deep-research`.

The 95% check applies to the lean-research side only: `deep-research` writes no `pages.csv`, so its share cannot be measured.

## On a miss

Tune the plugin once and re-run the lean-research side only; the `deep-research` run and the key-findings list stay as the reference. If it still misses only on tokens or time, publish the numbers and say so. If it still misses on quality (coverage under 0.85, anything contradicted, or an error), stop: do not release.
