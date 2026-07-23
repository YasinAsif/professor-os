"""ProfessorOS – Course, CLO, and Enrollment schemas."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field


# ── CLO ───────────────────────────────────────────────

class CLOCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=20)
    description: str = Field(..., min_length=1)


class CLOResponse(BaseModel):
    id: int
    code: str
    description: str

    model_config = {"from_attributes": True}


# ── Enrollment ────────────────────────────────────────

class EnrollRequest(BaseModel):
    user_id: int
    role: str = Field(default="student", pattern="^(student|ta)$")


class EnrollmentResponse(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    role: str
    enrolled_at: datetime

    model_config = {"from_attributes": True}


# ── Course ────────────────────────────────────────────

class CourseCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    code: str = Field(..., min_length=1, max_length=20)
    semester: str = Field(..., min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=1000)
    at_risk_threshold: float = Field(default=40.0, ge=0, le=100)
    quiz_weight: int = Field(default=20, ge=0, le=100)
    assignment_weight: int = Field(default=20, ge=0, le=100)
    midterm_weight: int = Field(default=20, ge=0, le=100)
    final_weight: int = Field(default=40, ge=0, le=100)


class CourseUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    code: Optional[str] = Field(None, min_length=1, max_length=20)
    semester: Optional[str] = Field(None, min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=1000)
    at_risk_threshold: Optional[float] = Field(None, ge=0, le=100)
    quiz_weight: Optional[int] = Field(None, ge=0, le=100)
    assignment_weight: Optional[int] = Field(None, ge=0, le=100)
    midterm_weight: Optional[int] = Field(None, ge=0, le=100)
    final_weight: Optional[int] = Field(None, ge=0, le=100)


class CourseResponse(BaseModel):
    id: int
    title: str
    code: str
    join_code: Optional[str] = None
    semester: str
    description: Optional[str] = None
    at_risk_threshold: float
    is_archived: bool
    quiz_weight: int
    assignment_weight: int
    midterm_weight: int
    final_weight: int
    professor_id: int
    professor_name: Optional[str] = None
    enrollment_count: Optional[int] = 0
    assignment_count: Optional[int] = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseJoinRequest(BaseModel):
    join_code: str = Field(..., min_length=6, max_length=10)


class CourseListResponse(BaseModel):
    courses: List[CourseResponse]
    total: int
