"""ProfessorOS – Test configuration.

The unit tests in this project use SimpleNamespace mocks (no real DB).
Integration tests requiring a live app are marked with @pytest.mark.integration
and skipped unless DATABASE_URL is configured.
"""
import pytest


# No app import here — unit tests use SimpleNamespace mocks directly.
# Integration tests that need the full app should be run with a real .env.
