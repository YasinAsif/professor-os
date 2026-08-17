"""ProfessorOS – User request/response schemas."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, EmailStr, Field


class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    role: str
    avatar_url: Optional[str] = None
    is_active: bool
    is_verified: bool
    is_approved: bool = True
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=255)


class RoleUpdateRequest(BaseModel):
    role: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8, max_length=128)


class UserStatusUpdate(BaseModel):
    is_active: bool


class CSVImportResult(BaseModel):
    created: int
    skipped: int
    errors: List[dict]  # [{"row": 3, "email": "x@y.z", "reason": "Duplicate email"}]


class UserListResponse(BaseModel):
    users: List[UserResponse]
    total: int
    page: int
    page_size: int


class AdminCreateUserRequest(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=255)
    role: str = Field("student", pattern="^(student|professor|ta|admin)$")
    password: str = Field(..., min_length=8, max_length=128)


class AdminResetPasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=8, max_length=128)


class UserStatsResponse(BaseModel):
    total_users: int
    active_users: int
    inactive_users: int
    pending_approvals: int = 0
    role_counts: dict  # {"professor": 5, "student": 50, "ta": 3, "admin": 2}


class ApprovalActionRequest(BaseModel):
    reason: str | None = None

