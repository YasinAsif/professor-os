import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options

options = Options()
# options.add_argument("--headless")
driver = webdriver.Chrome(options=options)

try:
    print("Loading page...")
    driver.get("https://professor-os-production.up.railway.app")
    time.sleep(5)
    
    body = driver.find_element(By.TAG_NAME, "body")
    print("Pressing TAB to force semantics...")
    body.send_keys(Keys.TAB)
    time.sleep(2)
    
    semantics = driver.find_elements(By.TAG_NAME, "flt-semantics")
    print(f"Found {len(semantics)} semantic nodes.")
    for s in semantics[:5]:
        print(s.get_attribute("outerHTML"))
        
finally:
    driver.quit()
