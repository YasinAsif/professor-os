---
name: scenario-countdown
description: Time-boxed demo preparation for when the demo is close, with strict plans for 24 hours, 2 hours, and 10 minutes left, including what to check, what to freeze, and what never to touch. Use this skill whenever the user says the demo is tomorrow, today, in a few hours, "last minute", "I have no time", "panic", "final checks", "freeze", or asks what to do at the last moment, and whenever the demo-readiness-qa hub picks countdown mode.
---

# Scenario: Countdown

When time is short, the biggest danger is not an existing bug. It is a new bug that you create while fixing the old ones. Last-minute work has one rule: protect the working version.

First step: ask how much time is left (or read it from the profile) and use the matching mode below. If the time is between modes, use the shorter one.

## Rules for all countdown modes

- Freeze these now: new features, refactors, dependency upgrades, database structure changes, framework or tool changes, renaming files, reformatting code.
- Only fix: P0 on the golden path, and P1 that is demo-visible and has a tiny safe fix.
- Every fix is small, tested right away, and followed by a full golden path run.
- If a fix is not working after 2 honest tries, revert it and use a workaround (hide it, change the demo order, use a fallback).
- Do not "just quickly improve" something. Improvements are for after the demo.
- Do not go into the full suite. Pick only what this skill says.

## Mode A: 24 hours left

Time plan (rough): 4 hours checking, 4 hours fixing, 2 hours hardening, 1 hour rehearsal, the rest is rest.

1. Make a safety point first.
   - Commit everything. Create a tag or a branch named something like `demo-known-good` once the golden path passes. Fix work happens on top of this, and you can always go back.
   - Back up the database and the demo data.
2. Run `scenario-fresh-machine` on the demo laptop or a clean copy. This catches the most disasters per hour spent.
3. Run the golden path as the main role, then as each other role it touches (`scenario-role-journeys`, golden path and handoffs only).
4. If the app uses AI: run the failure tests and a mock fallback check from `scenario-ai-failures` (only sections 2 and 7).
5. Fix list: P0 first, then P1 on the golden path. Max 5 to 8 fixes. Re-run the golden path after each.
6. Hardening (from the hub): clean demo seed with fresh dates, one-command reset, demo accounts written down, hide unfinished pages, clean browser profile.
7. Run the top 5 disasters from `scenario-demo-disasters` and write the one-page plan B table.
8. Rehearse twice, with a timer. Make the 5 minute version too.
9. Record a screen video of the golden path as the last-resort backup.
10. Make a final tag `demo-final`. Write the short report.

## Mode B: 2 hours left

1. Safety point: commit, tag `demo-known-good` only if the golden path works right now. If it does not, find the last commit where it did and check that out first.
2. Back up the database.
3. Run the golden path end to end on the demo device. This is the whole test.
4. Fix only P0. Only touch P1 if the fix is one line and obviously safe.
5. Check services: internet, API keys valid and funded, database running, ports free, correct environment.
6. Reset the demo data to the clean seed. Check the demo accounts work.
7. Hide anything broken or unfinished that is reachable from the menu.
8. Record a quick screen video of the golden path as backup. Take screenshots of the key screens.
9. Run the golden path one more time from the reset state. Time it.
10. Close everything not needed. Notifications off, sleep off, charger on, clean browser profile, zoom set for the projector.

## Mode C: 10 minutes left

No fixing. No code. No git changes. Only checking and calming down.

1. Is the app running? Is the right account logged in? Is the demo data in the clean state?
2. Open the golden path first screen. Click once through the first step to confirm the app responds.
3. Internet and API: one quick test of the AI call or any outside service.
4. Zoom and resolution fit the projector. Notifications off. Other tabs closed. Charger plugged in. Sleep off.
5. Open the backup recording and the screenshots in another window, ready.
6. Have the plan B table and the demo account details nearby.
7. Take a breath. Know your opening line.

If something is broken at this point, do not try to fix it. Use the plan B: skip that step, use the backup recording, or explain it honestly and move on.

## Decision guide for fixes under pressure

Ask these in order. Stop at the first yes.

1. Can the presenter simply avoid this? Then avoid it and write it in the presenter notes.
2. Can the broken feature be hidden or switched off safely? Do that.
3. Is the fix one or two lines with no side effects? Do it, test it, run the golden path.
4. Does the fix need more than 20 minutes or touches shared code? Do not. Use a workaround.

## Output

Write `qa/countdown-checklist.md` with the mode, the exact steps you did, what you fixed, what you deliberately did not fix, and the final presenter checklist. Keep it to one page.

## Do not

- Do not upgrade anything. Not a package, not a tool, not the OS.
- Do not change the database structure.
- Do not deploy new code in the last 2 hours unless it is a P0 fix and you can test it right after.
- Do not stay up all night fixing P2 bugs. Sleep helps the demo more than a polished edge case.
- Do not delete the backups.
