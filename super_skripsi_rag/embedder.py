"""
embedder.py
Wrapper embedding berbasis SentenceTransformers (lokal, gratis, multilingual).
Model: paraphrase-multilingual-MiniLM-L12-v2 (~120MB, support Bahasa Indonesia + Inggris)

FIX v2:
- Set TOKENIZERS_PARALLELISM=false sebelum import untuk mencegah deadlock HuggingFace tokenizer
- Model loading dijalankan di thread terpisah agar tidak block FastAPI event loop
"""

import os
import threading

# ── CRITICAL: Harus di-set SEBELUM import tokenizers/transformers ──────────────
# Mencegah deadlock yang menyebabkan RAG hang saat pertama kali load
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

from functools import lru_cache
from sentence_transformers import SentenceTransformer
import numpy as np

MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

# Lock untuk thread-safe singleton loading
_model_lock = threading.Lock()
_model_instance: SentenceTransformer | None = None


def _get_model() -> SentenceTransformer:
    """Singleton model — diload sekali, digunakan selamanya. Thread-safe."""
    global _model_instance
    if _model_instance is not None:
        return _model_instance

    with _model_lock:
        # Double-checked locking
        if _model_instance is None:
            print(f"[Embedder] ⏳ Memuat model {MODEL_NAME}...")
            _model_instance = SentenceTransformer(MODEL_NAME)
            print(f"[Embedder] ✅ Model siap.")

    return _model_instance


def embed_texts(texts: list[str]) -> list[list[float]]:
    """
    Embed daftar teks menjadi vector float.
    Mengembalikan list of lists (setiap vektor = 384 dimensi).
    """
    if not texts:
        return []
    model = _get_model()
    embeddings = model.encode(texts, show_progress_bar=False, normalize_embeddings=True)
    return embeddings.tolist()


def embed_query(query: str) -> list[float]:
    """Embed satu query string."""
    return embed_texts([query])[0]


def is_ready() -> bool:
    """Cek apakah model sudah bisa dimuat."""
    try:
        _get_model()
        return True
    except Exception:
        return False


def preload_model_background():
    """
    Preload model di background thread saat startup.
    Mencegah cold-start hang saat request pertama.
    """
    t = threading.Thread(target=_get_model, daemon=True)
    t.start()
    return t
