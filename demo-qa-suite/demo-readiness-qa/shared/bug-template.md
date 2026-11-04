# Finding template

Use this exact shape in `qa/findings/<persona-or-scenario>.md`. One block per finding.

```
ID: <PREFIX>-<number>        (prefix = persona or scenario short name, e.g. ATK-003)
Title: short and specific
Severity: P0 / P1 / P2 / P3   (+ tags: demo-visible, avoidable, after-demo)
Found by: persona or scenario name
Where: screen, route, file, or API
Steps to reproduce:
  1. ...
  2. ...
Expected: what should happen
Actual: what really happened
Evidence: screenshot path, log line, response body, or exact command output
Cause (if known): file and line, or "unknown"
Suggested fix: smallest safe change
Status: open / fixed / wont-fix / needs-user-decision
Verified how: (fill in after the fix)
```

## Rules

- No evidence, no finding. "Felt slow" is not evidence. "Took 11.4 seconds, measured with the network tab" is.
- Mask secrets. Write `sk-****abcd`, never the full key.
- If you could not test something, log it under `NOT TESTED` with the reason. Do not skip it silently.
- Keep titles short. The title should tell a reader what is wrong without opening the block.
