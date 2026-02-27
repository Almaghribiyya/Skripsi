"""
Firebase Authentication Middleware untuk FastAPI.

Mekanisme:
  - Frontend (Flutter) login via Firebase Auth → mendapat ID Token.
  - Token dikirim ke backend via header `Authorization: Bearer <token>`.
  - Backend memverifikasi token menggunakan Firebase Admin SDK.
  - Jika valid, request dilanjutkan dengan informasi user ter-inject.
  - Jika tidak valid/expired, kembalikan 401 Unauthorized.

Keputusan arsitektural:
  - AUTH_ENABLED=false memungkinkan development tanpa Firebase.
  - Dependency injection via FastAPI `Depends()` — clean & testable.
"""

import logging
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)

# Lazy-init Firebase Admin SDK (hanya saat dibutuhkan)
_firebase_app_initialized = False
_security = HTTPBearer(auto_error=False)


def _ensure_firebase_initialized(settings: Settings) -> None:
    """Inisialisasi Firebase Admin SDK sekali saat pertama kali dipanggil."""
    global _firebase_app_initialized
    if _firebase_app_initialized:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials as fb_credentials

        if settings.firebase_credentials_path:
            cred = fb_credentials.Certificate(settings.firebase_credentials_path)
            firebase_admin.initialize_app(cred)
        else:
            # Gunakan Application Default Credentials (ADC)
            firebase_admin.initialize_app()

        _firebase_app_initialized = True
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error("Gagal inisialisasi Firebase Admin SDK: %s", str(e))
        raise


async def verify_firebase_token(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_security),
    settings: Settings = Depends(get_settings),
) -> Optional[dict]:
    """
    FastAPI dependency untuk memverifikasi Firebase ID Token.

    Returns:
        dict berisi decoded token (uid, email, dll) jika valid.
        None jika auth dinonaktifkan (AUTH_ENABLED=false).

    Raises:
        HTTPException 401 jika token tidak valid atau expired.
    """
    # Bypass auth jika dinonaktifkan (development mode)
    if not settings.auth_enabled:
        return None

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token autentikasi tidak ditemukan. Silakan login terlebih dahulu.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    try:
        _ensure_firebase_initialized(settings)
        from firebase_admin import auth as fb_auth

        decoded_token = fb_auth.verify_id_token(token)
        logger.info("Token valid untuk user: %s", decoded_token.get("uid", "unknown"))
        return decoded_token

    except Exception as e:
        error_msg = str(e).lower()
        if "expired" in error_msg:
            detail = "Token telah kedaluwarsa. Silakan login ulang."
        elif "invalid" in error_msg or "decode" in error_msg:
            detail = "Token tidak valid."
        else:
            detail = "Gagal memverifikasi token autentikasi."

        logger.warning("Firebase token verification failed: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )
