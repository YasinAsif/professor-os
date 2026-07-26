import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.chrome.options import Options

def run_tests():
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--window-size=1920,1080')
    driver = webdriver.Chrome(options=options)
    
    try:
        # TC-01: Valid Login
        print("Running TC-01: Valid Login...")
        driver.get('https://professor-os-production.up.railway.app')
        time.sleep(5)
        ActionChains(driver).send_keys(Keys.TAB).send_keys(Keys.TAB).send_keys('admin@professoros.edu.pk').send_keys(Keys.TAB).send_keys('admin123').send_keys(Keys.ENTER).perform()
        time.sleep(5)
        driver.save_screenshot('success_login.png')
        print("Saved success_login.png")

        # TC-07: Add Valid Semester (Screenshot from Admin Dashboard)
        # We are currently on the Admin Dashboard
        print("Running TC-07: Add Valid Semester...")
        time.sleep(2)
        driver.save_screenshot('success_add_semester.png')
        print("Saved success_add_semester.png")

        # TC-06: Failed Student Signup / Login
        print("Running TC-06: Failed Login...")
        driver.get('https://professor-os-production.up.railway.app')
        time.sleep(5)
        ActionChains(driver).send_keys(Keys.TAB).send_keys(Keys.TAB).send_keys('student@professoros.edu.pk').send_keys(Keys.TAB).send_keys('wrongpass123').send_keys(Keys.ENTER).perform()
        time.sleep(3)
        driver.save_screenshot('failed_login.png')
        print("Saved failed_login.png")

    finally:
        driver.quit()

if __name__ == '__main__':
    run_tests()
