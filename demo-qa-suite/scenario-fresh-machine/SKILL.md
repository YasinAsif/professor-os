---
name: scenario-fresh-machine
description: Checks that the project runs on a clean computer using only the written instructions, to catch "works on my machine" problems like missing env variables, hardcoded paths, undocumented steps, version mismatches, and first-run-only bugs. Use this skill whenever the user will demo on a different laptop, share the project with a teammate or supervisor, deploy it, or asks "will it run on someone else's machine", or when running the demo-readiness-qa suite.
---

# Scenario: Fresh machine

The owner's laptop has years of invisible setup: global packages, environment variables, cached logins, old data. A new laptop has none of that. Your job is to act like a stranger with an empty computer who has only the README.

## Safety

- Work in a clean copy of the project in a new folder, or a container or fresh virtual environment. Do not wipe the owner's real working folder, database, or .env.
- Never print secret values. When you list env variables, list names only.
- Do not install system-wide software without asking the owner. Use local environments.

## Method

1. Make a clean copy: clone from git if possible (this also checks that everything needed is committed), or copy the folder without dependency folders, build output, and .env files.
2. If possible, use a clean environment: a new container, a fresh virtual machine, or at least a new empty virtual environment and a clean dependency install.
3. Follow ONLY the README, step by step, exactly as written. Do not use anything you know from outside it.
4. After every step, write down: command run, did it work, time taken, any warning.
5. When a step fails, record the exact error and what you did to get past it. That fix becomes a README change.
6. Continue until the golden path works end to end, or until you are truly stuck (then log it as P0).

## What to look for

Missing or wrong instructions
- Steps the README never mentions (create the database, run migrations, seed data, copy .env.example to .env, install a system tool).
- Commands that do not work as written (typos, wrong folder, old script names).
- Missing version info: language runtime, package manager, database version.

Hidden dependencies
- Packages imported in code but not in the package file.
- Globally installed tools the project quietly needs.
- Files that exist on the owner's laptop but are ignored by git (data files, models, certificates, config).

Environment and config
- Env variables the code reads that `.env.example` does not list.
- Hardcoded absolute paths (like a Windows user folder), hardcoded localhost URLs, and ports.
- Different behavior between operating systems: path separators, line endings, case-sensitive file names (Windows and Mac vs Linux), shell commands that only work in one shell.

Data
- Database not created, migrations not applied, no seed data, no default admin account.
- App needs existing data to even load its first screen.

First run vs later runs
- Does it work after the second start? After a restart? After the data is reset?
- Does the reset command really restore the demo state?

Versions
- Run with the version the README states, and also note if it breaks on the newest versions or the older ones. Recommend pinning versions (lock files committed).

Time to run
- How many minutes from clone to golden path? Over 20 minutes means the README is too painful for a quick demo setup.

## Rating

- Cannot get the app running from the README: P0
- Works only after undocumented steps: P1
- Works but with confusing warnings or slow setup: P2
- OS or version quirks that do not affect the demo laptop: P3

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Output

1. `qa/findings/fresh-machine.md` using `../demo-readiness-qa/shared/bug-template.md` with prefix FRM. Include a step log table: step, command, result, minutes.
2. A corrected README (or a patch to it) with the exact working steps. Fix the README in the repo as part of this, because a correct README is part of demo readiness.
3. If the setup is long, offer a one-command setup or reset script. Create it only if the owner agrees, or keep it very small.

## Do not

- Do not use your own knowledge to skip a broken step. If the README is wrong, that is the finding.
- Do not copy the owner's secrets into the clean copy "to make it work". Document which variables are needed and how to get them.
- Do not modify the owner's real project folder or data.
