"""Run every Selenium case as a separate pytest process in a fixed order."""

import subprocess
import sys


TEST_CASES = [
    "selenium_tests/tests/test_smoke.py::test_deployed_app_reaches_login_surface",
    "selenium_tests/tests/test_smoke.py::test_deployed_app_renders_non_empty_document",
    "selenium_tests/tests/test_authentication.py::test_empty_credentials_are_rejected",
    "selenium_tests/tests/test_authentication.py::test_invalid_password_is_rejected",
    "selenium_tests/tests/test_authentication.py::test_admin_can_sign_in",
    "selenium_tests/tests/test_admin.py::test_admin_area_is_accessible_after_login",
    "selenium_tests/tests/test_admin.py::test_admin_area_exposes_management_control",
    "selenium_tests/tests/test_courses.py::test_course_management_area_is_accessible",
    "selenium_tests/tests/test_courses.py::test_course_management_exposes_core_control",
]


def main():
    failed = []
    for index, test_case in enumerate(TEST_CASES, start=1):
        print(f"\n[{index}/{len(TEST_CASES)}] {test_case}", flush=True)
        result = subprocess.run(
            [sys.executable, "-m", "pytest", "-v", test_case, "--tb=short"],
            check=False,
        )
        if result.returncode != 0:
            failed.append(test_case)

    print(f"\nCompleted {len(TEST_CASES)} Selenium test cases.")
    if failed:
        print("Failed cases:")
        for test_case in failed:
            print(f"- {test_case}")
        return 1
    print("All Selenium test cases passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
