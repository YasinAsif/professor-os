# CONTEXT PART 12: OBE, CLO, ANALYTICS & HEC ACCREDITATION REPORTS

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Outcome-Based Education (OBE) & CLO Architecture

### 1.1 CLO Definitions & Data Model
`[CODE]` Defined in [backend/app/models/course.py:56](file:///e:/FYP_YASIN/backend/app/models/course.py#L56) and [backend/app/services/course_service.py:237-256](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L237-L256):
- **CLO Model**: `clos(id, course_id, code, description)`.
- **Assignment Mapping**: Many-to-many junction table `assignment_clos(assignment_id, clo_id)` in [backend/app/models/assignment.py:29-34](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L29-L34).
- **CRUD Operations**:
  - `GET /courses/{course_id}/clos`: [backend/app/api/v1/courses.py:252-267](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L252-L267).
  - `POST /courses/{course_id}/clos`: [backend/app/api/v1/courses.py:269-284](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L269-L284).
  - `DELETE /courses/{course_id}/clos/{clo_id}`: [backend/app/api/v1/courses.py:286-301](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L286-L301).

### 1.2 Washington Accord / HEC Attainment Calculation Engine
`[CODE]` Implemented in [backend/app/services/clo_attainment.py](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py):
- **Standards Implemented**: Higher Education Commission (HEC) and Washington Accord Outcome-Based Education (OBE) metrics.
- **Attainment Thresholds**:
  - Student Passing Benchmark: `passing_threshold_pct = 50.0%` ([clo_attainment.py:73](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py#L73)).
  - Cohort KPI Benchmark: `kpi_target_pct = 60.0%` (at least 60% of students must pass the outcome to achieve accreditation compliance) ([clo_attainment.py:37, 74](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py#L37)).
- **Historical Persistence**: Attainment runs are recorded to the PostgreSQL `attainment_records` table ([clo_attainment.py:9, 76](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py#L9)).
- **Continuous Quality Improvement (CQI)**:
  If a CLO fails to achieve the 60% KPI threshold, `_generate_cqi_recommendation` automatically synthesizes remediation actions ([clo_attainment.py:51-65](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py#L51-L65)):
  - **Gap > 20%**: *"Major CQI Deficit... Recommend restructuring prerequisite lab sessions, allocating 2 dedicated tutorial lectures, and revising question pacing for the next offering."*
  - **Gap <= 20%**: *"Minor CQI Gap... Recommend supplementary remedial assignments and targeted formative quizzes on this outcome."*

### 1.3 Misplaced Route Mounting for CLO Attainment
`[CODE]` The API endpoint for CLO attainment is **not** mounted in `courses.py` or `analytics.py`. It is mounted in [backend/app/api/v1/quizzes.py:638-660](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L638-L660):
- Route: `GET /courses/{course_id}/clo-attainment?semester={semester}`
- Handler: Calls `compute_and_record_attainment(course_id=course_id, semester=semester, db=db)`.
- Background Queue: `calculate_clo_attainment_task` dispatched on Celery queue `reporting_queue` ([backend/app/tasks/__init__.py:12](file:///e:/FYP_YASIN/backend/app/tasks/__init__.py#L12)).

---

## 2. Course Analytics & Cohort Telemetry

### 2.1 Course Analytics Dashboard & Redis Caching
`[CODE]` Handled in `GET /courses/{course_id}/analytics` in [backend/app/api/v1/analytics.py:23-119](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L23-L119):
- **Caching**: Redis-backed with key `analytics:{course_id}` and a 5-minute TTL ([analytics.py:29-42](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L29-L42)).
- **Metrics Computed**:
  - `mean`: Arithmetic average of normalized student submission percentages ([analytics_service.py:50](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L50)).
  - `median`: Median submission percentage ([analytics_service.py:51](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L51)).
  - `std_dev`: Standard deviation across submissions ([analytics_service.py:52](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L52)).
  - `distribution`: 5 standard score buckets (`0-20`, `21-40`, `41-60`, `61-80`, `81-100`) ([analytics_service.py:55-66](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L55-L66)).
  - `cohort_trend`: Historical chronological sequence of assignment average scores ([analytics.py:73-94](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L73-L94)).
- **Snapshot Table**: Snapshot records are stored append-only in `analytics_snapshots` table ([backend/app/models/analytics.py:15-35](file:///e:/FYP_YASIN/backend/app/models/analytics.py#L15-L35)).

### 2.2 HEC Grade Scale
`[CODE]` Defined in [backend/app/services/analytics_service.py:15-28](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L15-L28):

```python
# backend/app/services/analytics_service.py:15-28
HEC_GRADES = {
    "W": {"min": 80, "label": "World Class"},
    "X": {"min": 60, "label": "Acceptable"},
    "Y": {"min": 40, "label": "Needs Improvement"},
    "Z": {"min": 0, "label": "Below Standard"},
}
```

### 2.3 At-Risk Student Detection
`[CODE]` Implemented in [backend/app/services/analytics_service.py:88-128](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L88-L128):
- Threshold source: Reads `Course.at_risk_threshold` (defaults to 40.0% in model, defaults to 50.0% fallback in analytics service) ([analytics_service.py:161](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L161)).
- Aggregates each enrolled student's mean score across all graded submissions.
- Reconciles existing records: Clears stale warnings via `DELETE FROM at_risk_students WHERE course_id = :course_id` and re-inserts current at-risk records ([analytics_service.py:96-98](file:///e:/FYP_YASIN/backend/app/services/analytics_service.py#L96-L98)).
- Endpoint: `GET /courses/{course_id}/analytics/at-risk` ([analytics.py:142-168](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L142-L168)).

---

## 3. Accreditation Dossiers & Report Exports

### 3.1 HEC Course Dossier Engine (PDF & HTML)
`[CODE]` Handled by `get_hec_course_dossier` in [backend/app/api/v1/quizzes.py:1218-1248](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L1218-L1248) and [backend/app/services/hec_dossier.py](file:///e:/FYP_YASIN/backend/app/services/hec_dossier.py):
- Route: `GET /courses/{course_id}/hec-dossier?semester={semester}`
- Output File: `STORAGE_ROOT/dossiers/course_{course_id}_{semester}.pdf`.
- Synthesis:
  - Section 1: Course Catalog & Syllabus Information.
  - Section 2: Course Learning Outcome (CLO) Attainment Summary against the 60% KPI threshold.
  - Section 3: Assessment weightage compliance (HEC 20/20/20/40 rule).
  - Section 4: Continuous Quality Improvement (CQI) Action Plan.
- Rendering Engine: Uses PyMuPDF (`fitz`) or WeasyPrint to construct formal academic vector PDF documents.
- Celery Task: `generate_hec_dossier_task` on queue `reporting_queue` ([hec_dossier.py:580-595](file:///e:/FYP_YASIN/backend/app/services/hec_dossier.py#L580-L595)).

### 3.2 Analytics PDF Export
`[CODE]` `GET /courses/{course_id}/analytics/pdf` in [backend/app/api/v1/analytics.py:170-433](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L170-L433).
- Generates a styled A4 report summarizing HEC compliance grade, cohort average, median score, score distribution table, criteria breakdown, and at-risk student table.
- Attempts WeasyPrint PDF compilation with fallback to raw HTML if WeasyPrint native dependencies are absent on host.

---

PART 12 DONE
