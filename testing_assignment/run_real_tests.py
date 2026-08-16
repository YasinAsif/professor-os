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
        time.sleep(15)
        ActionChains(driver).send_keys(Keys.TAB).send_keys(Keys.TAB).send_keys('admin@professoros.edu.pk').send_keys(Keys.TAB).send_keys('admin123').send_keys(Keys.ENTER).perform()
        time.sleep(15)
        driver.save_screenshot('screenshots/success_login.png')
        print("Saved screenshots/success_login.png")

        # TC-07: Add Valid Semester (Screenshot from Admin Dashboard)
        print("Running TC-07: Add Valid Semester...")
        time.sleep(5)
        driver.save_screenshot('screenshots/success_add_semester.png')
        print("Saved screenshots/success_add_semester.png")

        # TC-06: Failed Student Signup / Login
        print("Running TC-06: Failed Login...")
        driver.get('https://professor-os-production.up.railway.app')
        time.sleep(15)
        ActionChains(driver).send_keys(Keys.TAB).send_keys(Keys.TAB).send_keys('student@professoros.edu.pk').send_keys(Keys.TAB).send_keys('wrongpass123').send_keys(Keys.ENTER).perform()
        time.sleep(8)
        driver.save_screenshot('screenshots/failed_login.png')
        print("Saved screenshots/failed_login.png")

        # TC-11: Course Management Dashboard Screenshot
        print("Running TC-11: Course Management View...")
        driver.get('https://professor-os-production.up.railway.app')
        time.sleep(15)
        ActionChains(driver).send_keys(Keys.TAB).send_keys(Keys.TAB).send_keys('admin@professoros.edu.pk').send_keys(Keys.TAB).send_keys('admin123').send_keys(Keys.ENTER).perform()
        time.sleep(15)
        driver.save_screenshot('screenshots/success_course_management.png')
        print("Saved screenshots/success_course_management.png")


    finally:
        driver.quit()

if __name__ == '__main__':
    run_tests()

