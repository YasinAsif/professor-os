# Stage 1: Build Flutter Web frontend
FROM ghcr.io/cirruslabs/flutter:3.24.3 AS flutter-builder
WORKDIR /app/frontend
COPY frontend/pubspec.* ./
RUN flutter pub get
COPY frontend/ .
RUN flutter build web --release

# Stage 2: Python backend
FROM python:3.12-slim

# System dependencies for weasyprint, pymupdf, psycopg2, and asyncpg
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    libffi-dev \
    shared-mime-info \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python backend dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy complete backend code
COPY backend/ .

# Copy compiled Flutter web assets from builder stage
COPY --from=flutter-builder /app/frontend/build/web /app/static

ENV PORT=8000
EXPOSE 8000

# Run migrations automatically on startup before booting uvicorn
CMD sh -c "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"
