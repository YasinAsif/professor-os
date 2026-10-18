# CONTEXT PART 10: COURSES, ENROLLMENT, CONTENT & RAG PIPELINE

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Course Creation, Settings & Lifecycle

### 1.1 Creation & Validation
`[CODE]` Course creation is handled by `POST /courses` in [backend/app/api/v1/courses.py:57-72](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L57-L72), restricted to `require_roles("admin", "professor")`.
- Professors can only create courses where `professor_id == user.id`. Admins can specify any valid professor ID ([courses.py:65](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L65)).
- The backend validates that the assigned `professor_id` belongs to an approved professor account in [backend/app/services/course_service.py:48-56](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L48-L56):

```python
# backend/app/services/course_service.py:48-56
professor = await self.db.get(User, professor_id)
if not professor:
    raise ValueError("Professor not found.")
if professor.role != "professor":
    raise ValueError("The selected user is not a professor.")
if not professor.is_approved:
    raise ValueError("The selected professor's account is not yet approved.")
```

### 1.2 HEC Assessment Weightage Validation
`[CODE]` Higher Education Commission (HEC) policy enforcement requires that the 4 assessment categories sum to exactly 100%. This is validated during course creation ([course_service.py:57-59](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L57-L59)) and course updating ([course_service.py:124-131](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L124-L131)):

```python
# backend/app/services/course_service.py:57-59
total = data.quiz_weight + data.assignment_weight + data.midterm_weight + data.final_weight
if total != 100:
    raise ValueError(f"HEC weights must sum to 100 (currently {total}).")
```

Default weights in the database model [backend/app/models/course.py:33-36](file:///e:/FYP_YASIN/backend/app/models/course.py#L33-L36):
- `quiz_weight`: 20
- `assignment_weight`: 20
- `midterm_weight`: 20
- `final_weight`: 40

### 1.3 Join Code Generation
`[CODE]` Every course automatically receives a unique alphanumeric join code upon instantiation ([course.py:16-17, 26](file:///e:/FYP_YASIN/backend/app/models/course.py#L16-L17)):

```python
# backend/app/models/course.py:16-17, 26
def generate_join_code() -> str:
    return secrets.token_hex(3).upper()

join_code: Mapped[str] = mapped_column(String(10), nullable=True, unique=True, index=True, default=generate_join_code)
```
`secrets.token_hex(3).upper()` generates a 6-character cryptographic hex string (e.g., `4F8A2E`).

### 1.4 Course Updating, Archiving vs. Permanent Deletion
`[CODE]`
- **Update (`PUT /courses/{course_id}`)**: [courses.py:94-106](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L94-L106). Allowed for owning professor or admin ([course_service.py:120-122](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L120-L122)). Normalizes `code` to uppercase.
- **Archive (`DELETE /courses/{course_id}`)**: [courses.py:109-122](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L109-L122). Performs a soft archive by setting `course.is_archived = True` ([course_service.py:143](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L143)). Archived courses cannot be joined via join code ([course_service.py:264](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L264)).
- **Permanent Delete (`DELETE /courses/{course_id}/permanent`)**: [courses.py:124-137](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L124-L137). Executes `self.db.delete(course)` ([course_service.py:151](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L151)). Cascades across all linked entities via SQLAlchemy ORM cascade:
  - `enrollments`: `cascade="all, delete-orphan"` ([course.py:53-55](file:///e:/FYP_YASIN/backend/app/models/course.py#L53-L55))
  - `clos`: `cascade="all, delete-orphan"` ([course.py:56](file:///e:/FYP_YASIN/backend/app/models/course.py#L56))
  - `assignments`: `cascade="all, delete-orphan"` ([course.py:57-59](file:///e:/FYP_YASIN/backend/app/models/course.py#L57-L59))

---

## 2. Enrollment & TA Delegation

### 2.1 Student Self-Enrollment via Join Code
`[CODE]` `POST /courses/join` in [courses.py:197-212](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L197-L212), restricted to `require_roles("student")`.
- Verification rule in [course_service.py:259-261](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L259-L261):
  ```python
  user = await self.db.get(User, user_id)
  if not user or not can_student_join_course(user):
      raise PermissionError("Only approved active student accounts can join courses.")
  ```
  `can_student_join_course` verifies that `is_active == True` and `is_approved == True`.
- Checks for active, non-archived courses matching `join_code.strip().upper()` ([course_service.py:262-268](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L262-L268)).
- Prevents duplicate enrollment: throws `ValueError("You are already enrolled in this course.")` ([course_service.py:273-274](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L273-L274)).

### 2.2 Direct Enrollment & Roster CSV Import
`[CODE]`
- **Direct Enrollment (`POST /courses/{course_id}/enroll`)**: [courses.py:165-194](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L165-L194). Allows professors and admins to enroll a user by `user_id` or `email`.
- **Roster CSV Import (`POST /courses/{course_id}/enroll/csv`)**: [courses.py:232-248](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L232-L248).
  - Bounded upload check: `MAX_ROSTER_CSV_BYTES = 5 * 1024 * 1024` (5 MB) in [courses.py:32](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L32).
  - Processing logic in [course_service.py:177-227](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L177-L227):
    - Decodes with `utf-8-sig` to strip Excel BOM ([course_service.py:180](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L180)).
    - Expects `email` and optional `role` (defaults to `"student"`). Valid roles: `"student"`, `"ta"`.
    - Batch queries users via `User.email.in_(emails)` ([course_service.py:199](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L199)).
    - Detects existing enrollments in batch via `Enrollment.user_id.in_(user_ids)` ([course_service.py:206-211](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L206-L211)).
    - Appends row-level errors for missing users or duplicates, commits successful entries, and returns `{"created": created, "errors": errors}` ([course_service.py:227](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L227)).

### 2.3 TA Delegation & The Critical TA Lockout Architecture Bug
`[CODE]`
- **TA Delegation Route**: `POST /courses/{course_id}/ta` in [courses.py:303-322](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L303-L322). Calls `enroll_user(course_id, body.user_id, role="ta")`.
- **The TA Lockout Vulnerability / Architecture Disconnect**:
  In the database, a delegated user has an `Enrollment` record with `role="ta"`, while their `users.role` is typically `"student"` (or `"ta"`).
  However, management access across course operations is guarded by `verify_course_management_access` in [course_service.py:106-117](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L106-L117):

```python
# backend/app/services/course_service.py:106-117
async def verify_course_management_access(self, course_id: int, user: User) -> Course:
    """Verify user can manage course (edit enrollments, CLOs, etc.)."""
    course = await self.get_course(course_id)
    
    # Only professor owner or admin can manage
    if user.role == "admin":
        return course
    
    if user.role != "professor" or course.professor_id != user.id:
        raise PermissionError("No permission to manage this course.")
    
    return course
```
- **Consequence**:
  1. Even though `POST /courses/{course_id}/clos` has dependency `require_roles("professor", "admin", "ta")` in [courses.py:272](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L272), line 278 calls `verify_course_management_access(course_id, user)`, which raises `HTTP 403 No permission to manage this course` for any TA!
  2. TAs cannot create assignments, edit assignments, publish assignments, or record exam flag decisions (`/decision`), locking them out of core academic assistant responsibilities.

---

## 3. Course Materials & Document Ingestion Pipeline

### 3.1 Misplaced Router Architecture
`[CODE]` Course material upload, listing, download, and deletion endpoints are **not** located in `courses.py`. They are placed in [backend/app/api/v1/quizzes.py:220-440](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L220-L440) under the quizzes APIRouter!

### 3.2 Ingest Route & Storage Configuration
`[CODE]` `POST /courses/{course_id}/materials/ingest` in [quizzes.py:220-307](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L220-L307).
- Access control: `require_roles("professor", "admin", "ta")` validated via `course_svc.get_course_with_access_check(course_id, user)` ([quizzes.py:237](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L237)).
- Allowed file formats: `.pdf`, `.pptx`, `.docx`, `.txt`, `.md` ([quizzes.py:242](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L242)).
- Upload size cap: `MAX_UPLOAD_BYTES = 25 * 1024 * 1024` (25 MB) in [quizzes.py:233, 267](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L233).
- Path Traversal prevention: filename sanitized via `_sanitize_filename(file.filename)` ([quizzes.py:243](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L243)).
- File Storage Location: `STORAGE_ROOT/uploads/course_{course_id}/{uuid}_{safe_name}` ([quizzes.py:252-257](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L252-L257)).

### 3.3 Worker Execution: Celery vs. FastAPI BackgroundTasks
`[CODE]` In [quizzes.py:277-298](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L277-L298), the API dispatches the indexing task:
1. It attempts to dispatch to Celery: `ingest_course_document_task.delay(...)` with a base64 encoded copy of the file payload (`file_data_b64`) to handle multi-container deployments where web and worker containers do not share storage ([quizzes.py:280-286](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L280-L286)).
2. If Celery or Redis is unreachable (`except Exception as celery_err:`), it logs a warning and falls back immediately to in-process execution via FastAPI `background_tasks.add_task(_process_course_document_background, ...)` ([quizzes.py:289-298](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L289-L298)).

### 3.4 Document Parsing Hierarchy (Docling & Fallbacks)
`[CODE]` Handled by `DoclingPipeline.parse_document_to_markdown` in [backend/app/services/document_ingestion.py:152-242](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L152-L242):
1. **Primary**: IBM Docling (`from docling.document_converter import DocumentConverter`) exports document to structured markdown ([document_ingestion.py:166-172](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L166-L172)).
2. **Fallback (`except ImportError`)**:
   - `.txt`, `.md`: Reads raw UTF-8 string ([document_ingestion.py:176-177](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L176-L177)).
   - `.pdf`: PyMuPDF (`fitz`) page-by-page text extraction; if PyMuPDF fails, cascades to `pypdf.PdfReader` ([document_ingestion.py:180-205](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L180-L205)).
   - `.docx`: `python-docx` (`docx.Document`) extracts paragraph texts ([document_ingestion.py:207-215](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L207-L215)).
   - `.pptx`: Extracts raw XML slide contents from zip container (`ppt/slides/slide*.xml`) using `xml.etree.ElementTree` ([document_ingestion.py:217-234](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L217-L234)).

### 3.5 Vector Indexing & Zero-Latency Embeddings
`[CODE]`
- **Embeddings**: In [document_ingestion.py:120-134](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L120-L134), to bypass heavy 500MB PyTorch model downloads in resource-constrained environments:
  ```python
  # backend/app/services/document_ingestion.py:122-133
  if os.environ.get("ENABLE_PYTORCH_EMBEDDINGS", "false").lower() != "true":
      from sklearn.feature_extraction.text import HashingVectorizer
      vectorizer = HashingVectorizer(n_features=384, alternate_sign=False, norm="l2")

      class SimpleEncoder:
          def encode(self, texts, normalize_embeddings=True, show_progress_bar=False):
              mat = vectorizer.transform(texts)
              return mat.toarray().astype(np.float32)

      self._embedding_model = SimpleEncoder()
      _SHARED_EMBEDDING_MODEL = self._embedding_model
      return self._embedding_model
  ```
- **FAISS vs. NumPy Vector Store**:
  - If `faiss` is installed: builds `faiss.IndexFlatIP(384)` index stored in `faiss_indexes/course_{course_id}.index` and metadata in `course_{course_id}_meta.json` ([document_ingestion.py:265-298](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L265-L298)).
  - If `faiss` is not installed: falls back to NumPy dot-product store saved via `np.save` to `course_{course_id}.index` and performs top-k cosine similarity via `np.dot(vectors, q_vec_np.T).flatten()` ([document_ingestion.py:300-325, 380-391](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L300-L325)).

---

## 4. Course Chat (RAG) & Strict Cross-Course Isolation

### 4.1 Chat Endpoint & Flow
`[CODE]` `POST /courses/{course_id}/chat` in [courses.py:326-460](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L326-L460).
1. **Access Check**: Enrolled students, professors, and TAs can access ([courses.py:340](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L340)).
2. **Intent Routing**: Runs `LocalIntentRouter.route(message)` for fast sub-35ms categorization ([courses.py:346-353](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L346-L353)).
3. **Vector Retrieval**: Calls `DoclingPipeline(course_id=course_id).search(message, top_k=3)` ([courses.py:356-357](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L356-L357)).
4. **Prompt Construction**: Compiles retrieved chunks with chunk IDs and source filenames, prompting the LLM (`MODEL_RAG_PRIMARY = "qwen/qwen3.8-27b"`) to act as an academic AI Teaching Assistant ([courses.py:378-400](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L378-L400)).

### 4.2 Cross-Course Isolation Guarantee
`[CODE]` Isolation is enforced at the file system level. Vector indexes are partitioned strictly per course:
`FAISS_STORAGE_PATH/course_{course_id}.index` and `course_{course_id}_meta.json`.
Because `DoclingPipeline(course_id=course_id)` exclusively reads and writes to its own `course_{course_id}` index file ([document_ingestion.py:110-111](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L110-L111)), **zero cross-course material leakage can occur**.

### 4.3 Hardcoded Mock Fallback Responses in Production Code
`[CODE]` If the LLM client call fails (network partition, rate limit, missing API key) and no course documents are indexed, lines 424-453 in [courses.py](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L424-L453) contain hardcoded keyword mocks:

```python
# backend/app/api/v1/courses.py:424-453
q_lower = body.message.lower()
if "sliding window" in q_lower:
    reply_text = (
        "**Sliding Window Protocol:**\n\n"
        "A sliding window protocol is a foundational flow control mechanism..."
    )
elif "tcp" in q_lower or "udp" in q_lower:
    reply_text = (
        "**TCP vs. UDP Protocol Architecture:**\n\n"
        "- **TCP (Transmission Control Protocol):** Connection-oriented..."
    )
elif "process" in q_lower and "thread" in q_lower:
    reply_text = (
        "**Processes vs. Threads:**\n\n"
        "- **Process:** An independent program in execution..."
    )
elif "deadlock" in q_lower:
    reply_text = (
        "**Deadlock in Operating Systems:**\n\n"
        "A situation where a set of processes are blocked..."
    )
```

---

## 5. Announcements, Notifications & Emails

### 5.1 Announcements & In-App Notifications: [NOT DONE]
`[NOT DONE]`
- **Announcements**: There are **zero** database models, tables, migrations, or endpoints for course announcements. No `announcements` table exists in PostgreSQL.
- **In-App Notifications**: There are **zero** notification tables or WebSocket notification hubs for student alert badges.

### 5.2 Email Notification Infrastructure
`[CODE]` Implemented in [backend/app/services/email_service.py](file:///e:/FYP_YASIN/backend/app/services/email_service.py).
- Selected via `settings.EMAIL_BACKEND` (`"resend"`, `"smtp"`, or `"console"`).
- **Resend SDK (`_try_resend`)**: In [email_service.py:121-141](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L121-L141). Sends via `resend.Emails.send(...)` using `settings.RESEND_API_KEY`.
- **Gmail SMTP Dual-Port Fallback (`_try_smtp`)**: In [email_service.py:144-180](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L144-L180). Attempts Port 465 SSL first; if failed, falls back to Port 587 STARTTLS.
- **Console Mode (`_send_console`)**: In [email_service.py:184-198](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L184-L198). Writes HTML body to `latest_email.html` on disk and prints summary to console.
- **Supported Email Triggers**:
  1. Verification email (`verification_email_html`, [email_service.py:66-75](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L66-L75))
  2. Password reset (`reset_password_email_html`, [email_service.py:78-87](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L78-L87))
  3. Account activation / welcome (`welcome_email_html`, [email_service.py:90-96](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L90-L96))
  4. Admin approval / rejection (`approval_email_html`, `rejection_email_html`, [email_service.py:99-116](file:///e:/FYP_YASIN/backend/app/services/email_service.py#L99-L116))

---

## 6. Student Dashboard Aggregation

### 6.1 Endpoint & Query Pipeline
`[CODE]` `GET /users/me/student-dashboard` in [backend/app/api/v1/users.py:52-77](file:///e:/FYP_YASIN/backend/app/api/v1/users.py#L52-L77).
- Restricted to `require_roles("student")`.
- Queries all active enrollments for the student with joined courses and assignments:
  ```python
  # backend/app/api/v1/users.py:57-64
  courses_result = await db.execute(
      select(Course)
      .join(Enrollment)
      .where(Enrollment.user_id == user.id, Enrollment.role == "student")
      .options(selectinload(Course.assignments))
      .order_by(Course.created_at.desc())
  )
  ```
- Collects all assignment IDs across the student's courses and fetches the student's corresponding `Submission` records ([users.py:65-75](file:///e:/FYP_YASIN/backend/app/api/v1/users.py#L65-L75)).

### 6.2 Aggregation Logic
`[CODE]` Aggregated in [backend/app/services/student_dashboard_service.py:11-87](file:///e:/FYP_YASIN/backend/app/services/student_dashboard_service.py#L11-L87):
- Filters out non-published assignments (`assignment.status != "published"`).
- Parses `submission.evaluation_metadata` JSON for `needs_review` and `triage_reasons` flags ([student_dashboard_service.py:27-33](file:///e:/FYP_YASIN/backend/app/services/student_dashboard_service.py#L27-L33)).
- Constructs:
  - `courses`: Enrolled course metadata and published assignment counts.
  - `upcoming`: Up to 10 unexpired assignments sorted ascending by deadline (`assignment.deadline >= now`).
  - `feedback`: Up to 10 graded submissions with score, feedback text, and triage reasons, sorted descending by `graded_at`.
  - `stats`: Totals for `enrolled_courses`, `published_assignments`, `pending`, and `graded`.

---

PART 10 DONE
