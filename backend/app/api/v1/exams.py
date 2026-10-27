"""ProfessorOS – Exam session endpoints (anti-cheat tracking, authoritative state & professor management)."""

import asyncio
import csv
from datetime import datetime, timedelta, timezone
import io
import json
import logging
import re
from typing import Annotated, Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.dependencies import get_current_user, require_roles
from app.core.proctor_config import (
    HEARTBEAT_TIMEOUT_SECONDS,
    SUBMISSION_GRACE_SECONDS,
    VIOLATION_DEDUPE_WINDOW_SECONDS,
    DEFAULT_STRIKE_LIMIT_FLAG,
    DEFAULT_STRIKE_LIMIT_AUTOSUBMIT,
)
from app.db.base import get_db
from app.models.user import User
from app.models.exam_attempt import ExamAttempt, ExamViolation, ExamAuditLog
from app.models.assignment import Assignment
from app.models.submission import Submission, SubmissionStatus
from app.services.course_service import CourseService

logger = logging.getLogger("professor_os.exams")
router = APIRouter(tags=["Exams"])

DEFAULT_GRACE_SECONDS = SUBMISSION_GRACE_SECONDS
DEDUPE_WINDOW_SECONDS = VIOLATION_DEDUPE_WINDOW_SECONDS


def sanitize_plain_text(text: Optional[str], max_length: int = 255) -> Optional[str]:
    """Sanitizes violation details and explanations to strict plain text."""
    if not text:
        return None
    cleaned = re.sub(r"<[^>]*>", "", text)
    cleaned = "".join(ch for ch in cleaned if ch.isprintable() or ch in "\n\r\t")
    return cleaned.strip()[:max_length]


class ViolationRequest(BaseModel):
    type: str = Field(
        ...,
        pattern="^(tab_switch|window_blur|fullscreen_exit|copy_paste|multi_monitor)$",
        description="Type of anti-cheat telemetry violation (heartbeat_missed is server-only)",
    )
    details: Optional[str] = Field(None, max_length=255)


class HeartbeatRequest(BaseModel):
    answers: Optional[str] = Field(
        None, max_length=200_000, description="Draft answer payload to auto-save while student is typing"
    )


class SubmitExamRequest(BaseModel):
    submission_type: Optional[str] = Field(None, pattern="^(text|file|programming|mcq)$")
    content: Optional[str] = Field(None, max_length=200_000)
    answers: Optional[Any] = None  # Tagged draft envelope {"v":1, "kind":"...", "data":...} or string/dict



class ExamSettingsRequest(BaseModel):
    time_limit_minutes: Optional[int] = Field(None, ge=1, le=600)
    strike_limit_flag: int = Field(DEFAULT_STRIKE_LIMIT_FLAG, ge=1, le=20)
    strike_limit_autosubmit: int = Field(DEFAULT_STRIKE_LIMIT_AUTOSUBMIT, ge=2, le=50)
    fullscreen_required: bool = True
    block_copy_paste: bool = True
    unsupported_browser_policy: str = Field("warn_allow", pattern="^(warn_allow|block)$")


class ExamDecisionRequest(BaseModel):
    action: str = Field(..., pattern="^(accept|invalidate|allow_retake|clear)$")
    reason: str = Field(..., min_length=3, max_length=1000, description="Mandatory instructor rationale")


def is_attempt_expired(
    attempt: ExamAttempt,
    assignment: Optional[Assignment] = None,
    now: Optional[datetime] = None,
    grace_seconds: int = 0,
) -> bool:
    """Return whether the server-side timed attempt deadline has passed."""
    limit_minutes = getattr(attempt, "duration_minutes", None) or (
        getattr(assignment, "time_limit_minutes", None) if assignment else None
    )
    started_at = getattr(attempt, "started_at", None)
    if not limit_minutes or not started_at:
        return False
    now = now or datetime.now(timezone.utc)
    if started_at.tzinfo is None:
        started_at = started_at.replace(tzinfo=timezone.utc)
    deadline = started_at + timedelta(minutes=limit_minutes) + timedelta(seconds=grace_seconds)
    return now >= deadline


def compute_remaining_seconds(
    attempt: ExamAttempt,
    assignment: Optional[Assignment] = None,
    now: Optional[datetime] = None,
) -> int:
    """Authoritative server-side calculation of remaining seconds for an attempt."""
    limit_minutes = getattr(attempt, "duration_minutes", None) or (
        getattr(assignment, "time_limit_minutes", None) if assignment else None
    )
    if not limit_minutes:
        return 0
    started_at = attempt.started_at
    if started_at.tzinfo is None:
        started_at = started_at.replace(tzinfo=timezone.utc)
    now = now or datetime.now(timezone.utc)
    elapsed = (now - started_at).total_seconds()
    return max(0, int((limit_minutes * 60) - elapsed))


def unpack_draft_answers(raw_draft: Any, assignment_type: str = "text") -> tuple[str, str, Optional[str]]:
    """Unpack a draft answer payload into (submission_type, content, file_name).
    Supports tagged envelope {"v":1, "kind":"mcq|text|code|file", "data":...}
    and legacy formats (raw text, raw json dict {"0":1}).
    """
    if raw_draft is None:
        return (assignment_type, "", None)

    data_dict = None
    if isinstance(raw_draft, dict):
        data_dict = raw_draft
    elif isinstance(raw_draft, str):
        raw_str = raw_draft.strip()
        if (raw_str.startswith("{") and raw_str.endswith("}")) or (raw_str.startswith("[") and raw_str.endswith("]")):
            try:
                parsed = json.loads(raw_str)
                if isinstance(parsed, dict):
                    data_dict = parsed
            except Exception:
                data_dict = None

    if data_dict is not None and "v" in data_dict and "kind" in data_dict:
        kind = data_dict.get("kind", assignment_type)
        val = data_dict.get("data")
        if kind == "file":
            return ("file", str(val or ""), str(val or ""))
        elif kind in ("programming", "code"):
            return ("programming", str(val or ""), None)
        elif kind == "mcq":
            mcq_content = json.dumps(val) if isinstance(val, (dict, list)) else str(val or "")
            return ("mcq", mcq_content, None)
        else:
            return ("text", str(val or ""), None)

    if isinstance(raw_draft, dict):
        return ("mcq", json.dumps(raw_draft), None)

    raw_str = str(raw_draft)
    if data_dict is not None and not any(k in data_dict for k in ("v", "kind")):
        if all(str(k).isdigit() for k in data_dict.keys()) and data_dict:
            return ("mcq", raw_str, None)

    sub_type = "programming" if assignment_type == "programming" else ("file" if assignment_type == "file" else "text")
    if assignment_type == "mcq":
        sub_type = "text"
    return (sub_type, raw_str, None)


async def auto_close_attempt(
    attempt: ExamAttempt,
    assignment: Assignment,
    db: AsyncSession,
    reason: str = "time_expired",
) -> bool:
    """Server-controlled automatic closure of an exam attempt.
    Safe against multi-worker concurrent execution via atomic compare-and-swap update.
    Returns True if this worker closed it, False if already closed by another worker."""
    now = datetime.now(timezone.utc)
    res = await db.execute(
        update(ExamAttempt)
        .where(ExamAttempt.id == attempt.id, ExamAttempt.submitted_at.is_(None))
        .values(submitted_at=now, auto_submitted=True)
    )
    if res.rowcount == 0:
        return False

    attempt.submitted_at = now
    attempt.auto_submitted = True

    # Log auto-close violation event
    event = ExamViolation(
        attempt_id=attempt.id,
        violation_type="auto_close",
        occurred_at=now,
        details=f"Attempt auto-closed ({reason}).",
    )
    db.add(event)

    # Reconcile submission record for THIS attempt
    sub_type, sub_content, sub_file = unpack_draft_answers(
        attempt.current_answers,
        assignment_type=getattr(assignment, "type", "text"),
    )
    fallback_content = (
        sub_content
        or f"// [Time Expired - Auto-Submitted by System ({reason})]"
    )

    sub_res = await db.execute(
        select(Submission)
        .where(Submission.attempt_id == attempt.id)
        .with_for_update()
    )
    existing_sub = sub_res.scalar_one_or_none()

    if existing_sub:
        existing_sub.auto_submitted = True
        if fallback_content and not existing_sub.content:
            existing_sub.content = fallback_content
        if sub_file and not existing_sub.file_name:
            existing_sub.file_name = sub_file
    else:
        sub_type_val = getattr(sub_type, "value", str(sub_type)).lower()
        if "." in sub_type_val:
            sub_type_val = sub_type_val.split(".")[-1]
        new_sub = Submission(
            assignment_id=assignment.id,
            student_id=attempt.student_id,
            attempt_id=attempt.id,
            submission_type=sub_type_val,
            content=fallback_content,
            file_name=sub_file,
            status=SubmissionStatus.PENDING.value,
            auto_submitted=True,
            submitted_at=now,
        )
        db.add(new_sub)

    await db.flush()
    return True


async def record_violation(
    attempt: ExamAttempt,
    assignment: Assignment,
    violation_type: str,
    details: Optional[str],
    db: AsyncSession,
) -> Dict[str, Any]:
    """Atomic violation recording and strike logic on the server using DB row lock."""
    attempt_id = getattr(attempt, "id", None)
    if attempt_id is not None:
        lock_res = await db.execute(
            select(ExamAttempt)
            .where(ExamAttempt.id == attempt_id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        locked = lock_res.scalar_one_or_none()
        if locked is not None:
            attempt = locked

    now = datetime.now(timezone.utc)
    details = sanitize_plain_text(details)

    # 1. Server-side expiration check on attempt requests
    if is_attempt_expired(attempt, assignment, now=now):
        await auto_close_attempt(attempt, assignment, db, reason="time_expired")
        try:
            await db.commit()
        except Exception:
            pass
        return {
            "attempt_id": attempt.id,
            "tab_switch_count": attempt.tab_switch_count,
            "strike_count": attempt.tab_switch_count,
            "is_flagged": attempt.is_flagged,
            "auto_closed": True,
            "message": "Exam deadline expired. Attempt auto-submitted.",
        }

    # 2. Server-side deduplication within sliding window (1.5 seconds)
    # Group tab_switch and window_blur under "focus_loss"
    if violation_type in ("tab_switch", "window_blur"):
        dedupe_types = ("tab_switch", "window_blur")
    else:
        dedupe_types = (violation_type,)

    recent_res = await db.execute(
        select(ExamViolation)
        .where(
            ExamViolation.attempt_id == attempt.id,
            ExamViolation.violation_type.in_(dedupe_types),
        )
        .order_by(ExamViolation.occurred_at.desc())
        .limit(1)
    )
    recent = recent_res.scalar_one_or_none()
    if recent:
        last_t = recent.occurred_at
        if last_t.tzinfo is None:
            last_t = last_t.replace(tzinfo=timezone.utc)
        if (now - last_t).total_seconds() < DEDUPE_WINDOW_SECONDS:
            logger.info(
                "Deduplicated %s violation for attempt %s (within %ss window)",
                violation_type,
                attempt.id,
                DEDUPE_WINDOW_SECONDS,
            )
            return {
                "attempt_id": attempt.id,
                "tab_switch_count": attempt.tab_switch_count,
                "strike_count": attempt.tab_switch_count,
                "is_flagged": attempt.is_flagged,
                "message": "Duplicate violation within debounce window ignored.",
                "deduplicated": True,
            }

    # 3. Determine if violation type incurs a strike
    # Strike rule: copy_paste, multi_monitor, and heartbeat_missed do NOT add strikes by default
    adds_strike = violation_type not in ("copy_paste", "multi_monitor", "heartbeat_missed", "auto_close")

    # Save violation event row for instructor audit timeline
    event = ExamViolation(
        attempt_id=attempt.id,
        violation_type=violation_type,
        occurred_at=now,
        details=details or f"Violation recorded: {violation_type}",
    )
    db.add(event)

    if adds_strike:
        attempt.tab_switch_count = (attempt.tab_switch_count or 0) + 1

    strike_flag = getattr(assignment, "strike_limit_flag", DEFAULT_STRIKE_LIMIT_FLAG) or DEFAULT_STRIKE_LIMIT_FLAG
    strike_auto = getattr(assignment, "strike_limit_autosubmit", DEFAULT_STRIKE_LIMIT_AUTOSUBMIT) or DEFAULT_STRIKE_LIMIT_AUTOSUBMIT

    # 5. Strike limit & auto-flagging logic
    if attempt.tab_switch_count >= strike_flag and not attempt.is_flagged:
        attempt.is_flagged = True
        attempt.flag_reason = (
            f"Flagged: {attempt.tab_switch_count} violations detected ({violation_type})."
        )

    # 5b. Immediate disqualification on fullscreen return timeout
    auto_closed = False
    if violation_type in ("fullscreen_exit_timeout", "return_timeout"):
        attempt.is_flagged = True
        attempt.flag_reason = (
            "Disqualified: Failed to return to exam within grace period after exiting fullscreen."
        )
        await auto_close_attempt(attempt, assignment, db, reason="fullscreen_exit_timeout")
        auto_closed = True

    # 6. Excessive violations auto-submit
    elif attempt.tab_switch_count >= strike_auto:
        attempt.is_flagged = True
        attempt.flag_reason = f"Disqualified: Reached violation strike limit ({attempt.tab_switch_count} strikes)."
        await auto_close_attempt(attempt, assignment, db, reason="excessive_violations")
        auto_closed = True

    await db.flush()
    try:
        await db.commit()
    except Exception:
        pass
    return {
        "attempt_id": attempt.id,
        "tab_switch_count": attempt.tab_switch_count,
        "strike_count": attempt.tab_switch_count,
        "is_flagged": attempt.is_flagged,
        "auto_closed": auto_closed,
        "message": (
            "Maximum violations reached. Exam auto-submitted."
            if auto_closed
            else ("Attempt flagged for review." if attempt.is_flagged else "Violation recorded.")
        ),
    }


# Backwards compatibility alias for test imports
record_violation_atomic = record_violation


def _make_attempt_payload(
    attempt: ExamAttempt,
    assignment: Assignment,
    attempts_used: int,
    resumed: bool,
    now: Optional[datetime] = None,
    retakes_allowed: int = 0,
) -> Dict[str, Any]:
    now = now or datetime.now(timezone.utc)
    remaining = compute_remaining_seconds(attempt, assignment, now=now)
    last_hb = attempt.last_heartbeat_at
    if last_hb and last_hb.tzinfo is None:
        last_hb = last_hb.replace(tzinfo=timezone.utc)
    elapsed_hb = int((now - last_hb).total_seconds()) if last_hb else None
    is_submitted = attempt.submitted_at is not None
    is_live = (not is_submitted) and (elapsed_hb is not None) and (elapsed_hb <= HEARTBEAT_TIMEOUT_SECONDS)

    if attempt.auto_submitted:
        status_str = "auto_submitted"
    elif is_submitted:
        status_str = "submitted"
    elif is_live:
        status_str = "active"
    else:
        status_str = "offline"

    return {
        "attempt_id": attempt.id,
        "time_limit_minutes": attempt.duration_minutes or assignment.time_limit_minutes,
        "remaining_seconds": remaining,
        "max_attempts": (assignment.max_attempts or 1) + retakes_allowed,
        "attempts_used": attempts_used,
        "attempt_number": getattr(attempt, "attempt_number", 1) or 1,
        "tab_switch_count": attempt.tab_switch_count,
        "strike_count": attempt.tab_switch_count,
        "is_flagged": attempt.is_flagged,
        "flag_reason": attempt.flag_reason,
        "resumed": resumed,
        "current_answers": attempt.current_answers,
        "auto_submitted": attempt.auto_submitted,
        "submitted_at": attempt.submitted_at.isoformat() if attempt.submitted_at else None,
        "started_at": attempt.started_at.isoformat() if attempt.started_at else None,
        "last_heartbeat_at": last_hb.isoformat() if last_hb else None,
        "seconds_since_heartbeat": elapsed_hb,
        "is_live": is_live,
        "status": status_str,
        # Server-enforced proctoring settings
        "strike_limit_flag": getattr(assignment, "strike_limit_flag", DEFAULT_STRIKE_LIMIT_FLAG) or DEFAULT_STRIKE_LIMIT_FLAG,
        "strike_limit_autosubmit": getattr(assignment, "strike_limit_autosubmit", DEFAULT_STRIKE_LIMIT_AUTOSUBMIT) or DEFAULT_STRIKE_LIMIT_AUTOSUBMIT,
        "fullscreen_required": getattr(assignment, "fullscreen_required", True),
        "block_copy_paste": getattr(assignment, "block_copy_paste", True),
        "unsupported_browser_policy": getattr(assignment, "unsupported_browser_policy", "warn_allow") or "warn_allow",
    }


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/start")
async def start_exam(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Start or resume an exam attempt."""
    assignment_result = await db.execute(
        select(Assignment)
        .where(Assignment.id == assignment_id)
        .with_for_update()
    )
    assignment = assignment_result.scalar_one_or_none()
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    if assignment.status != "published":
        raise HTTPException(status_code=400, detail="Assignment is not published.")

    # Load attempts for this student/assignment
    result = await db.execute(
        select(ExamAttempt)
        .where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
        )
        .order_by(ExamAttempt.started_at.desc())
        .with_for_update()
    )
    existing_attempts = list(result.scalars().all())

    active_attempt = next(
        (a for a in existing_attempts if a.submitted_at is None), None
    )

    completed_count = len(
        [a for a in existing_attempts if a.submitted_at is not None]
    )
    retakes_allowed = len(
        [a for a in existing_attempts if getattr(a, "retake_granted", False) or a.decision == "allow_retake"]
    )
    allowed_attempts = (assignment.max_attempts or 1) + retakes_allowed

    if active_attempt is not None:
        if is_attempt_expired(active_attempt, assignment):
            await auto_close_attempt(active_attempt, assignment, db, reason="time_expired")
            completed_count = len([a for a in existing_attempts if a.submitted_at is not None])
            if completed_count >= allowed_attempts:
                raise HTTPException(
                    status_code=400,
                    detail="Exam attempt time expired and has been submitted.",
                )
        else:
            active_attempt.last_heartbeat_at = datetime.now(timezone.utc)
            await db.flush()
            return _make_attempt_payload(
                active_attempt, assignment, len(existing_attempts), True, retakes_allowed=retakes_allowed
            )

    if completed_count >= allowed_attempts:
        raise HTTPException(
            status_code=400, detail="Maximum attempts reached for this exam."
        )

    now = datetime.now(timezone.utc)
    if assignment.deadline:
        dl = assignment.deadline if assignment.deadline.tzinfo else assignment.deadline.replace(tzinfo=timezone.utc)
        if now >= dl and not getattr(assignment, "allow_late", False):
            raise HTTPException(status_code=400, detail="Assignment deadline has passed.")

    duration_minutes = assignment.time_limit_minutes
    if duration_minutes and assignment.deadline and not getattr(assignment, "allow_late", False):
        dl = assignment.deadline if assignment.deadline.tzinfo else assignment.deadline.replace(tzinfo=timezone.utc)
        time_to_dl_minutes = int(round((dl - now).total_seconds() / 60))
        if time_to_dl_minutes <= 0:
            raise HTTPException(status_code=400, detail="Assignment deadline has passed.")
        if time_to_dl_minutes < duration_minutes:
            duration_minutes = time_to_dl_minutes

    attempt = ExamAttempt(
        assignment_id=assignment_id,
        student_id=user.id,
        started_at=now,
        duration_minutes=duration_minutes,
        last_heartbeat_at=now,
        tab_switch_count=0,
        is_flagged=False,
        attempt_number=len(existing_attempts) + 1,
    )
    db.add(attempt)
    await db.flush()

    return _make_attempt_payload(
        attempt, assignment, completed_count + 1, False, now=now, retakes_allowed=retakes_allowed
    )


@router.post("/attempts/{attempt_id}/violations")
async def report_attempt_violation(
    attempt_id: int,
    payload: ViolationRequest,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Universal atomic anti-cheat telemetry violation endpoint."""
    res = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.assignment))
        .where(
            ExamAttempt.id == attempt_id,
            ExamAttempt.student_id == user.id,
            ExamAttempt.submitted_at.is_(None),
        )
        .with_for_update()
    )
    attempt = res.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="Active exam attempt not found.")

    return await record_violation(
        attempt,
        attempt.assignment,
        payload.type,
        payload.details,
        db,
    )




@router.post("/attempts/{attempt_id}/heartbeat")
async def attempt_heartbeat(
    attempt_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    body: Optional[HeartbeatRequest] = None,
):
    """Heartbeat endpoint with server-side expiry check and draft answer auto-saving."""
    attempt_res = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.assignment))
        .where(
            ExamAttempt.id == attempt_id,
            ExamAttempt.student_id == user.id,
        )
        .with_for_update()
    )
    attempt = attempt_res.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="Exam attempt not found.")

    # 1. If already submitted, reject draft saving
    if attempt.submitted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Exam attempt has already been submitted. Draft answer saves are rejected.",
        )

    now = datetime.now(timezone.utc)

    # 2. If expired past deadline + grace period, close and reject draft save
    expired = is_attempt_expired(attempt, attempt.assignment, now=now)
    if expired:
        await auto_close_attempt(attempt, attempt.assignment, db, reason="time_expired")
        if body and body.answers is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Exam deadline has passed. Draft answer saves are rejected.",
            )
        return {
            "attempt_id": attempt.id,
            "remaining_seconds": 0,
            "is_flagged": attempt.is_flagged,
            "tab_switch_count": attempt.tab_switch_count,
            "strike_count": attempt.tab_switch_count,
            "auto_closed": True,
            "is_live": False,
            "status": "auto_submitted",
            "message": "Exam deadline expired. Attempt auto-closed.",
        }

    # 3. Valid active attempt: update heartbeat timestamp & save answer draft
    attempt.last_heartbeat_at = now
    if body and body.answers is not None:
        attempt.current_answers = body.answers

    # If flagged for offline, clear the offline status message
    strike_flag = getattr(attempt.assignment, "strike_limit_flag", DEFAULT_STRIKE_LIMIT_FLAG) or DEFAULT_STRIKE_LIMIT_FLAG
    if attempt.flag_reason and "[OFFLINE]" in attempt.flag_reason:
        attempt.flag_reason = (
            f"Flagged: {attempt.tab_switch_count} violations detected."
            if attempt.tab_switch_count >= strike_flag
            else None
        )
        attempt.is_flagged = attempt.tab_switch_count >= strike_flag

    await db.flush()
    return {
        "attempt_id": attempt.id,
        "remaining_seconds": compute_remaining_seconds(attempt, attempt.assignment, now=now),
        "tab_switch_count": attempt.tab_switch_count,
        "strike_count": attempt.tab_switch_count,
        "is_flagged": attempt.is_flagged,
        "auto_closed": False,
        "is_live": True,
        "seconds_since_heartbeat": 0,
        "status": "active",
    }




@router.get("/attempts/{attempt_id}/state")
async def get_attempt_state(
    attempt_id: int,
    user: Annotated[User, Depends(require_roles("student", "professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Authoritative endpoint to restore state on page reload during an exam."""
    res = await db.execute(
        select(ExamAttempt)
        .options(
            selectinload(ExamAttempt.assignment),
            selectinload(ExamAttempt.violations),
        )
        .where(ExamAttempt.id == attempt_id)
    )
    attempt = res.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="Exam attempt not found.")
    
    role = getattr(user.role, "value", user.role)
    if role == "student":
        if attempt.student_id != user.id:
            raise HTTPException(status_code=403, detail="Access denied.")
    else:
        from app.core.auth_guards import verify_course_staff_access
        assignment = attempt.assignment or await db.get(Assignment, attempt.assignment_id)
        await verify_course_staff_access(db, assignment.course_id, user, allow_ta=True)

    all_att_res = await db.execute(
        select(ExamAttempt).where(
            ExamAttempt.assignment_id == attempt.assignment_id,
            ExamAttempt.student_id == attempt.student_id,
        )
    )
    all_atts = list(all_att_res.scalars().all())
    retakes_allowed = len([a for a in all_atts if getattr(a, "retake_granted", False) or a.decision == "allow_retake"])
    return _make_attempt_payload(
        attempt, attempt.assignment, len(all_atts), True, retakes_allowed=retakes_allowed
    )


@router.get("/courses/{course_id}/assignments/{assignment_id}/exam/state")
async def get_exam_state(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Query current student exam state for resume on refresh."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")

    res = await db.execute(
        select(ExamAttempt)
        .options(
            selectinload(ExamAttempt.assignment),
            selectinload(ExamAttempt.violations),
        )
        .where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
        )
        .order_by(ExamAttempt.started_at.desc())
    )
    all_student_attempts = list(res.scalars().all())
    if not all_student_attempts:
        return {}

    attempt = all_student_attempts[0]
    retakes_allowed = len([a for a in all_student_attempts if getattr(a, "retake_granted", False) or a.decision == "allow_retake"])
    return _make_attempt_payload(
        attempt, assignment, len(all_student_attempts), True, retakes_allowed=retakes_allowed
    )


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/submit")
async def submit_exam(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    body: Optional[SubmitExamRequest] = None,
):
    """Atomic exam submit (Item 1.7): saves submission with attempt_id and closes attempt in one transaction. Idempotent."""
    now = datetime.now(timezone.utc)
    # Find active attempt first
    result = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.assignment))
        .where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
            ExamAttempt.submitted_at.is_(None),
        )
        .order_by(ExamAttempt.started_at.desc())
        .limit(1)
        .with_for_update()
    )
    attempt = result.scalar_one_or_none()

    if not attempt:
        # Check for recently submitted / auto-submitted attempt (idempotency & retry)
        latest_res = await db.execute(
            select(ExamAttempt)
            .options(selectinload(ExamAttempt.assignment))
            .where(
                ExamAttempt.assignment_id == assignment_id,
                ExamAttempt.student_id == user.id,
            )
            .order_by(ExamAttempt.started_at.desc())
            .limit(1)
            .with_for_update()
        )
        attempt = latest_res.scalar_one_or_none()
        if not attempt:
            raise HTTPException(status_code=404, detail="No active exam attempt found.")
        # Check if submission already exists for this attempt
        sub_check = await db.execute(
            select(Submission).where(Submission.attempt_id == attempt.id)
        )
        existing_sub = sub_check.scalar_one_or_none()
        if existing_sub:
            return {
                "message": "Exam submitted successfully.",
                "attempt_id": attempt.id,
                "submission_id": existing_sub.id,
                "tab_switch_count": attempt.tab_switch_count,
                "strike_count": attempt.tab_switch_count,
                "is_flagged": attempt.is_flagged,
            }

    # Close the attempt if not already closed
    if attempt.submitted_at is None:
        attempt.submitted_at = now

    assignment = attempt.assignment or await db.get(Assignment, assignment_id)

    # Determine submission content from body or draft answers
    raw_payload = None
    if body:
        if body.answers is not None:
            raw_payload = body.answers
        elif body.content is not None:
            raw_payload = body.content
    if raw_payload is None:
        raw_payload = attempt.current_answers

    sub_type, sub_content, sub_file = unpack_draft_answers(
        raw_payload,
        assignment_type=body.submission_type if (body and body.submission_type) else getattr(assignment, "type", "text"),
    )

    if not sub_content:
        sub_content = "[Submitted with empty response]"

    # Create or update submission linked to this attempt
    sub_res = await db.execute(
        select(Submission)
        .where(Submission.attempt_id == attempt.id)
        .with_for_update()
    )
    submission = sub_res.scalar_one_or_none()
    if submission:
        submission.content = sub_content
        submission.submission_type = sub_type
        if sub_file:
            submission.file_name = sub_file
    else:
        submission = Submission(
            assignment_id=assignment.id,
            student_id=attempt.student_id,
            attempt_id=attempt.id,
            submission_type=sub_type,
            content=sub_content,
            file_name=sub_file,
            status=SubmissionStatus.PENDING.value,
            auto_submitted=attempt.auto_submitted,
            submitted_at=now,
        )
        db.add(submission)

    await db.flush()
    return {
        "message": "Exam submitted successfully.",
        "attempt_id": attempt.id,
        "submission_id": submission.id,
        "tab_switch_count": attempt.tab_switch_count,
        "strike_count": attempt.tab_switch_count,
        "is_flagged": attempt.is_flagged,
    }


# ── Professor-facing Management, Live Console & Post-Exam Review ───────────────

@router.get("/courses/{course_id}/assignments/{assignment_id}/exam/attempts")
async def list_exam_attempts(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    status_filter: Optional[str] = Query(None, description="Optional filter: flagged, auto_submitted, has_violations"),
):
    """Professor/admin: list all exam attempts with real-time audit timeline and server-determined is_live status."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).verify_course_management_access(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    result = await db.execute(
        select(ExamAttempt)
        .options(
            selectinload(ExamAttempt.violations),
            selectinload(ExamAttempt.student),
            selectinload(ExamAttempt.reviewer),
        )
        .where(ExamAttempt.assignment_id == assignment_id)
    )
    attempts = list(result.scalars().all())
    now = datetime.now(timezone.utc)

    items = []
    for a in attempts:
        is_submitted = a.submitted_at is not None
        auto_sub = a.auto_submitted
        last_hb = a.last_heartbeat_at
        if last_hb and last_hb.tzinfo is None:
            last_hb = last_hb.replace(tzinfo=timezone.utc)
        elapsed_hb = int((now - last_hb).total_seconds()) if last_hb else None
        is_live = (not is_submitted) and (elapsed_hb is not None) and (elapsed_hb <= HEARTBEAT_TIMEOUT_SECONDS)

        if auto_sub:
            st = "auto_submitted"
        elif is_submitted:
            st = "submitted"
        elif is_live:
            st = "active"
        else:
            st = "offline"

        if status_filter == "flagged" and not a.is_flagged:
            continue
        if status_filter == "auto_submitted" and not auto_sub:
            continue
        if status_filter == "has_violations" and not (a.violations and len(a.violations) > 0):
            continue

        student_name = a.student.full_name if a.student else f"Student #{a.student_id}"
        student_email = a.student.email if a.student else ""
        reviewer_name = a.reviewer.full_name if (getattr(a, "reviewer", None) and a.reviewer) else None

        time_spent_minutes = 0
        if a.started_at:
            end_t = a.submitted_at or now
            st_t = a.started_at if a.started_at.tzinfo else a.started_at.replace(tzinfo=timezone.utc)
            time_spent_minutes = round((end_t - st_t).total_seconds() / 60.0, 1)

        item = {
            "id": a.id,
            "student_id": a.student_id,
            "student_name": student_name,
            "student_email": student_email,
            "attempt_number": getattr(a, "attempt_number", 1) or 1,
            "started_at": a.started_at.isoformat() if a.started_at else None,
            "submitted_at": a.submitted_at.isoformat() if a.submitted_at else None,
            "time_spent_minutes": time_spent_minutes,
            "is_active": not is_submitted,
            "is_live": is_live,
            "status": st,
            "last_heartbeat_at": last_hb.isoformat() if last_hb else None,
            "seconds_since_heartbeat": elapsed_hb,
            "auto_submitted": auto_sub,
            "tab_switch_count": a.tab_switch_count,
            "strike_count": a.tab_switch_count,
            "is_flagged": a.is_flagged,
            "flag_reason": a.flag_reason,
            "duration_minutes": a.duration_minutes,
            "decision": getattr(a, "decision", None),
            "decision_reason": getattr(a, "decision_reason", None),
            "reviewed_by_id": getattr(a, "reviewed_by_id", None),
            "reviewed_by_name": reviewer_name,
            "reviewed_at": a.reviewed_at.isoformat() if getattr(a, "reviewed_at", None) else None,
            "violations": [
                {
                    "id": v.id,
                    "type": v.violation_type,
                    "violation_type": v.violation_type,
                    "occurred_at": v.occurred_at.isoformat(),
                    "details": sanitize_plain_text(v.details),
                }
                for v in (a.violations or [])
            ],
        }
        items.append(item)

    # Flagged and offline students float to the top
    items.sort(
        key=lambda it: (
            0 if (it["is_flagged"] or it["status"] == "offline") else 1,
            it["started_at"] or "",
        ),
        reverse=False,
    )
    return items


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/attempts/{attempt_id}/decision")
async def update_exam_attempt_decision(
    course_id: int,
    assignment_id: int,
    attempt_id: int,
    payload: ExamDecisionRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Professor/admin: Record review decision (accept, invalidate, allow_retake, clear)."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).verify_course_management_access(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    result = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.violations))
        .where(
            ExamAttempt.id == attempt_id,
            ExamAttempt.assignment_id == assignment_id,
        )
        .with_for_update()
    )
    attempt = result.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="Exam attempt not found.")

    action = payload.action
    reason = payload.reason.strip()
    if not reason:
        raise HTTPException(status_code=400, detail="Decision reason is mandatory.")

    now = datetime.now(timezone.utc)
    attempt.reviewed_by_id = user.id
    attempt.reviewed_at = now
    attempt.decision = action
    attempt.decision_reason = reason

    if action == "invalidate":
        attempt.is_flagged = True
        attempt.flag_reason = f"[DISQUALIFIED] {reason}"
        if not attempt.submitted_at:
            attempt.submitted_at = now
        # Update linked submission status to invalidated and zero out score
        sub_res = await db.execute(
            select(Submission).where(
                (Submission.attempt_id == attempt.id)
                | (
                    (Submission.assignment_id == assignment_id)
                    & (Submission.student_id == attempt.student_id)
                )
            )
        )
        for s in sub_res.scalars().all():
            s.status = SubmissionStatus.INVALIDATED.value
            s.score = None
            s.feedback = f"[SUBMISSION INVALIDATED BY INSTRUCTOR]: {reason}"
    elif action == "accept":
        attempt.is_flagged = False
        attempt.flag_reason = f"[ACCEPTED] Verified by instructor: {reason}"
    elif action == "clear":
        attempt.is_flagged = False
        attempt.flag_reason = f"Flags reviewed and cleared by instructor: {reason}"
        # Baseline strike count is updated so student doesn't immediately re-trigger auto-submit
        attempt.reviewed_strike_baseline = attempt.tab_switch_count
    elif action == "allow_retake":
        attempt.is_flagged = True
        attempt.flag_reason = f"[RETAKE_ALLOWED] Instructor allowed retake: {reason}"
        attempt.retake_granted = True
        if not attempt.submitted_at:
            attempt.submitted_at = now

    # Record in immutable audit log table
    audit_entry = ExamAuditLog(
        assignment_id=assignment.id,
        attempt_id=attempt.id,
        instructor_id=user.id,
        action=action,
        reason=reason,
        created_at=now,
    )
    db.add(audit_entry)

    await db.flush()
    return {
        "message": f"Exam attempt decision '{action}' recorded successfully.",
        "attempt_id": attempt.id,
        "is_flagged": attempt.is_flagged,
        "flag_reason": attempt.flag_reason,
        "tab_switch_count": attempt.tab_switch_count,
        "strike_count": attempt.tab_switch_count,
        "decision": attempt.decision,
        "decision_reason": attempt.decision_reason,
        "reviewed_by_id": attempt.reviewed_by_id,
        "reviewed_at": attempt.reviewed_at.isoformat(),
    }


@router.get("/courses/{course_id}/assignments/{assignment_id}/exam/export-csv")
async def export_exam_attempts_csv(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Export all student attempts and proctoring audit metadata as a CSV file."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).verify_course_management_access(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    result = await db.execute(
        select(ExamAttempt)
        .options(
            selectinload(ExamAttempt.student),
            selectinload(ExamAttempt.reviewer),
            selectinload(ExamAttempt.violations),
        )
        .where(ExamAttempt.assignment_id == assignment_id)
        .order_by(ExamAttempt.started_at.asc())
    )
    attempts = list(result.scalars().all())

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Attempt ID",
        "Student ID",
        "Student Name",
        "Student Email",
        "Attempt Number",
        "Started At",
        "Submitted At",
        "Duration Limit (min)",
        "Strikes",
        "Flagged",
        "Auto-Submitted",
        "Total Violations",
        "Decision",
        "Decision Reason",
        "Reviewed By",
        "Reviewed At",
    ])

    for a in attempts:
        student_name = a.student.full_name if a.student else f"Student #{a.student_id}"
        student_email = a.student.email if a.student else ""
        reviewer_name = a.reviewer.full_name if (getattr(a, "reviewer", None) and a.reviewer) else ""
        from app.core.auth_guards import escape_csv_cell
        writer.writerow([
            a.id,
            a.student_id,
            escape_csv_cell(student_name),
            escape_csv_cell(student_email),
            getattr(a, "attempt_number", 1) or 1,
            a.started_at.isoformat() if a.started_at else "",
            a.submitted_at.isoformat() if a.submitted_at else "",
            a.duration_minutes or assignment.time_limit_minutes or "",
            a.tab_switch_count,
            "YES" if a.is_flagged else "NO",
            "YES" if a.auto_submitted else "NO",
            len(a.violations or []),
            escape_csv_cell(getattr(a, "decision", "") or ""),
            escape_csv_cell(getattr(a, "decision_reason", "") or ""),
            escape_csv_cell(reviewer_name),
            a.reviewed_at.isoformat() if getattr(a, "reviewed_at", None) else "",
        ])

    csv_data = output.getvalue()
    return StreamingResponse(
        iter([csv_data]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=exam_attempts_assignment_{assignment_id}.csv"
        },
    )


@router.put("/courses/{course_id}/assignments/{assignment_id}/exam/settings")
async def update_exam_settings(
    course_id: int,
    assignment_id: int,
    payload: ExamSettingsRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update exam proctoring settings. Locked once any student attempt has started."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).verify_course_management_access(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    # Enforce settings lock: reject if any attempt exists
    attempt_check = await db.execute(
        select(ExamAttempt.id)
        .where(ExamAttempt.assignment_id == assignment_id)
        .limit(1)
    )
    if attempt_check.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Exam settings are locked because student attempts have already started.",
        )

    assignment.time_limit_minutes = payload.time_limit_minutes
    assignment.strike_limit_flag = payload.strike_limit_flag
    assignment.strike_limit_autosubmit = payload.strike_limit_autosubmit
    assignment.fullscreen_required = payload.fullscreen_required
    assignment.block_copy_paste = payload.block_copy_paste
    assignment.unsupported_browser_policy = payload.unsupported_browser_policy

    # Audit log
    now = datetime.now(timezone.utc)
    audit = ExamAuditLog(
        assignment_id=assignment.id,
        attempt_id=None,
        instructor_id=user.id,
        action="update_settings",
        reason=f"Settings updated: limit={payload.time_limit_minutes}m, flag={payload.strike_limit_flag}, autosubmit={payload.strike_limit_autosubmit}, policy={payload.unsupported_browser_policy}",
        created_at=now,
    )
    db.add(audit)
    await db.flush()

    return {
        "message": "Exam settings updated successfully.",
        "assignment_id": assignment.id,
        "time_limit_minutes": assignment.time_limit_minutes,
        "strike_limit_flag": assignment.strike_limit_flag,
        "strike_limit_autosubmit": assignment.strike_limit_autosubmit,
        "fullscreen_required": assignment.fullscreen_required,
        "block_copy_paste": assignment.block_copy_paste,
        "unsupported_browser_policy": assignment.unsupported_browser_policy,
    }
