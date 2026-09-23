"""ProfessorOS – Models package exporting all ORM entities."""

from app.models.user import User, UserRole
from app.models.course import Course, CLO, Enrollment
from app.models.assignment import Assignment, AssignmentType, AssignmentStatus
from app.models.rubric import Rubric, RubricCriterion, RubricLevel
from app.models.submission import Submission, SubmissionStatus
from app.models.analytics import AnalyticsSnapshot, AtRiskRecord
from app.models.exam_attempt import ExamAttempt
from app.models.quiz_obe import (
    CLODefinition,
    QuizConfig,
    QuestionBankItem,
    StudentQuizAttempt,
    AttainmentRecord,
    QuestionGenerationJob,
)

__all__ = [
    "User",
    "UserRole",
    "Course",
    "CLO",
    "Enrollment",
    "Assignment",
    "AssignmentType",
    "AssignmentStatus",
    "Rubric",
    "RubricCriterion",
    "RubricLevel",
    "Submission",
    "SubmissionStatus",
    "AnalyticsSnapshot",
    "AtRiskRecord",
    "ExamAttempt",
    "CLODefinition",
    "QuizConfig",
    "QuestionBankItem",
    "StudentQuizAttempt",
    "AttainmentRecord",
    "QuestionGenerationJob",
]
