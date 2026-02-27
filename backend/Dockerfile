# ============================================================
# Dockerfile — Backend Pustaka Digital Al-Qur'an (RAG)
# ============================================================
# Multi-stage build untuk image yang lebih kecil.
# Stage 1: Install dependencies.
# Stage 2: Copy source code dan jalankan.
# ============================================================

FROM python:3.12-slim AS base

# Prevent Python from buffering stdout/stderr (penting untuk logging Docker)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# ── Stage: Dependencies ─────────────────────────────────────
FROM base AS dependencies

# Install system dependencies yang dibutuhkan oleh beberapa package Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ── Stage: Application ──────────────────────────────────────
FROM base AS application

# Copy installed packages dari stage dependencies
COPY --from=dependencies /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=dependencies /usr/local/bin /usr/local/bin

# Copy source code
COPY . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

# Jalankan dengan uvicorn
# --host 0.0.0.0 agar bisa diakses dari luar container
# --workers 1 karena embedding model berat di memori
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
