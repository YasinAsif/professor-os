# Live Demo Disaster Plan: ProfessorOS

Print or keep this single page open on your phone or tablet during the presentation.

---

## 60-Second Recovery Table

| Disaster | What You See | Plan B Action (Under 60 Seconds) |
|---|---|---|
| **Venue Wi-Fi drops completely** | Network error toast on screen | Switch laptop to phone 4G hotspot (already paired) or run local backend (`http://localhost:8000`). |
| **AI Evaluation takes > 15s** | Loading spinner on SpeedGrader | Wait calmly; backend automatically engages deterministic semantic fallback within 10s and displays grounded score. |
| **Presenter freezes or loses place** | Awkward silence | Say: *"Let me transition to the student's exam submission view to demonstrate the live anti-cheat engine."* |
| **Accidental tab switch / DevTools** | "Anti-cheat violation detected" toast | Say: *"Notice how the proctoring engine instantly detected window focus loss and logged a strike."* (Turn it into a feature demonstration!) |
| **Student cannot see published quiz** | Course list shows 0 quizzes | Refresh student page (F5). If still missing, check that Professor clicked "Publish" and not "Save as Draft". |
| **Projector cuts off resolution** | UI margins cut off | Press `Ctrl + -` (minus) twice in Chrome to zoom out to 80% or 90%. |
| **Backend process crashes** | 502 / Connection Refused | Run `uvicorn app.main:app --port 8000 --reload` in terminal. Recovers in 3 seconds. |

---

## Presentation Variations

### 3-Minute Version (If Presentation Time Is Cut Short)
1. **Min 0:00 - 1:00:** Show Course Dashboard & 1-click Assessment Wizard with CLO mapping.
2. **Min 1:00 - 2:00:** Switch to Student screen, launch exam, answer 1 MCQ and 1 short question, submit.
3. **Min 2:00 - 3:00:** Show SpeedGrader instant AI evaluation, rubric score breakdown, and CLO attainment chart.

### 5-Minute Version (Standard Defense)
- Add live tab-switch anti-cheat demonstration (step out of fullscreen -> show strike count increment).
- Show teacher reference answer ground-truth comparison in SpeedGrader.

---

## Anchor Lines
- **Opening Line:** *"Good morning panel. Today we are demonstrating ProfessorOS, an automated OBE assessment and proctored examination platform designed to make academic evaluation objective, fast, and cheat-resistant."*
- **Closing Line:** *"In summary, ProfessorOS connects assessment authoring, proctored execution, and rubric-accurate evaluation into a single unified platform. Thank you, and we welcome your questions."*
