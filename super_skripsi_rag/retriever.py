"""
retriever.py
Fungsi pencarian semantik yang mengembalikan top-k chunk
beserta skor relevansi dan nomor halaman.
"""

from vector_store import search


def semantic_search(
    query: str,
    doc_ids: list[str] | None = None,
    top_k: int = 5,
) -> list[dict]:
    """
    Cari chunk paling relevan secara semantik.

    Args:
        query:   Kalimat atau klaim yang ingin dicari padanannya di dokumen.
        doc_ids: Filter ke dokumen tertentu (None = semua dokumen).
        top_k:   Jumlah hasil yang dikembalikan.

    Returns:
        List chunk terurut dari paling relevan:
        [{
            'id', 'doc_id', 'content',
            'chunk_index', 'page_start', 'page_end', 'score'
        }]
    """
    results = search(query, doc_ids=doc_ids, top_k=top_k)

    # Buang hasil dengan skor sangat rendah (kemungkinan tidak relevan)
    SCORE_THRESHOLD = 0.25
    filtered = [r for r in results if r['score'] >= SCORE_THRESHOLD]

    if not filtered:
        # Kembalikan top-3 meski skor rendah (jangan kosong)
        filtered = results[:3]

    print(
        f"[Retriever] 🔍 Query: \"{query[:60]}...\" → "
        f"{len(filtered)} chunk (skor tertinggi: {filtered[0]['score'] if filtered else 'N/A'})"
    )
    return filtered
