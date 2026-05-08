/**
 * ragBridge.js
 * Bridge ke Python RAG Microservice (http://localhost:28146).
 *
 * Menyediakan semantic search yang jauh lebih akurat dari TF-IDF
 * karena menggunakan SentenceTransformers + ChromaDB.
 *
 * Jika Python service tidak aktif, semua fungsi mengembalikan null/[]
 * sehingga retrievalAgent.js bisa fallback ke Flutter Manager (TF-IDF).
 */

const RAG_SERVICE_URL = 'http://localhost:28146';
const TIMEOUT_MS = 5000;

/**
 * Cek apakah Python RAG service sedang aktif.
 * @returns {Promise<boolean>}
 */
export async function isRagServiceAvailable() {
  try {
    const res = await fetch(`${RAG_SERVICE_URL}/health`);
    if (!res.ok) return false;
    const data = await res.json();
    return data.status === 'ok' && data.embedder === 'ready';
  } catch {
    return false;
  }
}

/**
 * Semantic search menggunakan ChromaDB + SentenceTransformers.
 *
 * @param {string}   query   - Kalimat query
 * @param {string[]} docIds  - Filter dokumen (kosong = semua)
 * @param {number}   topK    - Jumlah hasil
 * @returns {Promise<Array<{id, doc_id, content, chunk_index, page_start, page_end, score}> | null>}
 *          null jika service tidak aktif
 */
export async function semanticSearch(query, docIds = [], topK = 8) {
  try {
    const params = new URLSearchParams({ q: query, top_k: topK });
    if (docIds.length > 0) {
      params.set('doc_ids', docIds.join(','));
    }

    const res = await fetch(`${RAG_SERVICE_URL}/search?${params}`);

    if (!res.ok) {
      console.warn(`[RAG Bridge] Search failed: HTTP ${res.status}`);
      return null;
    }

    const data = await res.json();
    const results = data.results || [];

    console.log(
      `[RAG Bridge] ✅ Semantic search: ${results.length} chunk ` +
      `(skor max: ${results[0]?.score?.toFixed(3) ?? 'N/A'})`
    );

    // Map ke format yang sama dengan TF-IDF search di managerBridge.js
     return results.map(r => ({
       chunkIndex: r.chunk_index,
       content: r.content,
       sitasi: r.sitasi || 'Unknown', // Ambil data sitasi dari metadata ChromaDB
       startPage: r.page_start,
       endPage: r.page_end,
       score: r.score,
       documentId: r.doc_id,
       source: 'semantic', 
     }));
  } catch (e) {
    if (e.name === 'TimeoutError') {
      console.warn('[RAG Bridge] ⏱️ Timeout saat semantic search.');
    } else {
      console.warn('[RAG Bridge] ❌ Error:', e.message);
    }
    return null;
  }
}

/**
 * LLM Extraction Agent via Python service.
 * Menggabungkan semantic retrieval + LLM extraction dalam 1 HTTP call.
 *
 * @param {string}   query    - Klaim/pertanyaan penelitian
 * @param {string[]} docIds   - Dokumen yang dicari
 * @param {string}   apiKey   - API key LLM
 * @param {string}   provider - Provider LLM (cerebras, gemini, dll)
 * @param {string}   model    - Model name
 * @returns {Promise<{extractions, ris, citation, doc_meta} | null>}
 */
export async function extractWithLLM(query, docIds, apiKey, provider = 'cerebras', model = 'cerebras/llama-3.3-70b') {
  try {
    const res = await fetch(`${RAG_SERVICE_URL}/extract`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query,
        doc_ids: docIds.length > 0 ? docIds : null,
        api_key: apiKey,
        provider,
        model,
        top_k: 6,
      }),
    });

    if (!res.ok) {
      console.warn(`[RAG Bridge] Extract failed: HTTP ${res.status}`);
      return null;
    }

    return await res.json();
  } catch (e) {
    console.warn('[RAG Bridge] ❌ Extract error:', e.message);
    return null;
  }
}

/**
 * Upload dokumen PDF ke Python RAG service untuk diindeks.
 * Dipanggil setelah Flutter Manager berhasil menyimpan dokumen.
 *
 * @param {File|Blob} pdfBlob  - PDF file
 * @param {Object}   docMeta   - {doc_id, title, authors, year, ...}
 * @returns {Promise<boolean>}
 */
export async function uploadToRagService(pdfBlob, docMeta) {
  try {
    const form = new FormData();
    form.append('file', pdfBlob, `${docMeta.doc_id}.pdf`);
    form.append('doc_id', docMeta.doc_id || '');
    form.append('title', docMeta.title || '');
    form.append('authors', JSON.stringify(docMeta.authors || []));
    form.append('year', String(docMeta.year || ''));
    form.append('journal_name', docMeta.journalName || '');

    const res = await fetch(`${RAG_SERVICE_URL}/upload`, {
      method: 'POST',
      body: form,
    });

    if (!res.ok) {
      console.warn(`[RAG Bridge] Upload failed: HTTP ${res.status}`);
      return false;
    }

    const data = await res.json();
    console.log(`[RAG Bridge] 📤 Upload berhasil: ${data.chunk_count} chunk untuk "${data.title}"`);
    return true;
  } catch (e) {
    console.warn('[RAG Bridge] ❌ Upload error:', e.message);
    return false;
  }
}
