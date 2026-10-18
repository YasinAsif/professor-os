"""Reconcile legacy create_all schema with ORM constraints.

Revision ID: 20261014_004
Revises: 20261014_003
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20261014_004"
down_revision: Union[str, None] = "20261014_003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE assignments SET max_attempts = 1 WHERE max_attempts IS NULL;")
    op.execute("UPDATE assignments SET randomize_questions = false WHERE randomize_questions IS NULL;")
    op.execute("UPDATE assignments SET show_results_after = true WHERE show_results_after IS NULL;")
    op.execute("UPDATE users SET is_approved = true WHERE is_approved IS NULL;")

    op.alter_column("assignments", "max_attempts", existing_type=sa.Integer(), nullable=False)
    op.alter_column("assignments", "randomize_questions", existing_type=sa.Boolean(), nullable=False)
    op.alter_column("assignments", "show_results_after", existing_type=sa.Boolean(), nullable=False)
    op.alter_column("users", "is_approved", existing_type=sa.Boolean(), nullable=False)

    for table in ("clo_definitions", "question_bank", "question_generation_jobs", "quiz_configs"):
        op.execute(f"UPDATE {table} SET created_at = NOW() WHERE created_at IS NULL;")
        op.alter_column(
            table,
            "created_at",
            existing_type=sa.DateTime(timezone=True),
            nullable=False,
        )

    inspector = sa.inspect(op.get_bind())
    course_indexes = {index["name"] for index in inspector.get_indexes("courses")}
    if "ix_courses_join_code" not in course_indexes:
        op.create_index("ix_courses_join_code", "courses", ["join_code"], unique=True)

    foreign_keys = {fk["name"] for fk in inspector.get_foreign_keys("courses")}
    if "courses_professor_id_fkey" in foreign_keys:
        op.drop_constraint("courses_professor_id_fkey", "courses", type_="foreignkey")
    op.create_foreign_key(
        "courses_professor_id_fkey",
        "courses",
        "users",
        ["professor_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    unique_constraints = {
        constraint["name"] for constraint in inspector.get_unique_constraints("rubrics")
    }
    if "rubrics_assignment_id_key" in unique_constraints:
        op.drop_constraint("rubrics_assignment_id_key", "rubrics", type_="unique")
    if "ix_rubrics_assignment_id" not in {
        index["name"] for index in inspector.get_indexes("rubrics")
    }:
        op.create_index("ix_rubrics_assignment_id", "rubrics", ["assignment_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_rubrics_assignment_id", table_name="rubrics")
    op.create_unique_constraint("rubrics_assignment_id_key", "rubrics", ["assignment_id"])
    op.drop_constraint("courses_professor_id_fkey", "courses", type_="foreignkey")
    op.create_foreign_key("courses_professor_id_fkey", "courses", "users", ["professor_id"], ["id"])
    op.drop_index("ix_courses_join_code", table_name="courses")
