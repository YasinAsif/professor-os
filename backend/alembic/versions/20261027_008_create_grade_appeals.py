"""create_grade_appeals_table

Revision ID: 20261027_008
Revises: 5c75c9f44a9f
Create Date: 2026-10-27 17:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20261027_008'
down_revision: Union[str, Sequence[str], None] = '5c75c9f44a9f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if "grade_appeals" not in tables:
        op.create_table(
            "grade_appeals",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("submission_id", sa.Integer(), nullable=False),
            sa.Column("student_id", sa.Integer(), nullable=False),
            sa.Column("assignment_id", sa.Integer(), nullable=False),
            sa.Column("challenged_criterion", sa.String(length=255), nullable=True),
            sa.Column("justification", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=50), nullable=False, server_default="pending"),
            sa.Column("adjusted_score", sa.Float(), nullable=True),
            sa.Column("professor_feedback", sa.Text(), nullable=True),
            sa.Column("reviewed_by_id", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["assignment_id"], ["assignments.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["student_id"], ["users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["submission_id"], ["submissions.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["reviewed_by_id"], ["users.id"], ondelete="SET NULL"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_grade_appeals_submission_id"), "grade_appeals", ["submission_id"], unique=False)
        op.create_index(op.f("ix_grade_appeals_student_id"), "grade_appeals", ["student_id"], unique=False)
        op.create_index(op.f("ix_grade_appeals_assignment_id"), "grade_appeals", ["assignment_id"], unique=False)
        op.create_index(op.f("ix_grade_appeals_status"), "grade_appeals", ["status"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()
    if "grade_appeals" in tables:
        op.drop_table("grade_appeals")
