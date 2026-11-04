import json
import pytest
from app.services.grading_pipeline import grade_mcq_submission

class MockAssignment:
    title = 'Quiz 1'
    max_marks = 100.0
    description = json.dumps({
        'type': 'mcq',
        'questions': [
            {'question': 'What is Python?', 'options': ['Language', 'Animal'], 'correct': 0},
            {'question': 'What is 2+2?', 'options': ['3', '4'], 'correct': 1},
        ]
    })

class MockSubmission:
    def __init__(self, content):
        self.id = 1
        self.submission_type = 'mcq'
        self.content = content
        self.score = None
        self.status = 'pending'
        self.feedback = None
        self.evaluation_metadata = None

def test_mcq_grading_0_based():
    sub = MockSubmission('{"0": 0, "1": 1}')
    res = grade_mcq_submission(MockAssignment(), sub)
    assert res['status'] == 'graded'
    assert res['score'] == 100.0
    assert sub.score == 100.0

def test_mcq_grading_1_based_legacy():
    # 1-based choices: 1 maps to option index 0, 2 maps to option index 1
    sub = MockSubmission('{"0": 1, "1": 2}')
    res = grade_mcq_submission(MockAssignment(), sub)
    assert res['status'] == 'graded'
    assert res['score'] == 100.0
    assert sub.score == 100.0

def test_mcq_grading_mixed_correct_incorrect():
    # Question 0 correct (0), Question 1 wrong (0)
    sub = MockSubmission('{"0": 0, "1": 0}')
    res = grade_mcq_submission(MockAssignment(), sub)
    assert res['status'] == 'graded'
    assert res['score'] == 50.0
