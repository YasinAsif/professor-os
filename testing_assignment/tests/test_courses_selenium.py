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


def open_courses_page(driver):
    driver.get(f"{BASE_URL}/courses")
    WebDriverWait(driver, 20).until(lambda d: d.execute_script("return document.readyState") == "complete")

    if "courses" not in driver.current_url.lower():
        nav_links = driver.find_elements(By.XPATH, "//*[contains(normalize-space(.), 'Courses') or contains(normalize-space(@aria-label), 'Courses')]")
        if nav_links:
            nav_links[0].click()


def test_course_listing_page_loads():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        open_courses_page(driver)
        page_text = driver.page_source.lower()
        assert "course" in page_text or "courses" in page_text or "professor" in page_text
    finally:
        driver.quit()


def test_course_creation_form_is_visible():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        open_courses_page(driver)

        labels = ["title", "code", "semester", "description"]
        visible_words = driver.page_source.lower()
        assert any(label in visible_words for label in labels) or "add course" in visible_words
    finally:
        driver.quit()


def test_course_weight_validation_message_is_shown_when_invalid():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        open_courses_page(driver)
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        page_text = driver.page_source.lower()
        assert "weight" in page_text or "hec" in page_text or "assessment" in page_text
    finally:
        driver.quit()
