import pytest

from selenium_tests.pages.login_page import LoginPage


def test_empty_credentials_are_rejected(driver, app_url):
    page = LoginPage(driver, app_url)
    page.load()
    page.submit_login("", "")
    assert page.stays_on_login_or_shows_error()


def test_invalid_password_is_rejected(driver, app_url):
    page = LoginPage(driver, app_url)
    page.load()
    page.submit_login("invalid-user@example.com", "definitely-wrong-password")
    assert page.stays_on_login_or_shows_error()


def test_admin_can_sign_in(driver, app_url, admin_credentials):
    if admin_credentials is None:
        pytest.skip("Set ADMIN_EMAIL and ADMIN_PASSWORD to run authenticated tests")
    page = LoginPage(driver, app_url)
    page.load()
    page.submit_login(*admin_credentials)
    assert page.wait_until_authenticated()
    assert "/admin" in driver.current_url.lower()
