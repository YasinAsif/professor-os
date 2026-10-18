"""Test suite for Alembic migration 20261017_005 (upgrade & downgrade)."""

import pytest
import sqlalchemy as sa
from sqlalchemy import create_engine, text
from alembic.migration import MigrationContext
from alembic.operations import Operations

import importlib.util
from pathlib import Path

_mig_path = Path(__file__).parent.parent / "alembic" / "versions" / "20261017_005_exam_proctoring_schema.py"
_spec = importlib.util.spec_from_file_location("migration_005", str(_mig_path))
migration_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(migration_mod)
upgrade = migration_mod.upgrade
downgrade = migration_mod.downgrade


def test_migration_005_upgrade_and_downgrade(tmp_path):
    """Verify that migration 20261017_005 upgrades and downgrades cleanly,
    and sets auto_submitted = False for existing rows."""
    db_file = tmp_path / "test_migration.db"
    engine = create_engine(f"sqlite:///{db_file}")

    with engine.begin() as conn:
        # Create base schema matching pre-005 state
        conn.execute(text("""
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email VARCHAR(255) NOT NULL
            );
        """))
        conn.execute(text("""
            CREATE TABLE assignments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title VARCHAR(255) NOT NULL
            );
        """))
        conn.execute(text("""
            CREATE TABLE submissions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assignment_id INTEGER NOT NULL REFERENCES assignments(id),
                student_id INTEGER NOT NULL REFERENCES users(id),
                submission_type VARCHAR(50) NOT NULL DEFAULT 'text',
                content TEXT
            );
        """))
        conn.execute(text("""
            CREATE TABLE exam_attempts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assignment_id INTEGER NOT NULL REFERENCES assignments(id),
                student_id INTEGER NOT NULL REFERENCES users(id),
                tab_switch_count INTEGER NOT NULL DEFAULT 0,
                is_flagged BOOLEAN NOT NULL DEFAULT 0
            );
        """))

        # Insert pre-existing rows
        conn.execute(text("INSERT INTO users (id, email) VALUES (1, 'student@test.edu');"))
        conn.execute(text("INSERT INTO assignments (id, title) VALUES (1, 'Midterm Exam');"))
        conn.execute(text("""
            INSERT INTO submissions (id, assignment_id, student_id, submission_type, content)
            VALUES (1, 1, 1, 'text', 'My initial answer');
        """))
        conn.execute(text("""
            INSERT INTO exam_attempts (id, assignment_id, student_id, tab_switch_count, is_flagged)
            VALUES (1, 1, 1, 0, 0);
        """))

    # ── Test UPGRADE ──
    with engine.begin() as conn:
        ctx = MigrationContext.configure(conn)
        op = Operations(ctx)
        # Monkeypatch alembic op context
        import alembic.op as alembic_op
        alembic_op._proxy = op
        upgrade()

    with engine.begin() as conn:
        # Check that auto_submitted was populated with False (0 in sqlite) on existing row
        sub_row = conn.execute(text("SELECT id, auto_submitted FROM submissions WHERE id = 1")).fetchone()
        assert sub_row is not None
        assert bool(sub_row[1]) is False

        attempt_row = conn.execute(text("SELECT id, auto_submitted, duration_minutes, current_answers FROM exam_attempts WHERE id = 1")).fetchone()
        assert attempt_row is not None
        assert bool(attempt_row[1]) is False
        assert attempt_row[2] is None
        assert attempt_row[3] is None

        # Insert an exam violation to prove the table exists and accepts records
        conn.execute(text("""
            INSERT INTO exam_violations (attempt_id, violation_type, details)
            VALUES (1, 'tab_switch', 'Focus lost');
        """))
        v_count = conn.execute(text("SELECT COUNT(*) FROM exam_violations WHERE attempt_id = 1")).scalar()
        assert v_count == 1

    # ── Test DOWNGRADE ──
    with engine.begin() as conn:
        ctx = MigrationContext.configure(conn)
        op = Operations(ctx)
        import alembic.op as alembic_op
        alembic_op._proxy = op
        downgrade()

    with engine.begin() as conn:
        # Confirm exam_violations table was dropped
        inspector = sa.inspect(conn)
        tables = inspector.get_table_names()
        assert "exam_violations" not in tables

        # Confirm columns were dropped from submissions
        sub_cols = [c["name"] for c in inspector.get_columns("submissions")]
        assert "auto_submitted" not in sub_cols

        # Confirm columns were dropped from exam_attempts
        attempt_cols = [c["name"] for c in inspector.get_columns("exam_attempts")]
        assert "auto_submitted" not in attempt_cols
        assert "duration_minutes" not in attempt_cols
        assert "last_heartbeat_at" not in attempt_cols
        assert "current_answers" not in attempt_cols
