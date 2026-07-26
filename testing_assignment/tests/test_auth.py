import pytest
from pages.login_page import LoginPage
import time

def test_tc01_valid_login(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "admin123")
    assert "/admin" in driver.current_url or "/dashboard" in driver.current_url or driver.current_url != page.url
    driver.save_screenshot("success_login.png")

def test_tc02_invalid_email(driver):
    page = LoginPage(driver)
    page.load()
    page.login("invalidemail", "admin123")
    assert "/admin" not in driver.current_url and "/dashboard" not in driver.current_url
    
def test_tc03_invalid_password(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "wrongpass")
    assert "/admin" not in driver.current_url and "/dashboard" not in driver.current_url

def test_tc04_empty_fields(driver):
    page = LoginPage(driver)
    page.load()
    page.login("", "")
    assert "/admin" not in driver.current_url and "/dashboard" not in driver.current_url
    
def test_tc05_password_boundary(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "12345678")
    assert "/admin" not in driver.current_url and "/dashboard" not in driver.current_url

def test_tc06_forced_failure_signup(driver):
    page = LoginPage(driver)
    page.load()
    page.login("student@professoros.edu.pk", "student123")
    try:
        assert "/admin" in driver.current_url or driver.current_url != page.url
    except AssertionError:
        driver.save_screenshot("failed_login.png")
        raise
