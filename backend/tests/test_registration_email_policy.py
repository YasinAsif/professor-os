from app.services.registration_policy import registration_flags


def test_self_registration_skips_email_verification_but_requires_admin_approval():
    assert registration_flags("student") == {"is_verified": True, "needs_approval": True}
    assert registration_flags("professor") == {"is_verified": True, "needs_approval": True}
