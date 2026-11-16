Judge brief: blind quality check of a candidate research report against a reference report on the same question. Spawn as Agent general-purpose, model sonnet, with this text (fill the brackets; give the two paths in random order as X and Y, and tell the judge only which letter is the reference).

```
Two research reports answer the same question: <question>.
Report X: <path>
Report Y: <path>
<X or Y> is the reference. Read both in one turn (Read each once; if Read returns a stub instead of the text, print the file with python -I -c "print(open(r'<path>',encoding='utf-8').read())"), then reply with only this, no preamble:

1. KEY FINDINGS of the reference: <if eval/keyfindings-<question>.md exists, paste its list here and write "use exactly this list">, otherwise its top-ranked conclusions (the must-haves / main recommendations, exactly 10 or all if fewer), one line each.
2. For each key finding: FOUND (same conclusion, same or higher rank), DEMOTED (present but ranked lower), MISSING, or CONTRADICTED, in the other report, with a few-word quote as proof.
3. The other report's top-ranked conclusions that the reference lacks: one line each, and SUPPORTED if the other report cites an opened source (a URL, not "search snippet") for it, else UNSUPPORTED.
4. ERRORS: claims in either report that the other report's sources show to be wrong. "none" if none.
5. SCORE line: coverage=<FOUND+DEMOTED>/<key findings> found=<FOUND> demoted=<DEMOTED> missing=<MISSING> contradicted=<n> extra_supported=<n> extra_unsupported=<n>
```

The first judge of a question picks the key findings; save them as `eval/keyfindings-<question>.md` and pass that list to every later judge (two judges of the same reference picked 10 and 7 findings, which made their scores incomparable).

Read the SCORE line into the run's notes in results.csv by hand (label column) or keep it beside the report. Coverage at or above 0.85 with no CONTRADICTED and no ERRORS against the candidate counts as quality kept.
