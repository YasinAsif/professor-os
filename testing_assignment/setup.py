import os

def create_file(path, content):
    dir = os.path.dirname(path)
    if dir: os.makedirs(dir, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

mock_server = """
from http.server import SimpleHTTPRequestHandler, HTTPServer
import threading

class MockServerRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/login.html'
        elif self.path == '/dashboard':
            self.path = '/dashboard.html'
        return super().do_GET()

def start_server():
    server = HTTPServer(('127.0.0.1', 8080), MockServerRequestHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server

if __name__ == '__main__':
    server = start_server()
    print("Mock server running on http://127.0.0.1:8080")
    import time
    while True: time.sleep(1)
"""

html_login = """
<!DOCTYPE html>
<html>
<head><title>ProfessorOS Login</title></head>
<body>
    <h1>Login</h1>
    <input id="email" type="email" placeholder="Email"><br>
    <input id="password" type="password" placeholder="Password"><br>
    <button id="login-btn">Sign In</button>
    <div id="error-msg" style="color:red; display:none;"></div>
    <script>
        document.getElementById('login-btn').onclick = function() {
            var e = document.getElementById('email').value;
            var p = document.getElementById('password').value;
            if(e === '' || p === '') {
                document.getElementById('error-msg').innerText = 'Fields cannot be empty';
                document.getElementById('error-msg').style.display = 'block';
            } else if(e === 'admin@professoros.edu.pk' && p === 'admin123') {
                window.location.href = '/dashboard';
            } else {
                document.getElementById('error-msg').innerText = 'Invalid credentials';
                document.getElementById('error-msg').style.display = 'block';
            }
        };
    </script>
</body>
</html>
"""

html_dashboard = """
<!DOCTYPE html>
<html>
<head><title>Admin Dashboard</title></head>
<body>
    <h1>Admin Dashboard</h1>
    <h2>Add Semester</h2>
    <input id="sem-name" type="text" placeholder="Semester Name"><br>
    <input id="sem-start" type="date"><br>
    <input id="sem-end" type="date"><br>
    <button id="add-sem-btn">Add Semester</button>
    <ul id="sem-list"></ul>
    <div id="sem-error" style="color:red; display:none;"></div>
    <script>
        document.getElementById('add-sem-btn').onclick = function() {
            var n = document.getElementById('sem-name').value;
            var s = document.getElementById('sem-start').value;
            var e = document.getElementById('sem-end').value;
            if(!n || !s || !e) {
                document.getElementById('sem-error').innerText = 'All fields required';
                document.getElementById('sem-error').style.display = 'block';
                return;
            }
            if(s === e) {
                document.getElementById('sem-error').innerText = 'Start and End dates cannot be same';
                document.getElementById('sem-error').style.display = 'block';
                return;
            }
            document.getElementById('sem-error').style.display = 'none';
            var li = document.createElement('li');
            li.innerText = n + ' (' + s + ' to ' + e + ')';
            document.getElementById('sem-list').appendChild(li);
        };
    </script>
</body>
</html>
"""

base_page = """
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class BasePage:
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 10)

    def find_element(self, by, value):
        return self.wait.until(EC.presence_of_element_located((by, value)))

    def click(self, by, value):
        element = self.wait.until(EC.element_to_be_clickable((by, value)))
        element.click()

    def send_keys(self, by, value, text):
        element = self.find_element(by, value)
        element.clear()
        element.send_keys(text)
"""

login_page = """
from selenium.webdriver.common.by import By
from .base_page import BasePage

class LoginPage(BasePage):
    URL = "http://127.0.0.1:8080"
    EMAIL_INPUT = (By.ID, "email")
    PASSWORD_INPUT = (By.ID, "password")
    LOGIN_BTN = (By.ID, "login-btn")
    ERROR_MSG = (By.ID, "error-msg")

    def load(self):
        self.driver.get(self.URL)

    def login(self, email, password):
        self.send_keys(*self.EMAIL_INPUT, email)
        self.send_keys(*self.PASSWORD_INPUT, password)
        self.click(*self.LOGIN_BTN)

    def get_error_message(self):
        return self.find_element(*self.ERROR_MSG).text
"""

dashboard_page = """
from selenium.webdriver.common.by import By
from .base_page import BasePage

class DashboardPage(BasePage):
    URL = "http://127.0.0.1:8080/dashboard"
    NAME_INPUT = (By.ID, "sem-name")
    START_INPUT = (By.ID, "sem-start")
    END_INPUT = (By.ID, "sem-end")
    ADD_BTN = (By.ID, "add-sem-btn")
    ERROR_MSG = (By.ID, "sem-error")
    SEM_LIST = (By.ID, "sem-list")

    def load(self):
        self.driver.get(self.URL)

    def add_semester(self, name, start, end):
        self.send_keys(*self.NAME_INPUT, name)
        self.send_keys(*self.START_INPUT, start)
        self.send_keys(*self.END_INPUT, end)
        self.click(*self.ADD_BTN)

    def get_error_message(self):
        return self.find_element(*self.ERROR_MSG).text
        
    def get_semesters_count(self):
        ul = self.find_element(*self.SEM_LIST)
        return len(ul.find_elements(By.TAG_NAME, "li"))
"""

conftest = """
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

@pytest.fixture
def driver():
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--window-size=1920,1080")
    d = webdriver.Chrome(options=options)
    yield d
    d.quit()
"""

test_auth = """
import pytest
from pages.login_page import LoginPage
import time

def test_tc01_valid_login(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "admin123")
    time.sleep(1) # wait for redirect
    assert "dashboard" in driver.current_url
    driver.save_screenshot("success_login.png")

def test_tc02_invalid_email(driver):
    page = LoginPage(driver)
    page.load()
    page.login("invalidemail", "admin123")
    assert "Invalid credentials" in page.get_error_message()
    
def test_tc03_invalid_password(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "wrongpass")
    assert "Invalid credentials" in page.get_error_message()

def test_tc04_empty_fields(driver):
    page = LoginPage(driver)
    page.load()
    page.login("", "")
    assert "Fields cannot be empty" in page.get_error_message()
    
def test_tc05_password_boundary(driver):
    page = LoginPage(driver)
    page.load()
    page.login("admin@professoros.edu.pk", "12345678")
    assert "Invalid credentials" in page.get_error_message()

def test_tc06_forced_failure(driver):
    page = LoginPage(driver)
    page.load()
    page.login("student@professoros.edu.pk", "student123")
    try:
        assert "dashboard" in driver.current_url
    except AssertionError:
        driver.save_screenshot("failed_login.png")
        raise
"""

test_admin = """
import pytest
from pages.dashboard_page import DashboardPage
import time

def test_tc07_add_valid_semester(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Fall 2026", "2026-09-01", "2027-01-31")
    assert page.get_semesters_count() == 1
    driver.save_screenshot("success_add_semester.png")

def test_tc08_missing_dates(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Spring 2027", "", "")
    assert "All fields required" in page.get_error_message()

def test_tc09_boundary_same_dates(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Summer 2026", "2026-06-01", "2026-06-01")
    assert "Start and End dates cannot be same" in page.get_error_message()

def test_tc10_boundary_max_year(driver):
    page = DashboardPage(driver)
    page.load()
    page.add_semester("Future 2035", "2035-01-01", "2035-06-01")
    assert page.get_semesters_count() == 1
"""

run_tests = """
import subprocess
import time
import os
from mock_server import start_server

if __name__ == '__main__':
    server = start_server()
    time.sleep(2)
    print("Running pytest...")
    subprocess.run(["pytest", "-v", "--html=report.html", "--self-contained-html"])
    print("Tests finished. Stopping server.")
    server.shutdown()
"""

create_file('mock_server.py', mock_server)
create_file('login.html', html_login)
create_file('dashboard.html', html_dashboard)
create_file('pages/__init__.py', '')
create_file('pages/base_page.py', base_page)
create_file('pages/login_page.py', login_page)
create_file('pages/dashboard_page.py', dashboard_page)
create_file('tests/__init__.py', '')
create_file('tests/conftest.py', conftest)
create_file('tests/test_auth.py', test_auth)
create_file('tests/test_admin.py', test_admin)
create_file('run_tests.py', run_tests)

print("Files successfully generated.")
