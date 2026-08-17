"""Registration policy for self-service accounts."""


def registration_flags(role: str) -> dict[str, bool]:
    return {"is_verified": True, "needs_approval": role in ("professor", "student", "ta")}
