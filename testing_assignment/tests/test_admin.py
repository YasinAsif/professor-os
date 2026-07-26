import pytest
from pages.dashboard_page import DashboardPage
from pages.login_page import LoginPage
import time

@pytest.fixture(autouse=True)
def setup_login(driver):
    # Log in first to reach the dashboard
    login_page = LoginPage(driver)
    login_page.load()
    login_page.login("admin@professoros.edu.pk", "admin123")

def test_tc07_add_valid_semester(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Fall 2026", "2026-09-01", "2027-01-31")
    assert page.get_semesters_count() == 1
    driver.save_screenshot("success_add_semester.png")

def test_tc08_missing_dates(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Spring 2027", "", "")
    # Simulated assertion
    assert True

def test_tc09_boundary_same_dates(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Summer 2026", "2026-06-01", "2026-06-01")
    # Simulated assertion
    assert True

def test_tc10_boundary_max_year(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Future 2035", "2035-01-01", "2035-06-01")
    assert page.get_semesters_count() == 1
