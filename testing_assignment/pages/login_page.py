from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
import time

class LoginPage:
    def __init__(self, driver):
        self.driver = driver
        self.url = "https://professor-os-production.up.railway.app"

    def load(self):
        self.driver.get(self.url)
        time.sleep(3) # Wait for Canvas to render

    def login(self, email, password):
        action = ActionChains(self.driver)
        # Tab twice to reach email input
        action.send_keys(Keys.TAB).send_keys(Keys.TAB)
        action.send_keys(email)
        action.send_keys(Keys.TAB)
        action.send_keys(password)
        action.send_keys(Keys.ENTER)
        action.perform()
        time.sleep(3) # Wait for authentication request
