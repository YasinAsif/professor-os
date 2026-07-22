"""ProfessorOS – Analytics schemas."""

from datetime import datetime
from typing import Optional, List, Dict

from pydantic import BaseModel


class DistributionBucket(BaseModel):
    label: str  # "0-20", "21-40", etc.
    count: int


class AtRiskStudentResponse(BaseModel):
    student_id: int
    student_name: str
    student_email: str
    average_score: Optional[float] = None
    last_submission: Optional[datetime] = None
    reason: str
    detected_at: datetime

    model_config = {"from_attributes": True}


class CohortTrendPoint(BaseModel):
    assignment_id: Optional[int] = None
    assignment_title: str
    average_score: float
    date: Optional[datetime] = None


class AnalyticsDashboardResponse(BaseModel):
    course_id: int
    total_students: int
    mean: float
    median: float
    std_dev: float
    distribution: List[DistributionBucket]
    criterion_scores: Dict[str, float]  # For radar chart
    hec_grade: Optional[str] = None  # W, X, Y, Z
    hec_grade_label: Optional[str] = None  # "World Class", "Acceptable", etc.
    overall_score: float
    cohort_trend: List[CohortTrendPoint]
    at_risk_students: List[AtRiskStudentResponse]
    quiz_weight: int
    assignment_weight: int
    midterm_weight: int
    final_weight: int
    computed_at: Optional[datetime] = None
