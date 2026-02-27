# file test legacy, dipertahankan supaya test lama tetap jalan.
# test suite utama sudah dipindahkan ke app/tests/.
# jalankan semua test: pytest app/tests/ -v

from app.tests.conftest import *  # noqa: F401, F403
from app.tests.test_health import *  # noqa: F401, F403
from app.tests.test_ask import *  # noqa: F401, F403
from app.tests.test_rag_service import *  # noqa: F401, F403