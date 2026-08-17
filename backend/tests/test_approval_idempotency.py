from types import SimpleNamespace

from app.services.approval_state import approve_if_pending


def test_approving_an_already_approved_user_is_idempotent():
    user = SimpleNamespace(is_approved=True)

    assert approve_if_pending(user) is False
    assert user.is_approved is True


def test_approving_a_pending_user_changes_state_once():
    user = SimpleNamespace(is_approved=False)

    assert approve_if_pending(user) is True
    assert user.is_approved is True
