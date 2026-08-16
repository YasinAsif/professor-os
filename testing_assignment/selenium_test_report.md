# Final Year Project: Automated Software Testing Report (CO-5)

## Part A – Test Planning

**Application Selected:** ProfessorOS (Final Year Project)  
**Modules Selected:**  
1. Authentication & Role Security (Login/Signup/RBAC)  
2. Course Management & Onboarding (Creation, HEC Weights, Join Codes, TA Delegation)  
3. Admin Panel (Semesters & System Date Boundaries)  

### Test Matrix (15 Automated Test Scenarios)

| Test Case ID | Module | Test Scenario Description | Type | Expected Result | Result | Evidence Artifact |
| :---: | :--- | :--- | :---: | :--- | :---: | :--- |
| **TC-01** | Auth | Verify successful admin login with valid credentials | Positive | User redirected to Admin Dashboard | **PASS** | `screenshots/success_login.png` |
| **TC-02** | Auth | Verify login fails with invalid email format | Negative | Rejected by input validation | **PASS** | `report.html` |
| **TC-03** | Auth | Verify login fails with incorrect password | Negative | Authentication error (401) | **PASS** | `report.html` |
| **TC-04** | Auth | Verify login fails when fields are left empty | Boundary | Validation prevents submission | **PASS** | `report.html` |
| **TC-05** | Auth | Verify password at minimum length boundary (8 chars) | Boundary | Accepts valid length submission | **PASS** | `report.html` |
| **TC-06** | Auth | Verify unregistered student signup forces error | Negative | System rejects and stays on login | **PASS** | `screenshots/failed_login.png` |
| **TC-07** | Admin | Verify Admin can add a new semester successfully | Positive | Semester added to DB list | **PASS** | `screenshots/success_add_semester.png` |
| **TC-08** | Admin | Verify adding semester fails if dates are missing | Negative | Validation error prevents creation | **PASS** | `report.html` |
| **TC-09** | Admin | Verify boundary where start and end date are same | Boundary | Evaluates system date rules | **PASS** | `report.html` |
| **TC-10** | Admin | Verify semester boundary with max year (2035) | Boundary | System accepts far-future year | **PASS** | `report.html` |
| **TC-11** | Course | Verify Professor can create course with 100% HEC weights | Positive | Course created & `join_code` generated | **PASS** | `screenshots/success_course_management.png` |

| **TC-12** | Course | Verify system rejects course if HEC weights != 100% | Negative | Validation error forces HEC 100% rule | **PASS** | `report.html` |
| **TC-13** | Course | Verify Professor can map HEC CLOs to a course | Positive | CLO created and linked to course | **PASS** | `report.html` |
| **TC-14** | Course | Verify Student joining with invalid join code fails | Negative | Clean error message shown | **PASS** | `report.html` |
| **TC-15** | Course | Verify Professor can delegate TA role for a course | Positive | TA assigned and granted permissions | **PASS** | `report.html` |

---

## Part B & C – Test Execution Summary

**Execution Date:** July 24, 2026 / Updated August 16, 2026  
**Framework:** Python (`pytest`, `selenium`, `ActionChains`, `httpx`)  
**Design Pattern:** Page Object Model (POM) & Asynchronous API Fixtures  

### Pass/Fail Summary
| Total Tests | Passed | Failed | Pass Rate |
| :---: | :---: | :---: | :---: |
| 15 | 15 | 0 | **100%** |

All 15 tests passed successfully. Tests were executed against the live Railway production deployment (`https://professor-os-production.up.railway.app`), verifying both browser visual interactions and API endpoint boundaries.

### Execution Evidence & Screenshots

#### 1. Successful Admin Authentication (TC-01)
Captured on live deployment. WebDriver navigated the UI using semantic keyboard tabbing (`Keys.TAB`), submitted valid credentials, and verified transition to the Dashboard.

![TC-01 Success](screenshots/success_login.png)

#### 2. Successful Admin Semester Creation (TC-07)
Captures the Admin Dashboard rendering after navigating date configuration forms.

![TC-07 Success](screenshots/success_add_semester.png)

#### 3. Negative Login Rejection (TC-06)
Captures rejection when attempting login with unregistered student credentials.

![TC-06 Failure](screenshots/failed_login.png)

#### 4. Course Management Dashboard & Roster View (TC-11)
Captures the Course Management module dashboard loaded on the live deployment.

![TC-11 Course Management](screenshots/success_course_management.png)


---

## Part D – Reflection & Evaluation Defense

**1. Which test case was most difficult to automate and why?**
Automating the **Course Creation & HEC Weightage Validation (TC-11 & TC-12)** and **Date Pickers (TC-07 to TC-10)** was the most difficult. Because ProfessorOS is built using Flutter Web, it draws form controls and date pickers directly on an HTML5 `<canvas>`. Standard DOM element IDs do not exist. To automate this, we utilized Selenium `ActionChains` keyboard focus tabbing (`Keys.TAB`) and asynchronous HTTP boundary testing.

**2. What challenge did you face while locating elements or handling synchronization?**
The primary challenge was that CanvasKit shadow DOM components do not support standard `By.ID` or `By.CLASS_NAME` locators. We solved this by using `ActionChains` for keyboard accessibility navigation and utilizing FastAPI backend API integration tests for precise endpoint validation.

**3. Which feature would you avoid automating via UI? Justify your answer.**
We avoid automating the pixel-perfect rendering of interactive analytics graphs via UI Selenium. Because charts are rendered on CanvasKit, Selenium cannot read tooltip text without OpenCV image recognition. Validating analytics via backend API endpoints (`GET /courses/{id}/analytics`) is significantly faster, more reliable, and less brittle.

