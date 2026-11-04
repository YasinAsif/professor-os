---
name: scenario-role-journeys
description: Walks each user role through its complete real-world journey, checks the handoffs between roles, and builds a permission matrix of who can and cannot do what. Use this skill whenever the app has several roles such as admin, teacher, student, customer, or manager, or the user asks to test end-to-end flows, permissions, "does the whole thing connect", or when running the demo-readiness-qa suite.
---

# Scenario: Role journeys

Single screens can work while the whole story is broken. Your job is to follow each role from the first click to the last, and to check what happens at the points where one role passes work to another.

Read `qa/project-profile.md` for roles, test accounts, and the golden path. If an account for a role is missing, create it using the project's own signup or seed tool, and note that in your file.

## Method

### 1. Write each journey

For every role, write the real journey as numbered steps from the person's point of view, not the feature list.

Example (an assessment platform):
- Teacher: sign up, log in, create a course, create an assessment, publish it, wait, open results, review a grade, change a grade, export.
- Student: log in, find the assessment, attempt it, submit, see the result, see feedback.
- Admin: log in, manage users, see system status, fix a problem user.

### 2. Run each journey end to end

Use a browser tool if you have one. At every step check that:
- the action works,
- the data is saved (refresh and look again),
- the data is correct,
- the next step is reachable without typing a URL.

### 3. Check handoffs between roles

These are where most real bugs live. For every handoff, log in as the second role right after the first role acts:
- Teacher publishes. Does the student see it right away, without a manual refresh or a re-login?
- Student submits. Does the teacher see it? With the right name, time, and answer?
- Teacher changes a result. Does the student see the updated one? Is the old one gone?
- Admin deactivates a user. What happens to that user's open session, and to their data?
- Delete flows: when a parent is deleted (a course), what happens to the children (assessments, submissions)? Orphans, errors, or a clean removal?
- Notifications, emails, or badges that should appear: do they?

### 4. Build the permission matrix

List every important action as a row and every role (plus "logged out") as a column. Fill in two values per cell: what the app currently does, and what it should do.

| Action | Admin | Teacher | Student | Logged out |
|--------|-------|---------|---------|------------|
| View all users | yes / should yes | no / should no | ... | ... |

Then TEST every cell that says "no": try the action, both through the UI and directly through the URL or API. A hidden button does not count as protection. Any "should be no" that actually works is a finding, and a likely P0 or P1.

### 5. Role state edge cases

- Brand new account of each role with zero data. Are all screens fine?
- A user who changes role or is deactivated while logged in.
- Two roles logged in at once in different browsers.
- User with partial data (started but did not finish something). Does it resume or break?
- Log in as the same user in two browsers.

## Rating

- Broken handoff on the golden path (the second role does not see the result): P0
- A "should be no" action that works: P0 or P1
- A journey that needs a manual workaround (refresh, re-login, URL typing): P1 if on golden path, else P2
- Edge case with unusual state: P2 or P3

Use `../demo-readiness-qa/shared/severity-scale.md`.

## Output

Write `qa/findings/role-journeys.md` using `../demo-readiness-qa/shared/bug-template.md` with prefix ROL. At the top include:
- Journey result per role: pass, issues, or fail, with the failing step
- The permission matrix
- Handoff table: from role, to role, result

## Do not

- Do not mark a journey as passing if you skipped a step by typing a URL.
- Do not trust the UI as proof of permissions. Always test the API or direct route.
- Do not leave test accounts with weak passwords in a deployed version. Note them for cleanup.
