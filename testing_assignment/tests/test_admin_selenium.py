import os

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

BASE_URL = os.getenv("APP_URL", "https://professor-os-production.up.railway.app")


def make_driver():
    options = Options()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1100")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    return webdriver.Chrome(options=options)


def login(driver, email, password):
    driver.get(BASE_URL)
    WebDriverWait(driver, 20).until(lambda d: d.execute_script("return document.readyState") == "complete")

    inputs = driver.find_elements(By.TAG_NAME, "input")
    if len(inputs) >= 2:
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", inputs[0], email)
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", inputs[1], password)

    buttons = driver.find_elements(By.TAG_NAME, "button") + driver.find_elements(By.TAG_NAME, "a")
    for element in buttons:
        text = (element.text or "").strip().lower()
        if any(token in text for token in ["login", "log in", "signin", "sign in", "submit"]):
            element.click()
            break


def open_admin_page(driver):
    driver.get(f"{BASE_URL}/admin")
    WebDriverWait(driver, 20).until(lambda d: d.execute_script("return document.readyState") == "complete")

    if "admin" not in driver.current_url.lower():
        nav_links = driver.find_elements(By.XPATH, "//*[contains(normalize-space(.), 'Admin') or contains(normalize-space(@aria-label), 'Admin')]")
        if nav_links:
            nav_links[0].click()


def test_admin_dashboard_loads_after_login():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        WebDriverWait(driver, 20).until(lambda d: "/admin" in d.current_url.lower() or "/dashboard" in d.current_url.lower())
        assert "/admin" in driver.current_url.lower() or "/dashboard" in driver.current_url.lower()
    finally:
        driver.quit()


def test_semester_management_page_is_accessible():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        open_admin_page(driver)
        page_text = driver.page_source.lower()
        assert "semester" in page_text or "manage" in page_text or "admin" in page_text
    finally:
        driver.quit()


def test_admin_screen_displays_core_controls():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        open_admin_page(driver)
        page_text = driver.page_source.lower()
        assert any(token in page_text for token in ["add", "semester", "users", "reports", "dashboard"])
    finally:
        driver.quit()
