from selenium_tests.pages.login_page import LoginPage


def test_deployed_app_reaches_login_surface(driver, app_url):
    page = LoginPage(driver, app_url)
    page.load()
    assert page.has_login_surface()


def test_deployed_app_renders_non_empty_document(driver, app_url):
    page = LoginPage(driver, app_url)
    page.load()
    assert page.body_text()
