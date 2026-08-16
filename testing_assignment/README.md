# ProfessorOS Automated Software Testing Suite (CO-5)

> **IEEE-829 Compliant Automated & Manual Software Testing Package**  
> *Verifies authentication, data validation, boundary limits, and admin workflows across API and Browser UI layers.*

---

## 📌 Testing Overview

This testing package fulfills the **CO-5 Software Testing & Validation** criteria for **ProfessorOS**. It incorporates automated API testing via `pytest`, end-to-end browser UI automation via `selenium` WebDriver, and complete IEEE-829 software test plan documentation.

### Test Coverage Summary
- **Total Test Cases Executed:** 10 Structured Scenarios (`TC-01` to `TC-10`)
- **Pass Rate:** 100% (10 Passed / 0 Failed)
- **Target Deployment:** Live Railway Cloud (`https://professor-os-production.up.railway.app`)

---

## 📁 Testing Folder Structure

```
testing_assignment/
├── tests/                           # Pytest Automated Test Case Scripts
│   ├── test_auth.py                 # Authentication, JWT, and boundary tests (TC-01 to TC-06)
│   └── test_admin.py                # Admin semester & date validation tests (TC-07 to TC-10)
│
├── pages/                           # Selenium Page Object Model (POM) Page Abstractions
│   ├── login_page.py                # Login page interaction methods
│   └── admin_page.py                # Admin dashboard & semester management methods
│
├── screenshots/                     # Visual Evidence Captured During Automated Execution
│   ├── success_login.png            # TC-01 Valid Login execution screenshot
│   ├── success_add_semester.png     # TC-07 Admin semester creation screenshot
│   └── failed_login.png             # TC-06 Negative login rejection screenshot
│
├── run_real_tests.py                # Selenium Headless Browser Automation Runner
├── setup.py                         # Pytest test suite configuration & fixtures
├── report.html                      # Pytest HTML Test Execution Report (100% Pass)
├── software_test_plan_ieee829.md    # IEEE-829 Standard Software Test Plan Document
├── selenium_test_report.md          # Full Evaluation Test Report & Reflection Document
└── README.md                        # Testing Suite User & Execution Guide
```

---

## 📋 Test Matrix & Execution Status

| Test ID | Module | Scenario Description | Test Type | Expected Result | Result | Evidence Screenshot |
| :---: | :--- | :--- | :---: | :--- | :---: | :--- |
| **TC-01** | Auth | Admin Login with valid credentials | Positive | Navigates to Admin Dashboard | **PASS** | `screenshots/success_login.png` |
| **TC-02** | Auth | Login with invalid email format | Negative | Rejected by input validation | **PASS** | `report.html` |
| **TC-03** | Auth | Login with incorrect password | Negative | Authentication error (401) | **PASS** | `report.html` |
| **TC-04** | Auth | Login with empty fields | Boundary | Prevented by client validation | **PASS** | `report.html` |
| **TC-05** | Auth | Password at minimum boundary (8 chars) | Boundary | Accepts valid length submission | **PASS** | `report.html` |
| **TC-06** | Auth | Unregistered student login rejection | Negative | Blocked from dashboard | **PASS** | `screenshots/failed_login.png` |
| **TC-07** | Admin | Create valid new semester | Positive | Semester added to database | **PASS** | `screenshots/success_add_semester.png` |
| **TC-08** | Admin | Create semester with missing dates | Negative | Validation error prevents submit | **PASS** | `report.html` |
| **TC-09** | Admin | Same start and end date boundary | Boundary | Evaluates system date rules | **PASS** | `report.html` |
| **TC-10** | Admin | Semester boundary max year (2035) | Boundary | Accepts far-future semester | **PASS** | `report.html` |

---

## ⚡ How to Run Tests Locally

### 1. Run Automated Pytest API Suite

```bash
# Navigate to testing directory
cd testing_assignment

# Execute pytest with verbose output
pytest -v

# Generate HTML test report
pytest --html=report.html --self-contained-html
```

### 2. Run Selenium UI Browser Automation

```bash
# Ensure Chrome browser and ChromeDriver are installed
python run_real_tests.py
```

*Screenshots will automatically be generated and saved inside `screenshots/` upon completion.*

---

## 📄 Reference Documents

- 📄 **IEEE-829 Test Plan:** [`software_test_plan_ieee829.md`](file:///e:/FYP_YASIN/testing_assignment/software_test_plan_ieee829.md)
- 📄 **Selenium Defense Report:** [`selenium_test_report.md`](file:///e:/FYP_YASIN/testing_assignment/selenium_test_report.md)
- 📊 **HTML Execution Report:** [`report.html`](file:///e:/FYP_YASIN/testing_assignment/report.html)
