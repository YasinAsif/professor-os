"""ProfessorOS – Application configuration via environment variables.

Backward-compatible bridge to app.config.settings.
"""

from app.config.settings import Settings, get_settings

__all__ = ["Settings", "get_settings"]
