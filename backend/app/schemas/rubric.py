"""ProfessorOS – Rubric schemas."""

from typing import List, Optional

from pydantic import BaseModel, Field


class RubricLevelCreate(BaseModel):
    level: str = Field(..., pattern="^(excellent|satisfactory|developing|insufficient)$")
    description: str = ""


class RubricCriterionCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    weight: float = Field(..., ge=0, le=100)
    order: int = 0
    levels: List[RubricLevelCreate] = Field(default_factory=list)


class RubricCreate(BaseModel):
    criteria: List[RubricCriterionCreate] = Field(..., min_length=3, max_length=10)


class RubricLevelResponse(BaseModel):
    id: int
    level: str
    description: str

    model_config = {"from_attributes": True}


class RubricCriterionResponse(BaseModel):
    id: int
    name: str
    weight: float
    order: int
    levels: List[RubricLevelResponse] = []

    model_config = {"from_attributes": True}


class RubricResponse(BaseModel):
    id: int
    assignment_id: int
    criteria: List[RubricCriterionResponse] = []
    total_weight: float = 0.0

    model_config = {"from_attributes": True}
