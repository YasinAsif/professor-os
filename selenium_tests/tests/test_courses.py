import pytest

from selenium_tests.pages.authenticated_page import AuthenticatedPage
from selenium_tests.pages.login_page import LoginPage


def test_course_management_area_is_accessible(driver, app_url, admin_credentials):
    if admin_credentials is None:
        pytest.skip("Set ADMIN_EMAIL and ADMIN_PASSWORD to run authenticated tests")
    LoginPage(driver, app_url).login_with_credentials(*admin_credentials)
    page = AuthenticatedPage(driver, app_url)
    page.open_courses()
    assert page.contains_any_text("course", "courses", "roster", "assignment", "join")


def test_course_management_exposes_core_control(driver, app_url, admin_credentials):
    if admin_credentials is None:
        pytest.skip("Set ADMIN_EMAIL and ADMIN_PASSWORD to run authenticated tests")
    LoginPage(driver, app_url).login_with_credentials(*admin_credentials)
    page = AuthenticatedPage(driver, app_url)
    page.open_courses()
    assert page.contains_any_text("create", "add", "join", "course", "assignment")
