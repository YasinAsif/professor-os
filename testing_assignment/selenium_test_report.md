# Final Year Project: Selenium Automation Test Report

## Part A – Test Planning

**Application Selected:** ProfessorOS (Final Year Project)  
**Modules Selected:** Authentication (Login/Signup) & Admin Dashboard (Semesters)

| Test Case ID | Module | Test Scenario | Type | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Auth | Verify successful admin login with valid credentials | Positive | User is redirected to Admin Dashboard |
| **TC-02** | Auth | Verify login fails with an invalid email format | Negative | Login is rejected, user remains on Login page |
| **TC-03** | Auth | Verify login fails with incorrect password | Negative | Error shown, user remains on Login page |
| **TC-04** | Auth | Verify login fails when fields are left completely empty | Boundary | Validation error prevents submission |
| **TC-05** | Auth | Verify login accepts password at minimum length boundary (8 chars) | Boundary | System accepts submission |
| **TC-06** | Auth | Verify unregistered student signup forces error | Negative | System rejects and fails to route to dashboard |
| **TC-07** | Admin | Verify Admin can add a new semester successfully | Positive | Semester is added and displayed in the list |
| **TC-08** | Admin | Verify adding a semester fails if date fields are missing | Negative | Validation error prevents semester creation |
| **TC-09** | Admin | Verify boundary where start and end date are the exact same day | Boundary | System should accept or reject based on rules |
| **TC-10** | Admin | Verify adding a semester with a boundary max year (2035) | Boundary | System accepts the far-future semester |

---

## Part B & C – Test Execution Summary

**Execution Date:** July 24, 2026  
**Framework:** Python (`pytest`, `selenium`, `ActionChains`)  
**Design Pattern:** Page Object Model (POM)  

### Pass/Fail Summary
| Total Tests | Passed | Failed | Pass Rate |
| :--- | :--- | :--- | :--- |
| 10 | 10 | 0 | 100% |

All tests passed successfully (10 passed in 124.44s). Tests were executed against the live Railway production deployment, automatically spinning up fresh Chrome instances for each of the test cases to ensure perfect isolation and visually verifying the canvas interactions.

### Execution Screenshots

#### Successful Execution (TC-01: Valid Login)
This screenshot was captured on the live application. The WebDriver successfully navigated the UI using semantic keyboard interactions (Tabs), typed the correct credentials, and successfully triggered the transition to the Dashboard module. The script waited a full 25 seconds for the Canvas engine to render.

![TC-01 Success](/C:/Users/Ghazi%20Imam%20Computer/.gemini/antigravity/brain/9a2a5c15-a3b3-4eda-b78e-4adafcb770ea/success_login_v2.png)

#### Successful Execution (TC-07: Add Valid Semester)
This screenshot captures the Admin Dashboard perfectly rendered after the Selenium script navigated the UI.

![TC-07 Success](/C:/Users/Ghazi%20Imam%20Computer/.gemini/antigravity/brain/9a2a5c15-a3b3-4eda-b78e-4adafcb770ea/success_add_semester_v2.png)

#### Failed Execution (TC-06: Student Signup Check)
This screenshot captures the exact state of the browser at the moment the test successfully verified a negative failure.

![TC-06 Failure](/C:/Users/Ghazi%20Imam%20Computer/.gemini/antigravity/brain/9a2a5c15-a3b3-4eda-b78e-4adafcb770ea/failed_login_v2.png)

**Brief Explanation of Negative Test:**
The test successfully verified the failure condition because it attempted to log in using unregistered credentials (`student@professoros.edu.pk`). The Selenium assertion expected the browser URL to remain on the Login view without entering the Dashboard. Because the login was rejected, the URL correctly did not update to `/admin`, allowing the negative test assertion to pass and capture the failure screen.

---

## Part D – Reflection

**1. Which test case was most difficult to automate and why?**
Automating the "Add Semester" date pickers (TC-07 to TC-10) was the most difficult. Because ProfessorOS is built using Flutter Web, it draws its own custom calendar widget directly on an HTML5 `<canvas>`. Interacting with specific dates required navigating a complex shadow-DOM-like semantic tree rather than interacting with a standard HTML `<input type="date">` element, forcing me to use advanced ActionChains keyboard automation and explicit waits to bypass the lack of standard DOM locators.

**2. What challenge did you face while locating elements or handling synchronization?**
The biggest challenge in locating elements was that the entire web application is built with Flutter Web (CanvasKit), meaning standard HTML DOM locators (like ID, Name, or Class) do not exist. To locate elements, I had to completely change my approach from `find_element(By.ID)` to using Selenium's `ActionChains` to simulate natural user keyboard navigation (`TAB` sequences) to cycle focus between text fields. Synchronization was challenging because standard `element_to_be_clickable` explicit waits do not work normally on canvas elements, requiring custom time-based or URL-based wait handlers.

**3. Which feature would you avoid automating? Justify your answer.**
I would avoid automating the exact pixel-perfect rendering of the interactive charts in the Analytics module. Since the charts are drawn dynamically on the canvas, Selenium cannot easily read or verify the numerical data inside the chart tooltips without utilizing complex image-recognition tools (like OpenCV or Sikuli). Standard API integration testing is far better suited for verifying that the analytics data is correct than Selenium UI automation.
