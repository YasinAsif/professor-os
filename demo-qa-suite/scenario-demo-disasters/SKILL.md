---
name: scenario-demo-disasters
description: Drills the things that go wrong during a live demo, such as WiFi dying, projector resolution, audience-chosen input, laptop sleep, session expiry, crashes, and shortened time, and writes a one-line plan B for each so the presenter can recover in under a minute. Use this skill whenever the user asks "what if something goes wrong during the demo", wants a backup plan, rehearsal, a recovery plan, presenter notes, or when running the demo-readiness-qa suite.
---

# Scenario: Demo disasters

Murphy's law is strongest on demo day. Your job is to rehearse the failures before they happen, and give the presenter a short, calm plan for each.

The goal for every disaster: get back on the golden path in under 60 seconds, or switch to the backup, without panic and without apologizing for 5 minutes.

Read `qa/project-profile.md` for the golden path, the demo device, and the audience.

## Method

For each disaster below:

1. Trigger it for real if safe (turn off WiFi, change resolution, expire the session, kill the server). If you cannot trigger it, reason it out from the code and mark it "simulated on paper".
2. Observe what the presenter would see.
3. Decide the plan B: the exact action, in one short line.
4. Time the recovery.
5. If recovery takes more than 60 seconds or needs knowledge the presenter will not have under stress, fix the cause or prepare a fallback (saved screenshots, a recording, a preloaded state, a mock mode).

## The disasters

Environment
1. WiFi drops or is very slow. What still works offline? Which step needs the internet? Is there a cached or mock fallback?
2. Projector forces 1024x768 or a different aspect ratio. Does the layout still work? Does the presenter know the zoom shortcut to fix it?
3. Laptop sleeps, locks, or restarts before the demo. How long to get back up? Are services set to start automatically, or is there a written start order?
4. Battery low, charger missing. (Presenter note: plug in, and turn off sleep and notifications.)
5. Screen share or second display problem. Is a backup device or a recorded video ready?

Software
6. The app crashes or shows an error mid-demo. Is the restart command known, and how long does it take? Does the state survive a restart?
7. Session expires or the wrong account is logged in. Are credentials written down and easy to reach? Is there a reset-and-login routine?
8. An external service (AI, email, maps) is slow or fails. Is there a mock or a pre-made result to show instead?
9. The seed data got changed or deleted by an earlier run. Is there a one-command reset? Does it really restore everything?
10. A port is taken or the database will not start. Is the fix known?

Human
11. The audience asks "try my input" and types something weird, very long, or in another language. Does the app cope? Does the presenter have a safe way to steer?
12. The audience asks to see something that is not built. Is there a prepared honest answer ("this is planned; here is how it would work")?
13. The audience asks to see the failure case, the admin view, or the data behind a result. Is that path ready and not embarrassing?
14. Time is cut in half (10 minutes becomes 5). Is there a 3 minute and a 5 minute version of the demo marked in the notes, with exactly what to skip?
15. The presenter freezes or forgets the order. Are there short cue notes, one line per step?

Browser noise
16. Notifications, other tabs, bookmarks, autofill suggestions, saved passwords, update popups, a wrong language. Is a clean browser profile prepared?

## Recovery drill

Pick the 5 most likely disasters for this project. For each, do a timed run:
- Start the golden path.
- Trigger the disaster at a random step.
- Follow the written plan B.
- Record the seconds until you are back on the golden path.

## Rating

- No recovery plan and the failure kills the whole demo: P1
- Recovery works but takes over 60 seconds or relies on memory: P2
- Rare disaster with a simple plan: P3

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Output

1. `qa/demo-disaster-plan.md`: a one-page table the presenter can print.

| If this happens | Do this (one line) | Time to recover |
|-----------------|--------------------|-----------------|

Include a "3 minute version" and a "5 minute version" of the demo, and a short opening line and closing line the presenter can say if they lose their place.

2. `qa/findings/demo-disasters.md`: gaps, using `../demo-readiness-qa/shared/bug-template.md` with prefix DIS.

## Do not

- Do not write a plan B that needs the presenter to debug live. Plan B means a click or a command.
- Do not rely on "the internet will be fine".
- Do not leave a recovery step untimed.
