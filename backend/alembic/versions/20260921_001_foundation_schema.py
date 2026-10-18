"""Create the foundation tables required by the application models.

Revision ID: 20260921_001
Revises: None
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260921_001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _enum(name: str, *values: str):
    enum_type = postgresql.ENUM(*values, name=name, create_type=False)
    enum_type.create(op.get_bind(), checkfirst=True)
    return enum_type


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if inspector.has_table("users"):
        return

    user_role = _enum("user_role", "professor", "student", "ta", "admin")
    assignment_type = _enum("assignment_type", "text", "file", "mcq", "programming")
    assignment_status = _enum("assignment_status", "draft", "published", "closed")
    submission_type = _enum("submission_type", "text", "file", "programming", "mcq")
    submission_status = _enum("submission_status", "pending", "graded")
    level_name = _enum("level_name", "excellent", "satisfactory", "developing", "insufficient")

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.Text(), nullable=False),
        sa.Column("role", user_role, nullable=False, server_default="student"),
        sa.Column("avatar_url", sa.String(512)),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("is_approved", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True)),
        sa.Column("token_valid_after", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "courses",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("code", sa.String(20), nullable=False),
        sa.Column("join_code", sa.String(10), unique=True),
        sa.Column("semester", sa.String(50), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("at_risk_threshold", sa.Float(), nullable=False, server_default="40"),
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("quiz_weight", sa.Integer(), nullable=False, server_default="20"),
        sa.Column("assignment_weight", sa.Integer(), nullable=False, server_default="20"),
        sa.Column("midterm_weight", sa.Integer(), nullable=False, server_default="20"),
        sa.Column("final_weight", sa.Integer(), nullable=False, server_default="40"),
        sa.Column("professor_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_courses_code", "courses", ["code"])
    op.create_index("ix_courses_join_code", "courses", ["join_code"])
    op.create_index("ix_courses_professor_id", "courses", ["professor_id"])

    op.create_table(
        "clos",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(20), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
    )
    op.create_index("ix_clos_course_id", "clos", ["course_id"])

    op.create_table(
        "enrollments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", sa.String(20), nullable=False, server_default="student"),
        sa.Column("enrolled_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_enrollments_course_id", "enrollments", ["course_id"])
    op.create_index("ix_enrollments_user_id", "enrollments", ["user_id"])

    op.create_table(
        "assignments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("type", assignment_type, nullable=False),
        sa.Column("status", assignment_status, nullable=False, server_default="draft"),
        sa.Column("max_marks", sa.Float(), nullable=False, server_default="100"),
        sa.Column("deadline", sa.DateTime(timezone=True)),
        sa.Column("allow_late", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("late_penalty_per_day", sa.Float(), nullable=False, server_default="0"),
        sa.Column("max_penalty_cap", sa.Float(), nullable=False, server_default="100"),
        sa.Column("time_limit_minutes", sa.Integer()),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("randomize_questions", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("show_results_after", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("time_limit_minutes IS NULL OR time_limit_minutes >= 0", name="ck_assignments_time_limit_nonnegative"),
        sa.CheckConstraint("max_attempts >= 1", name="ck_assignments_max_attempts_positive"),
    )
    op.create_index("ix_assignments_course_id", "assignments", ["course_id"])

    op.create_table(
        "assignment_clos",
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("clo_id", sa.Integer(), sa.ForeignKey("clos.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_table(
        "assignment_tas",
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("batch_size", sa.Integer()),
    )

    op.create_table(
        "rubrics",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, unique=True),
    )
    op.create_index("ix_rubrics_assignment_id", "rubrics", ["assignment_id"])
    op.create_table(
        "rubric_criteria",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("rubric_id", sa.Integer(), sa.ForeignKey("rubrics.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("weight", sa.Float(), nullable=False),
        sa.Column("order", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_rubric_criteria_rubric_id", "rubric_criteria", ["rubric_id"])
    op.create_table(
        "rubric_levels",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("criterion_id", sa.Integer(), sa.ForeignKey("rubric_criteria.id", ondelete="CASCADE"), nullable=False),
        sa.Column("level", level_name, nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
    )
    op.create_index("ix_rubric_levels_criterion_id", "rubric_levels", ["criterion_id"])

    op.create_table(
        "submissions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("submission_type", submission_type, nullable=False, server_default="text"),
        sa.Column("content", sa.Text()),
        sa.Column("file_path", sa.String(512)),
        sa.Column("file_name", sa.String(255)),
        sa.Column("status", submission_status, nullable=False, server_default="pending"),
        sa.Column("score", sa.Float()),
        sa.Column("feedback", sa.Text()),
        sa.Column("graded_by_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("submitted_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("graded_at", sa.DateTime(timezone=True)),
        sa.Column("evaluation_metadata", sa.Text()),
        sa.Column("evaluator_model", sa.String(255)),
    )
    op.create_index("ix_submissions_assignment_id", "submissions", ["assignment_id"])
    op.create_index("ix_submissions_student_id", "submissions", ["student_id"])

    op.create_table(
        "exam_attempts",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("submitted_at", sa.DateTime(timezone=True)),
        sa.Column("tab_switch_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_flagged", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("flag_reason", sa.String(255)),
    )
    op.create_index("ix_exam_attempts_assignment_id", "exam_attempts", ["assignment_id"])
    op.create_index("ix_exam_attempts_student_id", "exam_attempts", ["student_id"])

    op.create_table(
        "analytics_snapshots",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="SET NULL")),
        sa.Column("mean", sa.Float(), nullable=False, server_default="0"),
        sa.Column("median", sa.Float(), nullable=False, server_default="0"),
        sa.Column("std_dev", sa.Float(), nullable=False, server_default="0"),
        sa.Column("total_students", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("dist_buckets", sa.JSON()),
        sa.Column("criterion_scores", sa.JSON()),
        sa.Column("hec_grade", sa.String(1)),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_analytics_snapshots_course_id", "analytics_snapshots", ["course_id"])
    op.create_index("ix_analytics_snapshots_assignment_id", "analytics_snapshots", ["assignment_id"])

    op.create_table(
        "at_risk_records",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(100), nullable=False),
        sa.Column("average_score", sa.Float()),
        sa.Column("last_submission", sa.DateTime(timezone=True)),
        sa.Column("detected_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_at_risk_records_course_id", "at_risk_records", ["course_id"])
    op.create_index("ix_at_risk_records_student_id", "at_risk_records", ["student_id"])


def downgrade() -> None:
    op.drop_table("at_risk_records")
    op.drop_table("analytics_snapshots")
    op.drop_table("exam_attempts")
    op.drop_table("submissions")
    op.drop_table("rubric_levels")
    op.drop_table("rubric_criteria")
    op.drop_table("rubrics")
    op.drop_table("assignment_tas")
    op.drop_table("assignment_clos")
    op.drop_table("assignments")
    op.drop_table("enrollments")
    op.drop_table("clos")
    op.drop_table("courses")
    op.drop_table("users")

    for name in ("level_name", "submission_status", "submission_type", "assignment_status", "assignment_type", "user_role"):
        op.execute(sa.text(f"DROP TYPE IF EXISTS {name}"))

