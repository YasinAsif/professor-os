# Repository Cleanup Proposal (Phase 0.1)

## Context & Objectives
During the codebase safety and architecture audit, several large binary artifacts, redundant directories, and tracked database dumps were identified in the repository tree.
Per the safety protocol, no files are deleted directly without this formal proposal and review.

---

## 1. Large Committed Binary Assets

### Findings
- `backend/static/professor-os.apk` (~26.4 MB)
- `ProfessorOS_FYP_Report_30pct.docx` (~4.2 MB)
- `ProfessorOS_FYP_Report_Formatted.docx` (~4.2 MB)
- `Professor OS_SDS (1).pdf` (~1.7 MB)
- `ProfessorOS_SRS.pdf` (~1.7 MB)
- `ProfessorOS_Scope_Document (2).pdf` (~0.7 MB)

### Proposed Action
1. **Android APK**:
   - Move build artifacts out of version control.
   - Publish APKs exclusively via GitHub Releases or CI/CD deployment pipelines (e.g. Railway / GitHub Actions Artifacts).
   - Retain `.gitignore` entry `*.apk` (already active in `.gitignore`) and untrack the file via `git rm --cached backend/static/professor-os.apk`.
2. **Project Documentation & Reports (`.docx`, `.pdf`)**:
   - Move project proposals, SRS, SDS, and progress report drafts to a dedicated documentation archive or repository releases tag.
   - Store official living documentation in plain Markdown (`docs/`) to maintain git diff visibility and avoid repository bloat.

---

## 2. Duplicate Static Web Directories

### Findings
Two parallel static directories currently exist:
- `backend/app/static/` (31 files)
- `backend/static/` (36 files)

In `backend/app/main.py`:
```python
STATIC_DIR = Path(__file__).parent / "static"
if not STATIC_DIR.exists():
    STATIC_DIR = Path(__file__).parent.parent / "static"
```
The fallback causes confusion regarding which build is served in production versus local environments.

### Proposed Action
1. Standardize on a single static build target: `backend/static/` (consistent with Dockerfile and Railway build commands).
2. Remove redundant directory `backend/app/static/` after verifying identical hash assets.
3. Update `backend/app/main.py` to point directly to `backend/static/` without ambiguity.

---

## 3. Database Dumps and Backups

### Findings
- `backups/professor_os_live.sql` was previously tracked or present.
- `backend/backups/` exists in `.gitignore`.

### Proposed Action
1. Ensure all `*.sql`, `*.dump`, and `*.bak` files are untracked from git history.
2. Store database backups in secure external cloud object storage (S3 / Railway persistent volumes) rather than within the application code repository.
