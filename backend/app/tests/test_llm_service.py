# test untuk LLMService — fallback chain dan prompt selection.
# semua LLM di-mock, tidak butuh API key atau koneksi ke Gemini.

from unittest.mock import MagicMock, patch, PropertyMock
import pytest

from app.config import Settings
from app.services.llm_service import LLMService, FALLBACK_MESSAGE


def _make_settings() -> Settings:
    """Settings dummy untuk testing."""
    return Settings(
        gemini_api_key="test-key",
        llm_primary_model="gemini-2.5-flash",
        llm_fallback_model="gemini-2.0-flash",
        llm_temperature=0.3,
        auth_enabled=False,
        _env_file=None,
    )


@patch("app.services.llm_service.ChatGoogleGenerativeAI")
def test_primary_model_success(mock_chat_class):
    """Kalau primary model berhasil, jawabannya langsung dikembalikan."""
    mock_primary = MagicMock()
    mock_primary.invoke.return_value = MagicMock(content="Jawaban primary.")

    mock_fallback = MagicMock()

    # ChatGoogleGenerativeAI dipanggil 2x: primary lalu fallback
    mock_chat_class.side_effect = [mock_primary, mock_fallback]

    service = LLMService(_make_settings())
    result = service.generate(konteks="konteks", pertanyaan="pertanyaan")

    assert result == "Jawaban primary."
    mock_primary.invoke.assert_called_once()
    mock_fallback.invoke.assert_not_called()


@patch("app.services.llm_service.ChatGoogleGenerativeAI")
def test_fallback_when_primary_fails(mock_chat_class):
    """Kalau primary gagal, fallback harus dicoba."""
    mock_primary = MagicMock()
    mock_primary.invoke.side_effect = Exception("Primary down")

    mock_fallback = MagicMock()
    mock_fallback.invoke.return_value = MagicMock(content="Jawaban fallback.")

    mock_chat_class.side_effect = [mock_primary, mock_fallback]

    service = LLMService(_make_settings())
    result = service.generate(konteks="konteks", pertanyaan="pertanyaan")

    assert result == "Jawaban fallback."
    mock_primary.invoke.assert_called_once()
    mock_fallback.invoke.assert_called_once()


@patch("app.services.llm_service.ChatGoogleGenerativeAI")
def test_static_fallback_when_both_fail(mock_chat_class):
    """Kalau primary dan fallback gagal, kembalikan pesan statis."""
    mock_primary = MagicMock()
    mock_primary.invoke.side_effect = Exception("Primary down")

    mock_fallback = MagicMock()
    mock_fallback.invoke.side_effect = Exception("Fallback down")

    mock_chat_class.side_effect = [mock_primary, mock_fallback]

    service = LLMService(_make_settings())
    result = service.generate(konteks="konteks", pertanyaan="pertanyaan")

    assert result == FALLBACK_MESSAGE


@patch("app.services.llm_service.ChatGoogleGenerativeAI")
def test_history_prompt_used_when_riwayat_given(mock_chat_class):
    """Kalau riwayat diberikan, prompt multi-turn harus dipakai."""
    mock_primary = MagicMock()
    mock_primary.invoke.return_value = MagicMock(content="Jawaban dengan riwayat.")

    mock_fallback = MagicMock()
    mock_chat_class.side_effect = [mock_primary, mock_fallback]

    service = LLMService(_make_settings())
    result = service.generate(
        konteks="konteks ayat",
        pertanyaan="pertanyaan lanjutan",
        riwayat="Pengguna: apa itu sabar?\nAsisten: Sabar adalah..."
    )

    assert result == "Jawaban dengan riwayat."
    # verifikasi prompt yang dikirim mengandung riwayat
    call_args = mock_primary.invoke.call_args[0][0]
    assert "Riwayat Percakapan" in call_args
    assert "pertanyaan lanjutan" in call_args


@patch("app.services.llm_service.ChatGoogleGenerativeAI")
def test_single_turn_prompt_when_no_riwayat(mock_chat_class):
    """Kalau riwayat kosong, prompt single-turn yang dipakai."""
    mock_primary = MagicMock()
    mock_primary.invoke.return_value = MagicMock(content="Jawaban tanpa riwayat.")

    mock_fallback = MagicMock()
    mock_chat_class.side_effect = [mock_primary, mock_fallback]

    service = LLMService(_make_settings())
    result = service.generate(konteks="konteks ayat", pertanyaan="pertanyaan baru")

    call_args = mock_primary.invoke.call_args[0][0]
    assert "Riwayat Percakapan" not in call_args
    assert "pertanyaan baru" in call_args
