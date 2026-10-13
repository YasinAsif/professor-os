"""ExamAttempt anti-cheat flag logic – unit tests (no DB required).

Tests the flagging logic in isolation using a plain Python object that
mirrors the ExamAttempt model fields, matching the SimpleNamespace pattern.
"""

from types import SimpleNamespace


def _make_attempt(**kwargs):
    """Create a mock attempt with defaults."""
    defaults = dict(
        id=1, assignment_id=1, student_id=1,
        tab_switch_count=0, is_flagged=False, flag_reason=None,
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


def _apply_flag_logic(attempt):
    """Mirrors the flag logic in exams.py flag_exam_attempt endpoint."""
    attempt.tab_switch_count += 1
    if attempt.tab_switch_count >= 3 and not attempt.is_flagged:
        attempt.is_flagged = True
        attempt.flag_reason = f"Flagged: {attempt.tab_switch_count} tab switches detected."
    return attempt


def test_first_switch_does_not_flag():
    attempt = _make_attempt()
    _apply_flag_logic(attempt)
    assert attempt.tab_switch_count == 1
    assert attempt.is_flagged is False


def test_second_switch_does_not_flag():
    attempt = _make_attempt(tab_switch_count=1)
    _apply_flag_logic(attempt)
    assert attempt.tab_switch_count == 2
    assert attempt.is_flagged is False


def test_third_switch_triggers_flag():
    attempt = _make_attempt(tab_switch_count=2)
    _apply_flag_logic(attempt)
    assert attempt.tab_switch_count == 3
    assert attempt.is_flagged is True
    assert "Flagged: 3" in attempt.flag_reason


def test_already_flagged_attempt_stays_flagged_and_reason_unchanged():
    """Once flagged at 3, further switches do NOT overwrite the reason."""
    attempt = _make_attempt(tab_switch_count=3, is_flagged=True, flag_reason="Flagged: 3 tab switches detected.")
    _apply_flag_logic(attempt)
    assert attempt.tab_switch_count == 4
    assert attempt.is_flagged is True
    assert "Flagged: 3" in attempt.flag_reason  # reason still shows original 3


def test_flag_logic_increments_count_correctly():
    attempt = _make_attempt()
    for _ in range(5):
        _apply_flag_logic(attempt)
    assert attempt.tab_switch_count == 5
    assert attempt.is_flagged is True


def _apply_status_action(attempt, action: str, reason: str = None, instructor_name: str = "Prof"):
    """Mirrors update_exam_attempt_status logic."""
    if action == "invalidate":
        attempt.is_flagged = True
        desc = reason or "Disqualified / Attempt invalidated by instructor."
        attempt.flag_reason = f"[DISQUALIFIED] {desc}"
    elif action == "clear":
        attempt.is_flagged = False
        attempt.flag_reason = f"Flags cleared by instructor {instructor_name}."
        attempt.tab_switch_count = 0
    else:
        raise ValueError("Invalid action")
    return attempt


def test_invalidate_action_marks_attempt_disqualified():
    attempt = _make_attempt(tab_switch_count=1, is_flagged=False)
    _apply_status_action(attempt, "invalidate", "Pasting from ChatGPT detected")
    assert attempt.is_flagged is True
    assert "[DISQUALIFIED] Pasting from ChatGPT detected" in attempt.flag_reason


def test_clear_action_resets_switches_and_unflags():
    attempt = _make_attempt(tab_switch_count=4, is_flagged=True, flag_reason="Flagged: 4 tab switches detected.")
    _apply_status_action(attempt, "clear", instructor_name="Dr. Smith")
    assert attempt.is_flagged is False
    assert attempt.tab_switch_count == 0
    assert "Flags cleared by instructor Dr. Smith" in attempt.flag_reason

