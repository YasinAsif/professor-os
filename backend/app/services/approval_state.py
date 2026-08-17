"""Small state transition helpers for admin approval actions."""


def approve_if_pending(user) -> bool:
    if user.is_approved:
        return False
    user.is_approved = True
    return True
