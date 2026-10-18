"""Multi-threaded OS-level concurrency test for atomic violation updates.

Uses real OS threads via concurrent.futures.ThreadPoolExecutor against
a physical file-based SQLite database with WAL mode to verify atomic
SQL counter increments under real OS-thread contention.
"""

import sqlite3
import tempfile
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed


def test_real_os_threads_atomic_counter_increment():
    """Verify that multiple real OS threads incrementing tab_switch_count
    via atomic SQL `UPDATE exam_attempts SET tab_switch_count = tab_switch_count + 1`
    results in an exact, non-lost final count with zero race-condition undercounts."""
    with tempfile.TemporaryDirectory() as temp_dir:
        db_path = Path(temp_dir) / "test_concurrency.db"

        # Initialize schema
        init_conn = sqlite3.connect(str(db_path))
        init_conn.execute("PRAGMA journal_mode = WAL")
        init_conn.execute("PRAGMA busy_timeout = 10000")
        init_conn.execute(
            """
            CREATE TABLE exam_attempts (
                id INTEGER PRIMARY KEY,
                assignment_id INTEGER,
                student_id INTEGER,
                tab_switch_count INTEGER DEFAULT 0,
                is_flagged BOOLEAN DEFAULT 0,
                flag_reason TEXT
            )
            """
        )
        init_conn.execute(
            """
            CREATE TABLE exam_violations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                attempt_id INTEGER,
                violation_type TEXT,
                occurred_at TEXT,
                details TEXT
            )
            """
        )
        init_conn.execute(
            "INSERT INTO exam_attempts (id, assignment_id, student_id, tab_switch_count) VALUES (1, 10, 100, 0)"
        )
        init_conn.commit()
        init_conn.close()

        num_threads = 8
        increments_per_thread = 10
        expected_total = num_threads * increments_per_thread

        def worker_task(thread_id: int):
            # Each OS thread opens its own connection to the real database file
            conn = sqlite3.connect(str(db_path), timeout=30.0)
            conn.execute("PRAGMA busy_timeout = 15000")
            for i in range(increments_per_thread):
                # Atomic SQL increment
                conn.execute(
                    "UPDATE exam_attempts SET tab_switch_count = tab_switch_count + 1 WHERE id = 1"
                )
                conn.execute(
                    "INSERT INTO exam_violations (attempt_id, violation_type, occurred_at, details) VALUES (?, ?, datetime('now'), ?)",
                    (1, "tab_switch", f"Thread {thread_id} step {i}"),
                )
                conn.commit()
                # Micro-sleep to interleave thread execution
                time.sleep(0.002)
            conn.close()
            return True

        # Run concurrent OS threads
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures = [executor.submit(worker_task, tid) for tid in range(num_threads)]
            for fut in as_completed(futures):
                assert fut.result() is True

        # Verify final count in database
        verify_conn = sqlite3.connect(str(db_path))
        cur = verify_conn.cursor()
        cur.execute("SELECT tab_switch_count FROM exam_attempts WHERE id = 1")
        final_count = cur.fetchone()[0]

        cur.execute("SELECT count(*) FROM exam_violations WHERE attempt_id = 1")
        total_violations = cur.fetchone()[0]
        verify_conn.close()

        assert final_count == expected_total, (
            f"Atomic increment failed under real OS-thread contention! Expected {expected_total}, got {final_count}"
        )
        assert total_violations == expected_total, (
            f"Expected {expected_total} violation rows, got {total_violations}"
        )


def test_real_os_threads_worker_safety_auto_close():
    """Verify that if two or more background workers/threads attempt to close the same attempt,
    exactly one worker succeeds (atomic compare-and-swap SQL) and no double-close occurs."""
    with tempfile.TemporaryDirectory() as temp_dir:
        db_path = Path(temp_dir) / "test_worker_safety.db"

        init_conn = sqlite3.connect(str(db_path))
        init_conn.execute("PRAGMA journal_mode = WAL")
        init_conn.execute("PRAGMA busy_timeout = 10000")
        init_conn.execute(
            """
            CREATE TABLE exam_attempts (
                id INTEGER PRIMARY KEY,
                submitted_at TEXT,
                auto_submitted BOOLEAN DEFAULT 0
            )
            """
        )
        init_conn.execute("INSERT INTO exam_attempts (id, submitted_at, auto_submitted) VALUES (1, NULL, 0)")
        init_conn.commit()
        init_conn.close()

        num_workers = 6

        def close_attempt_worker(worker_id: int):
            conn = sqlite3.connect(str(db_path), timeout=30.0)
            conn.execute("PRAGMA busy_timeout = 15000")
            # Atomic compare-and-swap: only updates if submitted_at IS NULL
            cur = conn.cursor()
            cur.execute(
                """
                UPDATE exam_attempts
                SET submitted_at = datetime('now'), auto_submitted = 1
                WHERE id = 1 AND submitted_at IS NULL
                """
            )
            rows_updated = cur.rowcount
            conn.commit()
            conn.close()
            return rows_updated

        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            futures = [executor.submit(close_attempt_worker, wid) for wid in range(num_workers)]
            results = [fut.result() for fut in as_completed(futures)]

        # Exactly ONE worker must have rowcount == 1; all other workers get rowcount == 0
        assert sum(results) == 1, f"Expected exactly 1 worker to close the attempt, but results were: {results}"
        assert results.count(1) == 1
        assert results.count(0) == num_workers - 1
