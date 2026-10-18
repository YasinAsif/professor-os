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
    # Reconcile any pre-existing duplicate active attempts: keep the latest attempt active, close earlier duplicates
    op.execute(
        """
        UPDATE exam_attempts
        SET submitted_at = COALESCE(last_heartbeat_at, started_at),
            auto_submitted = TRUE,
            decision = 'invalidated',
            decision_reason = 'Auto-closed prior duplicate active attempt during migration'
        WHERE submitted_at IS NULL
          AND id NOT IN (
              SELECT MAX(id)
              FROM exam_attempts
              WHERE submitted_at IS NULL
              GROUP BY assignment_id, student_id
          )
        """
    )

    bind = op.get_bind()
    inspector = sa.inspect(bind)
    indexes = {idx["name"] for idx in inspector.get_indexes("exam_attempts")} if inspector.has_table("exam_attempts") else set()
    if 'uq_active_attempt_per_student_assignment' not in indexes:
        op.create_index(
            'uq_active_attempt_per_student_assignment',
            'exam_attempts',
            ['assignment_id', 'student_id'],
            unique=True,
            postgresql_where=sa.text('submitted_at IS NULL'),
            sqlite_where=sa.text('submitted_at IS NULL'),
        )

    # Immutable audit table for user administration (e.g. staff CSV imports)
    if not inspector.has_table('user_audit_logs'):
        op.create_table(
            'user_audit_logs',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('admin_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
            sa.Column('action', sa.String(length=64), nullable=False),
            sa.Column('role', sa.String(length=32), nullable=False),
            sa.Column('email', sa.String(length=255), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        )
        with op.batch_alter_table('user_audit_logs', schema=None) as batch_op:
            batch_op.create_index('ix_user_audit_logs_admin_id', ['admin_id'], unique=False)
            batch_op.create_index('ix_user_audit_logs_user_id', ['user_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP TABLE IF EXISTS user_audit_logs")
    op.drop_index(
        'uq_active_attempt_per_student_assignment',
        table_name='exam_attempts',
    )

