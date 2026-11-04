# Project profile template

The hub writes this to `qa/project-profile.md` once. Every persona and scenario reads it instead of repeating recon.

```
# Project profile

## Basics
Name:
One-line purpose:
Demo date and length:
Audience:
Demo device: (own laptop / deployed link / both)
Presenter: (who clicks during the demo)

## Run commands (exact, tested)
Install:
Start (backend):
Start (frontend):
Seed / reset data:
Run tests:
Build:
Default URL and ports:

## Stack
Frontend:
Backend:
Database:
Auth:
External services: (AI API, email, payment, storage, maps)
Env variables needed: (names only, never values)

## Roles
| Role | Test account | Main goals |
|------|--------------|------------|

## Screens and routes
(list the main ones)

## Golden path (the demo story)
1.
2.
3.

## Likely detours
-

## Known problems already (from the owner or the baseline run)
-

## Baseline
Tests passing / failing before any change:
Git commit at start:

## Assumptions I made (owner has not confirmed)
-
```
