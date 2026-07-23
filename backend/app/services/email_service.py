"""ProfessorOS – Email service (Resend SDK primary, Gmail SMTP fallback).

Backend is selected via EMAIL_BACKEND env var:
  - "resend"  → Resend SDK (primary, recommended)
  - "smtp"    → Gmail SMTP via app password
  - "console" → Print to stdout (dev/test)
"""

import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from app.core.config import get_settings


# ── HTML email templates ───────────────────────────────────────────────────────

def _base_template(title: str, body_html: str) -> str:
    """Wrap content in a responsive, branded HTML email shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>{title}</title>
<style>
  body {{ margin:0; padding:0; background:#0f172a; font-family:'Segoe UI',Arial,sans-serif; }}
  .wrapper {{ max-width:600px; margin:40px auto; background:#1e293b; border-radius:16px;
               border:1px solid #334155; overflow:hidden; }}
  .header {{ background:linear-gradient(135deg,#14b8a6 0%,#6366f1 100%);
              padding:32px 40px; text-align:center; }}
  .header h1 {{ margin:0; color:#fff; font-size:22px; font-weight:700; letter-spacing:.5px; }}
  .header p  {{ margin:6px 0 0; color:rgba(255,255,255,.75); font-size:13px; }}
  .body  {{ padding:36px 40px; color:#cbd5e1; line-height:1.7; }}
  .body h2 {{ margin:0 0 12px; color:#f1f5f9; font-size:18px; }}
  .body p  {{ margin:0 0 16px; font-size:15px; }}
  .btn   {{ display:inline-block; margin:8px 0 24px; padding:14px 32px;
             background:linear-gradient(135deg,#14b8a6,#6366f1); color:#fff !important;
             font-size:15px; font-weight:600; border-radius:10px;
             text-decoration:none; letter-spacing:.3px; }}
  .note  {{ font-size:13px; color:#64748b; border-top:1px solid #334155;
             padding-top:16px; margin-top:8px; }}
  .footer {{ background:#0f172a; padding:20px 40px; text-align:center;
               color:#475569; font-size:12px; }}
</style>
</head>
<body>
<div class="wrapper">
  <div class="header">
    <h1>🎓 ProfessorOS</h1>
    <p>Smart Academic Platform</p>
  </div>
  <div class="body">
    {body_html}
  </div>
  <div class="footer">
    © 2026 ProfessorOS · This email was sent automatically — please do not reply.
  </div>
</div>
</body>
</html>"""


def verification_email_html(full_name: str, verify_url: str) -> str:
    body = f"""
    <h2>Welcome, {full_name}! 👋</h2>
    <p>Thanks for registering. Please verify your email address to activate your account.</p>
    <a href="{verify_url}" class="btn">✅ Verify My Email</a>
    <p class="note">
      This link expires in <strong>24 hours</strong>.<br/>
      If you didn't create an account, you can safely ignore this email.
    </p>"""
    return _base_template("Verify Your Email – ProfessorOS", body)


def reset_password_email_html(full_name: str, reset_url: str) -> str:
    body = f"""
    <h2>Reset Your Password 🔑</h2>
    <p>Hi {full_name}, we received a request to reset the password for your account.</p>
    <a href="{reset_url}" class="btn">🔒 Reset Password</a>
    <p class="note">
      This link expires in <strong>24 hours</strong>.<br/>
      If you didn't request a password reset, please ignore this email — your account is safe.
    </p>"""
    return _base_template("Password Reset – ProfessorOS", body)


def welcome_email_html(full_name: str, role: str) -> str:
    body = f"""
    <h2>You're all set, {full_name}! 🎉</h2>
    <p>Your email has been verified and your <strong>{role.capitalize()}</strong> account is now active.</p>
    <p>You can now sign in and start using ProfessorOS to manage your academic workflow.</p>
    <p class="note">Need help? Contact your system administrator.</p>"""
    return _base_template("Account Activated – ProfessorOS", body)


# ── Email sender implementations ──────────────────────────────────────────────

def _send_via_resend(to: str, subject: str, html: str) -> None:
    """Send via Resend SDK."""
    import resend  # type: ignore

    settings = get_settings()
    resend.api_key = settings.RESEND_API_KEY
    resend.Emails.send({
        "from": settings.EMAIL_FROM,
        "to": to,
        "subject": subject,
        "html": html,
    })


def _send_via_smtp(to: str, subject: str, html: str) -> None:
    """Send via Gmail SMTP using SSL on port 465 (works on Railway)."""
    settings = get_settings()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"ProfessorOS <{settings.EMAIL_FROM}>"
    msg["To"] = to
    msg.attach(MIMEText(html, "html"))

    context = ssl.create_default_context()
    # Use port 465 with SSL (Railway blocks 587/STARTTLS)
    with smtplib.SMTP_SSL(settings.SMTP_HOST, 465, context=context, timeout=15) as server:
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.sendmail(settings.SMTP_USER, to, msg.as_string())


import os

def _send_console(to: str, subject: str, html: str) -> None:
    """Print email metadata to console and save HTML body to a file (development mode)."""
    file_path = os.path.join(os.getcwd(), "latest_email.html")
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(html)
        
    print(f"\n{'='*60}")
    print(f"[EMAIL CONSOLE] To: {to}")
    print(f"   Subject: {subject}")
    print(f"   (Saved full HTML to: {file_path})")
    print(f"{'='*60}\n")


# ── Public API ────────────────────────────────────────────────────────────────

def send_email(to: str, subject: str, html: str) -> None:
    """
    Dispatch an email using the configured backend.
    Silently falls back to console on send failure to avoid blocking auth flows.
    """
    settings = get_settings()
    backend = settings.EMAIL_BACKEND.lower()

    try:
        if backend == "resend":
            _send_via_resend(to, subject, html)
        elif backend == "smtp":
            _send_via_smtp(to, subject, html)
        else:
            _send_console(to, subject, html)
    except Exception as exc:  # pragma: no cover
        # Never crash an auth endpoint due to email failure
        print(f"[EMAIL ERROR] Failed to send to {to} via '{backend}': {exc}")
        _send_console(to, subject, html)


# ── Convenience wrappers ──────────────────────────────────────────────────────

def send_verification_email(to: str, full_name: str, verify_url: str) -> None:
    html = verification_email_html(full_name, verify_url)
    send_email(to, "Verify your ProfessorOS account", html)


def send_password_reset_email(to: str, full_name: str, reset_url: str) -> None:
    html = reset_password_email_html(full_name, reset_url)
    send_email(to, "Reset your ProfessorOS password", html)


def send_welcome_email(to: str, full_name: str, role: str) -> None:
    html = welcome_email_html(full_name, role)
    send_email(to, "Your ProfessorOS account is now active!", html)
