"""ProfessorOS – Admin user management endpoints (M-01)."""

from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.schemas.user import (
    CSVImportResult, ChangePasswordRequest, UserListResponse,
    UserResponse, UserStatusUpdate, UserUpdateRequest,
)
from app.core.security import hash_password, verify_password
from app.services.user_service import UserService

router = APIRouter(tags=["Users"])


# ── Current user profile ──────────────────────────────

@router.get("/users/me", response_model=UserResponse)
async def get_me(user: Annotated[User, Depends(get_current_user)]):
    return user


@router.put("/users/me", response_model=UserResponse)
async def update_me(
    body: UserUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if body.full_name:
        user.full_name = body.full_name
    await db.flush()
    return user


@router.put("/users/me/password")
async def change_password(
    body: ChangePasswordRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if not verify_password(body.old_password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    user.hashed_password = hash_password(body.new_password)
    await db.flush()
    return {"message": "Password changed successfully."}


@router.delete("/users/me/sessions")
async def sign_out_all(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from app.services.auth_service import AuthService
    svc = AuthService(db)
    await svc.revoke_all_sessions(user.id)
    return {"message": "Signed out from all devices."}


# ── Admin endpoints ───────────────────────────────────

@router.get("/admin/users", response_model=UserListResponse)
async def list_users(
    user: Annotated[User, Depends(require_roles("admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    role: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
):
    svc = UserService(db)
    users, total = await svc.list_users(page, page_size, role, search)
    return UserListResponse(
        users=[UserResponse.model_validate(u) for u in users],
        total=total, page=page, page_size=page_size,
    )


@router.post("/admin/users/import", response_model=CSVImportResult)
async def import_users_csv(
    user: Annotated[User, Depends(require_roles("admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    content = await file.read()
    svc = UserService(db)
    return await svc.import_csv(content)


@router.patch("/admin/users/{user_id}/status", response_model=UserResponse)
async def update_user_status(
    user_id: int,
    body: UserStatusUpdate,
    admin: Annotated[User, Depends(require_roles("admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = UserService(db)
    try:
        updated = await svc.update_status(user_id, body.is_active)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    admin: Annotated[User, Depends(require_roles("admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = UserService(db)
    try:
        await svc.delete_user(user_id)
        return {"message": "User deleted."}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
