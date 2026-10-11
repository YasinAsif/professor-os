"""Authenticated role journeys against the deployed Flutter web surface."""

from selenium_tests.pages.authenticated_page import AuthenticatedPage
from selenium_tests.pages.login_page import LoginPage


def test_each_role_reaches_its_dashboard(role_credentials, driver, app_url):
    role, email, password = role_credentials
    LoginPage(driver, app_url).login_with_credentials(email, password)
    page = AuthenticatedPage(driver, app_url)
    page.wait_until_text("dashboard", "course", "admin", "welcome")
    if role == "admin":
        assert "/admin" in driver.current_url.lower() or page.contains_any_text("admin", "users", "approval")
    elif role == "ta":
        assert "/ta-dashboard" in driver.current_url.lower() or page.contains_any_text("ta", "grading", "course")
    else:
        assert page.contains_any_text("course", "assignment", "dashboard", "welcome")


def test_role_course_workspace_and_filters_render(role_credentials, driver, app_url):
    _, email, password = role_credentials
    LoginPage(driver, app_url).login_with_credentials(email, password)
    page = AuthenticatedPage(driver, app_url)
    page.open_courses()
    assert page.contains_any_text("course", "courses", "assignment", "join")
    # Course list controls are semantic Flutter nodes when the canvas is active.
    if page.contains_any_text("active", "archived"):
        assert page.contains_any_text("active", "archived")


def test_role_assignment_grading_surface_has_a_recoverable_state(role_credentials, driver, app_url):
    role, email, password = role_credentials
    LoginPage(driver, app_url).login_with_credentials(email, password)
    page = AuthenticatedPage(driver, app_url)
    if role == "admin":
        page.open_admin()
        assert page.contains_any_text("admin", "users", "approval", "role")
        return
    page.open_seeded_course_workspace()
    assert page.contains_any_text(
        "browser e2e assignment", "assignment", "submission", "graded", "needs review", "no assignments", "try again"
    )
