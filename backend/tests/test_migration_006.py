"""Test suite for Alembic migration 20261017_006 (upgrade & downgrade).

Tests on a completely isolated temporary SQLite database.
"""

import pytest
import sqlalchemy as sa
from sqlalchemy import create_engine, text
from alembic.migration import MigrationContext
from alembic.operations import Operations

import importlib.util
from pathlib import Path

_mig_006_path = Path(__file__).parent.parent / "alembic" / "versions" / "20261017_006_exam_professor_audit_and_settings.py"
_spec_006 = importlib.util.spec_from_file_location("migration_006", str(_mig_006_path))
mig_006_mod = importlib.util.module_from_spec(_spec_006)
_spec_006.loader.exec_module(mig_006_mod)
upgrade_006 = mig_006_mod.upgrade
downgrade_006 = mig_006_mod.downgrade


def test_migration_006_upgrade_and_downgrade(tmp_path):
    """Verify that migration 20261017_006 upgrades and downgrades cleanly,
    sets default values for new columns on existing rows, and manages audit log table."""
    db_file = tmp_path / "test_migration_006.db"
    engine = create_engine(f"sqlite:///{db_file}")

    with engine.begin() as conn:
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
            CREATE TABLE exam_attempts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assignment_id INTEGER NOT NULL REFERENCES assignments(id),
                student_id INTEGER NOT NULL REFERENCES users(id),
                tab_switch_count INTEGER NOT NULL DEFAULT 0,
                is_flagged BOOLEAN NOT NULL DEFAULT 0,
                auto_submitted BOOLEAN NOT NULL DEFAULT 0
            );
        """))

        # Seed pre-existing rows
        conn.execute(text("INSERT INTO users (id, email) VALUES (1, 'prof@test.edu');"))
        conn.execute(text("INSERT INTO assignments (id, title) VALUES (1, 'Final Exam');"))
        conn.execute(text("""
            INSERT INTO exam_attempts (id, assignment_id, student_id, tab_switch_count, is_flagged, auto_submitted)
            VALUES (1, 1, 1, 0, 0, 0);
        """))

    # ── Test UPGRADE ──
    with engine.begin() as conn:
        ctx = MigrationContext.configure(conn)
        op = Operations(ctx)
        import alembic.op as alembic_op
        alembic_op._proxy = op
        upgrade_006()

    with engine.begin() as conn:
        # Check assignment new columns with defaults
        a_row = conn.execute(text("""
            SELECT id, strike_limit_flag, strike_limit_autosubmit, fullscreen_required, block_copy_paste, unsupported_browser_policy
            FROM assignments WHERE id = 1
        """)).fetchone()
        assert a_row is not None
        assert a_row[1] == 3
        assert a_row[2] == 5
        assert bool(a_row[3]) is True
        assert bool(a_row[4]) is True
        assert a_row[5] == "warn_allow"

        # Check exam_attempts new columns
        att_row = conn.execute(text("""
            SELECT id, attempt_number, reviewed_by_id, decision, decision_reason
            FROM exam_attempts WHERE id = 1
        """)).fetchone()
        assert att_row is not None
        assert att_row[1] == 1
        assert att_row[2] is None
        assert att_row[3] is None

        # Check exam_audit_logs table exists and accepts insertion
        conn.execute(text("""
            INSERT INTO exam_audit_logs (assignment_id, attempt_id, instructor_id, action, reason)
            VALUES (1, 1, 1, 'clear', 'Test audit log entry');
        """))
        log_count = conn.execute(text("SELECT COUNT(*) FROM exam_audit_logs WHERE assignment_id = 1")).scalar()
        assert log_count == 1

    # ── Test DOWNGRADE ──
    with engine.begin() as conn:
        ctx = MigrationContext.configure(conn)
        op = Operations(ctx)
        import alembic.op as alembic_op
        alembic_op._proxy = op
        downgrade_006()

    with engine.begin() as conn:
        # Verify exam_audit_logs dropped
        tables_res = conn.execute(text("SELECT name FROM sqlite_master WHERE type='table' AND name='exam_audit_logs';")).fetchall()
        assert len(tables_res) == 0

        # Verify new columns dropped from assignments
        a_cols = [row[1] for row in conn.execute(text("PRAGMA table_info(assignments);")).fetchall()]
        assert "strike_limit_flag" not in a_cols
        assert "unsupported_browser_policy" not in a_cols

        # Verify new columns dropped from exam_attempts
        att_cols = [row[1] for row in conn.execute(text("PRAGMA table_info(exam_attempts);")).fetchall()]
        assert "attempt_number" not in att_cols
        assert "decision" not in att_cols
