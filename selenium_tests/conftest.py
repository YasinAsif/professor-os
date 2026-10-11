import os
import subprocess
import sys
import time
from urllib.request import urlopen
from pathlib import Path

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


DEFAULT_APP_URL = "https://professor-os-production-65b2.up.railway.app"
LOCAL_APP_URL = "http://127.0.0.1:8765"
LOCAL_PASSWORD = "BrowserTest@2026"
LOCAL_ROLE_EMAILS = {
    "admin": "browser.admin@e2e.example.com",
    "professor": "browser.professor@e2e.example.com",
    "student": "browser.student@e2e.example.com",
    "ta": "browser.ta@e2e.example.com",
}


@pytest.fixture(scope="session", autouse=True)
def local_test_server():
    """Run a real local API/static app when no external target is configured."""
    configured_url = os.getenv("APP_URL", "").rstrip("/")
    if configured_url and configured_url != LOCAL_APP_URL:
        yield
        return

    repo_root = Path(__file__).resolve().parents[1]
    backend = repo_root / "backend"
    env = os.environ.copy()
    env["PYTHONPATH"] = str(backend)
    subprocess.run(
        [sys.executable, str(repo_root / "selenium_tests" / "local_bootstrap.py")],
        cwd=backend,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    try:
        with urlopen(f"{LOCAL_APP_URL}/health", timeout=1) as response:
            if response.status == 200:
                yield
                return
    except Exception:
        pass

    process = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8765"],
        cwd=backend,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(60):
            try:
                with urlopen(f"{LOCAL_APP_URL}/health", timeout=1) as response:
                    if response.status == 200:
                        break
            except Exception:
                time.sleep(0.5)
        else:
            raise RuntimeError("Local browser test server did not become ready")
        yield
    finally:
        process.terminate()
        process.wait(timeout=10)


@pytest.fixture
def app_url():
    return os.getenv("APP_URL", LOCAL_APP_URL).rstrip("/")


@pytest.fixture
def admin_credentials():
    email = os.getenv("ADMIN_EMAIL")
    password = os.getenv("ADMIN_PASSWORD")
    return (email, password) if email and password else (LOCAL_ROLE_EMAILS["admin"], LOCAL_PASSWORD)


@pytest.fixture(params=("professor", "student", "ta", "admin"))
def role_credentials(request):
    role = request.param
    email = os.getenv(f"{role.upper()}_EMAIL")
    password = os.getenv(f"{role.upper()}_PASSWORD")
    return role, email or LOCAL_ROLE_EMAILS[role], password or LOCAL_PASSWORD


@pytest.fixture
def driver(request):
    options = Options()
    if os.getenv("HEADLESS", "1") != "0":
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1100")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    browser = webdriver.Chrome(options=options)
    browser.set_page_load_timeout(int(os.getenv("SELENIUM_TIMEOUT", "45")))
    yield browser

    report = getattr(request.node, "rep_call", None)
    if report and report.failed and os.getenv("SCREENSHOTS", "0") == "1":
        target = Path("selenium_tests") / "artifacts"
        target.mkdir(parents=True, exist_ok=True)
        browser.save_screenshot(str(target / f"{request.node.name}.png"))
    browser.quit()


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    setattr(item, f"rep_{report.when}", report)
