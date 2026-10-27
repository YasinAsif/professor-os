# ProfessorOS Technical Limits & Architecture Boundaries

This document details explicit technical limits, platform boundaries, security models, and environmental constraints of ProfessorOS.

---

## 1. Operating System & Browser Proctoring Boundaries

- **Alt-Tab, Windows Key, and Task Switching**:
  Web-based applications running inside standard desktop browsers cannot physically block or intercept OS-level global key chords (such as `Alt + Tab`, `Super / Windows Key`, `Ctrl + Alt + Delete`, or macOS `Cmd + Tab`). ProfessorOS tracks window blur and HTML5 `visibilitychange` events and records them as focus loss violations rather than attempting kernel-level interception.
- **Second Physical Displays & External Monitors**:
  While the experimental Multi-Screen Window Placement API (`window.getScreenDetails()`) is queried when supported (Chrome/Edge desktop), web browsers cannot physically detect untracked external HDMI capture cards, secondary monitors disconnected from the browser viewport, splitters, or external mobile devices / smartphones placed next to the screen.
- **Virtual Machines & RDP Sessions**:
  Web browsers cannot reliably detect whether they are running inside a nested Virtual Machine (VMware, VirtualBox, QEMU) or a remote desktop session (RDP, VNC, AnyDesk) without native kernel agent extensions.
- **iOS & Mobile Safari**:
  Apple Safari on iOS does not support the HTML5 Fullscreen API on standard `<div>` elements (`document.documentElement.requestFullscreen`). Fullscreen focus lock is unavailable on iOS devices; on mobile devices, focus loss and visibility change tracking remain active, but fullscreen enforcement is bypassed under the `warn_allow` policy.
- **Keyboard Lock (Escape Key Lock)**:
  `navigator.keyboard.lock(['Escape'])` is an experimental API supported exclusively in Chromium-based desktop browsers (Google Chrome, Microsoft Edge) running under an active fullscreen context with user gesture activation. On Firefox, Safari, and Linux/macOS environments with system-level override shortcuts, holding `Escape` will exit browser fullscreen, triggering the fullscreen exit overlay.
- **Webcam & Biometric Continuous Proctoring**:
  ProfessorOS does NOT perform continuous automated webcam video streaming, gaze tracking, audio capture, or room scanning. Identity verification is one-time upfront device biometrics via `local_auth` (Fingerprint / Face ID / Windows Hello) or instructor bypass.

---

## 2. Artificial Intelligence & RAG Retrieval

- **Default Keyword Search (Hashing Vectorizer)**:
  By default, `ENABLE_PYTORCH_EMBEDDINGS` is set to `False` to maintain a lightweight, production-stable memory footprint. Course document retrieval and student chat utilize scikit-learn/scipy `HashingVectorizer` (fast keyword-based lexical retrieval). Dense vector neural embeddings (via `sentence-transformers` and FAISS) require enabling `ENABLE_PYTORCH_EMBEDDINGS=True` and provisioning adequate RAM and CPU/GPU resources.
- **Model Availability & Fallbacks**:
  If external LLM APIs (Gemini Studio, OpenAI, Anthropic) experience outages or rate limiting, the platform gracefully degrades: auto-grading sets submission status to `needs_review` with `grading_failed=True` without losing student answers, and RAG course chat returns a clear "Service temporarily unavailable" message instead of hallucinating answers.

---

## 3. Database & Concurrency

- **Database Engine Parity**:
  All standard test suites execute against async SQLite (`sqlite+aiosqlite:///:memory:` or WAL-mode temporary databases) for deterministic CI speed and developer isolation. Production deployments require PostgreSQL 16+ to enforce the partial unique index (`uq_active_attempt_per_student_assignment`) and transactional row-level locks (`SELECT ... FOR UPDATE`).
- **Postgres Marker Execution**:
  Live multi-worker concurrency tests against physical PostgreSQL instances are opt-in and executed via `pytest -m pg` when `TEST_PG_URL` is provisioned.
- **Notifications & Real-Time WebSockets**:
  Live real-time push announcements and institutional broadcast channels are not implemented; live proctoring updates rely on 10–15s client-to-server heartbeat and polling sync.

---

## 4. Decommissioned Features (Scope Cleanup)

- **AI Question Generation & Bloom's Quality Gate**:
  Autonomous LLM question generation and real-time Bloom's cognitive distribution validation gates were decommissioned to focus on human-authored question banks, manual assessments, and reliable auto-grading.
- **HEC Dossier & CLO Attainment Export**:
  Aggregated institutional PDF accreditation dossiers and batch CLO attainment calculations were removed from the API and frontend navigation; course CLO labels and student performance metrics remain accessible via direct Gradebook CSV export.
- **Cloud Infrastructure Target**:
  Default cloud deployment configuration is standardized to Microsoft Azure App Service (`https://professoros.azurewebsites.net`), removing legacy Railway deployment configurations.
