"""
ris_generator.py
Konversi metadata dokumen ke format RIS (Research Information Systems).
Format RIS bisa diimpor langsung ke Mendeley, Zotero, atau EndNote.
"""

from datetime import datetime


def to_ris(doc_meta: dict) -> str:
    """
    Konversi metadata dokumen ke string format RIS.

    doc_meta keys yang didukung:
        title, authors (list[str]), year, journal_name,
        volume, issue, pages, doi, url, abstract
    """
    lines = []

    # Tentukan tipe referensi
    if doc_meta.get("journal_name"):
        lines.append("TY  - JOUR")  # Journal article
    else:
        lines.append("TY  - GEN")   # Generic / book

    # Judul
    title = doc_meta.get("title", "Unknown Title")
    lines.append(f"TI  - {title}")

    # Penulis (satu per baris)
    authors = doc_meta.get("authors", [])
    for author in authors:
        # Format: Last, First → A1  - Last, First
        lines.append(f"A1  - {author.strip()}")

    # Tahun
    year = doc_meta.get("year")
    if year:
        lines.append(f"PY  - {year}")
        lines.append(f"Y1  - {year}///")

    # Jurnal
    journal = doc_meta.get("journal_name")
    if journal:
        lines.append(f"JO  - {journal}")
        lines.append(f"JF  - {journal}")

    # Volume & Issue
    volume = doc_meta.get("volume")
    issue = doc_meta.get("issue")
    if volume:
        lines.append(f"VL  - {volume}")
    if issue:
        lines.append(f"IS  - {issue}")

    # Halaman
    pages = doc_meta.get("pages")
    if pages:
        if "-" in str(pages):
            parts = str(pages).split("-", 1)
            lines.append(f"SP  - {parts[0].strip()}")
            lines.append(f"EP  - {parts[1].strip()}")
        else:
            lines.append(f"SP  - {pages}")

    # DOI & URL
    doi = doc_meta.get("doi")
    url = doc_meta.get("url")
    if doi:
        lines.append(f"DO  - {doi}")
    if url:
        lines.append(f"UR  - {url}")

    # Abstract
    abstract = doc_meta.get("abstract")
    if abstract:
        lines.append(f"AB  - {abstract[:500]}")  # Limit 500 char

    # Tanggal akses
    today = datetime.today().strftime("%Y/%m/%d")
    lines.append(f"Y2  - {today}")

    # End of record
    lines.append("ER  - ")

    return "\n".join(lines)


def to_ris_batch(documents: list[dict]) -> str:
    """Konversi multiple dokumen ke satu string RIS."""
    entries = [to_ris(doc) for doc in documents]
    return "\n\n".join(entries)


def apa7_citation(doc_meta: dict) -> str:
    """
    Generate sitasi singkat APA 7th untuk digunakan dalam teks.
    Contoh: "Apriani & Fadilla (2023)" atau "Kotler et al. (2020)"
    """
    authors = doc_meta.get("authors", [])
    year = doc_meta.get("year", "n.d.")

    if not authors:
        return f"(Unknown, {year})"

    # Ambil nama belakang saja
    last_names = []
    for author in authors:
        parts = author.strip().split()
        last_names.append(parts[-1] if parts else author)

    if len(last_names) == 1:
        return f"{last_names[0]} ({year})"
    elif len(last_names) == 2:
        return f"{last_names[0]} & {last_names[1]} ({year})"
    else:
        return f"{last_names[0]} et al. ({year})"
