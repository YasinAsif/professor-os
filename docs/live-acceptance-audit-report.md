# Live acceptance audit — ProfessorOS

**Environment:** Railway production • **Date:** 2026-10-14 • **Data:** explicitly authorised dummy QA records only

## Test data created

- Course: `LIVE QA Assessment Lab` (`LQA-901`), live course ID 69
- Join code observed: `500F57`
- Student enrolled: supplied QA student account
- Published assignments:
  - ID 18 — `LIVE QA Text Essay` (TEXT, published, 10 marks, CLO linked, 3-criterion rubric)
  - ID 19 — `LIVE QA Short Answer` (published)
- ID 20 — `LIVE QA Timed Proctored Exam` (PROGRAMMING, published, 10 marks, configured 5-minute limit)
- Fixture: `docs/fixtures/live-qa-course-notes.txt` (safe, non-personal dummy material)

## Confirmed live findings

| Severity | Finding | Evidence / impact |
|---|---|---|
| High UX | Cold start or direct route load shows a blank screen for roughly 5–20 seconds, sometimes longer. | Students and staff can mistake the application for a failure, especially before timed work. |
| High functional | A published Short Answer/Q&A was shown to the student as `TEXT` and `100 pts`, rather than its chosen type/marks. | Assessment type and default marks are not persisting/retrieving correctly; this blocks trust in quizzes and grading. |
| High functional | Course AI accepts typed text in its accessibility layer but leaves the visible composer blank; its unlabeled send control therefore cannot submit the question. | The primary student AI workflow is unusable by keyboard/assistive-tech and is not reliably testable. |
| Critical exam | Opening published timed assessment 20 as the enrolled student leaves a blank white page after repeated waits (~24 seconds); no exam start, timer, prompt, or proctoring UI appears. | Student cannot begin the exam. No browser console errors were captured, so this is a rendering/routing failure without a confirmed client exception. |
| Critical exam | After waiting ~40 seconds and enabling the Flutter accessibility tree, course 69 rendered. The exam's pre-start screen and five-minute timer rendered and a code answer could be entered. The confirmation dialog's `Submit Now` control did not complete submission; the confirmation remained open and the attempt result could not be verified. | Exam flow is only partially functional. Timer and response entry pass; final submission fails. |
| High exam | Professor exam detail confirms PROGRAMMING/PUBLISHED/10 marks but omits the configured 5-minute timer and any proctoring setting/status. | Professors cannot verify exam conditions; the student page fails before timer/answer saving can be tested. |
| High UX | Assessment authoring field state is inconsistent. A value can appear in the accessibility/DOM layer but not in the Flutter-rendered field; publication then says a required value is missing. | Makes authoring unreliable for keyboard/assistive-tech and automated QA users. |
| Medium UX | The visible **Enroll** button did not submit the roster modal; the form's hidden **Submit** control did. | A professor can reasonably believe enrolment is broken. |
| Medium UX | On the narrow live viewport, top action controls overflow and floating CTAs obscure content. | Key actions (analytics / new assignment / Course AI) are partly hidden or overlap lists. |
| Medium content | Materials view says the AI is grounded in lecture materials, but its empty state gives no visible upload action. | A professor cannot discover the required next action from the empty state. |
| Medium compliance | OBE/AI UI previously displayed literal `Widget.courseTitle` and reported compliant with zero tracked CLOs/submissions. | Misleading compliance signal; must be treated as incomplete, not compliant. |
| Medium workflow | Grading feedback and score controls can fall below the initial viewport. | Adds avoidable effort and risk of incomplete grading. |

## Assessment-family coverage status

| Type | Status | Notes |
|---|---|---|
| Text essay | Published | End-to-end authoring validated. |
| Short answer / Q&A | Published with defect | Student list reclassified it as TEXT and 100 points. |
| File upload | Blocked in UI | Type selection updates allowed formats, but the title was visually rejected as required despite DOM state. |
| MCQ | Pending | To test from student view after route/session check. |
| Programming / timed exam | Pending | Must validate start, timer, save, and proctoring warning. |
| Hybrid | Pending | Must validate component authoring and mixed submission. |

## Evidence snapshots captured during browser test

1. Course workspace: empty assignments screen with floating **New Assignment** CTA covering the empty state.
2. Materials empty state: no visible upload affordance despite instruction to upload materials.
3. Assignment editor: validation state and selected Short Answer type.
4. Published Text Essay detail: live ID 18, status Published, 10 marks, CLO-linked rubric.
5. Student successfully submitted the text essay; submission confirmation and submitted content were shown at 11:36 PM local time.
6. Course AI composer was tested with a harmless boundary-value question; no request was sent because the visible Flutter control did not receive the entered text.
7. Timed exam 20 first stayed white after ~24 seconds. On the latest retry, after a further ~40-second wait and enabling accessibility, the course rendered. Pre-start instructions specified 5 minutes, automatic submission at expiry, fullscreen focus mode, tab-switch logging, and flagging after three switches. Start worked; countdown reached 04:55 then 04:32; a test answer appeared in the code editor, but no save indicator was shown. A fresh tab was opened, but no warning appeared in the exam state observed. The Submit Exam confirmation opened; `Submit Now` left the confirmation visible and no submitted result was verified. No browser console errors were captured.

Screenshots were captured during the live browser session. The next pass will produce saved, linked image artifacts alongside this report.

## Immediate product priorities

1. Fix Flutter text-field/semantic-tree synchronisation; add an end-to-end authoring test for every assessment type.
2. Fix assessment-type and max-mark persistence. Block release of MCQ/programming/hybrid until a professor's selection is exactly reflected in the student experience.
3. Replace the roster modal's unreliable visible Enroll action with one accessible submit path.
4. Remove blank-screen startup by showing a branded loading/skeleton state on every deep route.
5. Make OBE status explicitly `Insufficient evidence` when CLO/submission data is empty.
6. Rework desktop/narrow-width action bars and floating CTA collision rules.

## Local remediation status — 2026-10-15

These source fixes are implemented and automated locally; the Railway deployment has not been rebuilt or re-tested, so the original live findings remain unverified there.

| Finding | Local change | Verification |
|---|---|---|
| OBE reports compliance without evidence | Missing attempts no longer create attainment records; empty/missing evidence returns `INSUFFICIENT_EVIDENCE`; OBE UI and HEC HTML/PDF no longer synthesize CLOs or 75–80% attainment. | Backend regression tests cover empty attempts and empty dossier output. |
| Professor course actions overflow narrow screens | Replaced the packed narrow-screen action row with an accessible course-actions menu; synchronized tab count with asynchronously loaded role. | Phone-width widget test verifies no layout exception and menu actions remain available. |
| Exam Return to Exam can re-open a warning immediately | Suppressed focus-loss detection while fullscreen is being restored and used the dialog navigator for actions. | Targeted Flutter tests/analyzer pass; browser behavior still needs post-deploy verification. |

Latest local verification: backend `73 passed`; Flutter test suite passed; Flutter analyzer reported no issues. Other findings above remain open until separately fixed and rechecked.
