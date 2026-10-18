"""Exam professor audit trail, settings lock, and decision metadata.

Revision ID: 20261017_006
Revises: 20261017_005
Create Date: 2026-10-17 19:00:00.000000
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "20261017_006"
down_revision: Union[str, None] = "20261017_005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add per-exam configurable settings to assignments
    with op.batch_alter_table("assignments", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("strike_limit_flag", sa.Integer(), nullable=False, server_default="3")
        )
        batch_op.add_column(
            sa.Column("strike_limit_autosubmit", sa.Integer(), nullable=False, server_default="5")
        )
        batch_op.add_column(
            sa.Column("fullscreen_required", sa.Boolean(), nullable=False, server_default=sa.true())
        )
        batch_op.add_column(
            sa.Column("block_copy_paste", sa.Boolean(), nullable=False, server_default=sa.true())
        )
        batch_op.add_column(
            sa.Column("unsupported_browser_policy", sa.String(length=32), nullable=False, server_default="warn_allow")
        )

    # 2. Add instructor decision & review metadata to exam_attempts
    with op.batch_alter_table("exam_attempts", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("attempt_number", sa.Integer(), nullable=False, server_default="1")
        )
        batch_op.add_column(
            sa.Column("reviewed_by_id", sa.Integer(), nullable=True)
        )
        batch_op.add_column(
            sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column("decision", sa.String(length=32), nullable=True)
        )
        batch_op.add_column(
            sa.Column("decision_reason", sa.Text(), nullable=True)
        )
        try:
            batch_op.create_foreign_key(
                "fk_exam_attempts_reviewed_by_user",
                "users",
                ["reviewed_by_id"],
                ["id"],
                ondelete="SET NULL",
            )
        except Exception:
            pass

    # 3. Create exam_audit_logs table for immutable audit history
    op.create_table(
        "exam_audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
        sa.Column("assignment_id", sa.Integer(), sa.ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("attempt_id", sa.Integer(), sa.ForeignKey("exam_attempts.id", ondelete="SET NULL"), nullable=True),
        sa.Column("instructor_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    with op.batch_alter_table("exam_audit_logs", schema=None) as batch_op:
        batch_op.create_index("ix_exam_audit_logs_assignment_id", ["assignment_id"], unique=False)
        batch_op.create_index("ix_exam_audit_logs_attempt_id", ["attempt_id"], unique=False)
        batch_op.create_index("ix_exam_audit_logs_instructor_id", ["instructor_id"], unique=False)


def downgrade() -> None:
    # 1. Drop exam_audit_logs
    op.drop_table("exam_audit_logs")

    # 2. Revert exam_attempts columns
    with op.batch_alter_table("exam_attempts", schema=None) as batch_op:
        try:
            batch_op.drop_constraint("fk_exam_attempts_reviewed_by_user", type_="foreignkey")
        except Exception:
            pass
        batch_op.drop_column("decision_reason")
        batch_op.drop_column("decision")
        batch_op.drop_column("reviewed_at")
        batch_op.drop_column("reviewed_by_id")
        batch_op.drop_column("attempt_number")

    # 3. Revert assignments columns
    with op.batch_alter_table("assignments", schema=None) as batch_op:
        batch_op.drop_column("unsupported_browser_policy")
        batch_op.drop_column("block_copy_paste")
        batch_op.drop_column("fullscreen_required")
        batch_op.drop_column("strike_limit_autosubmit")
        batch_op.drop_column("strike_limit_flag")
