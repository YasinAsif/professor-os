"""Re-export of app.services.intent_router to support root-level services imports."""

from app.services.intent_router import (
    IntentType,
    RoutingResult,
    LocalIntentRouter,
    get_intent_router,
)

__all__ = [
    "IntentType",
    "RoutingResult",
    "LocalIntentRouter",
    "get_intent_router",
]
