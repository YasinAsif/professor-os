# ProfessorOS Environment Configuration Guide

This document catalogs every environment variable consumed across the ProfessorOS backend and Celery workers, their locations of use, safe defaults for local development, and required values for production deployments.

---

## 1. Core Security & Authentication

| Variable | Location | Default / Dev Value | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `ENVIRONMENT` | `backend/app/config/settings.py` | `development` | `production` | Switches strict security validation, cookie attributes, and error verbosity. |
| `DEBUG` | `backend/app/config/settings.py` | `True` | `False` | Must be `False` in production; prevents sensitive exception stack trace leakage. |
| `JWT_SECRET_KEY` | `backend/app/config/settings.py` | Dev default string (>=32 chars) | High-entropy random 64-char string | Used to sign and verify HMAC-SHA256 access and refresh tokens. Startup fails if default key is used in production. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `backend/app/config/settings.py` | `60` | `60` | Token lifetime; lowered to 60 minutes for security posture. Transparent refresh handles active sessions. |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `backend/app/config/settings.py` | `7` | `7` | Refresh token lifespan stored in HttpOnly cookies and database session revocation ledger. |
| `INITIAL_ADMIN_EMAIL` | `backend/app/config/settings.py` | `admin@professoros.com` | Verified institution admin email | Superadmin seeded on bootstrap if table is empty. |
| `INITIAL_ADMIN_PASSWORD` | `backend/app/config/settings.py` | Weak dev pass | >= 14 char strong passphrase | Seed password for initial admin; startup rejects weak passwords in production. |
| `ALLOWED_ORIGINS` | `backend/app/config/settings.py` | `http://localhost:3000,...` | Explicit web app origin(s) | CORS origin allowlist. Wildcard `*` is strictly forbidden in production. |

---

## 2. Databases & Queues

| Variable | Location | Default / Dev Value | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `DATABASE_URL` | `backend/app/config/settings.py` | `postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os` | Valid Postgres URI with secure password | Primary PostgreSQL connection string. Refuses default `postgres:postgres` in production. |
| `REDIS_URL` | `backend/app/config/settings.py` | `redis://localhost:6379/0` | Secure Redis instance / cluster | Used for Celery broker, token blacklisting, and transient rate-limit counters. |
| `TEST_PG_URL` | `backend/tests/test_phase4_deploy.py` | Unset (skipped) | Dedicated scratch Postgres URI | Opt-in marker (`@pytest.mark.pg`) for live Postgres concurrency and partial index tests. |

---

## 3. Background Services & Monitoring

| Variable | Location | Default / Dev Value | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `TESTING` | `backend/tests/conftest.py` | Unset in prod (`1` in tests) | Must remain unset | When set to `1` or `true`, disables background daemons (such as the exam monitor) during test runs. |
| `HEARTBEAT_TIMEOUT_SECONDS` | `backend/app/api/v1/exams.py` | `30` | `30` | Heartbeat silence threshold before flagging an active exam attempt as offline. |
| `DEFAULT_GRACE_SECONDS` | `backend/app/api/v1/exams.py` | `120` | `120` | Server-side grace period added to exam time limit before auto-closing attempts. |

---

## 4. Email Dispatching & Notifications

| Variable | Location | Default / Dev Value | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `EMAIL_BACKEND` | `backend/app/config/settings.py` | `console` | `resend` or `smtp` | Controls delivery engine (`resend`, `smtp`, or `console`). Gracefully handles missing SMTP credentials without crashing. |
| `EMAIL_FROM` | `backend/app/config/settings.py` | `noreply@professoros.com` | Verified domain sender | `From` header on verification and alert emails. |
| `RESEND_API_KEY` | `backend/app/config/settings.py` | `""` | Valid Resend API Key | Required if `EMAIL_BACKEND=resend`. |
| `SMTP_HOST` | `backend/app/config/settings.py` | `smtp.gmail.com` | Production SMTP relay host | Required if `EMAIL_BACKEND=smtp`. |
| `SMTP_USER` | `backend/app/config/settings.py` | `""` | Authorized SMTP user | Username for authenticated SMTP dispatch. |
| `SMTP_PASSWORD` | `backend/app/config/settings.py` | `""` | SMTP App Password / secret | Password for authenticated SMTP dispatch. |

---

## 5. AI, Vector Store & Embeddings

| Variable | Location | Default / Dev Value | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `ENABLE_PYTORCH_EMBEDDINGS` | `backend/app/services/document_ingestion.py` | `False` | `False` (or `True` if GPU available) | When `False`, uses lightweight `HashingVectorizer` (keyword retrieval) to minimize memory footprint. Set to `True` only when PyTorch and sentence-transformers model weights are provisioned. |
| `MODEL_RAG_PRIMARY` | `backend/app/config/settings.py` | `gemini-1.5-flash` | Configured active model | Model identifier used for course syllabus RAG and student QA. |
| `GEMINI_API_KEY` | `backend/app/config/settings.py` | `""` | Google AI Studio Key | Primary LLM key for grading and conversational chat. |
| `OPENAI_API_KEY` | `backend/app/config/settings.py` | `""` | OpenAI API Key | Fallback LLM provider key. |
| `ANTHROPIC_API_KEY` | `backend/app/config/settings.py` | `""` | Anthropic API Key | Secondary fallback LLM provider key. |
