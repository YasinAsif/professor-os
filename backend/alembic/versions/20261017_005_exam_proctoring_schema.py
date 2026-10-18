"""Exam proctoring & anti-cheat schema hardening.

Revision ID: 20261017_005
Revises: 20261014_004
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20261017_005"
down_revision: Union[str, None] = "20261014_004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # 1. Submissions auto_submitted column
    sub_cols = {c["name"] for c in inspector.get_columns("submissions")} if inspector.has_table("submissions") else set()
    if "auto_submitted" not in sub_cols:
        with op.batch_alter_table("submissions") as batch_op:
            batch_op.add_column(
                sa.Column("auto_submitted", sa.Boolean(), nullable=False, server_default=sa.false())
            )

    # 2. Exam attempts duration, auto_submitted, last_heartbeat_at, current_answers
    attempt_cols = {c["name"] for c in inspector.get_columns("exam_attempts")} if inspector.has_table("exam_attempts") else set()
    with op.batch_alter_table("exam_attempts") as batch_op:
        if "duration_minutes" not in attempt_cols:
            batch_op.add_column(sa.Column("duration_minutes", sa.Integer(), nullable=True))
        if "auto_submitted" not in attempt_cols:
            batch_op.add_column(
                sa.Column("auto_submitted", sa.Boolean(), nullable=False, server_default=sa.false())
            )
        if "last_heartbeat_at" not in attempt_cols:
            batch_op.add_column(
                sa.Column("last_heartbeat_at", sa.DateTime(timezone=True), nullable=True)
            )
        if "current_answers" not in attempt_cols:
            batch_op.add_column(sa.Column("current_answers", sa.Text(), nullable=True))

    # 3. Exam violations event timeline table
    if not inspector.has_table("exam_violations"):
        op.create_table(
            "exam_violations",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "attempt_id",
                sa.Integer(),
                sa.ForeignKey("exam_attempts.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("violation_type", sa.String(64), nullable=False),
            sa.Column(
                "occurred_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column("details", sa.String(255), nullable=True),
        )
        op.create_index("ix_exam_violations_attempt_id", "exam_violations", ["attempt_id"])
        op.create_index("ix_exam_violations_violation_type", "exam_violations", ["violation_type"])


def downgrade() -> None:
    op.drop_index("ix_exam_violations_violation_type", table_name="exam_violations")
    op.drop_index("ix_exam_violations_attempt_id", table_name="exam_violations")
    op.drop_table("exam_violations")

    with op.batch_alter_table("exam_attempts") as batch_op:
        batch_op.drop_column("current_answers")
        batch_op.drop_column("last_heartbeat_at")
        batch_op.drop_column("auto_submitted")
        batch_op.drop_column("duration_minutes")

    with op.batch_alter_table("submissions") as batch_op:
        batch_op.drop_column("auto_submitted")
