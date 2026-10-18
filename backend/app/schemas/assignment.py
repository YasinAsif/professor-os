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
    time_limit_minutes: Optional[int] = Field(default=None, ge=0)
    max_attempts: int = Field(default=1, ge=1)
    randomize_questions: bool = False
    show_results_after: bool = True
    clo_ids: List[int] = Field(default_factory=list)


class AssignmentUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    max_marks: Optional[float] = Field(None, gt=0)
    deadline: Optional[datetime] = None
    allow_late: Optional[bool] = None
    late_penalty_per_day: Optional[float] = Field(None, ge=0)
    max_penalty_cap: Optional[float] = Field(None, ge=0, le=100)
    time_limit_minutes: Optional[int] = Field(default=None, ge=0)
    max_attempts: Optional[int] = Field(default=None, ge=1)
    randomize_questions: Optional[bool] = None
    show_results_after: Optional[bool] = None
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
    time_limit_minutes: Optional[int] = None
    max_attempts: int = 1
    randomize_questions: bool = False
    show_results_after: bool = True
    clo_ids: List[int] = []
    has_rubric: bool = False
    is_proctored: bool = False
    strike_limit_flag: Optional[int] = 3
    strike_limit_autosubmit: Optional[int] = 5
    fullscreen_required: Optional[bool] = True
    block_copy_paste: Optional[bool] = True
    unsupported_browser_policy: Optional[str] = "warn_allow"
    submissions_count: Optional[int] = 0
    graded_count: Optional[int] = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class AssignmentListResponse(BaseModel):
    assignments: List[AssignmentResponse]
    total: int


class AssignmentTARequest(BaseModel):
    user_id: int


class AssignmentTAResponse(BaseModel):
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    batch_size: Optional[int] = None
