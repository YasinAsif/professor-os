import json
import logging

logger = logging.getLogger(__name__)
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.core.dependencies import get_current_user, require_roles
from app.core.config import get_settings
from app.db.base import get_db
from app.models.user import User
from app.models.assignment import Assignment
from app.models.exam_attempt import ExamAttempt
from app.models.rubric import Rubric
from app.schemas.submission import (
    SubmissionCreate, SubmissionGrade, SubmissionResponse, SubmissionListResponse,
)
from app.services.submission_service import SubmissionService
from app.services.assignment_service import AssignmentService, ensure_assignment_in_course
from app.services.course_service import CourseService
from app.services.grading_pipeline import grade_submission_task, _grade_submission_core, PromptInjectionDetected
from app.services.document_ingestion import extract_text_from_submission_file, build_document_triage
from app.api.v1.exams import is_attempt_expired

router = APIRouter(tags=["Submissions"])
MAX_SUBMISSION_BYTES = 25 * 1024 * 1024
settings = get_settings()


def validate_timed_submission_attempt(
    assignment,
    attempt,
    now=None,
    *,
    allow_expired: bool = False,
    grace_seconds: int = 10,
) -> None:
    """Require a live server-side attempt before accepting timed-exam content."""
    if not getattr(assignment, "time_limit_minutes", None):
        return
    if attempt is None or getattr(attempt, "submitted_at", None) is not None:
        raise ValueError("An active exam attempt is required for this submission.")
    if is_attempt_expired(attempt, assignment, now=now, grace_seconds=grace_seconds) and not allow_expired:
        raise ValueError("The exam time limit has expired and the grace period has ended.")


async def _get_timed_attempt(assignment_id: int, student_id: int, db: AsyncSession):
    result = await db.execute(
        select(ExamAttempt)
        .where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == student_id,
            ExamAttempt.submitted_at.is_(None),
        )
        .order_by(ExamAttempt.started_at.desc())
        .limit(1)
        .with_for_update()
    )
    return result.scalar_one_or_none()


async def _verify_student_assignment(course_id: int, aid: int, user: User, db: AsyncSession) -> Assignment:
    assignment = await db.get(Assignment, aid)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    if (assignment.status or "").lower() == "draft":
        raise HTTPException(status_code=403, detail="Assignment is not yet published.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    return assignment


def _to_response(sub, requesting_user: Optional[User] = None, assignment: Optional[Assignment] = None) -> SubmissionResponse:
    metadata = {}
    if sub.evaluation_metadata:
        try:
            metadata = json.loads(sub.evaluation_metadata)
        except (TypeError, json.JSONDecodeError):
            metadata = {}
    triage_reasons = metadata.get("triage_reasons", metadata.get("review_reasons", []))
    if not isinstance(triage_reasons, list):
        triage_reasons = [str(triage_reasons)]

    score = sub.score
    feedback = sub.feedback
    eval_meta = sub.evaluation_metadata
    if requesting_user and requesting_user.role == "student":
        assign = assignment or getattr(sub, "assignment", None)
        if assign and not getattr(assign, "show_results_after", True):
            score = None
            feedback = "Results will be published after the grading period."
            eval_meta = None

    return SubmissionResponse(
        id=sub.id,
        assignment_id=sub.assignment_id,
        student_id=sub.student_id,
        student_name=sub.student.full_name if sub.student else None,
        student_email=sub.student.email if sub.student else None,
        submission_type=sub.submission_type,
        content=sub.content,
        file_name=sub.file_name,
        status=sub.status,
        score=score,
        feedback=feedback,
        graded_by_id=sub.graded_by_id,
        grader_name=sub.graded_by.full_name if sub.graded_by else None,
        submitted_at=sub.submitted_at,
        graded_at=sub.graded_at,
        auto_submitted=bool(getattr(sub, "auto_submitted", False)),
        evaluation_metadata=eval_meta,
        needs_review=bool(metadata.get("needs_review", False)),
        triage_reasons=triage_reasons,
        injection_detected=bool(metadata.get("injection_detected", False)),
    )


# ── Student: submit assignment ─────────────────────────

@router.post(
    "/courses/{course_id}/assignments/{aid}/submissions",
    response_model=SubmissionResponse,
    status_code=201,
)
async def submit_assignment(
    course_id: int,
    aid: int,
    body: SubmissionCreate,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        assignment = await _verify_student_assignment(course_id, aid, user, db)
        validate_timed_submission_attempt(
            assignment,
            await _get_timed_attempt(aid, user.id, db),
            allow_expired=False,
        )
        sub = await svc.submit(aid, user.id, body, auto_submitted=False)
        return _to_response(sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/courses/{course_id}/assignments/{aid}/submissions/file",
    response_model=SubmissionResponse,
    status_code=201,
)
async def submit_file(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    assignment = await _verify_student_assignment(course_id, aid, user, db)
    try:
        validate_timed_submission_attempt(
            assignment,
            await _get_timed_attempt(aid, user.id, db),
            allow_expired=False,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    # 3.7: Block dangerous file extensions and sniffed executable/script markup
    file_name = file.filename or "upload"
    file_ext = os.path.splitext(file_name)[1].lower()
    blocked_exts = {".html", ".htm", ".svg", ".js", ".mjs", ".php", ".phtml", ".exe", ".sh", ".bat", ".cmd", ".vbs"}
    if file_ext in blocked_exts:
        raise HTTPException(status_code=400, detail=f"File extension '{file_ext}' is forbidden for submission uploads.")
    content = await file.read(MAX_SUBMISSION_BYTES + 1)
    if len(content) > MAX_SUBMISSION_BYTES:
        raise HTTPException(status_code=413, detail="Submission file exceeds the 25 MB limit.")
    sniff_head = content[:2048].lower()
    if any(tag in sniff_head for tag in [b"<html", b"<script", b"<?php", b"<svg"]):
        raise HTTPException(status_code=400, detail="Uploaded file contains unsafe markup or scripts.")
    svc = SubmissionService(db)
    try:
        sub = await svc.save_file(
            aid,
            user.id,
            content,
            file.filename or "upload",
            auto_submitted=False,
        )
        # Extract text from document (PDF, DOCX, Code, Text) so SpeedGrader and AI grading have it immediately
        if sub.file_path:
            extracted_txt = extract_text_from_submission_file(sub.file_path)
            if extracted_txt:
                sub.content = extracted_txt
            triage_reasons = build_document_triage(extracted_txt, sub.file_path)
            if triage_reasons:
                sub.evaluation_metadata = json.dumps({
                    "needs_review": True,
                    "triage_reasons": triage_reasons,
                    "injection_detected": "injection_detected" in triage_reasons,
                })
            await db.commit()
            await db.refresh(sub)
        return _to_response(sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ── Student: view own submission ───────────────────────

@router.get(
    "/courses/{course_id}/assignments/{aid}/submissions/me",
    response_model=SubmissionResponse,
)
async def get_my_submission(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await _verify_student_assignment(course_id, aid, user, db)
    svc = SubmissionService(db)
    sub = await svc.get_my_submission(aid, user.id)
    if not sub:
        raise HTTPException(status_code=404, detail="No submission found.")
    return _to_response(sub)


# ── Prof/TA: list all submissions ─────────────────────

@router.get(
    "/courses/{course_id}/assignments/{aid}/submissions",
    response_model=SubmissionListResponse,
)
async def list_submissions(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        assignment = await AssignmentService(db).verify_assignment_access(aid, user)
        if assignment.course_id != course_id:
            raise PermissionError("Assignment not found in this course.")
        subs = await svc.list_submissions(aid)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    items = [_to_response(s) for s in subs]
    pending = sum(1 for s in subs if s.status == "pending")
    graded = sum(1 for s in subs if s.status == "graded")
    return SubmissionListResponse(
        submissions=items,
        total=len(items),
        pending_count=pending,
        graded_count=graded,
    )


# ── Prof/TA: grade a submission ────────────────────────

@router.put("/submissions/{sid}/grade", response_model=SubmissionResponse)
async def grade_submission(
    sid: int,
    body: SubmissionGrade,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        submission = await svc.get_submission(sid)
        await AssignmentService(db).verify_assignment_access(submission.assignment_id, user)
        sub = await svc.grade_submission(sid, body, user.id)
        return _to_response(sub)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── Prof/TA: trigger AI rubric-anchored grading ───────

@router.post("/submissions/{sid}/ai-grade")
async def trigger_ai_grading(
    sid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    sync: bool = True,
):
    """Triggers rubric-anchored AI grading via LLM."""
    svc = SubmissionService(db)
    submission = await svc.get_submission(sid)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found.")

    try:
        await AssignmentService(db).verify_assignment_access(submission.assignment_id, user)
    except PermissionError as auth_err:
        raise HTTPException(status_code=403, detail=str(auth_err))

    assignment = await db.get(Assignment, submission.assignment_id)
    if not assignment:
        raise HTTPException(status_code=404, detail="Associated assignment not found.")

    # Fetch rubric criteria
    rubric_res = await db.execute(
        select(Rubric).where(Rubric.assignment_id == assignment.id).options(selectinload(Rubric.criteria))
    )
    rubric = rubric_res.scalar_one_or_none()

    criteria_data = []
    if rubric and rubric.criteria:
        for c in rubric.criteria:
            criteria_data.append({
                "name": c.name,
                "weight": c.weight,
                "max_score": (c.weight / 100.0) * float(assignment.max_marks or 100.0),
            })
    else:
        max_m = float(assignment.max_marks or 100.0)
        criteria_data = [
            {"name": "Technical Accuracy & Methodology", "weight": 50.0, "max_score": max_m * 0.5},
            {"name": "Completeness & Problem Resolution", "weight": 30.0, "max_score": max_m * 0.3},
            {"name": "Clarity & Academic Quality", "weight": 20.0, "max_score": max_m * 0.2},
        ]

    # 3.1: Deterministic MCQ grading
    atype_val = str(getattr(assignment.type, "value", assignment.type) or "").lower()
    if atype_val == "mcq" or (submission.submission_type or "").lower() == "mcq":
        from app.services.grading_pipeline import grade_mcq_submission, apply_late_penalty_if_applicable
        mcq_res = grade_mcq_submission(assignment, submission)
        if submission.status == "graded":
            apply_late_penalty_if_applicable(assignment, submission)
            submission.graded_by_id = user.id
        await db.commit()
        return mcq_res

    # Extract submission text content (supports PDF, DOCX, Code, Text)
    content = submission.content or ""
    if not content and submission.file_path:
        content = extract_text_from_submission_file(submission.file_path)
    if not content:
        triage_reasons = build_document_triage(content, submission.file_path)
        submission.evaluation_metadata = json.dumps({
            "needs_review": True,
            "triage_reasons": triage_reasons or ["blank_or_unreadable"],
            "injection_detected": False,
        })
        await db.commit()
        return {
            "status": "needs_review",
            "mode": "deterministic_triage",
            "submission_id": sid,
            "needs_review": True,
            "triage_reasons": triage_reasons or ["blank_or_unreadable"],
            "injection_detected": False,
            "message": "Human review is required before AI grading.",
        }

    triage_reasons = build_document_triage(content, submission.file_path)
    if triage_reasons:
        submission.evaluation_metadata = json.dumps({
            "needs_review": True,
            "triage_reasons": triage_reasons,
            "injection_detected": "injection_detected" in triage_reasons,
        })
        await db.commit()
        return {
            "status": "needs_review",
            "mode": "deterministic_triage",
            "submission_id": sid,
            "needs_review": True,
            "triage_reasons": triage_reasons,
            "injection_detected": "injection_detected" in triage_reasons,
            "message": "Human review is required before AI grading.",
        }

    # Keep status pending while awaiting evaluation
    await db.commit()

    if sync or getattr(settings, 'CELERY_ALWAYS_EAGER', False):
        try:
            evaluation = _grade_submission_core(
                assignment_title=assignment.title,
                assignment_prompt=assignment.description or assignment.title,
                max_marks=float(assignment.max_marks or 100.0),
                rubric_criteria=criteria_data,
                student_submission_content=content,
                submission_type=submission.submission_type or "text",
            )
            eval_model = getattr(settings, "MODEL_GRADING_PRIMARY", "deepseek-r1-distill-llama-70b")
            submission.score = evaluation.total_score
            from app.services.grading_pipeline import apply_late_penalty_if_applicable
            apply_late_penalty_if_applicable(assignment, submission)
            submission.feedback = evaluation.student_feedback
            submission.status = "graded"
            submission.graded_by_id = user.id
            submission.graded_at = datetime.now(timezone.utc)
            submission.evaluator_model = eval_model
            submission.evaluation_metadata = json.dumps({
                "total_score": submission.score,
                "raw_ai_score": evaluation.total_score,
                "max_marks": evaluation.max_marks,
                "percentage": evaluation.percentage,
                "diagnostic_reasoning": evaluation.diagnostic_reasoning,
                "criteria_evaluations": [c.model_dump() for c in evaluation.criteria_evaluations],
                "highlights": evaluation.highlights,
                "needs_review": evaluation.needs_review,
                "review_reasons": evaluation.review_reasons,
                "student_feedback": evaluation.student_feedback,
                "highlights": evaluation.highlights,
                "evaluator_model": eval_model,
                "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
            })
            await db.commit()
            return {
                "status": submission.status,
                "mode": "synchronous",
                "submission_id": sid,
                "score": submission.score,
                "max_marks": evaluation.max_marks,
                "percentage": evaluation.percentage,
                "feedback": evaluation.student_feedback,
                "diagnostic_reasoning": evaluation.diagnostic_reasoning,
                "criteria_evaluations": [c.model_dump() for c in evaluation.criteria_evaluations],
                "needs_review": evaluation.needs_review,
                "review_reasons": evaluation.review_reasons,
                "evaluator_model": eval_model,
                "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
                "message": "AI grading completed successfully.",
            }
        except PromptInjectionDetected as injection:
            submission.evaluation_metadata = json.dumps({
                "needs_review": True,
                "triage_reasons": ["injection_detected"],
                "injection_detected": True,
                "detector_codes": injection.codes,
            })
            await db.commit()
            return {
                "status": "needs_review",
                "mode": "deterministic_triage",
                "submission_id": sid,
                "needs_review": True,
                "triage_reasons": ["injection_detected"],
                "injection_detected": True,
                "message": "Human review is required before AI grading.",
            }
        except Exception as e:
            logger.error("AI grading failed for submission %d: %s", sid, e, exc_info=True)
            submission.status = "needs_review"
            submission.feedback = "AI grading service temporarily unavailable; routed for manual review."
            submission.evaluation_metadata = json.dumps({
                "needs_review": True,
                "grading_failed": True,
                "error": str(e),
                "review_reasons": ["llm_unavailable_or_timeout"],
            })
            await db.commit()
            return {
                "status": "needs_review",
                "mode": "fallback_manual_review",
                "submission_id": sid,
                "needs_review": True,
                "grading_failed": True,
                "message": "AI grading service temporarily unavailable; submission routed to manual review.",
            }

    # Dispatch asynchronous background task to Celery with fallback
    try:
        task = grade_submission_task.delay(
            submission_id=submission.id,
            assignment_title=assignment.title,
            assignment_prompt=assignment.description or assignment.title,
            max_marks=float(assignment.max_marks or 100.0),
            rubric_criteria=criteria_data,
            student_submission_content=content,
            submission_type=submission.submission_type or "text",
        )
        return {
            "status": "queued",
            "mode": "asynchronous",
            "task_id": task.id,
            "submission_id": sid,
            "queue": "grading_normal",
            "evaluator_model": "deepseek-r1-distill-llama-70b",
            "message": "AI grading task dispatched to background queue.",
        }
    except Exception as dispatch_err:
        logger.warning("Celery dispatch failed (%s); falling back to synchronous evaluation", dispatch_err)
        evaluation = _grade_submission_core(
            assignment_title=assignment.title,
            assignment_prompt=assignment.description or assignment.title,
            max_marks=float(assignment.max_marks or 100.0),
            rubric_criteria=criteria_data,
            student_submission_content=content,
            submission_type=submission.submission_type or "text",
        )
        submission.score = evaluation.total_score
        from app.services.grading_pipeline import apply_late_penalty_if_applicable
        apply_late_penalty_if_applicable(assignment, submission)
        submission.feedback = evaluation.student_feedback
        submission.status = "graded"
        submission.graded_by_id = user.id
        submission.graded_at = datetime.now(timezone.utc)
        submission.evaluator_model = getattr(settings, "MODEL_GRADING_PRIMARY", "deepseek-r1-distill-llama-70b")
        submission.evaluation_metadata = json.dumps({
            "total_score": submission.score,
            "raw_ai_score": evaluation.total_score,
            "max_marks": evaluation.max_marks,
            "percentage": evaluation.percentage,
            "diagnostic_reasoning": evaluation.diagnostic_reasoning,
            "criteria_evaluations": [c.model_dump() for c in evaluation.criteria_evaluations],
            "needs_review": evaluation.needs_review,
            "review_reasons": evaluation.review_reasons,
            "student_feedback": evaluation.student_feedback,
            "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
        })
        await db.commit()
        return {
            "status": submission.status,
            "mode": "synchronous_fallback",
            "submission_id": sid,
            "score": submission.score,
            "max_marks": evaluation.max_marks,
            "percentage": evaluation.percentage,
            "feedback": evaluation.student_feedback,
            "diagnostic_reasoning": evaluation.diagnostic_reasoning,
            "criteria_evaluations": [c.model_dump() for c in evaluation.criteria_evaluations],
            "needs_review": evaluation.needs_review,
            "review_reasons": evaluation.review_reasons,
            "message": "AI grading completed successfully.",
        }


# ── Prof/TA: Batch AI grade all pending submissions ──

@router.post("/courses/{course_id}/assignments/{aid}/ai-grade-all")
async def batch_ai_grade_submissions(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Batch-evaluates all pending submissions for an assignment against the rubric."""
    try:
        assignment = await AssignmentService(db).verify_assignment_access(aid, user)
        ensure_assignment_in_course(course_id, assignment.course_id)
    except PermissionError as auth_err:
        raise HTTPException(status_code=403, detail=str(auth_err))

    # Fetch rubric criteria
    rubric_res = await db.execute(
        select(Rubric).where(Rubric.assignment_id == aid).options(selectinload(Rubric.criteria))
    )
    rubric = rubric_res.scalar_one_or_none()

    criteria_data = []
    max_m = float(assignment.max_marks or 100.0)
    if rubric and rubric.criteria:
        for c in rubric.criteria:
            criteria_data.append({
                "name": c.name,
                "weight": c.weight,
                "max_score": (c.weight / 100.0) * max_m,
            })
    else:
        criteria_data = [
            {"name": "Technical Accuracy & Methodology", "weight": 50.0, "max_score": max_m * 0.5},
            {"name": "Completeness & Problem Resolution", "weight": 30.0, "max_score": max_m * 0.3},
            {"name": "Clarity & Academic Quality", "weight": 20.0, "max_score": max_m * 0.2},
        ]

    # Find all pending/un-graded submissions
    subs_res = await db.execute(
        select(Submission).where(
            Submission.assignment_id == aid,
            Submission.status.in_(["pending", "submitted", "needs_review"]),
        )
    )
    pending_subs = subs_res.scalars().all()
    if not pending_subs:
        return {"graded_count": 0, "message": "No pending submissions to grade."}

    # 3.1: Deterministic MCQ grading for MCQ assignments
    atype_val = str(getattr(assignment.type, "value", assignment.type) or "").lower()
    if atype_val == "mcq":
        from app.services.grading_pipeline import grade_mcq_submission, apply_late_penalty_if_applicable
        mcq_graded = 0
        mcq_errors = []
        for sub in pending_subs[:50]:
            mcq_res = grade_mcq_submission(assignment, sub)
            if sub.status == "graded":
                apply_late_penalty_if_applicable(assignment, sub)
                sub.graded_by_id = user.id
                mcq_graded += 1
            else:
                mcq_errors.append(f"Sub #{sub.id}: {mcq_res.get('message', 'Routed to manual review')}")
        await db.commit()
        return {
            "status": "completed",
            "graded_count": mcq_graded,
            "total_pending": len(pending_subs),
            "errors": mcq_errors,
            "message": f"Successfully auto-graded {mcq_graded} of {len(pending_subs)} MCQ submissions.",
        }

    graded_count = 0
    errors = []
    # 3.4: Per-course batch cap (max 50 per run)
    for sub in pending_subs[:50]:
        # Extract submission text content (PDF, DOCX, Code, Text)
        content = sub.content or ""
        if not content and sub.file_path:
            content = extract_text_from_submission_file(sub.file_path)
        triage_reasons = build_document_triage(content, sub.file_path)
        if triage_reasons:
            sub.evaluation_metadata = json.dumps({
                "needs_review": True,
                "triage_reasons": triage_reasons,
                "injection_detected": "injection_detected" in triage_reasons,
            })
            errors.append(
                f"Sub #{sub.id}: Human review required ({', '.join(triage_reasons)})."
            )
            continue

        try:
            eval_res = _grade_submission_core(
                assignment_title=assignment.title,
                assignment_prompt=assignment.description or assignment.title,
                max_marks=max_m,
                rubric_criteria=criteria_data,
                student_submission_content=content,
                submission_type=sub.submission_type or "text",
            )
            eval_model = getattr(settings, "MODEL_GRADING_PRIMARY", "deepseek-r1-distill-llama-70b")
            sub.score = eval_res.total_score
            from app.services.grading_pipeline import apply_late_penalty_if_applicable
            apply_late_penalty_if_applicable(assignment, sub)
            sub.feedback = eval_res.student_feedback
            sub.status = "graded"
            sub.graded_by_id = user.id
            sub.graded_at = datetime.now(timezone.utc)
            sub.evaluator_model = eval_model
            sub.evaluation_metadata = json.dumps({
                "total_score": sub.score,
                "raw_ai_score": eval_res.total_score,
                "max_marks": eval_res.max_marks,
                "percentage": eval_res.percentage,
                "diagnostic_reasoning": eval_res.diagnostic_reasoning,
                "criteria_evaluations": [c.model_dump() for c in eval_res.criteria_evaluations],
                "needs_review": eval_res.needs_review,
                "review_reasons": eval_res.review_reasons,
                "evaluator_model": eval_model,
                "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
            })
            graded_count += 1
        except PromptInjectionDetected as injection:
            sub.evaluation_metadata = json.dumps({
                "needs_review": True,
                "triage_reasons": ["injection_detected"],
                "injection_detected": True,
                "detector_codes": injection.codes,
            })
            errors.append(f"Sub #{sub.id}: Human review required (injection_detected).")
        except Exception as e:
            logger.error("Batch grading failed for submission %d: %s", sub.id, e)
            sub.status = "needs_review"
            sub.feedback = "AI grading service temporarily unavailable; routed for manual review."
            sub.evaluation_metadata = json.dumps({
                "needs_review": True,
                "grading_failed": True,
                "error": str(e),
                "review_reasons": ["llm_unavailable_or_timeout"],
            })
            errors.append(f"Sub #{sub.id}: Grading failed ({str(e)}); routed to manual review.")

    await db.commit()
    return {
        "status": "completed",
        "graded_count": graded_count,
        "total_pending": len(pending_subs),
        "errors": errors,
        "message": f"Successfully auto-graded {graded_count} of {len(pending_subs)} submissions.",
    }


# ── Download submission file ───────────────────────────

@router.get("/submissions/{sid}/file")
async def download_submission_file(
    sid: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from sqlalchemy import select
    from app.models.submission import Submission
    result = await db.execute(select(Submission).where(Submission.id == sid))
    sub = result.scalar_one_or_none()
    if not sub or not sub.file_path:
        raise HTTPException(status_code=404, detail="File not found.")
    
    # Students can only download their own files; profs/TAs can download any
    if user.role == "student" and sub.student_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    
    if user.role in ("professor", "ta"):
        from app.models.assignment import Assignment
        from app.models.course import Course, Enrollment
        assignment = await db.get(Assignment, sub.assignment_id)
        if not assignment:
            raise HTTPException(status_code=404, detail="Assignment not found.")
        if user.role == "professor":
            course = await db.get(Course, assignment.course_id)
            if not course or course.professor_id != user.id:
                raise HTTPException(status_code=403, detail="Access denied.")
        elif user.role == "ta":
            enroll_res = await db.execute(
                select(Enrollment).where(
                    Enrollment.course_id == assignment.course_id,
                    Enrollment.user_id == user.id,
                    Enrollment.role == "ta"
                )
            )
            if not enroll_res.scalar_one_or_none():
                raise HTTPException(status_code=403, detail="Access denied.")
    path = Path(sub.file_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing from storage.")
    return FileResponse(
        str(path),
        filename=sub.file_name or path.name,
        headers={
            "X-Content-Type-Options": "nosniff",
            "Content-Disposition": f'attachment; filename="{sub.file_name or path.name}"',
        },
    )


# ── Grade Dispute & Appeal Endpoints ─────────────────────────────────

from pydantic import BaseModel, Field
from app.core.dependencies import get_current_user
from app.models.submission import Submission, GradeAppeal


class CreateAppealRequest(BaseModel):
    challenged_criterion: Optional[str] = None
    justification: str = Field(..., min_length=5, max_length=2000)


class ResolveAppealRequest(BaseModel):
    status: str = Field(..., pattern="^(accepted|rejected)$")
    adjusted_score: Optional[float] = None
    professor_feedback: Optional[str] = None


@router.post("/submissions/{sid}/appeal", status_code=status.HTTP_201_CREATED)
async def submit_grade_appeal(
    sid: int,
    payload: CreateAppealRequest,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Allows an enrolled student to appeal their grade for a finalized submission."""
    sub = await db.get(Submission, sid)
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found.")
    if sub.student_id != user.id:
        raise HTTPException(status_code=403, detail="You can only appeal your own submission.")
    if sub.status != "graded":
        raise HTTPException(status_code=400, detail="Only graded submissions can be appealed.")

    existing = await db.execute(
        select(GradeAppeal).where(
            GradeAppeal.submission_id == sid,
            GradeAppeal.status == "pending",
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A grade appeal is already pending review for this submission.")

    appeal = GradeAppeal(
        submission_id=sid,
        student_id=user.id,
        assignment_id=sub.assignment_id,
        challenged_criterion=payload.challenged_criterion,
        justification=payload.justification,
        status="pending",
    )
    db.add(appeal)
    await db.commit()
    await db.refresh(appeal)
    return {
        "id": appeal.id,
        "submission_id": appeal.submission_id,
        "challenged_criterion": appeal.challenged_criterion,
        "justification": appeal.justification,
        "status": appeal.status,
        "created_at": appeal.created_at.isoformat(),
        "message": "Grade appeal submitted successfully."
    }


@router.get("/submissions/{sid}/appeal")
async def get_grade_appeal(
    sid: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Retrieves the latest grade appeal for a submission."""
    sub = await db.get(Submission, sid)
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found.")
    
    if user.role == "student" and sub.student_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied.")

    res = await db.execute(
        select(GradeAppeal)
        .where(GradeAppeal.submission_id == sid)
        .order_by(GradeAppeal.created_at.desc())
        .limit(1)
    )
    appeal = res.scalar_one_or_none()
    if not appeal:
        return None
    return {
        "id": appeal.id,
        "submission_id": appeal.submission_id,
        "student_id": appeal.student_id,
        "challenged_criterion": appeal.challenged_criterion,
        "justification": appeal.justification,
        "status": appeal.status,
        "adjusted_score": appeal.adjusted_score,
        "professor_feedback": appeal.professor_feedback,
        "created_at": appeal.created_at.isoformat() if appeal.created_at else None,
        "resolved_at": appeal.resolved_at.isoformat() if appeal.resolved_at else None,
    }


@router.get("/submissions/assignments/{assignment_id}/appeals")
async def list_assignment_appeals(
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Lists all student appeals for an assignment."""
    from app.models.assignment import Assignment
    assignment = await db.get(Assignment, assignment_id)
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    await AssignmentService(db).verify_assignment_access(assignment_id, user)

    res = await db.execute(
        select(GradeAppeal)
        .where(GradeAppeal.assignment_id == assignment_id)
        .order_by(GradeAppeal.created_at.desc())
    )
    appeals = res.scalars().all()
    results = []
    for a in appeals:
        student_name = a.student.full_name if a.student else "Student"
        student_email = a.student.email if a.student else ""
        sub_score = a.submission.score if a.submission else None
        results.append({
            "id": a.id,
            "submission_id": a.submission_id,
            "student_id": a.student_id,
            "student_name": student_name,
            "student_email": student_email,
            "challenged_criterion": a.challenged_criterion,
            "justification": a.justification,
            "status": a.status,
            "current_score": sub_score,
            "adjusted_score": a.adjusted_score,
            "professor_feedback": a.professor_feedback,
            "created_at": a.created_at.isoformat() if a.created_at else None,
            "resolved_at": a.resolved_at.isoformat() if a.resolved_at else None,
        })
    return results


@router.patch("/submissions/appeals/{appeal_id}")
async def resolve_grade_appeal(
    appeal_id: int,
    payload: ResolveAppealRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Resolves an appeal: either accepts with an adjusted score or rejects."""
    appeal = await db.get(GradeAppeal, appeal_id)
    if not appeal:
        raise HTTPException(status_code=404, detail="Appeal not found.")
    
    await AssignmentService(db).verify_assignment_access(appeal.assignment_id, user)
    
    appeal.status = payload.status
    appeal.professor_feedback = payload.professor_feedback
    appeal.reviewed_by_id = user.id
    appeal.resolved_at = datetime.now(timezone.utc)

    if payload.status == "accepted" and payload.adjusted_score is not None:
        appeal.adjusted_score = payload.adjusted_score
        sub = await db.get(Submission, appeal.submission_id)
        if sub:
            sub.score = payload.adjusted_score
            sub.graded_by_id = user.id
            sub.feedback = (sub.feedback or "") + f"\n\n[Grade Adjusted via Appeal]: {payload.professor_feedback or 'Accepted'}"

    await db.commit()
    await db.refresh(appeal)
    return {
        "id": appeal.id,
        "status": appeal.status,
        "adjusted_score": appeal.adjusted_score,
        "professor_feedback": appeal.professor_feedback,
        "message": f"Appeal {appeal.status} successfully."
    }
