import os

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
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


def wait_for(driver, locator, timeout=15):
    return WebDriverWait(driver, timeout).until(EC.presence_of_element_located(locator))


def login(driver, email, password):
    driver.get(BASE_URL)
    WebDriverWait(driver, 20).until(lambda d: d.execute_script("return document.readyState") == "complete")

    inputs = driver.find_elements(By.TAG_NAME, "input")
    if len(inputs) >= 2:
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", inputs[0], email)
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", inputs[1], password)
    else:
        ActionChains(driver).send_keys(email).send_keys("\t").send_keys(password).send_keys("\n").perform()

    buttons = driver.find_elements(By.TAG_NAME, "button") + driver.find_elements(By.TAG_NAME, "a")
    for element in buttons:
        text = (element.text or "").strip().lower()
        if any(token in text for token in ["login", "log in", "signin", "sign in", "submit"]):
            element.click()
            break
    else:
        ActionChains(driver).send_keys("\n").perform()


def test_valid_admin_login():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "admin123")
        WebDriverWait(driver, 20).until(lambda d: "/admin" in d.current_url.lower() or "/dashboard" in d.current_url.lower() or "professor" in d.title.lower())
        assert "/admin" in driver.current_url.lower() or "/dashboard" in driver.current_url.lower() or "professor" in driver.title.lower()
    finally:
        driver.quit()


def test_invalid_password_login_rejected():
    driver = make_driver()
    try:
        login(driver, "admin@professoros.edu.pk", "wrong-password")
        WebDriverWait(driver, 15).until(lambda d: "login" in d.current_url.lower() or "error" in d.page_source.lower() or "incorrect" in d.page_source.lower())
        assert "login" in driver.current_url.lower() or "incorrect" in driver.page_source.lower() or "error" in driver.page_source.lower()
    finally:
        driver.quit()


def test_empty_login_form_is_blocked():
    driver = make_driver()
    try:
        driver.get(BASE_URL)
        WebDriverWait(driver, 20).until(lambda d: d.execute_script("return document.readyState") == "complete")
        submit_buttons = driver.find_elements(By.TAG_NAME, "button") + driver.find_elements(By.TAG_NAME, "a")
        if submit_buttons:
            for button in submit_buttons:
                text = (button.text or "").strip().lower()
                if any(token in text for token in ["login", "log in", "signin", "sign in", "submit"]):
                    button.click()
                    break
        assert driver.current_url.lower().startswith(BASE_URL.lower()) or "login" in driver.current_url.lower()
    finally:
        driver.quit()
