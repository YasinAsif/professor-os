"""Add quiz-question associations required by the ORM.

Revision ID: 20261014_002
Revises: 20260922_001
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20261014_002"
down_revision: Union[str, None] = "20260922_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    if sa.inspect(bind).has_table("quiz_questions"):
        return
    op.create_table(
        "quiz_questions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "quiz_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("quiz_configs.quiz_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "question_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("question_bank.question_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("points", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("order_index", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_quiz_questions_quiz_id", "quiz_questions", ["quiz_id"])
    op.create_index("ix_quiz_questions_question_id", "quiz_questions", ["question_id"])


def downgrade() -> None:
    op.drop_index("ix_quiz_questions_question_id", table_name="quiz_questions")
    op.drop_index("ix_quiz_questions_quiz_id", table_name="quiz_questions")
    op.drop_table("quiz_questions")
