# ProfessorOS Authorization Matrix (Phase 2 Forensic Analysis)

This document maps all API routes across the ProfessorOS platform, specifying expected role and scope enforcement versus verified implementation status.

## TA Authorization Architecture Decision
- A Teaching Assistant (TA) is an `Enrollment` record with `role="ta"` for that specific course.
- Authorization uses course enrollment role (`Enrollment.role == "ta"`), **never** global `users.role` alone.
- Canonical verification helper: `verify_course_staff_access(course_id, user, allow_ta: bool, assignment_id=None)`.
  - **Professor owner** and **Admin** always pass.
  - **TA** passes only if enrolled as `"ta"` in that specific `course_id`.
  - For assignment-level grading and decision endpoints, TA passes only if delegated in `assignment_ta_table` for that assignment.

---

## Route Authorization Matrix

| Endpoint | Method | Required Roles | Course/Resource Scope Check | TA Delegation Required? | Status |
| :--- | :---: | :--- | :--- | :---: | :--- |
| `/api/v1/courses/{course_id}` | GET | Authenticated | Enrolled student, course staff, or admin | No | Enforced |
| `/api/v1/courses/{course_id}` | PUT | Prof, Admin | Course professor or admin | No | Enforced |
| `/api/v1/courses/{course_id}` | DELETE | Prof, Admin | Archive course (soft delete) | No | Enforced |
| `/api/v1/courses/{course_id}/permanent` | DELETE | Prof, Admin | Permanent delete | No | Enforced (Requires attempt guard) |
| `/api/v1/courses/{course_id}/enrollments` | GET | Prof, Admin, TA | Course staff or admin | No | **Fixed in Phase 2** |
| `/api/v1/courses/{course_id}/enroll` | POST | Prof, Admin | Course staff or admin | No | Enforced |
| `/api/v1/courses/{course_id}/enroll/csv` | POST | Prof, Admin | Course staff or admin | No | Enforced |
| `/api/v1/courses/{course_id}/assignments` | GET | Authenticated | Enrolled student or course staff | No | Enforced |
| `/api/v1/courses/{course_id}/assignments` | POST | Prof, Admin, TA | Course staff or admin | No | **Fixed in Phase 2** |
| `/api/v1/courses/{course_id}/assignments/{aid}` | GET | Authenticated | Enrolled student or course staff | No | Enforced (Hides Qs before start) |
| `/api/v1/courses/{course_id}/assignments/{aid}` | PUT | Prof, Admin, TA | Course staff or admin | No | **Fixed in Phase 2** (Locked after attempts) |
| `/api/v1/courses/{course_id}/assignments/{aid}` | DELETE | Prof, Admin | Course staff or admin | No | Enforced (Requires attempt guard) |
| `/api/v1/courses/{course_id}/assignments/{aid}/publish`| POST | Prof, Admin, TA | Course staff or admin | No | **Fixed in Phase 2** |
| `/api/v1/courses/{course_id}/assignments/{aid}/submissions` | GET | Prof, Admin, TA | Course staff or admin | No | Enforced |
| `/api/v1/submissions/{sid}/grade` | PUT | Prof, Admin, TA | Staff of submission course | **Yes** (if TA) | **Fixed in Phase 2** |
| `/api/v1/submissions/{sid}/ai-grade` | POST | Prof, Admin, TA | Staff of submission course | **Yes** (if TA) | **Fixed in Phase 2** |
| `/api/v1/attempts/{attempt_id}/state` | GET | Student, Prof, Admin, TA | Attempt student OR course staff | No | **Fixed in Phase 2** |
| `/api/v1/attempts/{attempt_id}/result`| GET | Student, Prof, Admin, TA | Attempt student OR course staff | No | **Fixed in Phase 2** |
| `/api/v1/courses/.../exam/attempts/{aid}/decision` | POST | Prof, Admin, TA | Course staff or admin | No | **Fixed in Phase 2** |
