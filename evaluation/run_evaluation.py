#!/usr/bin/env python3
"""
Skrip Evaluasi Performa Sistem Tanya Jawab Al-Qur'an (RAG)
============================================================

Mengevaluasi sistem secara end-to-end menggunakan tiga metode:
  1. DeepEval  — Faithfulness & Answer Relevancy (LLM-as-Judge)
  2. BERTScore — Kemiripan semantik jawaban vs. jawaban referensi
  3. Negative Rejection Rate — Akurasi penolakan pertanyaan non-Al-Qur'an

Prasyarat:
  - Backend API harus berjalan (docker compose up)
  - Qdrant harus terisi data (jalankan data pipeline)
  - pip install -r requirements.txt
  - Set GEMINI_API_KEY di environment (untuk DeepEval)

Penggunaan:
  python run_evaluation.py
  python run_evaluation.py --api-url http://localhost:8000
  python run_evaluation.py --skip-deepeval
  python run_evaluation.py --skip-bertscore
  python run_evaluation.py --help

Hasil:
  - Tabel ringkasan di terminal (siap untuk BAB 4 skripsi)
  - File CSV di folder results/ untuk analisis lanjutan
"""

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

import httpx

# ── Konstanta ────────────────────────────────────────────────────

# pesan penolakan dari rag_service.py (dicocokkan sebagian)
REJECTION_FRAGMENTS = [
    "tidak menemukan ayat Al-Qur'an yang cukup relevan",
    "Sistem belum memiliki data ayat yang cukup",
]

RESULTS_DIR = Path(__file__).parent / "results"


# ═════════════════════════════════════════════════════════════════
#  FUNGSI UTILITAS
# ═════════════════════════════════════════════════════════════════


def load_dataset(path: str) -> list[dict]:
    """Memuat dataset evaluasi dari file JSON."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    cases = data.get("test_cases", data)
    print(f"  Dataset dimuat: {len(cases)} kasus uji")
    return cases


def is_rejection(jawaban: str) -> bool:
    """Cek apakah jawaban merupakan penolakan (negative rejection)."""
    lower = jawaban.lower()
    return any(frag.lower() in lower for frag in REJECTION_FRAGMENTS)


def call_rag_api(
    api_url: str,
    pertanyaan: str,
    auth_token: str | None = None,
    timeout: int = 120,
) -> dict:
    """Panggil endpoint /api/ask dan kembalikan response JSON."""
    headers = {"Content-Type": "application/json"}
    if auth_token:
        headers["Authorization"] = f"Bearer {auth_token}"

    payload = {
        "pertanyaan": pertanyaan,
        "top_k": 3,
        "riwayat_percakapan": [],
    }

    response = httpx.post(
        f"{api_url.rstrip('/')}/api/ask",
        json=payload,
        headers=headers,
        timeout=timeout,
    )
    response.raise_for_status()
    return response.json()


def query_all(
    dataset: list[dict],
    api_url: str,
    auth_token: str | None = None,
) -> list[dict]:
    """Jalankan query untuk semua kasus uji dan kumpulkan hasil."""
    results = []
    total = len(dataset)

    for i, case in enumerate(dataset, 1):
        pertanyaan = case["pertanyaan"]
        label = pertanyaan if len(pertanyaan) <= 55 else pertanyaan[:55] + "..."
        print(f"  [{i:>2}/{total}] {label}", end="  ", flush=True)

        start = time.time()
        try:
            resp = call_rag_api(api_url, pertanyaan, auth_token)
            elapsed = time.time() - start

            jawaban = resp.get("jawaban_llm", "")
            referensi = resp.get("referensi", [])
            skor = resp.get("skor_tertinggi", 0.0)

            # bangun retrieval context dari referensi untuk DeepEval
            konteks_list = []
            for ref in referensi:
                konteks_list.append(
                    f"Surah {ref['surah']} Ayat {ref['ayat']}: "
                    f"{ref.get('terjemahan', '')}"
                )

            results.append({
                "id": case.get("id", i),
                "kategori": case.get("kategori", ""),
                "topik": case.get("topik", ""),
                "pertanyaan": pertanyaan,
                "should_answer": case.get("should_answer", True),
                "jawaban_referensi": case.get("jawaban_referensi", ""),
                "jawaban_sistem": jawaban,
                "skor_tertinggi": skor,
                "jumlah_referensi": len(referensi),
                "retrieval_context": konteks_list,
                "is_rejection": is_rejection(jawaban),
                "waktu_respons": round(elapsed, 2),
                "error": None,
            })
            status_icon = "OK" if not is_rejection(jawaban) else "TOLAK"
            print(f"{status_icon}  ({elapsed:.1f}s, skor={skor:.4f})")

        except Exception as e:
            elapsed = time.time() - start
            results.append({
                "id": case.get("id", i),
                "kategori": case.get("kategori", ""),
                "topik": case.get("topik", ""),
                "pertanyaan": pertanyaan,
                "should_answer": case.get("should_answer", True),
                "jawaban_referensi": case.get("jawaban_referensi", ""),
                "jawaban_sistem": "",
                "skor_tertinggi": 0.0,
                "jumlah_referensi": 0,
                "retrieval_context": [],
                "is_rejection": True,
                "waktu_respons": round(elapsed, 2),
                "error": str(e),
            })
            print(f"ERROR: {e}")

    return results


# ═════════════════════════════════════════════════════════════════
#  EVALUASI DEEPEVAL (LLM-as-Judge)
# ═════════════════════════════════════════════════════════════════


def run_deepeval_evaluation(
    positive_results: list[dict],
    model: str,
) -> dict:
    """Jalankan Faithfulness & Answer Relevancy menggunakan DeepEval.

    Faithfulness : apakah jawaban grounded pada konteks retrieval?
    Answer Relevancy : apakah jawaban relevan dengan pertanyaan?
    """
    try:
        from deepeval.metrics import FaithfulnessMetric, AnswerRelevancyMetric
        from deepeval.test_case import LLMTestCase
    except ImportError:
        print("\n[!] deepeval belum terinstall. Jalankan:")
        print("    pip install deepeval")
        return {}

    n = len(positive_results)
    print(f"\n--- DeepEval ({n} kasus, model: {model}) ---")

    faithfulness_metric = FaithfulnessMetric(
        threshold=0.7,
        model=model,
        verbose_mode=False,
    )
    relevancy_metric = AnswerRelevancyMetric(
        threshold=0.7,
        model=model,
        verbose_mode=False,
    )

    faithfulness_scores: list[float] = []
    relevancy_scores: list[float] = []
    detail_rows: list[dict] = []

    for i, r in enumerate(positive_results, 1):
        label = r["pertanyaan"][:50]
        print(f"  [{i:>2}/{n}] {label}...", end="  ", flush=True)

        test_case = LLMTestCase(
            input=r["pertanyaan"],
            actual_output=r["jawaban_sistem"],
            retrieval_context=(
                r["retrieval_context"]
                if r["retrieval_context"]
                else ["Tidak ada konteks"]
            ),
            expected_output=r["jawaban_referensi"],
        )

        f_score = None
        r_score = None

        try:
            faithfulness_metric.measure(test_case)
            f_score = faithfulness_metric.score
            faithfulness_scores.append(f_score)
        except Exception as e:
            print(f"[Faith err: {e}] ", end="")

        try:
            relevancy_metric.measure(test_case)
            r_score = relevancy_metric.score
            relevancy_scores.append(r_score)
        except Exception as e:
            print(f"[Relv err: {e}] ", end="")

        detail_rows.append({
            "id": r["id"],
            "pertanyaan": r["pertanyaan"][:60],
            "faithfulness": round(f_score, 4) if f_score is not None else "N/A",
            "answer_relevancy": round(r_score, 4) if r_score is not None else "N/A",
        })
        print("OK")

    avg_f = (
        sum(faithfulness_scores) / len(faithfulness_scores)
        if faithfulness_scores
        else 0
    )
    avg_r = (
        sum(relevancy_scores) / len(relevancy_scores)
        if relevancy_scores
        else 0
    )

    return {
        "avg_faithfulness": round(avg_f, 4),
        "avg_answer_relevancy": round(avg_r, 4),
        "total_evaluated": n,
        "faithfulness_scores": faithfulness_scores,
        "relevancy_scores": relevancy_scores,
        "details": detail_rows,
    }


# ═════════════════════════════════════════════════════════════════
#  EVALUASI BERTSCORE (Kemiripan Semantik)
# ═════════════════════════════════════════════════════════════════


def run_bertscore_evaluation(positive_results: list[dict]) -> dict:
    """Hitung BERTScore antara jawaban sistem dan jawaban referensi.

    Precision : seberapa tepat kata-kata dalam jawaban sistem
    Recall    : seberapa lengkap jawaban mencakup referensi
    F1        : harmonic mean dari precision dan recall
    """
    try:
        from bert_score import score as bert_score_fn
    except ImportError:
        print("\n[!] bert-score belum terinstall. Jalankan:")
        print("    pip install bert-score")
        return {}

    # hanya kasus yang memiliki jawaban referensi
    valid = [r for r in positive_results if r.get("jawaban_referensi", "").strip()]
    if not valid:
        print("\n[!] Tidak ada kasus dengan jawaban referensi untuk BERTScore.")
        return {}

    n = len(valid)
    print(f"\n--- BERTScore ({n} kasus) ---")

    candidates = [r["jawaban_sistem"] for r in valid]
    references = [r["jawaban_referensi"] for r in valid]

    P, R, F1 = bert_score_fn(
        candidates,
        references,
        lang="id",
        verbose=True,
        rescale_with_baseline=True,
    )

    detail_rows: list[dict] = []
    for i, r in enumerate(valid):
        detail_rows.append({
            "id": r["id"],
            "pertanyaan": r["pertanyaan"][:60],
            "precision": round(P[i].item(), 4),
            "recall": round(R[i].item(), 4),
            "f1": round(F1[i].item(), 4),
        })

    return {
        "avg_precision": round(P.mean().item(), 4),
        "avg_recall": round(R.mean().item(), 4),
        "avg_f1": round(F1.mean().item(), 4),
        "total_evaluated": n,
        "details": detail_rows,
    }


# ═════════════════════════════════════════════════════════════════
#  EVALUASI NEGATIVE REJECTION
# ═════════════════════════════════════════════════════════════════


def evaluate_negative_rejection(negative_results: list[dict]) -> dict:
    """Evaluasi akurasi penolakan untuk pertanyaan non-Al-Qur'an.

    Sistem seharusnya menolak (return LOW_RELEVANCE_MESSAGE atau
    NO_DATA_MESSAGE) ketika pertanyaan tidak terkait Al-Qur'an.
    """
    if not negative_results:
        return {"accuracy": 0, "total": 0, "correct": 0, "details": []}

    n = len(negative_results)
    print(f"\n--- Negative Rejection ({n} kasus) ---")

    correct = 0
    detail_rows: list[dict] = []

    for r in negative_results:
        rejected = r["is_rejection"]
        if rejected:
            correct += 1

        detail_rows.append({
            "id": r["id"],
            "pertanyaan": r["pertanyaan"][:60],
            "ditolak": "Ya" if rejected else "Tidak",
            "skor": r["skor_tertinggi"],
            "benar": rejected,
        })

        icon = "OK" if rejected else "GAGAL"
        print(f"  {icon}  {r['pertanyaan'][:55]}  (skor={r['skor_tertinggi']:.4f})")

    accuracy = correct / n if n else 0
    return {
        "accuracy": round(accuracy, 4),
        "total": n,
        "correct": correct,
        "details": detail_rows,
    }


# ═════════════════════════════════════════════════════════════════
#  OUTPUT & EKSPOR
# ═════════════════════════════════════════════════════════════════


def print_summary(
    deepeval_results: dict,
    bertscore_results: dict,
    rejection_results: dict,
    all_results: list[dict],
) -> None:
    """Cetak ringkasan evaluasi dalam format tabel untuk skripsi."""
    try:
        from tabulate import tabulate
    except ImportError:
        print("[!] tabulate belum terinstall: pip install tabulate")
        return

    print()
    print("=" * 70)
    print("     RINGKASAN EVALUASI SISTEM TANYA JAWAB AL-QUR'AN (RAG)")
    print("=" * 70)

    # ── tabel metrik utama ───────────────────────────────────────
    summary_data: list[list] = []

    if deepeval_results:
        summary_data.append([
            "Faithfulness (DeepEval)",
            f"{deepeval_results['avg_faithfulness']:.4f}",
            f"{deepeval_results['total_evaluated']} kasus",
        ])
        summary_data.append([
            "Answer Relevancy (DeepEval)",
            f"{deepeval_results['avg_answer_relevancy']:.4f}",
            f"{deepeval_results['total_evaluated']} kasus",
        ])

    if bertscore_results:
        summary_data.append([
            "BERTScore Precision",
            f"{bertscore_results['avg_precision']:.4f}",
            f"{bertscore_results['total_evaluated']} kasus",
        ])
        summary_data.append([
            "BERTScore Recall",
            f"{bertscore_results['avg_recall']:.4f}",
            f"{bertscore_results['total_evaluated']} kasus",
        ])
        summary_data.append([
            "BERTScore F1",
            f"{bertscore_results['avg_f1']:.4f}",
            f"{bertscore_results['total_evaluated']} kasus",
        ])

    if rejection_results and rejection_results.get("total", 0) > 0:
        pct = rejection_results["accuracy"] * 100
        summary_data.append([
            "Negative Rejection Rate",
            f"{pct:.1f}%",
            f"{rejection_results['correct']}/{rejection_results['total']} kasus",
        ])

    # waktu respons rata-rata
    valid_times = [r["waktu_respons"] for r in all_results if not r.get("error")]
    if valid_times:
        avg_time = sum(valid_times) / len(valid_times)
        summary_data.append([
            "Rata-rata Waktu Respons",
            f"{avg_time:.2f} detik",
            f"{len(valid_times)} kasus",
        ])

    if summary_data:
        print()
        print(tabulate(
            summary_data,
            headers=["Metrik", "Nilai", "Sampel"],
            tablefmt="grid",
            colalign=("left", "center", "center"),
        ))

    # ── tabel distribusi per kategori ────────────────────────────
    categories: dict[str, dict] = {}
    for r in all_results:
        cat = r.get("kategori", "lainnya")
        if cat not in categories:
            categories[cat] = {
                "total": 0, "dijawab": 0, "ditolak": 0, "error": 0,
            }
        categories[cat]["total"] += 1
        if r.get("error"):
            categories[cat]["error"] += 1
        elif r["is_rejection"]:
            categories[cat]["ditolak"] += 1
        else:
            categories[cat]["dijawab"] += 1

    cat_data = []
    for cat, s in sorted(categories.items()):
        cat_data.append([cat.capitalize(), s["total"], s["dijawab"], s["ditolak"], s["error"]])

    print("\nDistribusi Hasil per Kategori:")
    print(tabulate(
        cat_data,
        headers=["Kategori", "Total", "Dijawab", "Ditolak", "Error"],
        tablefmt="grid",
        colalign=("left", "center", "center", "center", "center"),
    ))

    print()
    print("=" * 70)


def export_results(
    all_results: list[dict],
    deepeval_results: dict,
    bertscore_results: dict,
    rejection_results: dict,
    output_dir: Path,
) -> None:
    """Ekspor semua hasil evaluasi ke file CSV."""
    output_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 1. hasil keseluruhan
    path_all = output_dir / f"hasil_evaluasi_{timestamp}.csv"
    with open(path_all, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "Kategori", "Topik", "Pertanyaan",
            "Harus Dijawab", "Ditolak Sistem", "Benar",
            "Skor Tertinggi", "Jumlah Referensi",
            "Waktu (detik)", "Error",
        ])
        for r in all_results:
            should = r["should_answer"]
            rejected = r["is_rejection"]
            correct = (should and not rejected) or (not should and rejected)
            writer.writerow([
                r["id"], r["kategori"], r["topik"], r["pertanyaan"],
                "Ya" if should else "Tidak",
                "Ya" if rejected else "Tidak",
                "Ya" if correct else "Tidak",
                r["skor_tertinggi"], r["jumlah_referensi"],
                r["waktu_respons"], r.get("error", ""),
            ])
    print(f"\n  Hasil keseluruhan  : {path_all}")

    # 2. detail DeepEval
    if deepeval_results and deepeval_results.get("details"):
        path_de = output_dir / f"deepeval_detail_{timestamp}.csv"
        with open(path_de, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(
                f,
                fieldnames=["id", "pertanyaan", "faithfulness", "answer_relevancy"],
            )
            w.writeheader()
            w.writerows(deepeval_results["details"])
        print(f"  Detail DeepEval    : {path_de}")

    # 3. detail BERTScore
    if bertscore_results and bertscore_results.get("details"):
        path_bs = output_dir / f"bertscore_detail_{timestamp}.csv"
        with open(path_bs, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(
                f,
                fieldnames=["id", "pertanyaan", "precision", "recall", "f1"],
            )
            w.writeheader()
            w.writerows(bertscore_results["details"])
        print(f"  Detail BERTScore   : {path_bs}")

    # 4. ringkasan metrik
    path_sum = output_dir / f"ringkasan_metrik_{timestamp}.csv"
    with open(path_sum, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Metrik", "Nilai"])
        if deepeval_results:
            writer.writerow(["Faithfulness (rata-rata)", deepeval_results.get("avg_faithfulness", "")])
            writer.writerow(["Answer Relevancy (rata-rata)", deepeval_results.get("avg_answer_relevancy", "")])
        if bertscore_results:
            writer.writerow(["BERTScore Precision (rata-rata)", bertscore_results.get("avg_precision", "")])
            writer.writerow(["BERTScore Recall (rata-rata)", bertscore_results.get("avg_recall", "")])
            writer.writerow(["BERTScore F1 (rata-rata)", bertscore_results.get("avg_f1", "")])
        if rejection_results and rejection_results.get("total", 0) > 0:
            writer.writerow(["Negative Rejection Rate", rejection_results.get("accuracy", "")])
            writer.writerow(["Jumlah Kasus Penolakan", rejection_results.get("total", "")])
            writer.writerow(["Penolakan Benar", rejection_results.get("correct", "")])
    print(f"  Ringkasan metrik   : {path_sum}")


# ═════════════════════════════════════════════════════════════════
#  MAIN
# ═════════════════════════════════════════════════════════════════


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Evaluasi Performa Sistem Tanya Jawab Al-Qur'an (RAG)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Contoh:
  python run_evaluation.py
  python run_evaluation.py --api-url http://localhost:8000
  python run_evaluation.py --skip-deepeval
  python run_evaluation.py --skip-bertscore
  python run_evaluation.py --eval-model gemini/gemini-2.0-flash
        """,
    )
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000",
        help="URL backend API (default: http://localhost:8000)",
    )
    parser.add_argument(
        "--dataset",
        default=str(Path(__file__).parent / "eval_dataset.json"),
        help="Path file dataset evaluasi (default: eval_dataset.json)",
    )
    parser.add_argument(
        "--auth-token",
        default=None,
        help="Firebase auth token (jika AUTH_ENABLED=true)",
    )
    parser.add_argument(
        "--eval-model",
        default="gemini/gemini-2.0-flash",
        help="Model LLM untuk DeepEval (default: gemini/gemini-2.0-flash)",
    )
    parser.add_argument(
        "--skip-deepeval",
        action="store_true",
        help="Lewati evaluasi DeepEval (hanya BERTScore + Rejection)",
    )
    parser.add_argument(
        "--skip-bertscore",
        action="store_true",
        help="Lewati evaluasi BERTScore",
    )
    parser.add_argument(
        "--output-dir",
        default=str(RESULTS_DIR),
        help="Direktori output CSV (default: results/)",
    )

    args = parser.parse_args()

    # ── header ───────────────────────────────────────────────────
    print("=" * 70)
    print("  EVALUASI SISTEM TANYA JAWAB AL-QUR'AN BERBASIS RAG")
    print("=" * 70)
    print(f"  API URL       : {args.api_url}")
    print(f"  Dataset       : {args.dataset}")
    print(f"  Eval Model    : {args.eval_model}")
    print(f"  DeepEval      : {'Dilewati' if args.skip_deepeval else 'Aktif'}")
    print(f"  BERTScore     : {'Dilewati' if args.skip_bertscore else 'Aktif'}")
    print(f"  Output        : {args.output_dir}")
    print("=" * 70)

    # ── cek koneksi backend ──────────────────────────────────────
    print("\n[1/5] Memeriksa koneksi ke backend...")
    try:
        health = httpx.get(f"{args.api_url.rstrip('/')}/health", timeout=10)
        hd = health.json()
        print(f"  Status : {hd.get('status', '?')}")
        print(f"  Versi  : {hd.get('version', '?')}")
    except Exception as e:
        print(f"  GAGAL terhubung: {e}")
        print("  Pastikan backend berjalan (docker compose up / uvicorn)")
        sys.exit(1)

    # ── muat dataset ─────────────────────────────────────────────
    print("\n[2/5] Memuat dataset evaluasi...")
    try:
        dataset = load_dataset(args.dataset)
    except FileNotFoundError:
        print(f"  Dataset tidak ditemukan: {args.dataset}")
        sys.exit(1)

    # ── query semua kasus ────────────────────────────────────────
    print("\n[3/5] Menjalankan query ke backend API...")
    all_results = query_all(dataset, args.api_url, args.auth_token)

    # pisahkan positif / negatif / error
    positive = [r for r in all_results if r["should_answer"] and not r.get("error")]
    negative = [r for r in all_results if not r["should_answer"] and not r.get("error")]
    errors = [r for r in all_results if r.get("error")]

    print(f"\n  Ringkasan query: "
          f"{len(positive)} positif, {len(negative)} negatif, {len(errors)} error")

    # ── evaluasi metrik ──────────────────────────────────────────
    print("\n[4/5] Menjalankan evaluasi metrik...")

    deepeval_results: dict = {}
    bertscore_results: dict = {}

    # DeepEval
    if not args.skip_deepeval and positive:
        api_key = os.environ.get("GEMINI_API_KEY", "")
        if not api_key:
            # coba baca dari backend/.env
            env_path = Path(__file__).parent.parent / "backend" / ".env"
            if env_path.exists():
                for line in env_path.read_text(encoding="utf-8").splitlines():
                    if line.startswith("GEMINI_API_KEY="):
                        api_key = line.split("=", 1)[1].strip()
                        os.environ["GEMINI_API_KEY"] = api_key
                        break
        if api_key:
            deepeval_results = run_deepeval_evaluation(positive, args.eval_model)
        else:
            print("\n[!] GEMINI_API_KEY tidak ditemukan — DeepEval dilewati.")
            print("    Set env var atau isi di backend/.env")
    elif args.skip_deepeval:
        print("\n  DeepEval: dilewati (--skip-deepeval)")

    # BERTScore
    if not args.skip_bertscore and positive:
        bertscore_results = run_bertscore_evaluation(positive)
    elif args.skip_bertscore:
        print("\n  BERTScore: dilewati (--skip-bertscore)")

    # Negative Rejection
    rejection_results = evaluate_negative_rejection(negative)

    # ── output ───────────────────────────────────────────────────
    print("\n[5/5] Menyusun laporan...")
    print_summary(deepeval_results, bertscore_results, rejection_results, all_results)

    output_dir = Path(args.output_dir)
    export_results(
        all_results, deepeval_results, bertscore_results,
        rejection_results, output_dir,
    )

    print("\nEvaluasi selesai.")


if __name__ == "__main__":
    main()
