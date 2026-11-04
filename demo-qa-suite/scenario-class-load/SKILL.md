---
name: scenario-class-load
description: Tests what happens when many people use the app at the same time, such as a whole class submitting together, two people editing the same record, double submits, and slow database or AI calls under load, and measures real response times and error rates. Use this skill whenever the user asks "what if 50 people use it", "will it handle my class or audience", load testing, concurrency, race conditions, or when running the demo-readiness-qa suite.
---

# Scenario: Class load

A demo is not Netflix. The realistic worry is 5 to 50 people hitting the app at once: a class submitting an exam together, an audience scanning a QR code and all signing in, or two people editing the same thing. Your job is to find what breaks at that size, with real numbers.

Read `qa/project-profile.md` for roles, flows, run commands, and which parts call outside services.

## Safety and cost

- Only test the owner's local or staging app. Never load test a third-party service or a shared production system.
- Real AI or email or payment calls cost money. In load tests, replace them with a mock that waits a realistic time (for example 3 seconds) unless the owner agrees to real calls. Say which one you used.
- Back up or reset the demo data first. Load tests create a lot of junk.
- Start small (5 users), then 20, then 50. Stop if the machine freezes.

## Pick realistic targets

Ask or assume, and write down in the findings file:
- Peak simultaneous users: audience size, or class size (default 30)
- Most important action under load (default: login, then submit)
- Acceptable response: under 3 seconds for normal pages, errors under 1 percent

Do not test one million users. That is not a demo problem.

## Tools

Use what is available: k6, autocannon, locust, Apache Bench, wrk, Playwright with several browser contexts, or a short script (shell with curl in parallel, or a few lines of Python or Node). A simple script is enough. Say which tool you used.

## Scenarios

### 1. Everyone logs in together
- Simulate N users logging in within 10 seconds.
- Record: median and slowest time, number of failures, any lockouts or rate limit hits.

### 2. Everyone submits together
- N users each submit the main form or answer at the same moment.
- Check afterwards: exactly N records saved? No duplicates, no missing, no mixed-up owners?
- Check the server logs for errors, timeouts, and database lock messages.

### 3. Same record, two editors
- Two users edit the same record at the same time. Who wins? Is the other change silently lost? Is there a warning?
- Two users create something with the same unique value (same username, same title). Clean error or crash?

### 4. Double submit
- Send the same submit request twice within a few milliseconds (a double click). Do you get two records, two charges, two AI calls?

### 5. Slow dependency under load
- With the mock AI waiting 3 to 10 seconds, send N requests together. Do requests pile up? Do timeouts cascade? Does one slow call block other users (a single worker, a shared lock)?
- Is there any queue, and what happens when it is full?

### 6. Many reads
- N users open the heaviest page (dashboard, results list) at once with a realistic data size. Record load time.

### 7. Hold the load
- Keep a steady smaller load for 5 to 10 minutes. Watch response time and memory. Does it get slower and slower?

### 8. Recovery
- After the load stops, does the app return to normal speed by itself, or does it need a restart?

## What to measure

For each test, record real numbers:
- Users or requests, duration
- Median and 95th percentile response time
- Error count and error types
- CPU and memory of the server during the test (if you can see it)
- Database problems (locks, connection limit errors)

## Rating

- Lost, duplicated, or mixed-up data on the golden path: P0
- Crash or hang at the demo's realistic audience size: P0 or P1
- Slow responses (over 10 seconds) at realistic size with no loading state: P1
- Only breaks far above the realistic size: P3 (note it as a known limit, useful for the examiner)

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Typical fixes (smallest first)

- Disable the submit button after the first click, and make the server reject duplicates.
- Add a database unique rule or a lock where two writes must not collide.
- Raise a connection pool limit or add a timeout.
- Add pagination or caching to the heaviest page.
- Add a visible "Working..." state.

## Output

Write `qa/findings/class-load.md` using `../demo-readiness-qa/shared/bug-template.md` with prefix LOD. At the top, a table:

| Test | Users | Median | 95th percentile | Errors | Result |

Also state the honest limit: "handled N simultaneous users on this machine with this data size". This sentence is useful when the panel asks about scale.

## Do not

- Do not invent big numbers. Report only what you measured, on the machine you used.
- Do not load test with real paid API calls without asking.
- Do not leave test data in the demo database.
