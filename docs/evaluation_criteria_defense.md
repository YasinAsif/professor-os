# ProfessorOS – FYP Evaluation Criteria Defense & Marking Strategy

> **Evaluation Sheet Mapping & 30/30 Marks Defense Strategy**  
> *Targeted guide aligned directly with the official university evaluation rubric.*

---

## 📊 Summary of Evaluation Rubric & Mark Distribution

| Course Outcome (CO) | Criteria Description | Max Marks | Targeted Strategy for Full Marks |
| :--- | :--- | :---: | :--- |
| **CO-2** | 1. Major Modules Completion status w.r.t Scope (6 Marks)<br>2. Team Coordination Status (2 Marks) | **8 Marks** | Highlight 100% completion of Module 1 scope + clear role breakdown between Student 1 & Student 2. |
| **CO-5** | 1. Validation (Field & Code level) (2 Marks)<br>2. Test Cases (Automated Selenium + Pytest) (3 Marks)<br>3. UI Look & Feel ("Marginalia" Design System) (2 Marks) | **7 Marks** | Show Pydantic input validation, live Selenium automated test reports with screenshots, and paper-and-ink UI. |
| **CO-4** *(Highest Weight)* | 1. Algorithms, APIs & DB Schema Sync (7 Marks)<br>2. Tech Stack Rationale & Suitability (3 Marks) | **10 Marks** | Deep dive into Argon2id hashing, HEC CLO weighted algorithms, Redis Cache-Aside, and PostgreSQL ORM sync. |
| **CO-3** | 1. Implementation aligns with proposed solution (5 Marks) | **5 Marks** | Direct side-by-side mapping of original FYP proposal features to working software deliverables. |
| **TOTAL** | **Full FYP Evaluation** | **30 Marks** | **30 / 30 Target Strategy** |

---

# SECTION 1: CO-2 DEFENSE (8 MARKS) – MODULE COMPLETION & TEAM COORDINATION

### 1. Major Modules Completion Status (6 Marks)
- **What to present:** Clearly state that Module 1 is **100% Complete** according to the approved scope document.
- **Scope vs. Implementation Breakdown:**
  - ✅ **Authentication & Security:** Argon2id password hashing, Dual JWT tokens, 4-tier Role-Based Access Control (Admin, Professor, TA, Student).
  - ✅ **Course & Roster Management:** Course creation, 6-character hex join code generation, direct student enrolment, and bulk CSV roster import.
  - ✅ **Assignment & Rubric Engine:** HEC CLO mapping to rubric criteria, assignment wizard, submission infrastructure.
  - ✅ **Analytics & Insights Engine:** Real-time class statistics (Mean, Median, StdDev), HEC letter grade conversion, Redis caching layer, At-Risk detection, and PDF report export.
  - ✅ **Frontend & UI System:** Bespoke "Marginalia" paper-and-ink design system implemented across Web & Mobile.

### 2. Team Coordination Status (2 Marks)
- **How to explain team collaboration:**
  - **Student 1 (Yasin Asif – Lead Backend & Architecture):** Designed API contracts (OpenAPI/FastAPI), database schemas (PostgreSQL + Alembic), Argon2id security engine, Redis caching, and Celery worker queues.
  - **Student 2 (Co-Developer – Frontend, UI/UX & Testing):** Implemented Flutter frontend features, "Marginalia" adaptive UI layouts (Ledger Rail for Web & Bottom Nav for Mobile), state management, and automated Selenium/Pytest test suites.
  - **Collaboration Workflow:** Used Git feature branching, pull-request code reviews, and automated schema synchronization via Pydantic model validation.

---

# SECTION 2: CO-5 DEFENSE (7 MARKS) – TESTING, VALIDATION & UI LOOK AND FEEL

### 1. Software Testing & Validation (2 Marks)
- **Field-Level Validation:**
  - **Pydantic Schemas:** Strong data type enforcement at API boundaries (e.g., verifying email formats via `email-validator`, non-empty strings, numeric ranges for grades).
  - **Client-Side Form Guarding:** Flutter form validation preventing empty submissions or invalid join codes before sending network requests.
- **Code-Level Validation:**
  - **Database Transactions:** ACID compliance with automatic rollback on DB errors to prevent partial data corruption.
  - **HTTP Exception Handlers:** Explicit error handling (401 Unauthorized, 403 Forbidden, 404 Not Found) with structured JSON error messages.

### 2. Automated & Manual Test Cases (3 Marks)
- **Automated UI Testing (Selenium):** Show the `testing_assignment/` suite!
  - Automated Selenium test scripts (`run_real_tests.py`, `test_flutter.py`) verifying login, course addition, and roster updates.
  - Show the generated HTML test report (`testing_assignment/report.html`) and execution screenshots (`success_login.png`, `success_add_semester.png`).
- **Automated API Testing (Pytest + HTTPX):**
  - Asynchronous unit and integration tests (`pytest-asyncio`) testing auth endpoints, JWT decoding, and course CRUD logic.

### 3. Look & Feel of User Interfaces (2 Marks)
- **"Marginalia" Design System:**
  - Inspired by classic academic ledgers and paper typography.
  - **Color Tokens:** Warm Canvas background (`#F6F5F0`), Fountain-Pen Navy text (`#1E2A38`), zero drop shadows, hairline borders.
  - **Typography:** *Fraunces* (Serif headings), *Inter* (UI body), *JetBrains Mono* (Tabular data & metrics).
  - **Responsive Flows:** Dynamic layout adaptation—Ledger Rail on desktop browsers, Bottom Navigation Bar on mobile screens.

---

# SECTION 3: CO-4 DEFENSE (10 MARKS) – ALGORITHMS, APIS, DB SYNC & TECH STACK

### 1. Understanding of Implemented Algorithms, APIs & DB Schema Sync (7 Marks)
*This carries the highest marks in the evaluation sheet. Be ready to explain these 4 core components:*

#### A. Core Algorithms Implemented
1. **Argon2id Hashing Algorithm:** Memory-hard password encryption using `memory_cost=65,536 KB` and `time_cost=2` to prevent GPU brute-force cracking.
2. **Weighted HEC Grade Aggregation Algorithm:**
   $$\text{Final Mark} = (w_q \times \bar{Q}) + (w_a \times \bar{A}) + (w_m \times M) + (w_f \times F)$$
   Automatically maps final percentage scores into HEC letter grades (`A`, `A-`, `B+`, `B`, `B-`, `C+`, `C`, `F`).
3. **Automated At-Risk Student Detection Algorithm:** Iterates through enrolled cohort performance, scans weighted averages against threshold $\theta = 50.0\%$, and logs categorized risk flags.

#### B. API Architecture
- Asynchronous FastAPI endpoints utilizing Python `asyncio` and `asyncpg` drivers for non-blocking I/O.
- Restful resource routing under `/api/v1/` guarded by JWT bearer authentication middleware.

#### C. DB Schema Synchronization & Caching
- **ORM & Migrations:** SQLAlchemy 2.0 Async ORM synchronized with PostgreSQL 16 schema via **Alembic** migration scripts.
- **Redis Cache-Aside Pattern:** Analytics endpoints query Redis (`analytics:{course_id}`) with a 5-minute TTL. On cache miss, results are computed from PostgreSQL, stored in Redis, and returned immediately (< 5ms on cache hits).

### 2. Suitable Technologies & Technical Rationale (3 Marks)
- **Flutter (Dart):** Single unified codebase for Web, Android, and iOS. Direct native rendering without web-view overhead.
- **FastAPI (Python):** Sub-second response times, native async event loop, Pydantic data safety, and automatic OpenAPI documentation.
- **PostgreSQL 16:** ACID transactional guarantees essential for grade records and enrolment integrity.
- **Redis & Celery:** Redis for in-memory caching and message brokering; Celery for non-blocking background processing (bulk CSV uploads & email dispatch).

---

# SECTION 4: CO-3 DEFENSE (5 MARKS) – PROPOSED SOLUTION ALIGNMENT

### 1. Implementation According to Proposed Solution (5 Marks)
- **Direct Proposal vs. Implementation Traceability:**

| Proposed Feature in FYP Scope | Delivered Implementation Status | Code Evidence / Endpoint |
| :--- | :--- | :--- |
| **HEC Outcome (CLO) Mapping** | 100% Implemented & Verified | `POST /api/v1/courses/{id}/clos`, Rubric-CLO schema |
| **Multi-Role User Hierarchy** | 100% Implemented & Verified | `app/core/dependencies.py` (`require_roles`) |
| **Course & Student Onboarding** | 100% Implemented & Verified | 6-char hex join code + `POST /courses/{id}/enroll/csv` |
| **Academic Analytics & Reports** | 100% Implemented & Verified | `GET /courses/{id}/analytics` + WeasyPrint PDF export |
| **Cross-Platform Accessibility** | 100% Implemented & Verified | Flutter Web + Android APK (`professor-os.apk`) |

---

# SECTION 5: SLIDE DECK SLIDE-BY-SLIDE MAPPING FOR EVALUATORS

When presenting your slides, clearly display the target CO in the top corner of each slide so evaluators know exactly which criteria they are grading!

```
Slide 1: Title & Overview ───────────────────────────── (Intro)
Slide 2: Problem & Proposed Solution ────────────────── (CO-3: Proposed Alignment - 5 Marks)
Slide 3: Major Modules & Team Coordination ──────────── (CO-2: Scope & Team Work - 8 Marks)
Slide 4: System Architecture & Tech Stack Rationale ──── (CO-4: Suitable Tech - 3 Marks)
Slide 5: Security & Argon2id Hashing Algorithm ───────── (CO-4: Algorithms & APIs - 7 Marks)
Slide 6: DB Schema, Alembic & Redis Cache Sync ───────── (CO-4: DB Synchronization - 7 Marks)
Slide 7: Validation, Testing & Selenium Suite ────────── (CO-5: Testing & Validation - 5 Marks)
Slide 8: "Marginalia" UI Design & User Flow ──────────── (CO-5: UI Look & Feel - 2 Marks)
Slide 9: Live Demonstration Agenda ──────────────────── (CO-2/CO-3: Working Deliverable)
Slide 10: Conclusion & Summary ──────────────────────── (Wrap-up)
```
