"""ProfessorOS – ExamAttempt model (tracks anti-cheat data for timed exams)."""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ExamAttempt(Base):
    """Records a student's exam session for a timed assignment."""
    __tablename__ = "exam_attempts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    auto_submitted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, server_default="false")
    last_heartbeat_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    current_answers: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    tab_switch_count: Mapped[int] = mapped_column(Integer, default=0)
    is_flagged: Mapped[bool] = mapped_column(Boolean, default=False)
    flag_reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    attempt_number: Mapped[int] = mapped_column(Integer, default=1, server_default="1")

    # Instructor audit and decision
    reviewed_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    decision: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)  # accept, invalidate, allow_retake
    decision_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    retake_granted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, server_default="false")
    biometric_status: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)  # skipped, passed, bypassed

    # Relationships
    student = relationship("User", foreign_keys=[student_id], lazy="selectin")
    reviewer = relationship("User", foreign_keys=[reviewed_by_id], lazy="selectin")
    assignment = relationship("Assignment", back_populates="exam_attempts")
    violations = relationship("ExamViolation", back_populates="attempt", cascade="all, delete-orphan", lazy="selectin")

    def __repr__(self) -> str:
        return f"<ExamAttempt id={self.id} assignment={self.assignment_id} student={self.student_id} flagged={self.is_flagged}>"


class ExamViolation(Base):
    """Event log of individual anti-cheat telemetry violations for an exam attempt."""
    __tablename__ = "exam_violations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    attempt_id: Mapped[int] = mapped_column(
        ForeignKey("exam_attempts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    violation_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    details: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Relationship
    attempt = relationship("ExamAttempt", back_populates="violations")

    def __repr__(self) -> str:
        return f"<ExamViolation id={self.id} attempt_id={self.attempt_id} type={self.violation_type}>"


class ExamAuditLog(Base):
    """Immutable audit trail of professor/administrative actions taken on exam attempts or settings."""
    __tablename__ = "exam_audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    attempt_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("exam_attempts.id", ondelete="SET NULL"), nullable=True, index=True
    )
    instructor_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    action: Mapped[str] = mapped_column(String(64), nullable=False)  # clear_flags, invalidate, allow_retake, update_settings
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    instructor = relationship("User", foreign_keys=[instructor_id], lazy="selectin")
    attempt = relationship("ExamAttempt", foreign_keys=[attempt_id], lazy="selectin")

    def __repr__(self) -> str:
        return f"<ExamAuditLog id={self.id} action={self.action} instructor_id={self.instructor_id}>"
