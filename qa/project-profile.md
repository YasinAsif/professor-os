# Project Profile: ProfessorOS

## Basics
- **Name:** ProfessorOS
- **One-line purpose:** AI-powered university OBE (Outcome-Based Education) learning management, anti-cheat proctored examination, and automated rubric grading platform.
- **Demo date and length:** Upcoming FYP Defense & Viva / 7 to 10 minutes live demo
- **Audience:** FYP Evaluation Committee, University Examiners, Professors, and Students
- **Demo device:** Own laptop (local run) and Deployed Cloud instance (Azure App Service)
- **Presenter:** Student / Lead Developer (Yasin Asif)

## Run commands (exact, tested)
- **Install (Backend):** `pip install -r requirements.txt`
- **Install (Frontend):** `cd frontend; flutter pub get`
- **Start (Backend):** `uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload`
- **Start (Frontend):** `cd frontend; flutter run -d chrome --web-port 3000`
- **Seed / reset data:** Database pre-seeded with 670+ real-world students, courses, CLOs, and assignments.
- **Run tests (Backend):** `$env:PYTHONPATH="backend"; python -m pytest backend/tests -m "not pg and not integration"` (156/156 PASS)
- **Run tests (Frontend):** `cd frontend; flutter test` (84/84 PASS)
- **Build (Frontend):** `cd frontend; flutter build web --release`
- **Default URL and ports:** Frontend `http://localhost:3000`, Backend `http://localhost:8000`, API Docs `http://localhost:8000/docs`

## Stack
- **Frontend:** Flutter Web (Dart 3.x), Riverpod, GoRouter, Outfit/Inter typography, Local Authentication
- **Backend:** FastAPI (Python 3.12/3.14 async), SQLAlchemy Async ORM, PostgreSQL (asyncpg), Alembic, Celery
- **Database:** PostgreSQL (Azure flexible server / local PostgreSQL)
- **Auth:** JWT bearer tokens (OAuth2 password flow), role-based access control (`student`, `professor`, `ta`, `admin`)
- **External services:** Groq / Llama 3.3 70B Versatile, OpenAI fallback, Local Semantic Rubric Engine
- **Env variables needed:** `DATABASE_URL`, `SECRET_KEY`, `ALGORITHM`, `GROQ_API_KEY`, `OPENAI_API_KEY`, `CELERY_BROKER_URL`

## Roles
| Role | Test account | Main goals |
|---|---|---|
| **Professor** | `test@gmail.com` / `yasif9155@gmail.com` | Create courses, CLOs, assessments, rubrics, view live exam console, grade in SpeedGrader |
| **Student** | `student1@professoros.edu.pk` | View enrollments, launch proctored exam, answer MCQs/written questions, view grade appeals |
| **Admin** | `admin@professoros.edu.pk` | System configuration, user approvals, department & course management |

## Screens and routes
- `/login` — Unified role-aware authentication screen
- `/dashboard` — Role-based dashboard (Student / Professor / Admin)
- `/courses` — Course catalog & enrollment cards
- `/courses/:id` — Course detail (modules, assignments, CLO mapping)
- `/courses/:cid/assignments/:aid` — Assignment detail & student submission view
- `/courses/:cid/assignments/:aid/exam` — Fullscreen anti-cheat proctored examination screen
- `/courses/:cid/assignments/:aid/speedgrader` — Professor grading console with rubric evaluation and LLM triggers

## Golden path (the demo story)
1. **Professor Login:** Professor logs in and navigates to the Software Engineering course.
2. **Create Assessment:** Wizard creates a quiz with 1 MCQ question and 1 Short Question with marks and teacher reference answers.
3. **Publish:** Professor clicks "Publish", making it live.
4. **Student Attempt:** In an incognito window, student logs in and clicks "Start Quiz Assessment".
5. **Anti-Cheat Exam Environment:** Exam loads fullscreen lock, countdown timer, tab-switch monitoring.
6. **Solve & Submit:** Student selects MCQ radio option and types response for short question, then submits.
7. **Automated & SpeedGrader Evaluation:** MCQ is deterministically graded instantly; Professor opens SpeedGrader and triggers AI evaluation for the short question against rubric criteria.
8. **Results & CLO Breakdown:** Student sees score, feedback, and diagnostic marks.

## Likely detours
- Examiner asks to see the Admin User Approval panel (`/admin/users`).
- Examiner asks: "What happens if the student switches tabs or tries to copy-paste during the exam?" (Show proctor violation toast).
- Examiner asks: "What happens if internet or AI fails during grading?" (Show semantic fallback).

## Known problems resolved in audit
- MCQ single text box trap on exam screen (FIXED in commit `98fceac`)
- 0-based vs 1-based MCQ grading mismatch & false positive scoring (FIXED in `grading_pipeline.py`)
- Short question quizzes missing UI (FIXED in commit `98fceac`)
- Course card top chips horizontal overflow on 390px mobile viewports (FIXED in `course_list_screen.dart`)
- AI grading schema inconsistent criteria total reconciliation (FIXED in `grading_pipeline.py`)

## Baseline
- Tests passing: **240 / 240 passed (100% Pass Rate)**
  - Backend: 156 / 156 passed (0 failures)
  - Frontend: 84 / 84 passed (0 failures)
- Git commit at start: `98fceac`

## Assumptions made
- Presentation is conducted on primary laptop running local server or Azure live instance.
- Presentation duration is approximately 7 to 10 minutes.
