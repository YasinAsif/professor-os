"""ProfessorOS – Assignment & Rubric endpoints (M-02)."""

from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.schemas.assignment import (
    AssignmentCreate, AssignmentListResponse, AssignmentResponse, AssignmentUpdate,
)
from app.schemas.rubric import RubricCreate, RubricResponse
from app.services.assignment_service import AssignmentService
from app.services.course_service import CourseService

router = APIRouter(tags=["Assignments"])


@router.get("/courses/{course_id}/assignments", response_model=AssignmentListResponse)
async def list_assignments(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
):
    course_svc = CourseService(db)
    try:
        # Verify user has access to this course
        await course_svc.get_course_with_access_check(course_id, user)
        
        svc = AssignmentService(db)
        assignments = await svc.list_assignments(course_id, status)
        # Apply pagination
        total = len(assignments)
        start = (page - 1) * page_size
        end = start + page_size
        paginated = assignments[start:end]
        items = []
        for a in paginated:
            resp = AssignmentResponse.model_validate(a)
            resp.clo_ids = [c.id for c in a.clos] if a.clos else []
            resp.has_rubric = a.rubric is not None
            items.append(resp)
        return AssignmentListResponse(assignments=items, total=total)
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/courses/{course_id}/assignments", response_model=AssignmentResponse, status_code=201)
async def create_assignment(
    course_id: int, body: AssignmentCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course_svc = CourseService(db)
    try:
        # Verify user can manage this course
        await course_svc.verify_course_management_access(course_id, user)
        
        svc = AssignmentService(db)
        assignment = await svc.create_assignment(course_id, body)
        resp = AssignmentResponse.model_validate(assignment)
        resp.clo_ids = [c.id for c in assignment.clos] if assignment.clos else []
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.put("/courses/{course_id}/assignments/{aid}", response_model=AssignmentResponse)
async def update_assignment(
    course_id: int, aid: int, body: AssignmentUpdate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course_svc = CourseService(db)
    try:
        # Verify user can manage this course
        await course_svc.verify_course_management_access(course_id, user)
        
        svc = AssignmentService(db)
        assignment = await svc.update_assignment(aid, body)
        resp = AssignmentResponse.model_validate(assignment)
        resp.clo_ids = [c.id for c in assignment.clos] if assignment.clos else []
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/courses/{course_id}/assignments/{aid}/publish", response_model=AssignmentResponse)
async def publish_assignment(
    course_id: int, aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course_svc = CourseService(db)
    try:
        # Verify user can manage this course
        await course_svc.verify_course_management_access(course_id, user)
        
        svc = AssignmentService(db)
        assignment = await svc.publish_assignment(aid)
        resp = AssignmentResponse.model_validate(assignment)
        resp.clo_ids = [c.id for c in assignment.clos] if assignment.clos else []
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.get("/courses/{course_id}/assignments/{aid}", response_model=AssignmentResponse)
async def get_assignment(
    course_id: int, aid: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course_svc = CourseService(db)
    try:
        # Verify user has access to this course
        await course_svc.get_course_with_access_check(course_id, user)
        
        svc = AssignmentService(db)
        assignment = await svc.get_assignment(aid)
        resp = AssignmentResponse.model_validate(assignment)
        resp.clo_ids = [c.id for c in assignment.clos] if assignment.clos else []
        resp.has_rubric = assignment.rubric is not None
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


# ── Rubric endpoints ─────────────────────────────────

@router.get("/assignments/{aid}/rubric", response_model=RubricResponse)
async def get_rubric(
    aid: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = AssignmentService(db)
    rubric = await svc.get_rubric(aid)
    if not rubric:
        raise HTTPException(status_code=404, detail="Rubric not found.")
    resp = RubricResponse.model_validate(rubric)
    resp.total_weight = sum(c.weight for c in rubric.criteria)
    return resp


@router.post("/assignments/{aid}/rubric", response_model=RubricResponse, status_code=201)
async def create_rubric(
    aid: int, body: RubricCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = AssignmentService(db)
    rubric = await svc.create_or_update_rubric(aid, body)
    resp = RubricResponse.model_validate(rubric)
    resp.total_weight = sum(c.weight for c in rubric.criteria)
    return resp


@router.put("/assignments/{aid}/rubric", response_model=RubricResponse)
async def update_rubric(
    aid: int, body: RubricCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = AssignmentService(db)
    rubric = await svc.create_or_update_rubric(aid, body)
    resp = RubricResponse.model_validate(rubric)
    resp.total_weight = sum(c.weight for c in rubric.criteria)
    return resp


@router.delete("/courses/{course_id}/assignments/{aid}")
async def delete_assignment(
    course_id: int, aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delete a draft assignment. Cannot delete published assignments."""
    course_svc = CourseService(db)
    try:
        # Verify user can manage this course
        await course_svc.verify_course_management_access(course_id, user)
        
        svc = AssignmentService(db)
        assignment = await svc.get_assignment(aid)
        if assignment.status != "draft":
            raise HTTPException(status_code=400, detail="Only draft assignments can be deleted.")
        await db.delete(assignment)
        await db.flush()
        return {"message": "Assignment deleted."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.delete("/assignments/{aid}/rubric")
async def delete_rubric(
    aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delete the rubric from an assignment (allows re-creation)."""
    svc = AssignmentService(db)
    rubric = await svc.get_rubric(aid)
    if not rubric:
        raise HTTPException(status_code=404, detail="Rubric not found.")
    await db.delete(rubric)
    await db.flush()
    return {"message": "Rubric deleted."}

