---
name: scenario-time-and-dates
description: Hunts bugs around time, such as deadlines, timezones, midnight boundaries, token and session expiry, scheduled jobs, date formats, sorting by date, and clock problems, so features with a due date or timer do not fail on demo day. Use this skill whenever the app has deadlines, exams with timers, expiry, scheduling, reminders, "due date" or "submitted at" fields, reports by date, or the user mentions timezone, and when running the demo-readiness-qa suite.
---

# Scenario: Time and dates

Time bugs hide because the owner always tests "right now" in their own timezone. They show up when the server is in another timezone, when a deadline passes, or when a token expires in the middle of the demo.

Read `qa/project-profile.md`. List every place the app uses time: deadlines, timers, "created at" and "updated at", expiry (tokens, sessions, links, invites), scheduled or background jobs, reports and charts by date, and any "X minutes ago" text.

## Safety

- Changing the system clock can break other programs. Prefer other ways: set test dates in the data, use a fake clock or time-travel library in tests, or change the clock only in a throwaway environment or container.
- Back up or reset the demo data first.

## Method

### 1. Timezone

- What timezone does the server use? The database? The browser? Many deployments run in UTC while users are in Pakistan (UTC+5).
- Are times stored in one standard form (UTC) and converted for display, or stored as local text?
- Create a record at 11:30 PM local time. Is it shown with the correct date everywhere? Is it grouped under the right day in reports?
- Open the same record from a browser set to another timezone. Does it still make sense?
- Does the same moment show different times on different screens?

### 2. Deadlines and boundaries

For anything with a deadline or time limit:
- Submit well before the deadline, at the last second, and just after. Is the rule enforced on the server, and not only by hiding a button in the browser?
- A user who loaded the page before the deadline and submits after it. What happens?
- Deadline at exactly midnight or at 00:00 vs 23:59: is "inclusive or exclusive" clear and consistent?
- Timer features (exam timer): what happens if the user refreshes, closes the tab, loses internet, or changes the device clock? Does the countdown come from the server time or the browser clock? (A browser clock is easy to cheat and easy to break.)
- Late submission and extensions: do they work and show clearly?

### 3. Expiry

- Session and login token: what is the lifetime? What does the user see when it expires in the middle of a form? Is the typed data lost?
- Password reset links, invite links, and email verification links: do they expire? Does an expired link show a clear message?
- Cached data with a time limit: does it refresh?

### 4. Dates in data and display

- Format: day/month vs month/day confusion. Is the format clear and consistent across screens?
- Date input: invalid dates (31 February), past dates, far future dates, leap day (29 February), empty dates.
- Sorting and filtering by date: correct order? Does "last 7 days" use the right start?
- Relative text ("5 minutes ago"): correct, and not negative or "in 5 hours" because of a timezone mix-up?
- Weekdays and week start (Monday vs Sunday), month ends, year change.
- Calendar libraries or date pickers: do they work at the demo's resolution and in the project's language?

### 5. Scheduled and background work

- Jobs that run at a set time, reminders, daily reports, cleanup jobs: do they run? In which timezone? Do they run twice or not at all after a restart?
- What happens to a job that was due while the server was off?

### 6. Clock and ordering

- If the computer clock is a few minutes wrong, what breaks? (token validation, signed links, timestamps)
- Two records created at nearly the same moment: stable order or random?

### 7. Demo-day dates

- Does the demo data have dates that will look strange on the demo day? (An "upcoming" exam whose date has already passed, a "recent" item from 6 months ago, a deadline in the past.)
- Make the seed data use dates relative to "now" so it always looks fresh, or reset the dates before the demo.

## Rating

- Deadline or timer logic wrong or cheatable on the golden path: P1
- Wrong date shown on a demo screen: P1 (demo-visible)
- Token or session expiry that loses data without a clear message: P1 if on golden path, else P2
- Format inconsistency or rare calendar edge cases: P2 or P3

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Output

Write `qa/findings/time-and-dates.md` using `../demo-readiness-qa/shared/bug-template.md` with prefix TIM. At the top: a table of every time-based feature found, how time is stored and shown, and the result of the tests. Add a line on the stale seed dates and what you changed or recommend.

## Do not

- Do not leave the system clock changed.
- Do not trust the browser clock as proof of anything.
- Do not assume the server and the demo laptop use the same timezone.
