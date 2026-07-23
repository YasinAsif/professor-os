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
from app.services.email_service import _try_smtp
from app.core.config import get_settings
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


@router.get("/test-email")
async def test_email_sync(email: str = Query(...)):
    """Temporary endpoint to debug production email sending."""
    settings = get_settings()
    import smtplib
    import ssl
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText

    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        return {"status": "error", "reason": "Missing SMTP credentials in environment."}

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Production SMTP Test"
    msg["From"] = f"ProfessorOS <{settings.EMAIL_FROM}>"
    msg["To"] = email
    msg.attach(MIMEText("<h1>Test</h1>", "html"))

    context = ssl.create_default_context()
    logs = []

    # Try 465
    try:
        with smtplib.SMTP_SSL(settings.SMTP_HOST, 465, context=context, timeout=5) as server:
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_USER, email, msg.as_string())
            logs.append("465 SSL Success")
            return {"status": "success", "backend": settings.EMAIL_BACKEND, "user": settings.SMTP_USER, "logs": logs}
    except Exception as exc:
        logs.append(f"465 SSL Failed: {exc}")

    # Try 587
    try:
        with smtplib.SMTP(settings.SMTP_HOST, 587, timeout=5) as server:
            server.starttls(context=context)
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_USER, email, msg.as_string())
            logs.append("587 STARTTLS Success")
            return {"status": "success", "backend": settings.EMAIL_BACKEND, "user": settings.SMTP_USER, "logs": logs}
    except Exception as exc:
        logs.append(f"587 STARTTLS Failed: {exc}")

    return {"status": "error", "backend": settings.EMAIL_BACKEND, "user": settings.SMTP_USER, "logs": logs}


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
