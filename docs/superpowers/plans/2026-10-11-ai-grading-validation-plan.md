# AI Grading Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent malformed or internally inconsistent AI grading responses from being persisted as valid grades, including document submissions.

**Architecture:** Keep document extraction unchanged because PDF/DOCX extraction already works. Add strict validation to the grading response model and make the shared structured-response client reject empty objects, so synchronous, batch, and Celery grading all fail safely before writing a grade.

**Tech Stack:** Python, Pydantic v2, FastAPI services, pytest.

---

### Task 1: Regression tests for invalid grading output

**Files:**
- Modify: `backend/tests/test_audit_fixes.py`
- Test: `backend/app/services/grading_pipeline.py`, `backend/app/config/llm_config.py`

- [x] **Step 1: Write tests proving empty responses and score mismatches are rejected.**
- [x] **Step 2: Run the focused tests and confirm they fail for the current implementation.**

### Task 2: Enforce grading invariants

**Files:**
- Modify: `backend/app/services/grading_pipeline.py`
- Modify: `backend/app/config/llm_config.py`

- [x] **Step 1: Reject empty structured objects before Pydantic defaults can create a fake grade.**
- [x] **Step 2: Require at least one criterion and validate score bounds and aggregate consistency.**
- [x] **Step 3: Run the regression tests and confirm they pass.**

### Task 3: Verify document grading paths

**Files:**
- Modify: `backend/tests/test_audit_fixes.py`

- [x] **Step 1: Keep PDF and DOCX extraction coverage, including DOCX tables.**
- [x] **Step 2: Run focused grading/document tests and the full backend suite.**
- [x] **Step 3: Report remaining environment-only failures separately from code failures.**
