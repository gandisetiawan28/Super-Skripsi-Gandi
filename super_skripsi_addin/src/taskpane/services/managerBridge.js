/**
 * Manager Bridge Service
 * Fetches API keys and document data from the Flutter Manager's local HTTP server
 */

const MANAGER_URL = 'http://localhost:28145';

export async function checkManagerConnection() {
  try {
    // Gunakan fetch biasa tanpa timeout modern agar kompatibel dengan Word WebView
    const res = await fetch(`${MANAGER_URL}/api/health`);
    return res.ok;
  } catch (e) {
    return false;
  }
}

export async function fetchApiKeys() {
  try {
    const res = await fetch(`${MANAGER_URL}/api/keys`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return data.keys || {};
  } catch (e) {
    console.warn('Failed to fetch API keys from Manager:', e);
    return {};
  }
}

export async function fetchDocuments() {
  try {
    const res = await fetch(`${MANAGER_URL}/api/documents`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return data.documents || [];
  } catch (e) {
    console.warn('Failed to fetch documents from Manager:', e);
    return [];
  }
}

export async function fetchDocumentChunks(docId) {
  try {
    const res = await fetch(`${MANAGER_URL}/api/documents/${docId}/chunks`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return data.chunks || [];
  } catch (e) {
    console.warn('Failed to fetch chunks:', e);
    return [];
  }
}

const RAG_URL = 'http://localhost:28146';

export async function searchChunks(query, documentIds = []) {
  try {
    const params = new URLSearchParams({ 
      q: query,
      top_k: 12
    });
    
    // Gunakan RAG Python backend secara langsung untuk semantic search
    const res = await fetch(`${RAG_URL}/search?${params}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    
    // Mapping format ChromaDB ke format yang diharapkan Add-in
    return (data.results || []).map(r => ({
      chunkIndex: r.chunk_index,
      content: r.content,
      startPage: r.halaman || r.page_start || 0,
      score: r.score,
      id: r.id,
      metadata: r // Masukkan semua metadata structured (penulis, tahun, dll)
    }));
  } catch (e) {
    console.warn('Failed to search chunks via RAG Python:', e);
    return [];
  }
}

export async function fetchDocumentContext(docId) {
  try {
    const res = await fetch(`${MANAGER_URL}/api/documents/${docId}/context`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    console.warn('Failed to fetch document context:', e);
    return null;
  }
}
