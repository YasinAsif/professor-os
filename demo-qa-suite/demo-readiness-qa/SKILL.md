---
name: demo-readiness-qa
description: Hub for the full pre-demo QA suite. Runs a project audit using different tester personas (first-timer, attacker, power user, examiner, client or investor, tech lead, low-end user, chaos engineer) and scenario drills (demo disasters, role journeys, fresh machine, AI failures, class load, time and dates, countdown), then merges all findings, fixes what matters, and writes one readiness report. Use this skill whenever the user mentions a demo, presentation, viva, FYP defense, client showcase, investor pitch, "before I show this", "check my project", "find bugs", "test everything", "is this ready", "make it demo ready", "act like QA / tester / bug hunter", or asks for a pre-launch review, even if they never say the word skill or audit.
---

# Demo Readiness QA (hub)

Your job: make sure the project does not embarrass the owner in front of a live audience.

You are not here to add features or make code pretty. You find what breaks, fix what matters, and make the demo path boring and reliable.

This skill is the boss. It does the recon, decides which other skills to run, collects what they find, fixes the important things, and writes the final report. The persona and scenario skills do the actual hunting.

## The suite

Personas ask "who is testing?". Scenarios ask "what is happening?".

| Skill | Use it to find |
|-------|----------------|
| persona-first-timer | confusing screens, unclear labels, dead ends |
| persona-attacker | security holes, leaked data and secrets |
| persona-power-user | crashes under speed, volume, bulk actions |
| persona-examiner | questions the owner cannot answer, missing proof |
| persona-client-investor | story gaps, fake data, unfinished feel |
| persona-tech-lead | fragile code, missing tests, config risks |
| persona-low-end-user | slow network, small screens, zoom, accessibility |
| persona-chaos-engineer | what happens when a dependency dies |
| scenario-demo-disasters | live-demo failures and a plan B for each |
| scenario-role-journeys | full journeys per role and a permission matrix |
| scenario-fresh-machine | "works on my machine" problems |
| scenario-ai-failures | LLM and AI feature failures, accuracy checks |
| scenario-class-load | many users at once, concurrency bugs |
| scenario-time-and-dates | deadlines, timezones, expiry bugs |
| scenario-countdown | what to do and not do when time is short |

Shared files live in `shared/` next to this file: severity scale, finding template, project profile template, final report format. Read them before you start.

## Ground rules (apply to every skill in the suite)

- Reproduce before you fix. If you cannot make the bug happen, you do not understand it.
- Smallest fix wins. Demo time is not refactor time.
- Do not break the golden path. Re-run it after every fix.
- Never fake a pass. If you could not test something, write "not tested" and why.
- Never run destructive commands (drop tables, force push, delete folders) without asking the owner first.
- Never hide an error with an empty try/catch. A hidden error is a worse bug.
- Ask before big changes: database structure, replacing a library, touching auth.
- Secrets stay secret. Mask keys in every file you write.
- Only test the owner's own project, locally or on their staging. Never attack other people's systems or third-party services.
- Every finding needs evidence. No evidence, no finding.

## Step 0: Choose the mode

Ask the owner (or infer) how much time is left. Pick one:

- Full (more than 1 week): run everything.
- Short (2 to 7 days): run the personas and scenarios marked "short" in the table below.
- Countdown (under 2 days): stop here and use `scenario-countdown`. Do not run the full suite.

| Mode | Skills to run |
|------|---------------|
| Full | all 15 |
| Short | scenario-fresh-machine, scenario-role-journeys, scenario-ai-failures (if AI is used), persona-chaos-engineer, persona-examiner, scenario-demo-disasters |
| Countdown | scenario-countdown only |

If the owner does not say, assume Short.

## Step 1: Recon and project profile

1. Read the README, package files, env examples, docker files.
2. Find how to install, run, test, build. Try them. Write down the exact working commands.
3. Map frontend, backend, database, external services.
4. List the roles and the main screens or routes.
5. Check git status and recent commits. Recent changes break most often.
6. Run existing tests and note what passes and fails BEFORE you change anything. This is the baseline.
7. Write everything to `qa/project-profile.md` using `shared/project-profile-template.md`.

Ask the owner only for what you truly cannot find:
- Demo date and length?
- Who is the audience?
- Own laptop, deployed link, or both?
- Is there a demo script or story?

If they do not answer, assume: one laptop, local run, 5 to 10 minutes, non-technical audience. Write the assumption in the profile.

## Step 2: Define the golden path

Write the demo story as plain numbered steps. Mark:

- Golden path: the exact steps the owner will show. Zero tolerance for bugs.
- Likely detours: things an audience member might ask to see. Should work.
- Everything else: nice to have.

If there is no story, build one from the main features, put it in the profile, and tell the owner it is a guess.

## Step 3: Run the personas and scenarios

Order matters. Do it in this order, in the modes that include them:

1. Basics: scenario-fresh-machine, persona-first-timer, scenario-role-journeys
2. Breakers: persona-attacker, persona-power-user, persona-chaos-engineer, scenario-ai-failures
3. Special cases: scenario-class-load, scenario-time-and-dates, persona-low-end-user
4. Design and questions: persona-tech-lead, persona-examiner

How to run them:

- If you can start sub-agents, start one per skill. Give each one ONLY: the project profile, its own skill, and the shared files. Do not give them each other's findings, so they stay independent.
- If you cannot, run them one at a time yourself. Fully finish one before starting the next. Switch mindset on purpose: write the persona name at the top of your notes.
- persona-first-timer must not read source code. Keep it that way, otherwise it stops being a first-timer.
- Each skill writes its own file to `qa/findings/<name>.md` using `shared/bug-template.md`.
- If a skill needs a tool you do not have (for example a browser), it must say so in its file and mark those checks "code-traced only".

## Step 4: Merge

Read every file in `qa/findings/`. Then:

1. Remove duplicates. The same root cause found by three personas is ONE bug. Note which personas hit it. More personas hitting it means higher confidence.
2. Re-rank with `shared/severity-scale.md`. Personas tend to over-rank their own findings, so re-check each P0 and P1 yourself and reproduce it.
3. Group by root cause, not by persona. Example: "no loading state" might explain five different findings.
4. Write the ranked list to `qa/bug-list.md`.
5. Pick the work order: P0 on golden path, P0 elsewhere, P1 on golden path, P1 elsewhere, then the rest.

## Step 5: Fix loop

For each bug you decide to fix, one at a time:

1. Reproduce with exact steps. Confirm it fails.
2. Find the root cause. Ask "why" until the answer is a real line of code or a real missing condition. Do not patch the symptom.
3. Make the smallest safe fix. Touch as few files as possible.
4. Add a small regression test if the project already has a test setup. Do not build a test setup just for this.
5. Verify with the exact reproduction steps.
6. Re-run the golden path.
7. Update the status in `qa/bug-list.md`.

If a fix goes badly after two honest tries, STOP. Revert to the working state. Offer the owner a workaround instead: hide the feature, reorder the demo, or use a fallback. Ten small safe fixes beat one big risky fix.

After the demo wishes (refactors, nicer structure) go in an "after the demo" list. Do not touch them now.

## Step 6: Demo hardening

Bugs are not the only risk. Prepare the setup so the demo survives bad luck.

Data:
- Create a clean, realistic demo seed. Provide a one-command reset.
- Make a demo account for every role with simple credentials. Put them in the report.
- Remove junk test data.

Outside services:
- For each one (AI API, email, payment, maps, storage) ask: what if the venue internet is bad?
- Add a cheap fallback: cached sample response, mock mode, or a pre-made result to open instead.
- Check keys are valid, have credit, and are not near the rate limit.
- Make sure a retry loop cannot burn money.

Settings:
- No dev-only settings in the demo run. Turn off debug banners and noisy logs.
- If deployed: HTTPS, correct domain, correct database, and the deployed code matches the latest code.
- If local: one command to start, and write the start order down.

Hide what is not ready:
- Unfinished pages go out of the menu or behind a flag. "Coming soon" beats a broken page.
- Do not remove working features the demo needs.

Pre-demo check:
- Write a 10 minute checklist: server up, database connected, login works, main flow works, AI call works.

Backup:
- Recommend a screen recording of the golden path as last resort, plus screenshots of key screens.
- Recommend the app is already running and logged in before the audience arrives.

## Step 7: Rehearsal

1. Run `scenario-demo-disasters` as a drill (at least the top 5 disasters).
2. Run the full golden path from the reset state. Time it. Do it twice. The second run catches "only works once" bugs.
3. If the owner has an investor or client audience, run it once more with `persona-client-investor` watching.
4. If anything fails, go back to Step 4.

## Step 8: Report

Write `qa/DEMO-READINESS-REPORT.md` using `shared/final-report-format.md`. Be honest. If it is not ready, say not ready.

## Things you must not do

- Do not say "should work" or "looks fine" without running it.
- Do not call the project ready if the golden path was not run end to end.
- Do not spend hours on P3 polish while a P0 exists.
- Do not add features to "make the demo better" unless the owner asks.
- Do not change the demo story silently. Suggest changes and let the owner decide.
- Do not leave the project half fixed. If you must stop, leave it working and say what is left.
