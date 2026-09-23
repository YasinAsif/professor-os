"""Add quiz configurations, question bank, attempts, and OBE accreditation tables.

Revision ID: 20260922_001
Revises: None
Create Date: 2026-09-22 23:20:00.000000
"""

from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20260922_001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Create Enums if they do not exist ─────────────────────────────
    bloom_level_enum = postgresql.ENUM("C1", "C2", "C3", "C4", "C5", "C6", name="bloom_level_enum", create_type=False)
    question_type_enum = postgresql.ENUM("MCQ", "SHORT_ANSWER", "ESSAY", name="question_type_enum", create_type=False)
    question_status_enum = postgresql.ENUM("DRAFT", "APPROVED", "ARCHIVED", name="question_status_enum", create_type=False)
    job_status_enum = postgresql.ENUM("QUEUED", "PROCESSING", "DONE", "FAILED", name="job_status_enum", create_type=False)

    bloom_level_enum.create(op.get_bind(), checkfirst=True)
    question_type_enum.create(op.get_bind(), checkfirst=True)
    question_status_enum.create(op.get_bind(), checkfirst=True)
    job_status_enum.create(op.get_bind(), checkfirst=True)

    # ── 2. Table: clo_definitions (OBE Course Learning Outcomes) ────────
    op.create_table(
        "clo_definitions",
        sa.Column("clo_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("code", sa.String(length=20), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("bloom_target_level", bloom_level_enum, nullable=False, server_default="C3"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── 3. Table: quiz_configs (Assessment timing and anti-cheat params) ─
    op.create_table(
        "quiz_configs",
        sa.Column("quiz_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, unique=True, index=True),
        sa.Column("time_limit_minutes", sa.Integer(), nullable=True),
        sa.Column("randomize_order", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("max_attempts", sa.Integer(), server_default="1", nullable=False),
        sa.Column("show_answers_after", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("bloom_gate_passed", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── 4. Table: question_bank (Item repository with Bloom calibration) ─
    op.create_table(
        "question_bank",
        sa.Column("question_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("created_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("question_type", question_type_enum, nullable=False, server_default="MCQ"),
        sa.Column("options", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("correct_answer", sa.Text(), nullable=False),
        sa.Column("bloom_level", bloom_level_enum, nullable=False, server_default="C2"),
        sa.Column("clo_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("clo_definitions.clo_id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("difficulty", sa.Float(), server_default="0.5", nullable=False),
        sa.Column("source_material_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("status", question_status_enum, server_default="APPROVED", nullable=False),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── 5. Table: student_quiz_attempts (Telemetry & individual scoring) ──
    op.create_table(
        "student_quiz_attempts",
        sa.Column("attempt_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("quiz_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("quiz_configs.quiz_id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("answers", postgresql.JSONB(astext_type=sa.Text()), server_default="[]", nullable=False),
        sa.Column("auto_score", sa.Numeric(precision=6, scale=2), nullable=True),
        sa.Column("proctor_session_id", postgresql.UUID(as_uuid=True), nullable=True),
    )

    # ── 6. Table: attainment_records (Continuous OBE Quality Records) ───
    op.create_table(
        "attainment_records",
        sa.Column("record_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("clo_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("clo_definitions.clo_id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("quiz_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("quiz_configs.quiz_id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("semester", sa.String(length=50), nullable=False),
        sa.Column("attainment_pct", sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # ── 7. Table: question_generation_jobs (Asynchronous slide generator)
    op.create_table(
        "question_generation_jobs",
        sa.Column("job_id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("material_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("requested_bloom_levels", postgresql.JSONB(astext_type=sa.Text()), server_default="[]", nullable=False),
        sa.Column("status", job_status_enum, server_default="QUEUED", nullable=False),
        sa.Column("questions_generated", sa.Integer(), server_default="0", nullable=False),
        sa.Column("celery_task_id", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    # Drop tables in reverse topological order
    op.drop_table("question_generation_jobs")
    op.drop_table("attainment_records")
    op.drop_table("student_quiz_attempts")
    op.drop_table("question_bank")
    op.drop_table("quiz_configs")
    op.drop_table("clo_definitions")

    # Drop custom PostgreSQL enum types
    op.execute("DROP TYPE IF EXISTS job_status_enum;")
    op.execute("DROP TYPE IF EXISTS question_status_enum;")
    op.execute("DROP TYPE IF EXISTS question_type_enum;")
    op.execute("DROP TYPE IF EXISTS bloom_level_enum;")
