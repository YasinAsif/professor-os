"""ProfessorOS – Submission endpoints."""

from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.schemas.submission import (
    SubmissionCreate, SubmissionGrade, SubmissionResponse, SubmissionListResponse,
)
from app.services.submission_service import SubmissionService
from app.services.assignment_service import AssignmentService

router = APIRouter(tags=["Submissions"])


def _to_response(sub) -> SubmissionResponse:
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
        score=sub.score,
        feedback=sub.feedback,
        graded_by_id=sub.graded_by_id,
        grader_name=sub.graded_by.full_name if sub.graded_by else None,
        submitted_at=sub.submitted_at,
        graded_at=sub.graded_at,
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
        sub = await svc.submit(aid, user.id, body)
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
    content = await file.read()
    svc = SubmissionService(db)
    try:
        sub = await svc.save_file(aid, user.id, content, file.filename or "upload")
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
    path = Path(sub.file_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing from storage.")
    return FileResponse(str(path), filename=sub.file_name or path.name)
