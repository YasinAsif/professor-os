# Selenium Deployment Testing Design

## Goal

Replace the mixed `testing_assignment` folder with a focused Selenium/pytest suite that validates the deployed Flutter Web application, including authentication, admin navigation, and course-management access.

## Scope

- Run against `APP_URL`, defaulting to the current Railway deployment.
- Use Selenium Chrome with headless mode enabled by default.
- Use explicit waits rather than fixed sleeps; the default timeout is configurable because the deployed app can take time to render.
- Exercise safe, read-only checks by default: app load, authentication outcomes, admin-page access, admin controls, course-management controls, and navigation.
- Use environment variables for credentials. The valid-login and authenticated-area tests skip when credentials are absent.
- Capture screenshots only on failures, plus optional screenshots when `SCREENSHOTS=1`.

## Replacement and cleanup

Delete the obsolete `testing_assignment` folder, including its mock server generator, generated HTML pages, placeholder page objects, duplicated API/Selenium tests, stale reports, and fixed-delay runner. Create a new `selenium_tests` folder with a self-contained README and requirements file.

## Structure

```text
selenium_tests/
├── conftest.py
├── pages/
│   ├── base_page.py
│   ├── login_page.py
│   └── authenticated_page.py
├── tests/
│   ├── test_smoke.py
│   ├── test_authentication.py
│   ├── test_admin.py
│   └── test_courses.py
├── requirements.txt
└── README.md
```

The page objects centralize Flutter Web-friendly keyboard navigation and text-based assertions. Tests should not depend on brittle generated DOM IDs or pretend to create records.

## Success criteria

The old folder is gone; the new suite is importable; tests use explicit waits; missing credentials cause authenticated tests to skip rather than fail; and the suite can be run with `pytest -v selenium_tests/tests` against the deployment.
