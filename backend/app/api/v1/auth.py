"""ProfessorOS – Auth endpoints (M-01)."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.base import get_db
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest, LoginRequest, MessageResponse, RefreshRequest,
    RegisterRequest, RegisterResponse, ResendVerificationRequest, ResetPasswordRequest, TokenResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=RegisterResponse, status_code=201)
async def register(body: RegisterRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    svc = AuthService(db)
    try:
        user, token = await svc.register(body.email, body.full_name, body.password, body.role)
        return RegisterResponse(
            message="Registration successful. Check your email to verify your account.",
            verification_token=token,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    svc = AuthService(db)
    try:
        access, refresh = await svc.login(body.email, body.password)
        return TokenResponse(access_token=access, refresh_token=refresh)
    except ValueError as e:
        msg = str(e)
        if msg.startswith("UNVERIFIED:"):
            raise HTTPException(status_code=403, detail=msg.replace("UNVERIFIED:", ""))
        raise HTTPException(status_code=401, detail=msg)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    svc = AuthService(db)
    try:
        new_access = await svc.refresh(body.refresh_token)
        return TokenResponse(access_token=new_access, refresh_token=body.refresh_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/logout", response_model=MessageResponse)
async def logout(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = AuthService(db)
    await svc.revoke_all_sessions(user.id)
    return MessageResponse(message="Logged out successfully.")


@router.get("/verify-email", response_model=MessageResponse)
async def verify_email(token: str = Query(...), db: AsyncSession = Depends(get_db)):
    svc = AuthService(db)
    try:
        await svc.verify_email(token)
        return MessageResponse(message="Email verified successfully. You can now sign in.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(
    body: ResendVerificationRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    svc = AuthService(db)
    try:
        await svc.resend_verification(body.email)
        return MessageResponse(message="Verification email sent.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    body: ForgotPasswordRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    svc = AuthService(db)
    await svc.forgot_password(body.email)
    return MessageResponse(message="If an account with that email exists, a reset link has been sent.")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    body: ResetPasswordRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    svc = AuthService(db)
    try:
        await svc.reset_password(body.token, body.new_password)
        return MessageResponse(message="Password updated successfully.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/seed-admin")
async def seed_admin(db: Annotated[AsyncSession, Depends(get_db)]):
    from sqlalchemy import text
    from app.core.security import hash_password
    try:
        res = await db.execute(text("SELECT id FROM users WHERE email='admin@professoros.edu.pk'"))
        if res.fetchone():
            return {"message": "Admin already exists"}
        hashed = hash_password("admin123")
        await db.execute(
            text("INSERT INTO users (email, full_name, hashed_password, role, is_active, is_verified, failed_attempts) VALUES (:email, :name, :hashed, :role, :is_active, :is_verified, 0)"),
            {
                "email": "admin@professoros.edu.pk",
                "name": "System Administrator",
                "hashed": hashed,
                "role": "admin",
                "is_active": True,
                "is_verified": True,
            }
        )
        await db.commit()
        return {"message": "Admin created"}
    except Exception as e:
        return {"error": str(e)}
