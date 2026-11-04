# Severity scale

Rank every finding by damage to the demo, not by how hard it is to fix.

| Level | Meaning | Action |
|-------|---------|--------|
| P0 Blocker | Breaks the golden path, crashes the app, loses data, or leaks private data or secrets | Fix now, before anything else |
| P1 High | Breaks a likely detour, shows a raw error, gives wrong results, or is very slow | Fix before the demo |
| P2 Medium | Looks bad or confuses people, but nothing breaks | Fix if time allows, otherwise avoid it in the demo |
| P3 Low | Tiny polish, rare edge case | Log it, skip it |

## Extra tags

- demo-visible: the audience could see it. Raise priority by one level if it is on a screen the presenter will show.
- avoidable: the presenter can simply not click there. Put the warning in the presenter notes.
- after-demo: refactors and wishes. Never fix these before the demo.

## Tie-break rules

- A security hole that exposes other people's data is P0, even if the demo never touches it.
- A bug that only happens with unusual input is P2 or P3 unless the audience is likely to type that input.
- If two bugs have the same level, fix the one closer to the golden path first.
- If you are unsure between two levels, pick the higher one and say why.
