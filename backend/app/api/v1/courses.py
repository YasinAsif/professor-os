"""ProfessorOS – Course endpoints (M-02)."""

from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.schemas.course import (
    CLOCreate, CLOResponse, CourseCreate, CourseListResponse, CourseResponse,
    CourseUpdate, EnrollRequest, EnrollmentResponse, CourseJoinRequest,
)
from app.services.course_service import CourseService

router = APIRouter(prefix="/courses", tags=["Courses"])


@router.get("", response_model=CourseListResponse)
async def list_courses(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    courses = await svc.list_courses(user)
    items = []
    for c in courses:
        resp = CourseResponse.model_validate(c)
        resp.professor_name = c.professor.full_name if c.professor else None
        resp.enrollment_count = len(c.enrollments) if c.enrollments else 0
        resp.assignment_count = len(c.assignments) if c.assignments else 0
        items.append(resp)
    return CourseListResponse(courses=items, total=len(items))


@router.post("", response_model=CourseResponse, status_code=201)
async def create_course(
    body: CourseCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        course = await svc.create_course(body, user.id)
        return CourseResponse.model_validate(course)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{course_id}", response_model=CourseResponse)
async def get_course(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        course = await svc.get_course(course_id)
        resp = CourseResponse.model_validate(course)
        resp.professor_name = course.professor.full_name if course.professor else None
        resp.enrollment_count = len(course.enrollments) if course.enrollments else 0
        resp.assignment_count = len(course.assignments) if course.assignments else 0
        return resp
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.put("/{course_id}", response_model=CourseResponse)
async def update_course(
    course_id: int, body: CourseUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        course = await svc.update_course(course_id, body, user)
        return CourseResponse.model_validate(course)
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.delete("/{course_id}")
async def archive_course(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        await svc.archive_course(course_id, user)
        return {"message": "Course archived."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


# ── Enrollment ────────────────────────────────────────

@router.get("/{course_id}/enrollments", response_model=list[EnrollmentResponse])
async def list_enrollments(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    enrollments = await svc.list_enrollments(course_id)
    items = []
    for e in enrollments:
        resp = EnrollmentResponse.model_validate(e)
        resp.user_name = e.user.full_name if e.user else None
        resp.user_email = e.user.email if e.user else None
        items.append(resp)
    return items


@router.post("/{course_id}/enroll", response_model=EnrollmentResponse, status_code=201)
async def enroll_user(
    course_id: int, body: EnrollRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        enrollment = await svc.enroll_user(course_id, body.user_id, body.role)
        return EnrollmentResponse.model_validate(enrollment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/join", response_model=EnrollmentResponse, status_code=201)
async def join_course(
    body: CourseJoinRequest,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        enrollment = await svc.join_course(user.id, body.join_code)
        resp = EnrollmentResponse.model_validate(enrollment)
        resp.user_name = user.full_name
        resp.user_email = user.email
        return resp
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{course_id}/enroll/{uid}")
async def remove_enrollment(
    course_id: int, uid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        await svc.remove_enrollment(course_id, uid)
        return {"message": "Enrollment removed."}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{course_id}/enroll/csv")
async def enroll_csv(
    course_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    content = await file.read()
    svc = CourseService(db)
    return await svc.import_enrollments_csv(course_id, content)


# ── CLOs ──────────────────────────────────────────────

@router.get("/{course_id}/clos", response_model=list[CLOResponse])
async def list_clos(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    clos = await svc.list_clos(course_id)
    return [CLOResponse.model_validate(c) for c in clos]


@router.post("/{course_id}/clos", response_model=CLOResponse, status_code=201)
async def create_clo(
    course_id: int, body: CLOCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    clo = await svc.create_clo(course_id, body.code, body.description)
    return CLOResponse.model_validate(clo)


@router.delete("/{course_id}/clos/{clo_id}")
async def delete_clo(
    course_id: int, clo_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        await svc.delete_clo(course_id, clo_id)
        return {"message": "CLO deleted."}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{course_id}/ta", response_model=EnrollmentResponse, status_code=201)
async def delegate_ta(
    course_id: int, body: EnrollRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delegate TA role to a user for a course."""
    svc = CourseService(db)
    try:
        enrollment = await svc.enroll_user(course_id, body.user_id, role="ta")
        resp = EnrollmentResponse.model_validate(enrollment)
        resp.user_name = enrollment.user.full_name if enrollment.user else None
        resp.user_email = enrollment.user.email if enrollment.user else None
        return resp
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

