from app.models.submission import Submission


def test_submission_persists_the_evaluator_model_used_for_grading():
    assert "evaluator_model" in Submission.__table__.c
