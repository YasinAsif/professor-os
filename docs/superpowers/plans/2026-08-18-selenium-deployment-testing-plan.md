# Selenium Deployment Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stale mixed testing package with a reliable Selenium suite for deployed authentication, admin, and course-management flows.

**Architecture:** A pytest fixture owns one Chrome driver per test and failure screenshot handling. Small page objects provide explicit waits and keyboard/text helpers suited to Flutter Web; test modules contain only user-visible behavior assertions.

**Tech Stack:** Python 3.11+, pytest, Selenium 4, Chrome/ChromeDriver, environment variables.

---

### Task 1: Replace the legacy testing package

**Files:**
- Delete: `testing_assignment/` (all contents)
- Create: `selenium_tests/` and its subdirectories

- [ ] **Step 1: Remove only the requested legacy folder**

Run: `Remove-Item -LiteralPath 'testing_assignment' -Recurse -Force`
Expected: the old mixed folder no longer exists.

- [ ] **Step 2: Create the new folder skeleton**

Create `selenium_tests/pages` and `selenium_tests/tests`, each with `__init__.py`.

### Task 2: Add shared Selenium configuration and page objects

**Files:**
- Create: `selenium_tests/conftest.py`
- Create: `selenium_tests/pages/base_page.py`
- Create: `selenium_tests/pages/login_page.py`
- Create: `selenium_tests/pages/authenticated_page.py`

- [ ] **Step 1: Add the driver fixture**

Read `APP_URL`, `SELENIUM_TIMEOUT`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` from the environment. Configure headless Chrome, maximize the viewport, set page-load timeout, and save a screenshot on test failure.

- [ ] **Step 2: Add explicit-wait helpers**

Implement `wait_for_page_ready`, `wait_for_text`, `wait_for_any_text`, `click_text`, and `fill_inputs_by_order`. Each helper must use `WebDriverWait`; no `time.sleep` is allowed.

- [ ] **Step 3: Add login and authenticated navigation helpers**

Login by finding visible inputs or using keyboard fallback, click a semantic login/sign-in control, wait for a route/title/content change, and expose `is_authenticated`, `open_admin`, and `open_courses` helpers.

### Task 3: Add failing Selenium test cases first

**Files:**
- Create: `selenium_tests/tests/test_smoke.py`
- Create: `selenium_tests/tests/test_authentication.py`
- Create: `selenium_tests/tests/test_admin.py`
- Create: `selenium_tests/tests/test_courses.py`

- [ ] **Step 1: Write smoke tests**

Cover page readiness and a visible login/authentication affordance.

- [ ] **Step 2: Write authentication tests**

Cover empty credentials, invalid password, and valid admin login. Mark the valid-login-dependent test with a skip when credentials are unavailable.

- [ ] **Step 3: Write admin tests**

After valid login, assert admin route or admin-related text, then assert at least one admin control/section such as semester, users, approvals, or dashboard.

- [ ] **Step 4: Write course tests**

After valid login, navigate to course-management UI, assert course/course-management text, and assert at least one visible course control such as create, join, roster, assignment, or course.

- [ ] **Step 5: Run collection/import validation**

Run: `python -m pytest --collect-only -q selenium_tests/tests`
Expected: collection succeeds and the tests are visible; live tests may be skipped or fail until helper behavior is completed.

### Task 4: Make the suite pass against the deployment

**Files:**
- Modify: `selenium_tests/pages/base_page.py`
- Modify: `selenium_tests/pages/login_page.py`
- Modify: `selenium_tests/pages/authenticated_page.py`
- Modify: `selenium_tests/tests/*.py`

- [ ] **Step 1: Run the smoke suite against `APP_URL`**

Run: `$env:APP_URL='https://professor-os-production.up.railway.app'; python -m pytest -v selenium_tests/tests/test_smoke.py`
Expected: page-readiness tests pass.

- [ ] **Step 2: Run authenticated tests with credentials supplied securely**

Run with `ADMIN_EMAIL` and `ADMIN_PASSWORD` set in the shell, never committed to source.
Expected: authentication, admin, and courses tests pass or report a clear application-side failure.

- [ ] **Step 3: Remove brittle behavior revealed by failures**

Replace fixed sleeps, hard-coded tab counts, fake success return values, and assumptions about a dashboard URL with explicit waits and content-based assertions.

### Task 5: Document and verify handoff

**Files:**
- Create: `selenium_tests/README.md`
- Create: `selenium_tests/requirements.txt`
- Modify: `README.md`

- [ ] **Step 1: Document setup and commands**

Explain installation, Chrome requirements, environment variables, safe default behavior, optional screenshots, and commands for smoke versus authenticated tests.

- [ ] **Step 2: Update the root testing documentation**

Point the root README to `selenium_tests` and remove claims that refer to the deleted mock suite.

- [ ] **Step 3: Run final verification**

Run: `python -m pytest --collect-only -q selenium_tests/tests` and `rg -n "time\.sleep|mock_server|127\.0\.0\.1:8080|pretend|assume" selenium_tests`
Expected: collection succeeds and the second command returns no obsolete implementation patterns.
