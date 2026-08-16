# SOFTWARE TEST PLAN (FYP-I — 30% Implementation Milestone)
### Prepared in Accordance with IEEE Std 829-1998 (IEEE Standard for Software Test Documentation)

---

**Project / Product Name:** ProfessorOS — Higher Education Learning & Assessment Platform (FYP-I)  
**Test Plan Identifier:** `TP-PROFESSOROS-FYP1-30PCT-01`  
**Course:** Test Automation — Department of Software Engineering  
**Institution:** Shifa Tameer-e-Millat University (STMU), Islamabad  
**Version:** 1.0 (FYP-I 30% Implementation Baseline)  
**Date:** 26 July 2026  

**Prepared By:** Muhammad Yasin Asif (Student / Test Automation Engineer)  
**Reviewed By:** FYP Advisor & Course Instructor  
**Approved By:** Head of Department, Software Engineering  

---

## Document Control

**Purpose:** Track every revision of this Test Plan so reviewers and approvers always know which version they are reading.

| Version | Date | Author | Description of Change |
| :--- | :--- | :--- | :--- |
| **1.0** | 26 July 2026 | Muhammad Yasin Asif | FYP-I Baseline Test Plan corresponding to the 30% implementation milestone (Core Auth, Admin Roster, and Course Foundation). |

---

## Table of Contents

1. [Test Plan Identifier](#1-test-plan-identifier)
2. [Introduction](#2-introduction)
3. [Test Items](#3-test-items)
4. [Features to Be Tested](#4-features-to-be-tested)
5. [Features Not to Be Tested](#5-features-not-to-be-tested)
6. [Approach](#6-approach)
   - 6.1 [Test Levels & Types](#61-test-levels--types)
   - 6.2 [Tools & Frameworks](#62-tools--frameworks)
   - 6.3 [Constraints](#63-constraints)
7. [Item Pass/Fail Criteria](#7-item-passfail-criteria)
8. [Suspension Criteria and Resumption Requirements](#8-suspension-criteria-and-resumption-requirements)
9. [Test Deliverables](#9-test-deliverables)
10. [Testing Tasks](#10-testing-tasks)
11. [Environmental Needs](#11-environmental-needs)
    - 11.1 [Hardware](#111-hardware)
    - 11.2 [Software](#112-software)
    - 11.3 [Tools & Security](#113-tools--security)
12. [Responsibilities](#12-responsibilities)
13. [Staffing and Training Needs](#13-staffing-and-training-needs)
14. [Schedule](#14-schedule)
15. [Risks and Contingencies](#15-risks-and-contingencies)
16. [Approvals](#16-approvals)

---

## 1. Test Plan Identifier

* **Document Identifier:** `TP-PROFESSOROS-FYP1-30PCT-01`
* **Version:** `1.0 (FYP-I 30% Milestone)`
* **Parent Project:** ProfessorOS Final Year Project Phase I (FYP-I) Master Test Plan
* **Configuration Management Location:** `https://github.com/YasinAsif/professor-os/blob/main/testing_assignment/software_test_plan_ieee829.md`

---

## 2. Introduction

**System Under Test (SUT) Overview:**  
ProfessorOS is an enterprise-grade Higher Education Learning and Assessment OS tailored for Pakistani universities and compliant with Higher Education Commission (HEC) policies. Built with a Flutter Web (CanvasKit) frontend and a Python FastAPI asynchronous backend, ProfessorOS delivers role-based management for Admins, Professors, TAs, and Students.

**FYP-I Implementation Context (30% Progress Stage):**  
At this stage of **FYP-I**, the project has completed **approximately 30% of its planned implementation**. The completed modules focus on the core foundational architecture, including:
1. **JWT-based Role Authentication** (Login, Email Verification, Session Management).
2. **Admin User Management** (Single User Creation, Role Editing, Status Toggles, Roster Listing, CSV Roster Import/Export).
3. **Basic Academic Course & Semester Structure** (Semester creation with date ranges, Course Join Codes).

This test plan defines the comprehensive testing strategy for these 30% implemented core modules, while clearly demarcating un-implemented features reserved for FYP-II.

**Business / Academic Context:**  
This test plan establishes an automated regression strategy using Selenium WebDriver, pytest, and the Page Object Model (POM) to ensure that the initial 30% baseline is rock-solid before expanding into FYP-II features.

**Reference Documents:**
1. *ProfessorOS System Requirements Specification (SRS v1.0 — FYP-I)*
2. *ProfessorOS System Architecture & Design Document (SADD v1.0)*
3. *IEEE Std 829-1998: IEEE Standard for Software Test Documentation*
4. *HEC Higher Education Policy Guidelines on Assessment & Grading (2023)*

---

## 3. Test Items

The following software components represent the **30% completed implementation baseline** under test:

| Item / Module Name | FYP-I Status | Version / Build | Reference Documentation | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Authentication Module** | **Completed (10%)** | `v1.0.0` | SRS §3.1, Design Doc §2.1 | Handles Login, Registration, Password Reset, JWT verification, and Role-Based Access Control (RBAC). |
| **Admin User Management** | **Completed (12%)** | `v1.1.0` | SRS §3.2, Design Doc §2.2 | Roster listing, manual single user creation, role editing, CSV import/export, and status toggles. |
| **Academic Course & Semester**| **Completed (8%)** | `v1.0.0` | SRS §3.3, Design Doc §2.3 | Semester lifecycle management, start/end dates, and 6-character course join codes. |
| **FastAPI Backend Engine** | **Completed Core** | `v1.1.0` | SRS §4.1, Design Doc §3.1 | Asynchronous RESTful API backend deployed live on Railway (`/api/v1`). |

---

## 4. Features to Be Tested

The following functional features (representing the 30% FYP-I progress) are the primary objects of this test plan:

1. **Authentication & Role Access Control (Module Auth)**
   - Valid user login (`admin@professoros.edu.pk` / `admin123`).
   - Negative login validation (Invalid email format, incorrect password).
   - Boundary checks (Empty form submission, password length boundary at 8 characters).
   - Unregistered student signup error handling.
2. **Admin User & Roster Management (Module Admin)**
   - Manual creation of new user accounts (Professor, Student, TA, Admin).
   - Role modification (e.g. promoting Student to TA/Professor).
   - Admin-initiated password reset.
   - Bulk CSV Roster import and CSV export capabilities.
   - User account activation/deactivation and permanent deletion.
3. **Course & Semester Administration (Module Academic)**
   - Creation of academic semesters with valid date ranges.
   - Boundary checks on semester start/end dates (Same day dates, far-future year 2035).
   - Joining courses via 6-character join codes.

---

## 5. Features Not to Be Tested

The following features represent the **remaining 70% implementation scope** reserved for FYP-II or third-party components, and are NOT tested in this FYP-I test cycle:

| Excluded Feature / Component | Scope Phase | Reason for Exclusion | Compensating Control |
| :--- | :--- | :--- | :--- |
| **Advanced OBE / CLO Analytics Engine** | FYP-II Scope | Scheduled for implementation in FYP-II phase. | Mock analytics endpoints in backend. |
| **Automated AI Essay & Code Plagiarism Checker** | FYP-II Scope | Out of scope for 30% FYP-I milestone. | Deferred to FYP-II execution phase. |
| **Interactive Canvas SpeedGrader** | FYP-II Scope | UI prototype phase; dynamic grading engine in development. | Manual UI verification during FYP-II. |
| **Third-Party Payment / Fee Gateways** | Out of Scope | Not required for university academic deployment. | Mocked in architecture. |
| **Flutter CanvasKit C++ Render Engine** | Third-Party | Internal framework code owned by Google/Flutter. | Selenium ActionChains focus testing. |

---

## 6. Approach

### 6.1 Test Levels & Types
1. **Unit Testing:** Executed via `pytest` on backend services (`user_service.py`, `course_service.py`).
2. **Integration Testing:** API endpoint verification using FastAPI `TestClient` and Dio client handlers.
3. **System & End-to-End (E2E) Testing:** Automated functional testing executed against live Railway production builds using Selenium WebDriver in Python.
4. **Acceptance Testing:** Initial FYP-I milestone verification with academic supervisor.

### 6.2 Tools & Frameworks
* **Automation Framework:** Selenium WebDriver (Python 3.14) with `ActionChains` for Flutter Web CanvasKit navigation.
* **Test Runner:** `pytest` (v9.1+) with `pytest-html` and `allure-pytest` plugins.
* **Design Pattern:** Page Object Model (POM) separating page element interactions (`pages/`) from test logic (`tests/`).
* **CI/CD Integration:** GitHub Actions triggering automated build analysis (`flutter analyze`) and Pytest suites on push to `main`.
* **Deployment Target:** Railway Cloud Platform (`https://professor-os-production.up.railway.app`).

### 6.3 Constraints
* **FYP-I 30% Scope Boundary:** Testing is strictly restricted to the 30% completed codebase. Unimplemented FYP-II routes must fail gracefully without crashing the core auth/admin engine.
* **Flutter CanvasKit DOM Limitations:** Automation must rely on `ActionChains` keyboard navigation (`Keys.TAB`, `Keys.ENTER`) and explicit delays due to lack of traditional DOM element IDs.

---

## 7. Item Pass/Fail Criteria

### Individual Test Case Pass Criteria
A test case is marked **PASS** if and only if:
1. All ActionChains sequences complete without raising unhandled driver exceptions (`NoSuchElementException`, `TimeoutException`).
2. Expected URL routes (e.g. hash routing `/admin`) or visual states match expected post-conditions.
3. Relevant evidence screenshots (`.png`) are successfully captured and non-blank.

### Feature & Module Pass Criteria
A 30% FYP-I feature is marked **PASS** if:
1. 100% of Priority-1 (Critical) test cases associated with the feature pass cleanly.
2. Zero Critical or High severity defects remain open against the 30% baseline modules.

### Overall FYP-I Test Milestone Exit Criteria
The FYP-I 30% test phase is declared **SUCCESSFUL** if:
1. At least **95%** of all planned automated test cases (minimum 10 test cases) execute and pass.
2. All positive, negative, and boundary test cases pass as designed.
3. Complete IEEE 829 test documentation is submitted.

---

## 8. Suspension Criteria and Resumption Requirements

### Suspension Criteria
Testing activities shall be immediately suspended if:
1. **Deployment Unavailability:** The live Railway server is unreachable (HTTP 502/503/504) or database connection fails.
2. **Blocking Auth Defect:** A blocking failure in the Authentication module prevents logging in or accessing the Admin dashboard.
3. **Environment Instability:** Test execution failure rate exceeds 30% due to environment latency or network timeouts.

### Resumption Requirements
Testing shall resume when:
1. A stable build is re-deployed to Railway and verified via a manual sanity check.
2. The blocking defect is resolved and committed to `main`.
3. **Resumption Scope:** Execution of the Smoke Test Suite (TC-01 and TC-07) before resuming full test suite execution.

---

## 9. Test Deliverables

The following test documentation and artifacts will be delivered for the FYP-I milestone:

| Deliverable | Format / Path | Owner | Description |
| :--- | :--- | :--- | :--- |
| **FYP-I Software Test Plan** | `testing_assignment/software_test_plan_ieee829.md` | Test Lead | IEEE Std 829-1998 compliant test plan (this document). |
| **Page Object Model Suite** | `testing_assignment/pages/` & `tests/` | Automation Engineer | Modular Python Selenium POM codebase (`login_page.py`, `dashboard_page.py`). |
| **Pytest Execution Suite** | `testing_assignment/tests/test_auth.py`, `test_admin.py` | Automation Engineer | Automated test cases covering positive, negative, and boundary scenarios. |
| **Selenium Test Report** | `testing_assignment/selenium_test_report.md` | Test Lead | Markdown reflection report with pass/fail metrics and answers. |
| **Visual Screenshots** | `testing_assignment/*.png` | Automation Engineer | Evidence images (`success_login.png`, `success_add_semester.png`, `failed_login.png`). |
| **HTML Test Report** | `testing_assignment/report.html` | Automation Engineer | Interactive HTML report generated by `pytest-html`. |

---

## 10. Testing Tasks

The testing workflow for the FYP-I 30% milestone follows this sequence:

```
[ Task 1: Environment Setup ]
              │
              ▼
[ Task 2: Test Data Preparation ]
              │
              ▼
[ Task 3: POM & Script Development ]
              │
              ▼
[ Task 4: Automated Test Execution ]
              │
              ▼
[ Task 5: Evidence & Screenshot Capture ]
              │
              ▼
[ Task 6: Documentation & Final Reporting ]
```

1. **Environment Setup:** Configure Python 3.14, Selenium, Pytest, ChromeDriver (`--window-size=1920,1080`).
2. **Test Data Preparation:** Setup valid admin credentials (`admin@professoros.edu.pk` / `admin123`), invalid pairs, and boundary dates.
3. **POM Scripting:** Develop `LoginPage` and `DashboardPage` encapsulating ActionChains navigation logic.
4. **Automated Execution:** Execute `pytest tests/ -v` sequentially with browser instance isolation per test.
5. **Screenshot & Evidence Verification:** Verify non-blank visual captures for `success_login.png`, `success_add_semester.png`, and `failed_login.png`.
6. **IEEE 829 Sign-Off:** Finalize report and submit to FYP supervisor.

---

## 11. Environmental Needs

### 11.1 Hardware
* **Test Workstation:** Intel/AMD x64 Processor (Quad-Core 2.5 GHz+), 16 GB RAM.
* **Display Resolution:** 1920 x 1080 Full HD (Required for accurate CanvasKit viewport rendering).
* **Network:** Minimum 10 Mbps stable internet connection for live Railway cloud backend interaction.

### 11.2 Software
* **Operating System:** Windows 10/11 (x64).
* **Browsers:** Google Chrome (v126.0+), Headless Chrome & Visible Chrome options.
* **Runtime / Frameworks:** Python 3.14.3, Pytest 9.1.1, Selenium WebDriver 4.28.0.
* **SUT Stack (30% Baseline):** Flutter Web 3.x (CanvasKit engine), Python FastAPI 0.110+, PostgreSQL 16 (Railway Cloud).

### 11.3 Tools & Security
* **Version Control:** Git & GitHub repository (`YasinAsif/professor-os`).
* **Security & Privacy:** Test accounts use synthetic mock data. JWT access tokens stored in session storage. HTTPS encryption enabled for all Railway endpoints.

---

## 12. Responsibilities

| Role | Name / Title | Primary Responsibilities |
| :--- | :--- | :--- |
| **Test Lead** | Muhammad Yasin Asif | Author Test Plan, coordinate execution, publish IEEE 829 summary reports. |
| **Test / Automation Engineer**| Muhammad Yasin Asif | Implement POM pages, write Pytest scripts, execute E2E Selenium tests, capture visual evidence. |
| **Backend / Frontend Developer**| Muhammad Yasin Asif | Maintain Railway API deployment, fix identified defects, ensure SUT testability. |
| **Course Instructor / Supervisor**| Department Faculty (STMU) | Review FYP-I 30% test plan, evaluate test coverage, approve final assignment deliverables. |

---

## 13. Staffing and Training Needs

### Staffing Requirements
* **Test Automation Engineer:** 1 Person (Muhammad Yasin Asif).

### Required Skill Sets
* Proficient in Python software development and `pytest` test runners.
* Expertise in Selenium WebDriver API, `ActionChains`, and keyboard navigation strategies.
* Solid understanding of Page Object Model (POM) design patterns and asynchronous web architecture.

---

## 14. Schedule

The FYP-I testing schedule and key milestones are detailed below:

| Milestone / Task | Start Date | End Date | Deliverable / Output |
| :--- | :--- | :--- | :--- |
| **FYP-I 30% Scope Definition & Analysis** | 20 July 2026 | 21 July 2026 | Test Plan Scope Document |
| **Environment Setup & Tooling Configuration** | 22 July 2026 | 22 July 2026 | Pytest + Selenium Environment Ready |
| **Page Object Model (POM) Scripting** | 23 July 2026 | 23 July 2026 | `login_page.py`, `dashboard_page.py` |
| **Automated Test Suite Execution** | 24 July 2026 | 24 July 2026 | 10 Passed Test Cases, 3 Evidence PNGs |
| **IEEE 829 Test Plan & Final Documentation** | 26 July 2026 | 26 July 2026 | `software_test_plan_ieee829.md` |

---

## 15. Risks and Contingencies

| Risk Description | Likelihood / Impact | Contingency / Mitigation Plan |
| :--- | :--- | :--- |
| **Flutter CanvasKit Element Unlocatability** | **High / High** | Bypass traditional `By.ID` locators entirely; utilize `ActionChains` keyboard navigation (`TAB`, `ENTER`) and semantic text sweeps. |
| **Railway Cloud Network Latency / Delay** | **Medium / High** | Implement robust explicit wait buffers (20-25 seconds) before DOM assertion and screenshot capture. |
| **Headless Browser Visual Render Truncation** | **Medium / Medium** | Fall back to non-headless visible Chrome browser execution (`take_perfect_screenshots.py`) for visual evidence capture. |
| **Scope Creep Beyond 30% Baseline** | **Low / Medium** | Strictly restrict FYP-I test suite to completed 30% baseline (Auth, Admin User Management, Basic Academic Structure). |

---

## 16. Approvals

The undersignees hereby approve this Software Test Plan as meeting the requirements of IEEE Std 829-1998 for the FYP-I (30% Implementation Stage) milestone of ProfessorOS:

```
_______________________________________             Date: 26 July 2026
Muhammad Yasin Asif
Test Lead / Student Engineer
Department of Software Engineering, STMU


_______________________________________             Date: ______________
Course Instructor / FYP Supervisor
Department of Software Engineering, STMU


_______________________________________             Date: ______________
Head of Department
Department of Software Engineering, STMU
```

---
*Reference: IEEE Std 829-1998, IEEE Standard for Software Test Documentation, Institute of Electrical and Electronics Engineers, Inc.*
