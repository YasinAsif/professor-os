from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
import time

from .base_page import BasePage


class LoginPage(BasePage):
    def load(self):
        super().load()
        self.wait.until(lambda _: self.has_login_surface())

    def has_login_surface(self):
        return len(self.visible_inputs()) >= 2 or self.contains_any_text("login", "sign in", "email", "password")

    def submit_login(self, email, password):
        views = self.driver.find_elements(By.CSS_SELECTOR, "flutter-view")
        if views:
            inputs = self.visible_inputs()
            if len(inputs) >= 2:
                # Flutter's password semantics node is pointer-transparent;
                # focus the email field, then tab into the real text editor.
                self.driver.execute_script("arguments[0].focus();", inputs[0])
                inputs[0].send_keys(Keys.CONTROL, "a")
                inputs[0].send_keys(email)
                ActionChains(self.driver).send_keys(Keys.TAB).perform()
                time.sleep(0.25)
                ActionChains(self.driver).send_keys(password).perform()
                if inputs[1].get_attribute("value") != password:
                    self.driver.execute_script("arguments[0].focus();", inputs[1])
                    inputs[1].send_keys(Keys.CONTROL, "a", password)
            else:
                self.driver.execute_script("arguments[0].focus();", views[0])
                ActionChains(self.driver).send_keys(
                    Keys.TAB, email, Keys.TAB, password
                ).perform()
            try:
                self.click_text("sign in", "login")
            except Exception:
                ActionChains(self.driver).send_keys(Keys.ENTER).perform()
        else:
            inputs = self.visible_inputs()
            self.fill_inputs_by_order((email, password))
            self.driver.switch_to.active_element.send_keys(email, Keys.TAB, password, Keys.ENTER)
        self.wait_for_ready()

    def login_with_credentials(self, email, password):
        self.load()
        self.submit_login(email, password)
        self.wait_until_authenticated()

    def wait_until_authenticated(self):
        WebDriverWait(self.driver, max(self.timeout, 60)).until(
            lambda _: any(route in self.driver.current_url.lower() for route in ("/courses", "/admin", "/dashboard", "/ta-dashboard"))
            or self.contains_any_text("dashboard", "admin", "course", "welcome")
        )
        return any(route in self.driver.current_url.lower() for route in ("/courses", "/admin", "/dashboard", "/ta-dashboard"))

    def stays_on_login_or_shows_error(self):
        return self.contains_any_text("invalid", "incorrect", "required", "error", "login", "sign in")
