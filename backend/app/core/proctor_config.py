"""ProfessorOS – Central proctoring configuration constants."""

# Single source of truth for heartbeat and timeout thresholds
HEARTBEAT_TIMEOUT_SECONDS: int = 30
SUBMISSION_GRACE_SECONDS: int = 10
VIOLATION_DEDUPE_WINDOW_SECONDS: float = 1.5
DEFAULT_STRIKE_LIMIT_FLAG: int = 3
DEFAULT_STRIKE_LIMIT_AUTOSUBMIT: int = 5
MAX_RESTORING_WINDOW_SECONDS: int = 3
FILE_PICKER_GRACE_SECONDS: float = 1.5


def is_assignment_proctored(assignment) -> bool:
    """Canonical proctored definition (Item 1.14):
    Proctored = time_limit_minutes > 0 OR type in (mcq, quiz) with fullscreen_required.
    """
    time_limit = getattr(assignment, "time_limit_minutes", None) or 0
    if time_limit > 0:
        return True
    atype = getattr(assignment, "type", "")
    atype_val = atype.value if hasattr(atype, "value") else str(atype)
    fs_req = bool(getattr(assignment, "fullscreen_required", False))
    if atype_val in ("mcq", "quiz") and fs_req:
        return True
    return False

