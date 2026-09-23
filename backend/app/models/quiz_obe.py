"""ProfessorOS – SQLAlchemy models for Question Bank, Quiz Configurations, and OBE Attainment."""

import enum
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy import (
    Boolean, DateTime, Enum, Float, ForeignKey, Integer, Numeric, String, Text
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class BloomLevelEnum(str, enum.Enum):
    C1 = "C1"
    C2 = "C2"
    C3 = "C3"
    C4 = "C4"
    C5 = "C5"
    C6 = "C6"


class QuestionTypeEnum(str, enum.Enum):
    MCQ = "MCQ"
    SHORT_ANSWER = "SHORT_ANSWER"
    ESSAY = "ESSAY"


class QuestionStatusEnum(str, enum.Enum):
    DRAFT = "DRAFT"
    APPROVED = "APPROVED"
    ARCHIVED = "ARCHIVED"


class JobStatusEnum(str, enum.Enum):
    QUEUED = "QUEUED"
    PROCESSING = "PROCESSING"
    DONE = "DONE"
    FAILED = "FAILED"


class CLODefinition(Base):
    """Course Learning Outcome definition with Bloom's target taxonomy level."""
    __tablename__ = "clo_definitions"

    clo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    code: Mapped[str] = mapped_column(String(20), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    bloom_target_level: Mapped[str] = mapped_column(
        Enum(BloomLevelEnum, name="bloom_level_enum", values_callable=lambda e: [m.value for m in e], native_enum=True),
        default=BloomLevelEnum.C3.value,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    course = relationship("Course", lazy="selectin")
    questions = relationship("QuestionBankItem", back_populates="clo", lazy="selectin")
    attainment_records = relationship("AttainmentRecord", back_populates="clo", lazy="selectin")


class QuizConfig(Base):
    """Configuration and HEC Bloom's gate tracking for an assessment."""
    __tablename__ = "quiz_configs"

    quiz_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, unique=True, index=True
    )
    time_limit_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    randomize_order: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    max_attempts: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    show_answers_after: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    bloom_gate_passed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    assignment = relationship("Assignment", lazy="selectin")
    attempts = relationship("StudentQuizAttempt", back_populates="quiz", lazy="selectin", cascade="all, delete-orphan")
    quiz_questions = relationship("QuizQuestion", back_populates="quiz", lazy="selectin", cascade="all, delete-orphan")


class QuizQuestion(Base):
    """Associates questions from the question bank with specific quizzes with points and ordering."""
    __tablename__ = "quiz_questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    quiz_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("quiz_configs.quiz_id", ondelete="CASCADE"), nullable=False, index=True
    )
    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("question_bank.question_id", ondelete="CASCADE"), nullable=False, index=True
    )
    points: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Relationships
    quiz = relationship("QuizConfig", back_populates="quiz_questions", lazy="selectin")
    question = relationship("QuestionBankItem", lazy="selectin")


class QuestionBankItem(Base):
    """Item repository for questions with Bloom calibration and distractor rationales."""
    __tablename__ = "question_bank"

    question_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    question_type: Mapped[str] = mapped_column(
        Enum(QuestionTypeEnum, name="question_type_enum", values_callable=lambda e: [m.value for m in e], native_enum=True),
        default=QuestionTypeEnum.MCQ.value,
        nullable=False,
    )
    options: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)
    correct_answer: Mapped[str] = mapped_column(Text, nullable=False)
    bloom_level: Mapped[str] = mapped_column(
        Enum(BloomLevelEnum, name="bloom_level_enum", values_callable=lambda e: [m.value for m in e], native_enum=True),
        default=BloomLevelEnum.C2.value,
        nullable=False,
    )
    clo_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("clo_definitions.clo_id", ondelete="SET NULL"), nullable=True, index=True
    )
    difficulty: Mapped[float] = mapped_column(Float, default=0.5, nullable=False)
    source_material_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    status: Mapped[str] = mapped_column(
        Enum(QuestionStatusEnum, name="question_status_enum", values_callable=lambda e: [m.value for m in e], native_enum=True),
        default=QuestionStatusEnum.APPROVED.value,
        nullable=False,
    )
    metadata_json: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    clo = relationship("CLODefinition", back_populates="questions", lazy="selectin")


class StudentQuizAttempt(Base):
    """Student test attempt with telemetry and scoring."""
    __tablename__ = "student_quiz_attempts"

    attempt_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    quiz_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("quiz_configs.quiz_id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    answers: Mapped[Any] = mapped_column(JSONB, default=list, nullable=False)
    auto_score: Mapped[Optional[Decimal]] = mapped_column(Numeric(6, 2), nullable=True)
    proctor_session_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)

    # Relationships
    quiz = relationship("QuizConfig", back_populates="attempts", lazy="selectin")
    student = relationship("User", lazy="selectin")


class AttainmentRecord(Base):
    """Accreditation outcome attainment metrics per semester."""
    __tablename__ = "attainment_records"

    record_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    clo_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("clo_definitions.clo_id", ondelete="CASCADE"), nullable=False, index=True
    )
    quiz_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("quiz_configs.quiz_id", ondelete="SET NULL"), nullable=True, index=True
    )
    semester: Mapped[str] = mapped_column(String(50), nullable=False)
    attainment_pct: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    # Relationships
    clo = relationship("CLODefinition", back_populates="attainment_records", lazy="selectin")


class QuestionGenerationJob(Base):
    """Job tracking table for asynchronous lecture slide to question generation."""
    __tablename__ = "question_generation_jobs"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    material_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    requested_bloom_levels: Mapped[Any] = mapped_column(JSONB, default=list, nullable=False)
    status: Mapped[str] = mapped_column(
        Enum(JobStatusEnum, name="job_status_enum", values_callable=lambda e: [m.value for m in e], native_enum=True),
        default=JobStatusEnum.QUEUED.value,
        nullable=False,
    )
    questions_generated: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    celery_task_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
