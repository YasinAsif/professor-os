import pytest
from app.services.grading_pipeline import GradingEvaluationSchema, CriterionGradingResult
from app.api.v1.quizzes import _normalize_options_for_student
from app.api.v1.exams import _sanitize_exam_description_for_student
import json


def test_grading_schema_reconciliation_without_top_level_max_and_percentage():
    """Verify that when LLM returns only criteria without top-level percentage and max_marks,
    GradingEvaluationSchema dynamically computes total_score, max_marks, and percentage."""
    raw_llm_dict = {
        "diagnostic_reasoning": "Student answers are accurate.",
        "criteria": [
            {
                "criterion_name": "Technical Accuracy & Methodology",
                "score": 4.5,
                "max_score": 5.0,
                "rationale": "Accurate calculation.",
            },
            {
                "criterion_name": "Completeness & Problem Resolution",
                "score": 2.5,
                "max_score": 3.0,
                "rationale": "Mostly complete.",
            },
            {
                "criterion_name": "Clarity & Academic Quality",
                "score": 1.5,
                "max_score": 2.0,
                "rationale": "Clear writing.",
            },
        ],
    }
    evaluation = GradingEvaluationSchema.model_validate(raw_llm_dict)
    assert evaluation.total_score == 8.5
    assert evaluation.max_marks == 10.0
    assert evaluation.percentage == 85.0
    assert len(evaluation.criteria_evaluations) == 3


def test_normalize_options_for_student_strips_dict_and_correct_flags():
    """Verify student-facing MCQ options are clean strings and never leak is_correct."""
    # Shape A: AI-generated list of dicts with is_correct
    raw_options = [
        {"text": "Option A (O(log n))", "is_correct": True},
        {"text": "Option B (O(n))", "is_correct": False},
        {"text": "Option C (O(1))", "is_correct": False},
    ]
    normalized = _normalize_options_for_student(raw_options)
    assert normalized == ["Option A (O(log n))", "Option B (O(n))", "Option C (O(1))"]
    # Check that is_correct does not appear in any string
    for opt in normalized:
        assert "is_correct" not in opt
        assert "True" not in opt

    # Shape B: Professor manual string array
    raw_strings = ["Alpha", "Beta", "Gamma"]
    assert _normalize_options_for_student(raw_strings) == ["Alpha", "Beta", "Gamma"]


def test_sanitize_exam_description_strips_answers():
    """Verify that teacher ground truth answers and reference answers are removed from student exam payload."""
    raw_desc = json.dumps({
        "type": "mcq",
        "questions": [
            {
                "question": "What is the capital of France?",
                "options": [{"text": "Paris", "is_correct": True}, {"text": "London", "is_correct": False}],
                "correct_answer": "Paris",
                "correct": 0,
                "reference_answer": "Paris is the capital of France.",
            }
        ]
    })
    sanitized_str = _sanitize_exam_description_for_student(raw_desc)
    assert sanitized_str is not None
    data = json.loads(sanitized_str)
    q0 = data["questions"][0]
    assert "correct_answer" not in q0
    assert "correct" not in q0
    assert "reference_answer" not in q0
    assert q0["options"] == ["Paris", "London"]


def test_fallback_rubric_evaluation_produces_valid_grading():
    """Verify that _fallback_rubric_evaluation scores against rubric benchmarks and never crashes."""
    from app.services.grading_pipeline import _fallback_rubric_evaluation

    criteria = [
        {"name": "Technical Accuracy & Methodology", "weight": 50.0, "max_score": 50.0},
        {"name": "Completeness & Problem Resolution", "weight": 30.0, "max_score": 30.0},
        {"name": "Clarity & Academic Quality", "weight": 20.0, "max_score": 20.0},
    ]

    eval_res = _fallback_rubric_evaluation(
        assignment_title="Operating Systems Midterm",
        assignment_prompt="Explain process scheduling algorithms and context switching.",
        max_marks=100.0,
        rubric_criteria=criteria,
        student_submission_content="Process scheduling algorithms include Round Robin, FCFS, and Priority Scheduling. Context switching saves the PCB state and restores another process.",
        submission_type="text",
        teacher_reference_answer="Round Robin uses time slicing. Context switching incurs CPU overhead when switching between processes and updating process control blocks.",
    )

    assert eval_res.total_score > 0
    assert eval_res.max_marks == 100.0
    assert eval_res.percentage > 50.0
    assert len(eval_res.criteria_evaluations) == 3
    assert eval_res.student_feedback
    assert eval_res.diagnostic_reasoning
    assert eval_res.needs_review is False

