"""
pdf_extractor.py
Ekstraksi teks PDF page-by-page menggunakan pdfplumber.
Fitur: pembersihan header/footer otomatis, hyphen baris, ligature Unicode.
"""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path
from typing import Optional

import pdfplumber


# ── Konstanta ──────────────────────────────────────────────────────────────────

LIGATURES = {
    '\ufb01': 'fi', '\ufb02': 'fl', '\ufb00': 'ff',
    '\ufb03': 'ffi', '\ufb04': 'ffl',
}

PAGE_NUMBER_PATTERN = re.compile(
    r'^\s*(?:halaman\s*)?\d{1,4}\s*$|^\s*[-\u2013]\s*\d{1,4}\s*[-\u2013]\s*$',
    re.IGNORECASE | re.MULTILINE,
)


# ── Fungsi Utama ───────────────────────────────────────────────────────────────

def extract_pdf(file_path: str) -> dict:
    """
    Ekstrak teks PDF dan kembalikan sebagai dict dengan metadata.

    Returns:
        {
          "full_text": str,
          "page_texts": {1: str, 2: str, ...},
          "title": str,
          "page_count": int,
        }
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File tidak ditemukan: {file_path}")

    raw_lines_per_page: dict = {}

    with pdfplumber.open(str(path)) as pdf:
        for i, page in enumerate(pdf.pages):
            raw = page.extract_text() or ''
            lines = raw.split('\n')
            raw_lines_per_page[i + 1] = lines

    # Nonaktifkan deteksi header/footer berulang agar metadata & hal tetap ada
    page_texts: dict = {}
    for page_num, lines in raw_lines_per_page.items():
        # Gunakan set kosong agar tidak ada baris yang dibuang
        cleaned = _clean_page(lines, set())
        page_texts[page_num] = cleaned

    full_text = '\n\n'.join(t for t in page_texts.values() if t.strip())
    title = _heuristic_title(page_texts.get(1, ''))

    return {
        'full_text': full_text.strip(),
        'page_texts': page_texts,
        'title': title,
        'page_count': len(page_texts),
    }


# ── Helper ─────────────────────────────────────────────────────────────────────

def _detect_repeated_lines(pages: dict, threshold: float = 0.5) -> set:
    """Deteksi baris yang muncul di hampir semua halaman (header/footer)."""
    total_pages = len(pages)
    if total_pages < 3:
        return set()

    line_counter: Counter = Counter()
    for lines in pages.values():
        seen: set = set()
        for line in lines:
            stripped = line.strip()
            if stripped and stripped not in seen:
                line_counter[stripped] += 1
                seen.add(stripped)

    repeated: set = set()
    for line, count in line_counter.items():
        if count / total_pages >= threshold and len(line) < 120:
            repeated.add(line)
    return repeated


def _clean_page(lines: list, repeated_lines: set) -> str:
    """Bersihkan satu halaman dari header/footer, nomor halaman, ligature, dll."""
    cleaned_lines = []

    for line in lines:
        # Simpan semua baris (termasuk header, footer, dan nomor halaman)
        cleaned_lines.append(line)

    text = '\n'.join(cleaned_lines)

    # Bersihkan artefak encoding
    text = text.replace('\u00ad', '')  # Soft hyphen
    for lig, repl in LIGATURES.items():
        text = text.replace(lig, repl)

    # Sambung kata yang dipotong hyphen di akhir baris: "penga-\nruh" → "pengaruh"
    text = re.sub(r'-\n(\S)', r'\1', text)

    # Newline tunggal di tengah kalimat → spasi
    text = re.sub(r'(?<!\n)\n(?!\n)', ' ', text)

    # Normalisasi spasi dan newline berlebih
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()


def _heuristic_title(page1_text: str) -> str:
    """Coba ambil judul dari baris non-kosong pertama halaman 1."""
    if not page1_text:
        return 'Unknown Title'

    lines = [l.strip() for l in page1_text.split('\n') if l.strip()]
    for line in lines[:8]:
        upper_ratio = sum(1 for c in line if c.isupper()) / max(len(line), 1)
        if upper_ratio > 0.4 and len(line) > 10:
            return line
    return lines[0] if lines else 'Unknown Title'
