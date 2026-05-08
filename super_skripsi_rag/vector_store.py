"""
vector_store.py
Penyimpanan vector menggunakan ChromaDB (lokal, persisten).
Setiap chunk dokumen disimpan dengan embedding + metadata.

FIX v2: Kompatibel dengan ChromaDB 0.6.x
- Hapus import Settings dari chromadb.config (API berubah di 0.6.x)
- anonymized_telemetry kini diset via env var ANONYMIZED_TELEMETRY=False
"""

from __future__ import annotations

import os
import time
from pathlib import Path
import chromadb

from embedder import embed_texts, embed_query

# ── Matikan telemetry via env var (ChromaDB 0.6.x) ────────────────────────────
os.environ.setdefault("ANONYMIZED_TELEMETRY", "False")

# ── Konfigurasi ────────────────────────────────────────────────────────────────

DB_BASE_PATH = Path.home() / ".super_skripsi"
DB_PATH = DB_BASE_PATH / "chroma_db"
COLLECTION_NAME = "rag_chunks"

def set_user_id(user_id: str):
    """Update DB path based on user ID."""
    global DB_PATH
    if user_id:
        DB_PATH = DB_BASE_PATH / "users" / user_id / "chroma_db"
    else:
        DB_PATH = DB_BASE_PATH / "chroma_db"
    print(f"[VectorStore] 📂 Storage path set to: {DB_PATH}")


from typing import Optional, List, Dict, Any

# ── Singleton ChromaDB Client ─────────────────────────────────────────────────

_client: Any = None
_collection = None


def _get_collection():
    global _client, _collection
    if _collection is not None:
        return _collection

    DB_PATH.mkdir(parents=True, exist_ok=True)

    # ChromaDB 0.6.x: PersistentClient tidak perlu Settings object
    _client = chromadb.PersistentClient(path=str(DB_PATH))

    _collection = _client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
    )
    print(f"[VectorStore] ✅ ChromaDB siap di {DB_PATH}")
    return _collection


# ── Operasi CRUD ───────────────────────────────────────────────────────────────

def upsert_chunks(chunks: List[Dict]) -> int:
    """
    Simpan/update chunks ke ChromaDB.
    """
    if not chunks:
        return 0

    col = _get_collection()
    texts = [c['content'] for c in chunks]
    embeddings = embed_texts(texts)

    ids = [c['id'] for c in chunks]
    docs = texts
    metadatas = [
        {
            k: v for k, v in c.items() 
            if k not in ('id', 'content')
        }
        for c in chunks
    ]

    col.upsert(
        ids=ids,
        embeddings=embeddings,
        documents=docs,
        metadatas=metadatas,
    )

    print(f"[VectorStore] 💾 {len(chunks)} chunk di-upsert untuk doc_id={chunks[0]['doc_id']}")
    return len(chunks)


def search(
    query: str,
    doc_ids: Optional[List[str]] = None,
    top_k: int = 5,
) -> List[Dict]:
    """
    Semantic search: cari top_k chunk paling relevan dengan query.
    """
    col = _get_collection()
    total = col.count()
    if total == 0:
        return []

    # Filter doc_id jika ada
    where = None
    if doc_ids:
        if len(doc_ids) == 1:
            where = {"doc_id": {"$eq": doc_ids[0]}}
        else:
            where = {"doc_id": {"$in": doc_ids}}

    # JIKA QUERY KOSONG -> Browse mode
    if not query or query.strip() == "":
        results = col.get(
            limit=top_k * 10,
            where=where,
            include=["documents", "metadatas"]
        )
        output = []
        ids = results.get('ids') or []
        docs = results.get('documents') or []
        metas = results.get('metadatas') or []

        for i in range(len(ids)):
            doc_content = docs[i] if len(docs) > i else "No content"
            raw_meta = metas[i] if len(metas) > i else {}
            meta_data = dict(raw_meta) if raw_meta is not None else {}
            
            item = {
                'id': ids[i],
                'content': doc_content,
                'score': 1.0, 
                **meta_data
            }
            output.append(item)
        return output

    # JIKA ADA QUERY -> Semantic search mode
    query_embedding = embed_query(query)

    results = col.query(
        query_embeddings=[query_embedding],
        n_results=min(top_k, total),
        where=where,
        include=["documents", "metadatas", "distances"],
    )

    output = []
    # Resilient access to results
    all_ids = (results.get('ids') or [[]])[0]
    all_docs = (results.get('documents') or [[]])[0]
    all_metas = (results.get('metadatas') or [[]])[0]
    all_dists = (results.get('distances') or [[]])[0]

    for i in range(len(all_ids)):
        doc = all_docs[i] if len(all_docs) > i else ""
        meta = all_metas[i] if len(all_metas) > i else {}
        dist = all_dists[i] if len(all_dists) > i else 1.0
        
        # ChromaDB cosine distance: 0 = identical, 2 = opposite
        score = 1.0 - (dist / 2.0)
        item = {
            'id': all_ids[i],
            'content': doc,
            'score': round(score, 4),
            **(dict(meta) if meta else {})
        }
        output.append(item)

    return output


def delete_document(doc_id: str) -> int:
    """Hapus semua chunk milik dokumen tertentu."""
    col = _get_collection()
    existing = col.get(where={"doc_id": {"$eq": doc_id}})
    ids_to_delete = existing['ids']
    if ids_to_delete:
        col.delete(ids=ids_to_delete)
        print(f"[VectorStore] 🗑️ {len(ids_to_delete)} chunk dihapus untuk doc_id={doc_id}")
    return len(ids_to_delete)


def delete_chunk(chunk_id: str) -> bool:
    """Hapus spesifik satu chunk."""
    col = _get_collection()
    existing = col.get(ids=[chunk_id])
    if existing['ids']:
        col.delete(ids=[chunk_id])
        print(f"[VectorStore] 🗑️ Chunk {chunk_id} dihapus.")
        return True
    return False


def delete_all_chunks() -> int:
    """Hapus SEMUA data dari ChromaDB (reset collection) secara aman."""
    try:
        col = _get_collection()
        count = col.count()
        if count == 0:
            return 0
            
        # Ambil semua ID yang ada
        results = col.get()
        ids = results.get('ids', [])
        
        if ids:
            # Hapus bertahap jika data sangat besar (opsional, tapi aman)
            col.delete(ids=ids)
            print(f"[VectorStore] 🧨 Berhasil menghapus {len(ids)} data!")
            return len(ids)
        return 0
    except Exception as e:
        print(f"[VectorStore] ⚠️ Gagal membersihkan data: {e}")
        return 0


def list_documents() -> List[str]:
    """Kembalikan daftar doc_id unik yang tersimpan."""
    col = _get_collection()
    res = col.get(include=["metadatas"])
    all_meta = res.get('metadatas', [])
    
    doc_ids = set()
    if all_meta:
        for m in all_meta:
            if m and 'doc_id' in m:
                doc_ids.add(str(m['doc_id']))
    return list(doc_ids)


def get_chunk_count(doc_id: str | None = None) -> int:
    """Total chunks tersimpan (opsional filter per dokumen)."""
    col = _get_collection()
    if doc_id:
        return len(col.get(where={"doc_id": {"$eq": doc_id}})['ids'])
    return col.count()
