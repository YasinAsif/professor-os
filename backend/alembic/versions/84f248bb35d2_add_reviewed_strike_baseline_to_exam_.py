"""add_reviewed_strike_baseline_to_exam_attempts

Revision ID: 84f248bb35d2
Revises: 20261018_007
Create Date: 2026-10-18 12:39:58.430579

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '84f248bb35d2'
down_revision: Union[str, Sequence[str], None] = '20261018_007'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "exam_attempts",
        sa.Column("reviewed_strike_baseline", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("exam_attempts", "reviewed_strike_baseline")
