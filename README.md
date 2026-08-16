# ProfessorOS — Smart Academic Management Platform

> **Final Year Project (FYP) — Module 1 Evaluation & Technical Milestone**  
> *A purpose-built academic management system tailored for Pakistani universities and HEC Outcome-Based Education (OBE) compliance.*

---

## 📌 Project Overview

**ProfessorOS** is a cross-platform academic management system designed to streamline course administration, assignment grading workflows, and HEC Outcome-Based Education (OBE) compliance for universities. It bridges the gap between traditional Learning Management Systems (LMS) and accreditation standards by embedding Course Learning Outcomes (CLOs) directly into assignments and grading rubrics.

### Key Capabilities
- 🔐 **Zero-Trust Multi-Role Authentication:** Argon2id password hashing, dual JWT tokens (Access + Refresh), and 4-tier Role-Based Access Control (`Admin`, `Professor`, `Teaching Assistant (TA)`, `Student`).
- 📚 **Course & Roster Management:** Dynamic course creation, cryptographically generated 6-character hex join codes (`JOIN_CODE`), student self-enrolment, and bulk CSV roster onboarding.
- 🎯 **HEC Outcome-Based Education (OBE):** Direct mapping of assignment rubric criteria to HEC Course Learning Outcomes (CLOs).
- 📊 **Real-time Cohort Analytics:** Statistical metrics (Mean, Median, StdDev), automated HEC letter grade conversion, At-Risk student detection ($\theta = 50\%$), and server-side PDF report exports.
- 🎨 **"Marginalia" Design System:** Clean paper-and-ink visual aesthetic inspired by academic journals, featuring adaptive responsive layouts (Desktop Ledger Rail vs Mobile Bottom Navigation).

---

## 🏗️ System Architecture & Tech Stack

ProfessorOS is built on a modern, decoupled 3-tier architecture:

```
  ┌──────────────────────────────────────────────────────────┐
  │              Flutter Cross-Platform Client               │
  │           (Web App & Native Android APK)                 │
  └────────────────────────────┬─────────────────────────────┘
                               │ HTTPS / REST JSON API
                               ▼
  ┌──────────────────────────────────────────────────────────┐
  │              FastAPI Asynchronous Backend                │
  └──────────────┬─────────────────────────────┬─────────────┘
                 │                             │
       Async DB  │                             │ Cache-Aside
       Connection│                             │ Fallback
                 ▼                             ▼
  ┌────────────────────────────┐ ┌───────────────────────────┐
  │   PostgreSQL 16 Database   │ │    Redis Cache Engine     │
  │(Relational Grade Integrity)│ │  (Sub-5ms Dashboards)     │
  └────────────────────────────┘ └───────────────────────────┘
```

### Technology Breakdown

| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Frontend** | **Flutter (Dart 3.5)** | Single unified codebase for Web and Android APK (`professor-os.apk`), direct native compilation, and adaptive UI layouts. |
| **Backend** | **FastAPI (Python 3.11+)** | Native `asyncio` event loop, Pydantic v2 data safety, sub-second execution, and auto-generated OpenAPI (Swagger) docs. |
| **Database** | **PostgreSQL 16** | Strict ACID transactional guarantees for grade records and version-controlled schema migrations via **Alembic**. |
| **ORM** | **SQLAlchemy 2.0 Async** | Non-blocking database queries via `asyncpg` drivers. |
| **Cache & Worker** | **Redis 7 + Celery** | Sub-5ms response caching for dashboard queries; Celery background workers for bulk CSV processing and PDF generation. |
| **Security** | **Argon2id + JWT** | Memory-hard password hashing (`64MB` RAM cost) and dual JWT bearer token authentication. |

---

## 📁 Repository Folder Structure

```
FYP_YASIN/
├── backend/                  # FastAPI Python Asynchronous Backend Engine
│   ├── app/
│   │   ├── api/v1/           # REST API Route Controllers (auth, courses, assignments, analytics, submissions, users)
│   │   ├── core/             # Security (Argon2id, JWT), Config & Role Dependencies
│   │   ├── db/               # SQLAlchemy Async Engine, Base Models & Session Management
│   │   ├── models/           # Database Entities (User, Course, Assignment, Rubric, Submission, Analytics)
│   │   ├── schemas/          # Pydantic v2 Request/Response Data Schemas
│   │   ├── services/         # Business Logic & CRUD Services (CourseService, AssignmentService, etc.)
│   │   ├── tasks/            # Celery Worker Background Tasks (CSV Import, Email Dispatch)
│   │   └── main.py           # FastAPI Main Application Entrypoint & Static File Router
│   ├── alembic/              # Database Schema Migration Scripts
│   ├── Dockerfile            # Production Docker Build Configuration
│   └── requirements.txt      # Backend Python Dependencies
│
├── frontend/                 # Flutter Cross-Platform Client Application
│   ├── lib/
│   │   ├── main.dart         # Flutter Main Entrypoint (Path URL Strategy)
│   │   ├── app.dart          # GoRouter Navigation & ProviderScope Configuration
│   │   ├── core/             # "Marginalia" Palette Theme Tokens & Network Interceptors
│   │   ├── shared/           # Reusable UI Components (Cards, Badges, Confirmation Sheets, Shimmers)
│   │   └── features/         # Feature-First Modular Structure (Data, Presentation, Providers)
│   │       ├── auth/         # Login, Registration, Token Secure Storage
│   │       ├── courses/      # Course Creation Wizard, Join Code, Roster & CSV Import
│   │       ├── analytics/    # Cohort Performance Charts & PDF Export Trigger
│   │       └── admin/        # System Administration & Semester Management
│   ├── web/                  # Flutter Web Entrypoint & index.html
│   ├── android/              # Native Android App Build Pipeline
│   └── pubspec.yaml          # Flutter Package Dependencies
│
├── docs/                     # Documentation & Defense Reference Guides
│   ├── presentation_deck_9_slides.md  # Official 9-Slide Committee Presentation Deck
│   └── evaluation_criteria_defense.md # Rubric Defense & System Strategy Guide
│
├── testing_assignment/       # Automated Software Testing Suite (CO-5 Verification)
│   ├── tests/                # Pytest & Selenium Automated Test Cases (TC-01 to TC-10)
│   ├── run_real_tests.py     # Selenium Automated Browser Test Runner
│   ├── report.html           # Generated HTML Test Execution Report
│   └── selenium_test_report.md # IEEE-829 Software Test Report Document
│
├── evaluation_artifacts/     # Stored Proof & Proof-of-Concept Deliverables
├── docker-compose.yml        # Docker Multi-Container Deployment (FastAPI, Postgres, Redis, Celery)
├── professor-os.apk          # Compiled Android Native Application Binary (26.5 MB)
├── BRANDING_CONTEXT.md       # "Marginalia" Design System Brand Specification
└── DESIGN_SYSTEM.md          # UI Tokens, Color Schemes & Typography Layout Rules
```

---

## ⚡ Quick Start & Deployment Guide

### Option 1: Running with Docker Compose (Recommended)

To spin up the full stack (FastAPI Backend, PostgreSQL 16, Redis, Celery Worker, and Flutter Web):

```bash
# 1. Clone repository & copy environment variables
cp .env.example .env

# 2. Launch all services via Docker Compose
docker-compose up --build -d

# 3. Access Application & Docs
# Frontend App: http://localhost:8000
# OpenAPI Docs: http://localhost:8000/docs
# Health Check: http://localhost:8000/health
```

### Option 2: Running Backend Locally (Development)

```bash
# 1. Navigate to backend directory
cd backend

# 2. Create and activate virtual environment
python -m venv .venv
# On Windows:
.venv\Scripts\activate
# On Linux/macOS:
source .venv/bin/activate

# 3. Install backend dependencies
pip install -r requirements.txt

# 4. Start local Uvicorn dev server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Option 3: Running Frontend Locally (Flutter)

```bash
# 1. Navigate to frontend directory
cd frontend

# 2. Fetch Flutter packages
flutter pub get

# 3. Run Flutter Web app
flutter run -d chrome
```

---

## 🧪 Software Testing & Verification (CO-5)

Our automated test suite verifies 10 core test cases covering positive authentication, invalid input rejections, boundary empty fields, semester creation, and date boundary limits:

```bash
# Execute automated Pytest API suite
cd testing_assignment
pytest -v

# Run Selenium Browser Automation Suite against live deployment
python run_real_tests.py
```

- **Pass Rate:** 100% (10 Passed / 0 Failed).
- **Execution Report:** [`testing_assignment/report.html`](file:///e:/FYP_YASIN/testing_assignment/report.html)
- **Screenshot Evidence:** `testing_assignment/success_login.png`, `failed_login.png`, `success_add_semester.png`.

---

## 👥 Project Team & Supervisors

- **Department:** Department of Computer Science & Software Engineering
- **Team Members:**
  - **Yasin Asif** (BSSE-23S-0036) — *Lead Backend & Architecture*
  - **Fahim** (BSSE-23S-0033) — *Frontend & UI/UX*
  - **Rayyan** — *QA & Testing Specialist*
- **Project Supervisors:**
  - Ms. Habib-un-Nisa
  - Mr. Muhammad Shaban Qabil
