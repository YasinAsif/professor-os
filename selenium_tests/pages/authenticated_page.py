from .base_page import BasePage


class AuthenticatedPage(BasePage):
    def open_admin(self):
        if "/admin" not in self.driver.current_url.lower():
            try:
                self.driver.get(f"{self.app_url}/admin")
                self.wait_for_ready()
            except Exception:
                self.click_text("admin", "dashboard")
        self.wait_until_text("admin", "semester", "users", "approval", "dashboard")

    def open_courses(self):
        if not any(route in self.driver.current_url.lower() for route in ("/course", "/courses")):
            try:
                self.driver.get(f"{self.app_url}/courses")
                self.wait_for_ready()
            except Exception:
                self.driver.get(self.app_url)
                self.wait_for_ready()
                self.click_text("course", "courses")
        self.wait_until_text("course", "courses", "roster", "assignment", "join")
