"""Persist grading metadata and enforce assignment integrity rules.

Revision ID: 20261014_003
Revises: 20261014_002
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20261014_003"
down_revision: Union[str, None] = "20261014_002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "evaluator_model" not in {c["name"] for c in inspector.get_columns("submissions")}:
        op.add_column("submissions", sa.Column("evaluator_model", sa.String(length=255), nullable=True))
    existing_constraints = {
        c["name"] for c in inspector.get_check_constraints("assignments")
    }
    if "ck_assignments_time_limit_nonnegative" not in existing_constraints:
        op.create_check_constraint(
            "ck_assignments_time_limit_nonnegative",
            "assignments",
            "time_limit_minutes IS NULL OR time_limit_minutes >= 0",
        )
    if "ck_assignments_max_attempts_positive" not in existing_constraints:
        op.create_check_constraint(
            "ck_assignments_max_attempts_positive",
            "assignments",
            "max_attempts >= 1",
        )


def downgrade() -> None:
    op.drop_constraint("ck_assignments_max_attempts_positive", "assignments", type_="check")
    op.drop_constraint("ck_assignments_time_limit_nonnegative", "assignments", type_="check")
    op.drop_column("submissions", "evaluator_model")
