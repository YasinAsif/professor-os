"""Re-export of app.config.settings to support root-level config imports."""

from app.config.settings import Settings, get_settings

__all__ = ["Settings", "get_settings"]
