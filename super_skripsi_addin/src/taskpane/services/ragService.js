/**
 * RAG Service
 * Menyediakan chunk kandidat dari Vector Store untuk diproses oleh Retrieval Agent.
 *
 * Pipeline:
 *   getCandidateChunks() → chunk mentah
 *       ↓
 *   retrievalAgent.selectVerbatimPassages() → verbatim terpilih (LLM #1)
 *       ↓
 *   appStore.sendMessage() → parafrase (LLM #2)
 */

import { searchChunks, fetchDocumentChunks, fetchDocumentContext } from './managerBridge';

/**
 * Ambil chunk kandidat mentah dari dokumen yang dipilih.
 * Menggunakan TF-IDF sebagai pre-filter, dengan broadening fallback
 * jika skor terlalu rendah (semantic mismatch).
 *
 * @param {string}   query          - Query pengguna
 * @param {string[]} selectedDocIds - ID dokumen yang dipilih
 * @param {number}   targetCount    - Jumlah chunk kandidat yang dicari
 * @returns {Promise<Array<{index, content, startPage, endPage, score}>>}
 */
export async function getCandidateChunks(query, selectedDocIds, targetCount = 8) {
  if (!selectedDocIds || selectedDocIds.length === 0) return [];

  try {
    // Tahap 1: Coba TF-IDF vector search
    const rankedChunks = await searchChunks(query, selectedDocIds);

    if (rankedChunks && rankedChunks.length > 0) {
      const maxScore = Math.max(...rankedChunks.map(c => c.score || 0));
      const LOW_SCORE_THRESHOLD = 0.03;

      if (maxScore >= LOW_SCORE_THRESHOLD) {
        console.log(`[RAG] ✅ TF-IDF match (skor max: ${maxScore.toFixed(4)}). ${rankedChunks.length} chunk.`);
        return rankedChunks.map(c => ({
          index: c.chunkIndex,
          content: c.content,
          startPage: c.startPage,
          endPage: c.endPage,
          score: c.score,
          metadata: c.metadata // Sertakan metadata terstruktur (penulis, tahun, dll)
        }));
      }

      console.warn(`[RAG] ⚠️ Skor TF-IDF rendah (${maxScore.toFixed(4)}). Switching ke broadening fallback.`);
    }

    // Tahap 2: Broadening fallback — ambil chunk awal dokumen secara berurutan
    return await _getBroadChunks(selectedDocIds, targetCount);

  } catch (e) {
    console.error('[RAG] ❌ Error saat getCandidateChunks:', e);
    return [];
  }
}

/**
 * Ambil chunk secara berurutan dari awal dokumen (fallback saat TF-IDF gagal).
 * Cukup representatif untuk jurnal akademik yang biasanya memaparkan teori di awal.
 */
async function _getBroadChunks(docIds, maxChunks) {
  const allChunks = [];

  for (const id of docIds) {
    const chunks = await fetchDocumentChunks(id);
    for (const c of chunks.slice(0, maxChunks)) {
      allChunks.push({
        index: c.index ?? c.chunk_index,
        content: c.content || '',
        startPage: c.startPage ?? c.start_page ?? null,
        endPage: c.endPage ?? c.end_page ?? null,
        score: 0,
      });
    }
    if (allChunks.length >= maxChunks) break;
  }

  console.log(`[RAG] 📦 Broadening fallback: ${allChunks.length} chunk.`);
  return allChunks;
}

/**
 * Get document metadata untuk membangun konteks sitasi.
 */
export async function getDocumentMeta(docId) {
  const doc = await fetchDocumentContext(docId);
  if (!doc) return null;
  return {
    title: doc.title,
    authors: doc.authors,
    year: doc.year,
  };
}

// ── Legacy export (dipertahankan untuk backward compat) ──

/**
 * @deprecated Gunakan getCandidateChunks() + retrievalAgent.js
 * Dipertahankan agar tidak break jika masih ada referensi lain.
 */
export async function buildRAGContext(query, selectedDocIds) {
  const chunks = await getCandidateChunks(query, selectedDocIds);
  if (chunks.length === 0) return '';
  return chunks.map(c => `--- [Chunk #${c.index}] ---\n${c.content.trim()}`).join('\n\n');
}
