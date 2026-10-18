"""ProfessorOS – Test configuration and environment isolation.

Enforces:
1. TESTING=1 environment flag to deactivate background daemons (e.g. exam monitor).
2. Tests that do not require a live database remain mock-isolated.
"""

import os
import pytest

# Ensure TESTING flag is set BEFORE any application modules import settings/lifespan
os.environ["TESTING"] = "1"

# Guarantee that no tests touch the live/dev database.
# If TEST_PG_URL is set (for explicit opt-in pg tests against scratch DB), use it.
# Otherwise, set DATABASE_URL to an unreachable host to fail-fast if any test connects.
if "TEST_PG_URL" in os.environ:
    os.environ["DATABASE_URL"] = os.environ["TEST_PG_URL"]
else:
    os.environ["DATABASE_URL"] = "postgresql+asyncpg://invalid_test_user:invalid_test_pass@127.0.0.1:59999/invalid_test_db"


@pytest.fixture(autouse=True)
def enforce_test_isolation():
    """Safety guard: verify that the testing flag is active for all test runs."""
    assert os.getenv("TESTING") == "1"
    yield

