import os
import re

from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support import expected_conditions as expected
from selenium.webdriver.support.ui import WebDriverWait


class BasePage:
    def __init__(self, driver, app_url):
        self.driver = driver
        self.app_url = app_url
        self.timeout = int(os.getenv("SELENIUM_TIMEOUT", "45"))
        self.wait = WebDriverWait(driver, self.timeout)

    def load(self, path=""):
        self.driver.get(f"{self.app_url}/{path.lstrip('/')}")
        self.wait_for_ready()

    def wait_for_ready(self):
        self.wait.until(lambda d: d.execute_script("return document.readyState") == "complete")
        self.wait.until(expected.presence_of_element_located((By.TAG_NAME, "body")))
        self.wait.until(
            lambda d: d.find_elements(By.CSS_SELECTOR, "flutter-view")
            or d.find_elements(By.TAG_NAME, "input")
        )
        placeholders = self.driver.find_elements(By.CSS_SELECTOR, "flt-semantics-placeholder")
        if placeholders:
            self.driver.execute_script("arguments[0].click();", placeholders[0])
        self.wait.until(
            lambda d: d.find_elements(By.TAG_NAME, "input")
            or d.find_element(By.TAG_NAME, "body").text.strip()
        )

    def body_text(self):
        return self.driver.find_element(By.TAG_NAME, "body").text.strip()

    def contains_any_text(self, *terms):
        text = self.body_text().lower()
        return any(term.lower() in text for term in terms)

    def wait_until_text(self, *terms):
        self.wait.until(lambda _: self.contains_any_text(*terms))

    def visible_inputs(self):
        return [element for element in self.driver.find_elements(By.TAG_NAME, "input") if element.is_displayed()]

    def fill_inputs_by_order(self, values):
        inputs = self.visible_inputs()
        if len(inputs) < len(values):
            raise AssertionError(f"Expected {len(values)} visible inputs, found {len(inputs)}")
        for element, value in zip(inputs[:len(values)], values):
            self.driver.execute_script("arguments[0].focus();", element)
            element.send_keys(Keys.CONTROL, "a")
            element.send_keys(value)

    def click_text(self, *terms):
        pattern = "|".join(re.escape(term) for term in terms)
        locator = (
            By.XPATH,
            "//*[self::button or self::a or @role='button' or @aria-label]["
            f"contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{terms[0].lower()}') "
            "or contains(translate(@aria-label, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "
            f"'{terms[0].lower()}')]",
        )
        candidates = self.wait.until(expected.presence_of_all_elements_located(locator))
        for element in candidates:
            label = (element.get_attribute("aria-label") or "").lower()
            text = (element.text or "").lower()
            if element.is_displayed() and any(term.lower() in text or term.lower() in label for term in terms):
                self.wait.until(lambda _: element.is_enabled())
                self.driver.execute_script("arguments[0].click();", element)
                return
        raise TimeoutException(f"Could not find clickable text matching {pattern}")
