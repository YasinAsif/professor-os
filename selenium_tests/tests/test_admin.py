import pytest

from selenium_tests.pages.authenticated_page import AuthenticatedPage
from selenium_tests.pages.login_page import LoginPage


def test_admin_area_is_accessible_after_login(driver, app_url, admin_credentials):
    if admin_credentials is None:
        pytest.skip("Set ADMIN_EMAIL and ADMIN_PASSWORD to run authenticated tests")
    LoginPage(driver, app_url).login_with_credentials(*admin_credentials)
    page = AuthenticatedPage(driver, app_url)
    page.open_admin()
    assert page.contains_any_text("admin", "semester", "users", "approval", "dashboard")


def test_admin_area_exposes_management_control(driver, app_url, admin_credentials):
    if admin_credentials is None:
        pytest.skip("Set ADMIN_EMAIL and ADMIN_PASSWORD to run authenticated tests")
    LoginPage(driver, app_url).login_with_credentials(*admin_credentials)
    page = AuthenticatedPage(driver, app_url)
    page.open_admin()
    assert page.contains_any_text("add", "manage", "semester", "user", "approval")
