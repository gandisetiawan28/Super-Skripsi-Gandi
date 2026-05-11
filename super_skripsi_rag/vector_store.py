import os
# Matikan telemetry ChromaDB sebelum import
os.environ["ANONYMIZED_TELEMETRY"] = "False"

import chromadb
from chromadb.config import Settings
from typing import Any

# Simpan referensi ke client agar tidak re-init terus
_chroma_client: Any = None
_current_user_id: str | None = None
DB_PATH = os.path.join(os.path.expanduser("~"), ".super_skripsi", "chroma_db")

def set_user_id(user_id: str | None):
    """Set ID user untuk isolasi database."""
    global _current_user_id, _chroma_client, DB_PATH
    if _current_user_id != user_id:
        _current_user_id = user_id
        # Reset client agar re-init dengan path baru
        _chroma_client = None
        
        # Update DB_PATH untuk kompatibilitas dengan main.py health check
        base_path = os.path.join(os.path.expanduser("~"), ".super_skripsi")
        if _current_user_id:
            DB_PATH = os.path.join(base_path, "users", _current_user_id, "chroma_db")
        else:
            DB_PATH = os.path.join(base_path, "chroma_db")

def _get_collection():
    global _chroma_client, _current_user_id, DB_PATH
    
    db_path = DB_PATH

    if not os.path.exists(db_path):
        os.makedirs(db_path, exist_ok=True)
    
    if _chroma_client is None:
        _chroma_client = chromadb.PersistentClient(
            path=db_path,
            settings=Settings(anonymized_telemetry=False)
        )
    
    # Gunakan koleksi tunggal 'rag_chunks'
    return _chroma_client.get_or_create_collection(name="rag_chunks")

def upsert_chunks(chunks: list[dict[str, Any]]):
    """Simpan atau update chunks ke ChromaDB."""
    if not chunks:
        return
    
    col = _get_collection()
    
    ids = [c['id'] for c in chunks]
    metadatas = []
    documents = []
    
    for c in chunks:
        # Use copy to avoid mutating the original dict if needed, 
        # but pop is okay here since we rebuild metas
        item = dict(c)
        doc = item.pop('content', '')
        documents.append(doc)
        metadatas.append(item)
        
    col.upsert(
        ids=ids,
        metadatas=metadatas,
        documents=documents
    )

def search(
    query: str,
    doc_ids: list[str] | None = None,
    top_k: int = 5,
    filter_key: str | None = None,
    filter_val: str | None = None,
    bab: str | None = None,
    sub_bab: str | None = None,
) -> list[dict[str, Any]]:
    """
    Semantic search: cari top_k chunk paling relevan dengan query.
    """
    col = _get_collection()
    total = col.count()
    if total == 0:
        return []

    # 1. Bangun filter 'where'
    conditions = []
    if doc_ids:
        if len(doc_ids) == 1:
            conditions.append({"doc_id": {"$eq": doc_ids[0]}})
        else:
            conditions.append({"doc_id": {"$in": doc_ids}})
    
    if filter_key and filter_val:
        if "|" in filter_val:
            vals = [v.strip() for v in filter_val.split("|") if v.strip()]
            if vals: conditions.append({filter_key: {"$in": vals}})
        else:
            conditions.append({filter_key: {"$eq": filter_val.strip()}})

    if bab:
        conditions.append({"bab": {"$eq": bab.strip()}})

    if sub_bab:
        if "|" in sub_bab:
            vals = [v.strip() for v in sub_bab.split("|") if v.strip()]
            if vals: conditions.append({"sub_bab": {"$in": vals}})
        else:
            conditions.append({"sub_bab": {"$eq": sub_bab.strip()}})

    where = None
    if len(conditions) == 1:
        where = conditions[0]
    elif len(conditions) > 1:
        where = {"$and": conditions}

    # 2. Eksekusi Query
    results = None
    if not query or query.strip() == "":
        # Browse mode: gunakan get()
        results = col.get(
            limit=top_k * 5,
            where=where,
            include=["documents", "metadatas"]
        )
    else:
        # Semantic mode: gunakan query()
        # Perlu lazy import embedder untuk menghindari circular import
        from embedder import embed_query
        query_embedding = embed_query(query)
        results = col.query(
            query_embeddings=[query_embedding],
            n_results=top_k,
            where=where,
            include=["documents", "metadatas", "distances"]
        )

    # 3. FALLBACK: Jika tidak ada hasil dan ada filter, coba filter manual (Normalized)
    has_results = False
    if results:
        ids = results.get('ids', [])
        if ids and isinstance(ids[0], list): # format query()
            has_results = len(ids[0]) > 0
        else: # format get()
            has_results = len(ids) > 0

    if not has_results and (bab or sub_bab):
        print(f"[VectorStore] 🔍 Exact match gagal ({bab}/{sub_bab}). Mencoba fallback normalized...")
        all_recent = col.get(limit=300, include=["documents", "metadatas"])
        if all_recent and all_recent.get('ids'):
            fallback_items = []
            
            def normalize(s):
                return "".join(c.lower() for c in str(s) if c.isalnum())
            
            norm_bab = normalize(bab) if bab else None
            norm_sub_list = [normalize(v) for v in (sub_bab.split("|") if sub_bab else [])]
            
            for i in range(len(all_recent['ids'])):
                m = all_recent['metadatas'][i]
                m_bab = normalize(m.get('bab', ''))
                m_sub = normalize(m.get('sub_bab', ''))
                
                match_bab = True if not bab else (m_bab == norm_bab or m_sub == norm_bab)
                match_sub = True if not sub_bab else (m_sub in norm_sub_list)
                
                if match_bab and match_sub:
                    fallback_items.append({
                        'id': all_recent['ids'][i],
                        'content': all_recent['documents'][i],
                        'score': 0.85,
                        **m
                    })
            if fallback_items:
                print(f"[VectorStore] ✅ Fallback found {len(fallback_items)} items.")
                return fallback_items

    # 4. Format hasil akhir
    output = []
    if not results: return []

    ids = results.get('ids', [])
    docs = results.get('documents', [])
    metas = results.get('metadatas', [])
    dists = results.get('distances', [])

    # Normalisasi struktur (query returns list of lists, get returns list)
    if ids and isinstance(ids[0], list):
        ids, docs, metas = ids[0], docs[0], metas[0]
        dists = dists[0] if dists else []
    
    for i in range(len(ids)):
        score = 1.0
        if dists and i < len(dists):
            # Cosine distance to similarity
            score = round(1.0 - (dists[i] / 2.0), 4)
            
        output.append({
            'id': ids[i],
            'content': docs[i] if i < len(docs) else "",
            'score': score,
            **(metas[i] if i < len(metas) else {})
        })
        
    return output

def delete_document(doc_id: str) -> int:
    """Hapus semua chunk milik dokumen tertentu."""
    col = _get_collection()
    existing = col.get(where={"doc_id": {"$eq": doc_id}})
    ids_to_delete = existing['ids']
    if ids_to_delete:
        col.delete(ids=ids_to_delete)
        return len(ids_to_delete)
    return 0

def delete_chunk(chunk_id: str) -> bool:
    """Hapus satu chunk berdasarkan ID."""
    try:
        col = _get_collection()
        col.delete(ids=[chunk_id])
        return True
    except:
        return False

def delete_all_chunks() -> int:
    """Hapus seluruh isi database ChromaDB."""
    try:
        col = _get_collection()
        total = col.count()
        if total > 0:
            all_data = col.get()
            if all_data['ids']:
                col.delete(ids=all_data['ids'])
        return total
    except:
        return 0

def get_chunk_count() -> int:
    """Ambil total jumlah chunk."""
    try:
        col = _get_collection()
        return col.count()
    except:
        return 0

def list_documents() -> list[str]:
    """Ambil daftar unique doc_id."""
    return get_indexed_doc_ids()

def get_total_stats():
    """Ambil statistik jumlah dokumen dan chunk."""
    try:
        col = _get_collection()
        total_chunks = col.count()
        
        # Ambil unique doc_id
        all_meta = col.get(include=['metadatas'])
        doc_ids = set()
        for m in all_meta['metadatas']:
            if m and 'doc_id' in m:
                doc_ids.add(m['doc_id'])
                
        return {
            "total_chunks": total_chunks,
            "total_documents": len(doc_ids)
        }
    except:
        return {"total_chunks": 0, "total_documents": 0}

def get_indexed_doc_ids() -> list[str]:
    """Ambil daftar unique doc_id yang sudah ada di ChromaDB."""
    try:
        col = _get_collection()
        all_meta = col.get(include=['metadatas'])
        doc_ids = set()
        for m in all_meta['metadatas']:
            if m and 'doc_id' in m:
                doc_ids.add(m['doc_id'])
        return list(doc_ids)
    except:
        return []
