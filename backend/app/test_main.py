"""
Legacy test file — dipertahankan untuk backward compatibility.
Test suite utama telah dipindahkan ke app/tests/.

Jalankan semua test:
  pytest app/tests/ -v
"""

from app.tests.conftest import *  # noqa: F401, F403
from app.tests.test_health import *  # noqa: F401, F403
from app.tests.test_ask import *  # noqa: F401, F403
from app.tests.test_rag_service import *  # noqa: F401, F403