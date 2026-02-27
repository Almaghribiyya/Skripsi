# middleware autentikasi firebase untuk fastapi.
# alur kerjanya: flutter login lewat firebase auth, dapat id token,
# kirim ke backend lewat header authorization bearer, lalu backend
# verifikasi token pakai firebase admin sdk.
# kalau auth_enabled diset false, autentikasi dilewati sepenuhnya
# supaya bisa development tanpa perlu setup firebase.

import logging
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)

# firebase admin sdk diinisialisasi secara lazy, baru jalan saat ada
# request pertama yang butuh verifikasi token
_firebase_app_initialized = False
_security = HTTPBearer(auto_error=False)


def _ensure_firebase_initialized(settings: Settings) -> None:
    """Inisialisasi firebase admin sdk satu kali saja.
    Kalau sudah pernah dipanggil, langsung skip."""
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
            # pakai application default credentials kalau path tidak diisi
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
    """Verifikasi firebase id token dari header authorization.
    Mengembalikan decoded token kalau valid, none kalau auth dinonaktifkan,
    atau raise http 401 kalau token tidak valid atau kedaluwarsa."""

    # kalau auth dinonaktifkan, langsung lewat tanpa cek token
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
        # bedakan pesan error supaya user tahu harus ngapain
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
