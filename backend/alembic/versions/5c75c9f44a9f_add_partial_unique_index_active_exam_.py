"""add_partial_unique_index_active_exam_attempt

Revision ID: 5c75c9f44a9f
Revises: 84f248bb35d2
Create Date: 2026-10-18 14:02:35.646186

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5c75c9f44a9f'
down_revision: Union[str, Sequence[str], None] = '84f248bb35d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: partial unique index guaranteeing only one active attempt per student assignment."""
    op.create_index(
        'uq_active_attempt_per_student_assignment',
        'exam_attempts',
        ['assignment_id', 'student_id'],
        unique=True,
        postgresql_where=sa.text('submitted_at IS NULL'),
        sqlite_where=sa.text('submitted_at IS NULL'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        'uq_active_attempt_per_student_assignment',
        table_name='exam_attempts',
    )
