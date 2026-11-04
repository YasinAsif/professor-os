# Final report format

Write to `qa/DEMO-READINESS-REPORT.md`. The owner must be able to read it in two minutes.

```
# Demo Readiness Report

## Verdict
READY / READY WITH WARNINGS / NOT READY, and one line why.

## Golden path result
Step by step: PASS / FAIL (with the failing step named)

## Fixed
- [P0] title, cause, fix, files, how verified
- [P1] ...

## Still open (and what to do about it)
- [P2] title, how to avoid it in the demo
- ...

## Not tested
- thing, reason

## Viva / Q&A gaps (if examiner ran)
- question, why the project cannot answer it yet, suggested fix

## Demo setup
- Start commands (exact)
- Demo accounts
- Reset command
- 10 minute pre-demo checklist

## Presenter warnings
- Do not click X
- If Y fails, do Z

## Suggested demo order
1.
2.

## After the demo
- refactors and wishes that were deliberately not touched
```

## Rules

- Plain language. No jargon the owner did not use first.
- Lead with the most important thing.
- If it is not ready, say it is not ready.
- No praise padding.
- Count honestly: how many findings per persona, how many fixed, how many left.
