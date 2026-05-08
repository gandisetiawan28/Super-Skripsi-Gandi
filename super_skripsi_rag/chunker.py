"""
chunker.py
Memecah teks panjang menjadi chunk 500-800 kata dengan overlap 100 kata.
Preservasi batas kalimat — tidak memotong di tengah kalimat.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional


@dataclass
class TextChunk:
    doc_id: str
    chunk_index: int
    content: str
    word_count: int
    page_start: Optional[int]
    page_end: Optional[int]


# ── Konstanta ──────────────────────────────────────────────────────────────────

TARGET_WORDS = 300      # Target kata per chunk (lebih granular)
MAX_WORDS = 500         # Batas maksimal kata (lebih granular)
OVERLAP_WORDS = 50      # Kata overlap antar chunk
MIN_CHUNK_WORDS = 50    # Chunk kurang dari ini diabaikan


# ── Fungsi Utama ───────────────────────────────────────────────────────────────

def chunk_text(doc_id: str, text: str) -> list:
    """Chunk teks plain (tanpa info halaman) menjadi list[TextChunk]."""
    sentences = _split_sentences(text)
    return _build_chunks(doc_id, sentences)


def chunk_pages(doc_id: str, page_texts: dict) -> list:
    """
    Chunk teks dengan page-awareness.
    Setiap kalimat tahu di halaman berapa ia berasal.
    """
    sentences_with_pages = []
    for page_num in sorted(page_texts.keys()):
        text = page_texts[page_num]
        if not text.strip():
            continue
        for sent in _split_sentences(text):
            sentences_with_pages.append((sent, page_num))

    return _build_chunks_with_pages(doc_id, sentences_with_pages)


# ── Helper ─────────────────────────────────────────────────────────────────────

_SENTENCE_END = re.compile(r'(?<=[.!?])\s+(?=[A-Z\d"])')


def _split_sentences(text: str) -> list:
    """Pecah teks ke kalimat-kalimat. Pertahankan daftar bernomor sebagai unit."""
    parts = _SENTENCE_END.split(text)
    result = []
    for part in parts:
        stripped = part.strip()
        if stripped:
            result.append(stripped)
    return result


def _build_chunks(doc_id: str, sentences: list) -> list:
    """Bangun chunks dari list kalimat tanpa info halaman."""
    chunks = []
    buffer = []
    buf_words = 0
    chunk_idx = 0

    for sent in sentences:
        words = sent.split()
        word_count = len(words)

        if buf_words + word_count > MAX_WORDS and buf_words >= MIN_CHUNK_WORDS:
            # Flush buffer jadi satu chunk
            content = ' '.join(buffer)
            chunks.append(TextChunk(
                doc_id=doc_id,
                chunk_index=chunk_idx,
                content=content,
                word_count=buf_words,
                page_start=None,
                page_end=None,
            ))
            chunk_idx += 1

            # Overlap: ambil kata-kata terakhir dari buffer
            all_words = content.split()
            overlap_words = all_words[-OVERLAP_WORDS:] if len(all_words) > OVERLAP_WORDS else all_words
            buffer = [' '.join(overlap_words)]
            buf_words = len(overlap_words)

        buffer.append(sent)
        buf_words += word_count

    # Flush sisa
    if buf_words >= MIN_CHUNK_WORDS:
        chunks.append(TextChunk(
            doc_id=doc_id,
            chunk_index=chunk_idx,
            content=' '.join(buffer),
            word_count=buf_words,
            page_start=None,
            page_end=None,
        ))

    return chunks


def _build_chunks_with_pages(doc_id: str, sentences_with_pages: list) -> list:
    """Bangun chunks dengan tracking halaman per kalimat."""
    chunks = []
    buffer_sents = []      # list of str
    buffer_pages = []      # list of int
    buf_words = 0
    chunk_idx = 0

    for sent, page in sentences_with_pages:
        word_count = len(sent.split())

        if buf_words + word_count > MAX_WORDS and buf_words >= MIN_CHUNK_WORDS:
            # Flush — buat chunk dari buffer saat ini
            content = ' '.join(buffer_sents)
            chunks.append(TextChunk(
                doc_id=doc_id,
                chunk_index=chunk_idx,
                content=content,
                word_count=buf_words,
                page_start=min(buffer_pages) if buffer_pages else None,
                page_end=max(buffer_pages) if buffer_pages else None,
            ))
            chunk_idx += 1

            # Overlap: ambil N kata terakhir dari chunk ini
            all_words = content.split()
            overlap_count = min(OVERLAP_WORDS, len(all_words))
            overlap_text = ' '.join(all_words[-overlap_count:])
            last_page = buffer_pages[-1] if buffer_pages else page

            buffer_sents = [overlap_text]
            buffer_pages = [last_page]
            buf_words = overlap_count

        buffer_sents.append(sent)
        buffer_pages.append(page)
        buf_words += word_count

    # Flush sisa
    if buf_words >= MIN_CHUNK_WORDS:
        content = ' '.join(buffer_sents)
        chunks.append(TextChunk(
            doc_id=doc_id,
            chunk_index=chunk_idx,
            content=content,
            word_count=buf_words,
            page_start=min(buffer_pages) if buffer_pages else None,
            page_end=max(buffer_pages) if buffer_pages else None,
        ))

    return chunks
