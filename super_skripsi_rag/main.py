"""
main.py — FastAPI RAG Microservice
Port: 28146
Endpoint:
  POST /upload                 Upload & ingest PDF ke ChromaDB
  GET  /search                 Semantic search
  POST /extract                LLM extraction agent
  GET  /documents              List semua dokumen
  DELETE /documents/{doc_id}  Hapus dokumen
  GET  /health                 Health check
"""

import os
import sys

# ── CRITICAL: Ensure script's own directory is in sys.path ──────────────────
# Fixes ModuleNotFoundError when installed to paths with spaces
# (e.g., "C:\Program Files (x86)\Super Skripsi Gandi\rag")
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

os.environ["ANONYMIZED_TELEMETRY"] = "False"
import hashlib
import json
import uuid
from pathlib import Path
from typing import List, Dict, Optional, Any, Union

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from pdf_extractor import extract_pdf
from theory_processor import extract_structured_theories
from llm_extractor import extract_from_chunks # NEW
from chunker import chunk_pages
from vector_store import upsert_chunks, search, delete_document, list_documents, get_chunk_count, delete_chunk, delete_all_chunks
from retriever import semantic_search
from ris_generator import to_ris, apa7_citation
from embedder import is_ready, preload_model_background

# ── Global Cancellation State ──────────────────────────────────────────────────
is_aborted = False

# ── App Setup ──────────────────────────────────────────────────────────────────

from contextlib import asynccontextmanager
import httpx as _httpx


@asynccontextmanager
async def lifespan(app):
    # Preload embedding model di background saat startup
    # Mencegah cold-start hang saat request pertama masuk
    print("[Startup] 🚀 Preloading embedding model di background...")
    preload_model_background()
    yield


app = FastAPI(
    title="Super Skripsi RAG Service",
    description="Semantic RAG microservice untuk ekosistem Parafrase Gandi.",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Paths ──────────────────────────────────────────────────────────────────────
DB_BASE_PATH = Path.home() / ".super_skripsi"
UPLOAD_DIR = DB_BASE_PATH / "uploaded_pdfs"
DOC_REGISTRY_PATH = DB_BASE_PATH / "doc_registry.json"

def setup_paths(user_id: Optional[str] = None):
    global UPLOAD_DIR, DOC_REGISTRY_PATH
    if user_id:
        user_root = DB_BASE_PATH / "users" / user_id
        UPLOAD_DIR = user_root / "uploaded_pdfs"
        DOC_REGISTRY_PATH = user_root / "doc_registry.json"
        print(f"[Startup] 👤 User context detected: {user_id}")
    else:
        print("[Startup] 🌐 Using global/guest context.")
    
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[Startup] 📂 Upload directory: {UPLOAD_DIR}")
    print(f"[Startup] 📝 Registry path: {DOC_REGISTRY_PATH}")
    
    from vector_store import set_user_id
    set_user_id(user_id)


def _load_registry() -> dict:
    if DOC_REGISTRY_PATH.exists():
        return json.loads(DOC_REGISTRY_PATH.read_text(encoding="utf-8"))
    return {}


def _save_registry(registry: dict):
    DOC_REGISTRY_PATH.write_text(
        json.dumps(registry, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


# ── Models ─────────────────────────────────────────────────────────────────────

class SearchRequest(BaseModel):
    query: str
    doc_ids: Optional[List[str]] = None
    top_k: int = 5


class ExtractRequest(BaseModel):
    query: str
    doc_ids: Optional[List[str]] = None
    api_key: str
    provider: str = "cerebras"
    model: str = "cerebras/llama-3.3-70b"
    top_k: int = 6


@app.post("/abort")
def abort_process():
    """Mengaktifkan flag pembatalan untuk proses yang sedang berjalan."""
    global is_aborted
    is_aborted = True
    print("[RAG] 🛑 Sinyal pembatalan (ABORT) diterima!")
    return {"status": "aborted"}


# ── Endpoints ──────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    """Health check — cek kesiapan embedder dan ChromaDB."""
    from vector_store import DB_PATH
    embedder_ready = is_ready()
    total_chunks = get_chunk_count()
    docs = list_documents()
    
    # Ambil user_id dari path database jika ada
    # Path format: .../users/{user_id}/chroma_db
    user_id = "global"
    if "/users/" in str(DB_PATH).replace("\\", "/"):
        user_id = str(DB_PATH).replace("\\", "/").split("/users/")[1].split("/")[0]

    return {
        "status": "ok",
        "service": "Super Skripsi RAG",
        "user_id": user_id,
        "version": "2.0.0",
        "port": 28146,
        "embedder": "ready" if embedder_ready else "loading",
        "total_chunks": total_chunks,
        "total_documents": len(docs),
    }


@app.get("/models")
async def fetch_models(provider: str, api_key: str):
    """
    Proxy endpoint: fetch daftar model live dari provider AI.
    Dipakai oleh add-in untuk dynamic model dropdown.

    Query params:
      provider: 'openai' | 'groq' | 'anthropic' | 'gemini' | 'deepseek' | 'xai'
      api_key:  API key user untuk provider tersebut
    """
    provider_lower = provider.lower()
    models: list[str] = []

    try:
        async with _httpx.AsyncClient(timeout=10.0) as client:

            # ── OpenAI-compatible (OpenAI, Groq, DeepSeek, xAI, Cerebras) ────────
            if provider_lower in ("openai", "groq", "deepseek", "xai", "cerebras"):
                urls = {
                    "openai": "https://api.openai.com/v1/models",
                    "groq": "https://api.groq.com/openai/v1/models",
                    "deepseek": "https://api.deepseek.com/v1/models",
                    "xai": "https://api.x.ai/v1/models",
                    "cerebras": "https://api.cerebras.ai/v1/models",
                }
                resp = await client.get(
                    urls[provider_lower],
                    headers={"Authorization": f"Bearer {api_key}"},
                )
                resp.raise_for_status()
                data = resp.json()
                raw = [m["id"] for m in data.get("data", [])]

                # Filter: hanya model yang relevan untuk chat
                if provider_lower == "openai":
                    raw = [m for m in raw if "gpt" in m or "o1" in m or "o3" in m or "o4" in m]
                elif provider_lower == "groq":
                    raw = [m for m in raw if not m.endswith("-tool-use")]

                models = sorted(raw)

            # ── Anthropic ───────────────────────────────────────────────────────
            elif provider_lower == "anthropic":
                resp = await client.get(
                    "https://api.anthropic.com/v1/models",
                    headers={
                        "x-api-key": api_key,
                        "anthropic-version": "2023-06-01",
                    },
                )
                resp.raise_for_status()
                data = resp.json()
                models = sorted([m["id"] for m in data.get("data", [])])

            # ── Google Gemini ───────────────────────────────────────────────────
            elif provider_lower in ("gemini", "google gemini"):
                resp = await client.get(
                    f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}",
                )
                resp.raise_for_status()
                data = resp.json()
                raw = [
                    m["name"].replace("models/", "")
                    for m in data.get("models", [])
                    if "generateContent" in m.get("supportedGenerationMethods", [])
                ]
                models = sorted(raw)

            # ── Localhost (Ollama, LM Studio, etc.) ─────────────────────────────
            elif provider_lower == "localhost":
                base_url = api_key if api_key.startswith("http") else "http://localhost:11434/v1"
                
                # Gemini Flow Bridge Detection
                if ":3000" in base_url or "/api/" in base_url:
                    models = ["gemini", "openai", "claude", "groq", "deepseek", "xai", "cerebras"]
                else:
                    # Try OpenAI-compatible /models first
                    try:
                        target_url = base_url.rstrip("/") + "/models"
                        resp = await client.get(target_url)
                        if resp.status_code == 200:
                            data = resp.json()
                            models = sorted([m["id"] for m in data.get("data", [])])
                        else:
                            # Try Ollama native /api/tags if port is 11434
                            if ":11434" in base_url:
                                ollama_url = base_url.split("/v1")[0] + "/api/tags"
                                resp = await client.get(ollama_url)
                                if resp.status_code == 200:
                                    data = resp.json()
                                    models = sorted([m["name"] for m in data.get("models", [])])
                                else:
                                    models = ["llama3", "mistral", "phi3"] # Fallback
                            else:
                                models = ["llama3", "mistral", "phi3"] # Fallback
                    except:
                        models = ["llama3", "mistral", "phi3"] # Fallback

            else:
                raise HTTPException(400, f"Provider '{provider}' tidak dikenali.")

    except _httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Provider API error: {e.response.text[:300]}",
        )
    except Exception as e:
        import traceback
        print("\n" + "!"*50)
        print(f"[RAG ERROR] Gagal melakukan indexing!")
        print(f"Detail: {str(e)}")
        print(traceback.format_exc())
        print("!"*50 + "\n")
        raise HTTPException(500, f"Internal Server Error: {str(e)}")

    return {
        "provider": provider,
        "count": len(models),
        "models": models,
        "source": "live",
    }



@app.post("/upload")
async def upload_pdf(
    file: UploadFile = File(...),
    title: str = Form(""),
    authors: str = Form("[]"),       # JSON list string
    year: str = Form(""),
    journal_name: str = Form(""),
    volume: str = Form(""),
    issue: str = Form(""),
    pages: str = Form(""),
    category: str = Form(""),
    doc_id: str = Form(""),          # Opsional: gunakan ID dari Flutter Manager
    api_key: str = Form(""),         # NEW: Untuk structured RAG Indexing
    provider: str = Form("gemini"),  # NEW
    model: str = Form(""),           # NEW
    judul_skripsi: str = Form(""),       # RESEARCH CONTEXT
    lokasi_penelitian: str = Form(""),   # RESEARCH CONTEXT
    kerangka_skripsi: str = Form(""),    # RESEARCH CONTEXT
    system_prompt: str = Form(""),       # NEW: Prompt dari Dart
):
    """
    Upload PDF → ekstrak → chunk → embed → simpan ke ChromaDB.
    Mengembalikan doc_id dan jumlah chunk yang diproses.
    """
    try:
        if not file.filename or not file.filename.endswith(".pdf"):
            raise HTTPException(400, "Hanya file PDF yang diterima.")

        # Baca file
        content = await file.read()

        # MD5 hash untuk dedup
        md5 = hashlib.md5(content).hexdigest()

        # Gunakan doc_id dari Flutter Manager jika ada, else generate
        effective_doc_id = doc_id.strip() if doc_id.strip() else str(uuid.uuid4())

        # Simpan file sementara
        tmp_path = UPLOAD_DIR / f"{effective_doc_id}.pdf"
        tmp_path.write_bytes(content)

        # Ekstrak teks
        extracted = extract_pdf(str(tmp_path))

        # Chunk dengan page-awareness
        chunks_obj = chunk_pages(effective_doc_id, extracted["page_texts"])

        if not chunks_obj:
            raise HTTPException(422, "Tidak berhasil mengekstrak teks dari PDF ini.")

        # Parse authors
        try:
            authors_list = json.loads(authors) if authors else []
        except Exception:
            authors_list = [a.strip() for a in authors.split(",") if a.strip()]

        # [MANDATORY] Structured RAG pass
        if not api_key:
            print("[RAG] ❌ Gagal: API Key kosong!")
            raise HTTPException(400, "API Key wajib ada untuk Structured RAG Indexing.")

        # Ambil seluruh teks dokumen (bukan kuncinya saja)
        all_text = extracted.get("full_text", "")
        if not all_text:
             # Fallback jika full_text kosong, coba gabungkan dari page_texts values
             page_data = extracted.get("page_texts", {})
             if isinstance(page_data, dict):
                 all_text = "\n\n".join([str(v) for v in page_data.values()])
             else:
                 all_text = str(page_data)

        print(f"[RAG] 🤖 Mengirim {len(all_text)} karakter ke AI ({provider})...")
        
        global is_aborted
        is_aborted = False # Reset flag before start

        extraction_result = await extract_structured_theories(
            all_text, 
            api_key, 
            provider, 
            model,
            judul_skripsi=judul_skripsi,
            lokasi_penelitian=lokasi_penelitian,
            kerangka_skripsi=kerangka_skripsi,
            doc_title=title or extracted.get("title", file.filename),
            doc_authors=", ".join(authors_list) if authors_list else "Tidak diketahui",
            doc_year=year or "n/a",
            doc_journal=journal_name or "Tidak tersedia",
            custom_prompt=system_prompt,
            check_abort=lambda: is_aborted # Pass check function
        )

        theories = extraction_result.get("theories", [])
        ai_meta = extraction_result.get("metadata", {})

        
        if not theories:
            print(f"[RAG] ❌ AI tidak memberikan hasil atau gagal parsing JSON.")
            raise HTTPException(422, "AI gagal mengekstrak teori. Cek API Key atau kuota AI Anda.")

        print(f"[RAG] 🧬 AI Berhasil! Ditemukan {len(theories)} data terstruktur.")
        print(f"[RAG] 📝 Sampel data pertama: {theories[0] if theories else 'Empty'}")

        # Upsert ke ChromaDB dengan mapping yang lebih cerdas (resilient mapping)
        chunk_dicts = []
        for i, t in enumerate(theories):
            # Ambil konten utama (AI kadang pakai nama kunci berbeda)
            content = (
                t.get("kutipan_verbatim") or 
                t.get("kutipan") or 
                t.get("teks") or 
                t.get("sub_bab") or 
                "No content"
            )
            
            # Ambil halaman (resilient)
            page_val = t.get("halaman") or t.get("page") or "0"
            
            # Ambil sitasi/author (resilient)
            sitasi_val = (
                t.get("sitasi") or 
                t.get("sumber") or 
                t.get("author_year") or 
                t.get("cleaned_author") or 
                t.get("penulis") or
                "Unknown"
            )
            
            # Tambahkan tahun jika ada dan belum ada di sitasi_val
            tahun_val = str(t.get("tahun") or "")
            if tahun_val and tahun_val not in sitasi_val:
                sitasi_val = f"{sitasi_val} ({tahun_val})"
            
            # Ambil sub_bab/konteks (resilient)
            sub_bab_val = str(
                t.get("sub_bab") or 
                t.get("variable_terkait") or 
                t.get("konteks") or 
                "Umum"
            ).strip()

            # Infer Bab (NEW)
            # Logika: Jika sub_bab diawali angka '1.', maka Bab 1. Jika ada kata 'Bab 2', maka Bab 2.
            bab_val = "Umum"
            sb_lower = sub_bab_val.lower()
            if "bab 1" in sb_lower or sub_bab_val.startswith("1."): bab_val = "Bab 1"
            elif "bab 2" in sb_lower or sub_bab_val.startswith("2."): bab_val = "Bab 2"
            elif "bab 3" in sb_lower or sub_bab_val.startswith("3."): bab_val = "Bab 3"
            elif "bab 4" in sb_lower or sub_bab_val.startswith("4."): bab_val = "Bab 4"
            elif "bab 5" in sb_lower or sub_bab_val.startswith("5."): bab_val = "Bab 5"
            # Fallback: Cari angka pertama
            elif sub_bab_val and sub_bab_val[0].isdigit():
                bab_val = f"Bab {sub_bab_val[0]}"

            # Ambil jenis sumber (primer/sekunder)
            jenis_val = str(t.get("jenis_sumber") or t.get("citation_type") or t.get("jenis") or "Primer").strip()

            # Buat metadata bersih untuk ChromaDB
            meta = {
                "id": f"{effective_doc_id}_theory_{i}",
                "doc_id": effective_doc_id,
                "content": str(content).strip(),
                "chunk_index": i,
                "is_structured": "true",
                "halaman": str(page_val).strip(),
                "bab": bab_val,
                "sub_bab": sub_bab_val,
                "sitasi": str(sitasi_val).strip(),
                "jenis_sumber": jenis_val,
                "daftar_pustaka_source": str(t.get("daftar_pustaka_source") or t.get("tahun") or "-").strip()
            }
            # Tambahkan sisa metadata dari AI jika ada (pastikan string & strip)
            for k, v in t.items():
                if k not in meta:
                    meta[k] = str(v).strip()
            
            chunk_dicts.append(meta)
        
        upsert_chunks(chunk_dicts)

        # Simpan metadata ke registry
        doc_meta = {
            "doc_id": effective_doc_id,
            "md5": md5,
            "title": title or extracted.get("title", file.filename),
            "authors": authors_list,
            "year": year or None,
            "journal_name": journal_name or None,
            "volume": volume or None,
            "issue": issue or None,
            "pages": pages or None,
            "category": category or None,
            "page_count": extracted["page_count"],
            "chunk_count": len(chunk_dicts),
            "file_path": str(tmp_path),
        }
        registry = _load_registry()
        registry[effective_doc_id] = doc_meta
        _save_registry(registry)

        return {
            "success": True,
            "doc_id": effective_doc_id,
            "chunk_count": len(chunk_dicts),
            "page_count": extracted["page_count"],
            "title": doc_meta["title"],
            "metadata": ai_meta, # Return AI extracted metadata
            "ris": to_ris(doc_meta),
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print("\n" + "!"*50)
        print(f"[RAG ERROR INDEXING] Gagal memproses dokumen!")
        print(f"Detail: {str(e)}")
        print(traceback.format_exc())
        print("!"*50 + "\n")
        raise HTTPException(500, f"Internal Server Error: {str(e)}")


@app.get("/search")
def search_endpoint(
    q: str = "",
    doc_ids: str = "",
    top_k: int = 5,
    filter_key: str = "",
    filter_val: str = "",
    bab: Optional[str] = None,
    sub_bab: Optional[str] = None,
):
    """
    Semantic search. Query params:
      q:       kalimat query (jika kosong = browse all)
      doc_ids: comma-separated doc_id
      top_k:   jumlah hasil
      bab:     filter bab (opsional)
      sub_bab: filter sub_bab (opsional)
    """
    ids = [d.strip() for d in doc_ids.split(",") if d.strip()] if doc_ids else None
    results = semantic_search(
        q, 
        doc_ids=ids, 
        top_k=top_k, 
        filter_key=filter_key, 
        filter_val=filter_val,
        bab=bab,
        sub_bab=sub_bab
    )

    return {
        "query": q,
        "count": len(results),
        "results": results,
    }


@app.post("/add_manual")
def add_manual(data: Dict):
    """Menambahkan data teori secara manual ke ChromaDB"""
    try:
        doc_id = data.get("doc_id")
        content = data.get("content")
        metadata = data.get("metadata", {})
        
        if not doc_id or not content:
            raise HTTPException(status_code=400, detail="doc_id and content are required")
            
        import uuid
        manual_id = f"manual_{uuid.uuid4().hex}"
        
        # Simpan ke ChromaDB
        # Perlu import upsert_chunks dari vector_store? Tidak, kita bisa pakai collection langsung
        # tapi metadata harus string-friendly
        clean_meta = {
            "id": manual_id,
            "doc_id": str(doc_id),
            "content": str(content),
            "is_structured": "true",
        }
        for k, v in metadata.items():
            clean_meta[k] = str(v)

        from vector_store import upsert_chunks
        upsert_chunks([clean_meta])
        
        return {"status": "ok", "id": manual_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/extract")
def extract_endpoint(req: ExtractRequest):
    """
    LLM Extraction Agent:
    1. Semantic search → top chunks
    2. Kirim ke LLM → verbatim + parafrase + halaman + sitasi
    3. Return hasil + RIS
    """
    ids = req.doc_ids or None

    # Tahap 1: Semantic retrieval
    chunks = semantic_search(req.query, doc_ids=ids, top_k=req.top_k)
    if not chunks:
        raise HTTPException(404, "Tidak ditemukan chunk relevan untuk query ini.")

    # Ambil metadata dari registry (gunakan doc pertama)
    registry = _load_registry()
    first_doc_id = chunks[0]["doc_id"]
    doc_meta = registry.get(first_doc_id, {"title": "Unknown", "authors": [], "year": None})

    # Tahap 2: LLM extraction
    result = extract_from_chunks(
        query=req.query,
        chunks=chunks,
        doc_meta=doc_meta,
        api_key=req.api_key,
        provider=req.provider,
        model=req.model,
    )

    return {
        "query": req.query,
        "chunks_used": len(chunks),
        "extractions": result["extractions"],
        "doc_meta": result["doc_meta"],
        "ris": result["ris"],
        "citation": apa7_citation(doc_meta),
    }


@app.get("/documents")
def list_docs():
    """Kembalikan semua dokumen yang tersimpan di ChromaDB."""
    registry = _load_registry()
    return {
        "count": len(registry),
        "documents": list(registry.values()),
    }


@app.delete("/documents/all")
def delete_all_documents():
    """Hapus semua dokumen dan chunks dari ChromaDB dan registry."""
    deleted_count = delete_all_chunks()
    _save_registry({})
    
    # Hapus juga file-file di UPLOAD_DIR
    for f in UPLOAD_DIR.glob("*.pdf"):
        try:
            f.unlink()
        except Exception:
            pass

    return {
        "success": True,
        "chunks_deleted": deleted_count,
        "message": "Semua data RAG telah dibersihkan."
    }


@app.delete("/documents/{doc_id}")
def delete_doc(doc_id: str):
    """Hapus dokumen dari ChromaDB dan registry."""
    deleted_chunks = delete_document(doc_id)

    registry = _load_registry()
    doc_meta = registry.pop(doc_id, None)
    _save_registry(registry)

    # Hapus file PDF jika ada
    if doc_meta and doc_meta.get("file_path"):
        try:
            Path(doc_meta["file_path"]).unlink(missing_ok=True)
        except Exception:
            pass

    if doc_meta is None and deleted_chunks == 0:
        raise HTTPException(404, f"Dokumen {doc_id} tidak ditemukan.")

    return {
        "success": True,
        "doc_id": doc_id,
        "chunks_deleted": deleted_chunks,
    }


@app.post("/documents/update")
def update_document_metadata(data: Dict):
    """Update metadata dokumen di registry (doc_registry.json)."""
    doc_id = None
    try:
        doc_id = data.get("doc_id")
        new_meta = data.get("metadata", {})
        
        if not doc_id:
            raise HTTPException(400, "doc_id wajib diisi")
            
        registry = _load_registry()
        if doc_id not in registry:
            raise HTTPException(404, f"Dokumen {doc_id} tidak ditemukan di registry.")
            
        # Update metadata di registry
        doc = registry[doc_id]
        for k, v in new_meta.items():
            doc[k] = v
            
        _save_registry(registry)
        
        return {"status": "ok", "doc_id": doc_id}
    except Exception as e:
        print(f"[RAG] ❌ Error updating document {doc_id}: {e}")
        raise HTTPException(500, detail=str(e))


@app.post("/chunks/update")
def update_chunk_metadata(data: Dict):
    """Update metadata untuk satu chunk spesifik di ChromaDB."""
    chunk_id = None
    try:
        chunk_id = data.get("chunk_id")
        new_metadata = data.get("metadata", {})
        
        if not chunk_id:
            raise HTTPException(status_code=400, detail="chunk_id wajib diisi")
            
        from vector_store import _get_collection
        col = _get_collection()
        
        # Ambil data lama untuk memastikan chunk ada
        res = col.get(ids=[chunk_id], include=['metadatas'])
        if not res['ids']:
             raise HTTPException(404, f"Chunk {chunk_id} tidak ditemukan.")

        # Gabungkan metadata lama dengan yang baru
        # Gunakan dict() untuk memastikan objek bisa diubah (mutable)
        raw_meta = res['metadatas'][0] if (res.get('metadatas') and len(res['metadatas']) > 0) else {}
        current_meta = dict(raw_meta) if raw_meta is not None else {}
        
        for k, v in new_metadata.items():
            current_meta[k] = str(v)
            
        # Simpan perubahan
        col.update(
            ids=[chunk_id],
            metadatas=[current_meta]
        )
        
        return {"status": "ok", "chunk_id": chunk_id, "updated_fields": list(new_metadata.keys())}
    except Exception as e:
        print(f"[RAG] ❌ Error updating chunk {chunk_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/chunks/{chunk_id}")
def delete_chunk_endpoint(chunk_id: str):
    """Hapus satu spesifik chunk berdasarkan ID."""
    success = delete_chunk(chunk_id)
    if not success:
        raise HTTPException(404, f"Chunk {chunk_id} tidak ditemukan.")
    return {"success": True, "chunk_id": chunk_id}


# ── Entry Point ────────────────────────────────────────────────────────────────

import os
import signal
import threading
import time

import sys

def watchdog():
    """Mematikan server jika pipe stdin tertutup (berarti parent/Flutter mati)."""
    print("[Watchdog] Menunggu sinyal dari parent...")
    sys.stdin.read() # Akan memblokir sampai stdin ditutup (EOF)
    print("[Watchdog] Parent process ditutup. Mematikan RAG service...")
    os.kill(os.getpid(), signal.SIGTERM)

@app.get("/indexed_docs")
async def get_indexed_docs():
    """Mengambil daftar doc_id yang sudah ada di ChromaDB"""
    try:
        from vector_store import _get_collection
        col = _get_collection()
        
        # Cek apakah koleksi ada datanya
        count = col.count()
        if count == 0:
            return {"indexed_ids": []}

        # Ambil semua metadata
        results = col.get(include=['metadatas'])
        metadatas = results.get('metadatas', [])
        
        if not metadatas:
            return {"indexed_ids": []}
            
        # Ekstrak unique doc_id dengan pengamanan ekstra
        indexed_ids = []
        for m in metadatas:
            if m and isinstance(m, dict) and m.get('doc_id'):
                indexed_ids.append(m.get('doc_id'))
        
        return {"indexed_ids": list(set(indexed_ids))}
    except Exception as e:
        print(f"[RAG] ❌ Error in /indexed_docs: {e}")
        # Jangan lempar 500, kembalikan list kosong saja agar UI tidak hang
        return {"indexed_ids": [], "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=28146)
    parser.add_argument("--parent-pid", type=int, default=0)
    parser.add_argument("--user-id", default="") # Folder ID unik per user
    args = parser.parse_args()

    # Inisialisasi Path berdasarkan user
    setup_paths(args.user_id)

    # Jalankan watchdog di thread terpisah
    thread = threading.Thread(target=watchdog, daemon=True)
    thread.start()

    uvicorn.run(app, host=args.host, port=args.port, loop="asyncio")
