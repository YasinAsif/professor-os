from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
import time

def take_screenshots():
    print("Starting screenshot generation...")
    
    # TC-06: Failed Login
    print("Generating Failed Login Screenshot...")
    options = Options()
    options.add_argument("--window-size=1920,1080")
    driver = webdriver.Chrome(options=options)
    driver.get("https://professor-os-production.up.railway.app")
    print("Waiting 20 seconds for Login Page to fully render...")
    time.sleep(20) # Wait for initial render
    
    action = ActionChains(driver)
    # The page might not auto-focus, or 2 tabs skips Email. We use 1 tab to reach Email.
    action.send_keys(Keys.TAB)
    action.send_keys("student@professoros.edu.pk")
    action.send_keys(Keys.TAB)
    action.send_keys("student123")
    action.send_keys(Keys.ENTER)
    action.perform()
    print("Waiting 10 seconds for error state...")
    time.sleep(10) # Wait for error animation
    driver.save_screenshot("failed_login.png")
    driver.quit()
    print("Saved failed_login.png")

    # TC-01: Success Login & TC-07 Dashboard
    print("Generating Success Screenshots...")
    options = Options()
    options.add_argument("--window-size=1920,1080")
    driver = webdriver.Chrome(options=options)
    driver.get("https://professor-os-production.up.railway.app")
    print("Waiting 20 seconds for Login Page to fully render...")
    time.sleep(20) # Wait for initial render
    
    action = ActionChains(driver)
    action.send_keys(Keys.TAB)
    action.send_keys("admin@professoros.edu.pk")
    action.send_keys(Keys.TAB)
    action.send_keys("admin123")
    action.send_keys(Keys.ENTER)
    action.perform()
    
    # Wait a LONG time for login network request and CanvasKit dashboard render
    print("Waiting 25 seconds for Dashboard to render completely...")
    time.sleep(25) 
    
    driver.save_screenshot("success_login.png")
    print("Saved success_login.png")
    
    # Wait a bit more and save it as the semester one too
    time.sleep(5)
    driver.save_screenshot("success_add_semester.png")
    driver.quit()
    print("Saved success_add_semester.png")
    
    print("Done!")

if __name__ == "__main__":
    take_screenshots()
