"""Add submission.attempt_id FK, exam_attempts.retake_granted, and biometric_status.

Revision ID: 20261018_007
Revises: 20261017_006
Create Date: 2026-10-18 12:00:00.000000
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "20261018_007"
down_revision: Union[str, None] = "20261017_006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add retake_granted and biometric_status to exam_attempts
    with op.batch_alter_table("exam_attempts", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("retake_granted", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch_op.add_column(
            sa.Column("biometric_status", sa.String(length=32), nullable=True)
        )

    # 2. Add attempt_id FK to submissions
    with op.batch_alter_table("submissions", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "attempt_id",
                sa.Integer(),
                sa.ForeignKey("exam_attempts.id", ondelete="SET NULL"),
                nullable=True,
            )
        )
        batch_op.create_index("ix_submissions_attempt_id", ["attempt_id"], unique=False)

    # 3. Backfill existing exam submissions to link to the latest attempt
    op.execute(
        """
        UPDATE submissions
        SET attempt_id = (
            SELECT ea.id
            FROM exam_attempts ea
            WHERE ea.assignment_id = submissions.assignment_id
              AND ea.student_id = submissions.student_id
            ORDER BY ea.started_at DESC
            LIMIT 1
        )
        WHERE attempt_id IS NULL
          AND EXISTS (
              SELECT 1 FROM exam_attempts ea
              WHERE ea.assignment_id = submissions.assignment_id
                AND ea.student_id = submissions.student_id
          )
        """
    )


def downgrade() -> None:
    with op.batch_alter_table("submissions", schema=None) as batch_op:
        batch_op.drop_index("ix_submissions_attempt_id")
        batch_op.drop_column("attempt_id")

    with op.batch_alter_table("exam_attempts", schema=None) as batch_op:
        batch_op.drop_column("biometric_status")
        batch_op.drop_column("retake_granted")
