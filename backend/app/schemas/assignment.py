"""ProfessorOS – Assignment schemas."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class AssignmentCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    type: str = Field(..., pattern="^(text|file|mcq|programming)$")
    max_marks: float = Field(default=100.0, gt=0)
    deadline: Optional[datetime] = None
    allow_late: bool = False
    late_penalty_per_day: float = Field(default=0.0, ge=0)
    max_penalty_cap: float = Field(default=100.0, ge=0, le=100)
    clo_ids: List[int] = Field(default_factory=list)


class AssignmentUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    max_marks: Optional[float] = Field(None, gt=0)
    deadline: Optional[datetime] = None
    allow_late: Optional[bool] = None
    late_penalty_per_day: Optional[float] = Field(None, ge=0)
    max_penalty_cap: Optional[float] = Field(None, ge=0, le=100)
    clo_ids: Optional[List[int]] = None


class AssignmentResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    type: str
    status: str
    max_marks: float
    deadline: Optional[datetime] = None
    allow_late: bool
    late_penalty_per_day: float
    max_penalty_cap: float
    clo_ids: List[int] = []
    has_rubric: bool = False
    submissions_count: Optional[int] = 0
    graded_count: Optional[int] = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class AssignmentListResponse(BaseModel):
    assignments: List[AssignmentResponse]
    total: int
