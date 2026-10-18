"""Seed duplicate active attempts on scratch Postgres and verify 5c75c9f44a9f migration reconciliation."""

import asyncio
import os
import subprocess
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text, select

PG_URL = os.getenv("TEST_PG_URL", "postgresql+asyncpg://postgres:admin@127.0.0.1:5432/professor_os_scratch")


async def main():
    import sys
    print("=== Step 1: Downgrade from head to 84f248bb35d2 ===")
    env = os.environ.copy()
    env["DATABASE_URL"] = PG_URL
    p_down = subprocess.run([sys.executable, "-m", "alembic", "downgrade", "84f248bb35d2"], env=env, capture_output=True, text=True)
    print(p_down.stdout)
    if p_down.returncode != 0:
        print("Downgrade error:", p_down.stderr)

    print("=== Step 2: Seed duplicate active attempts for same student and assignment ===")
    engine = create_async_engine(PG_URL)
    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        # Get assignment and student
        aid = (await session.execute(text("SELECT id FROM assignments LIMIT 1"))).scalar_one()
        sid = (await session.execute(text("SELECT id FROM users WHERE role='student' LIMIT 1"))).scalar_one()

        # Delete any existing attempts for this pair
        await session.execute(
            text("DELETE FROM exam_attempts WHERE assignment_id=:aid AND student_id=:sid"),
            {"aid": aid, "sid": sid},
        )
        await session.commit()

        # Insert attempt 1 (older active attempt)
        r1 = await session.execute(
            text("""
                INSERT INTO exam_attempts (assignment_id, student_id, started_at, duration_minutes, tab_switch_count, is_flagged)
                VALUES (:aid, :sid, :t1, 60, 1, FALSE)
                RETURNING id
            """),
            {"aid": aid, "sid": sid, "t1": datetime(2026, 10, 18, 10, 0, tzinfo=timezone.utc)},
        )
        att1_id = r1.scalar_one()

        # Insert attempt 2 (newer active attempt)
        r2 = await session.execute(
            text("""
                INSERT INTO exam_attempts (assignment_id, student_id, started_at, duration_minutes, tab_switch_count, is_flagged)
                VALUES (:aid, :sid, :t2, 60, 0, FALSE)
                RETURNING id
            """),
            {"aid": aid, "sid": sid, "t2": datetime(2026, 10, 18, 10, 30, tzinfo=timezone.utc)},
        )
        att2_id = r2.scalar_one()
        await session.commit()
        print(f"Seeded duplicate active attempts: older id={att1_id}, newer id={att2_id}")

    await engine.dispose()

    print("=== Step 3: Run alembic upgrade head (5c75c9f44a9f) ===")
    p_up = subprocess.run([sys.executable, "-m", "alembic", "upgrade", "head"], env=env, capture_output=True, text=True)
    print(p_up.stdout)
    if p_up.returncode != 0:
        print("Upgrade error:", p_up.stderr)
        return

    print("=== Step 4: Verify duplicate reconciliation and unique index enforcement ===")
    engine = create_async_engine(PG_URL)
    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        r_att1 = (await session.execute(
            text("SELECT id, submitted_at, decision, decision_reason FROM exam_attempts WHERE id=:id"),
            {"id": att1_id},
        )).mappings().one()
        r_att2 = (await session.execute(
            text("SELECT id, submitted_at, decision, decision_reason FROM exam_attempts WHERE id=:id"),
            {"id": att2_id},
        )).mappings().one()

        print(f"Older attempt {att1_id}: submitted_at={r_att1['submitted_at']}, decision={r_att1['decision']}")
        print(f"Newer attempt {att2_id}: submitted_at={r_att2['submitted_at']}, decision={r_att2['decision']}")
        assert r_att1["submitted_at"] is not None, "Older duplicate attempt must be closed!"
        assert r_att1["decision"] == "invalidated", "Older duplicate attempt must be invalidated!"
        assert r_att2["submitted_at"] is None, "Newest duplicate attempt must remain active!"

        # Clean up test rows
        await session.execute(
            text("DELETE FROM exam_attempts WHERE id IN (:id1, :id2)"),
            {"id1": att1_id, "id2": att2_id},
        )
        await session.commit()
    await engine.dispose()
    print("Reconciliation successfully verified!")


if __name__ == "__main__":
    asyncio.run(main())
