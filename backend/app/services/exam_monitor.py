"""ProfessorOS – Background exam attempt monitoring service.

Auto-closes attempts that exceeded their deadline and flags attempts with missed heartbeats.
"""

import asyncio
from datetime import datetime, timezone
import logging
from typing import Dict

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.base import async_session
from app.models.exam_attempt import ExamAttempt, ExamViolation
from app.api.v1.exams import (
    auto_close_attempt,
    is_attempt_expired,
    DEFAULT_GRACE_SECONDS,
    HEARTBEAT_TIMEOUT_SECONDS,
)

logger = logging.getLogger("professor_os.exam_monitor")


async def monitor_active_exam_attempts(
    db: AsyncSession, now: Optional[datetime] = None
) -> Dict[str, int]:
    """Scan all active exam attempts and enforce server-side auto-close and offline flagging."""
    now = now or datetime.now(timezone.utc)
    res = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.assignment))
        .where(ExamAttempt.submitted_at.is_(None))
        .with_for_update()
    )
    active_attempts = list(res.scalars().all())

    closed_count = 0
    flagged_offline_count = 0

    for attempt in active_attempts:
        assignment = attempt.assignment
        if not assignment:
            continue

        # 1. Server-side auto-close past deadline + grace period
        if is_attempt_expired(attempt, assignment, now=now, grace_seconds=DEFAULT_GRACE_SECONDS):
            await auto_close_attempt(attempt, assignment, db, reason="time_expired_background_job")
            closed_count += 1
            continue

        # 2. Heartbeat monitoring (30s threshold)
        if attempt.last_heartbeat_at is not None:
            last_hb = attempt.last_heartbeat_at
            if last_hb.tzinfo is None:
                last_hb = last_hb.replace(tzinfo=timezone.utc)
            elapsed = (now - last_hb).total_seconds()
            if elapsed > HEARTBEAT_TIMEOUT_SECONDS:
                # Log exactly once per outage:
                # Check if a heartbeat_missed event has already been recorded after the last received heartbeat.
                recent_hb_res = await db.execute(
                    select(ExamViolation)
                    .where(
                        ExamViolation.attempt_id == attempt.id,
                        ExamViolation.violation_type == "heartbeat_missed",
                        ExamViolation.occurred_at >= last_hb,
                    )
                    .limit(1)
                )
                can_log = recent_hb_res.scalar_one_or_none() is None

                if can_log:
                    event = ExamViolation(
                        attempt_id=attempt.id,
                        violation_type="heartbeat_missed",
                        occurred_at=now,
                        details=f"No heartbeat received for {int(elapsed)}s.",
                    )
                    db.add(event)
                    attempt.is_flagged = True
                    attempt.flag_reason = f"[OFFLINE] Heartbeat missed ({int(elapsed)}s without signal)."
                    flagged_offline_count += 1

    await db.commit()
    return {
        "active_scanned": len(active_attempts),
        "closed_count": closed_count,
        "flagged_offline": flagged_offline_count,
    }


async def run_exam_monitor_daemon(interval_seconds: int = 15) -> None:
    """Async periodic worker loop checking active attempts every 15-30 seconds."""
    logger.info("Starting Exam Monitor daemon (interval: %ss)", interval_seconds)
    while True:
        try:
            async with async_session() as session:
                stats = await monitor_active_exam_attempts(session)
                if stats["closed_count"] > 0 or stats["flagged_offline"] > 0:
                    logger.info("Exam Monitor cycle completed: %s", stats)
        except asyncio.CancelledError:
            logger.info("Exam Monitor daemon cancelled.")
            break
        except Exception as e:
            logger.exception("Error in Exam Monitor daemon: %s", e)
        await asyncio.sleep(interval_seconds)
