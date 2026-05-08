/**
 * Retrieval Agent — LLM Call #1
 *
 * Strategi Hybrid (dijalankan secara otomatis):
 *   1. Coba Python RAG service (semantic embedding, akurat) → port 28146
 *   2. Jika tidak aktif, gunakan TF-IDF dari Flutter Manager → port 28145
 *
 * Pemilihan passage diverifikasi oleh LLM untuk memastikan relevansi verbatim.
 */

import { isRagServiceAvailable, semanticSearch } from './ragBridge';

import { buildRetrievalPrompt } from '../prompts/retrieval_prompt';


/**
 * Parse respons Retrieval Agent
 */
function parseRetrievalResponse(rawText) {
  try {
    let cleaned = rawText.trim();
    cleaned = cleaned.replace(/```json\s*/gi, '').replace(/```\s*/g, '');
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    const data = JSON.parse(cleaned);
    if (data.selected && Array.isArray(data.selected)) {
      return data.selected.filter(s => s.passage && s.passage.trim().length > 0);
    }
  } catch (e) {
    console.error('[Agent #1] ❌ Parse error:', e);
  }
  return [];
}

/**
 * Retrieval Agent — eksekusi (Hybrid Mode)
 */
export async function selectVerbatimPassages(query, chunks, llmOptions) {
  const { provider, model, apiKeys, signal, sendToLLM, onStatusUpdate, selectedDocIds } = llmOptions;

  // 1. Coba Semantic Search jika RAG aktif
  const ragAvailable = await isRagServiceAvailable();
  let candidateChunks = chunks || [];

  if (ragAvailable) {
    onStatusUpdate?.('🧠 Semantic search via Python RAG...');
    const semanticResults = await semanticSearch(query, selectedDocIds || [], 8);
    if (semanticResults && semanticResults.length > 0) {
      candidateChunks = semanticResults;
      console.log(`[Agent #1] 🚀 Menggunakan ${candidateChunks.length} hasil semantic search.`);
    }
  }

  if (candidateChunks.length === 0) {
    console.warn('[Agent #1] ⚠️ Tidak ada chunk kandidat.');
    return [];
  }

  // 2. Gunakan LLM #1 (Selection Agent) untuk memverifikasi relevansi chunk
  onStatusUpdate?.(`🔍 Memverifikasi ${candidateChunks.length} teks dokumen via AI...`);
  const prompt = buildRetrievalPrompt(query, candidateChunks);

  try {
    const rawResponse = await sendToLLM({
      provider,
      model,
      messages: [{ role: 'user', content: prompt }],
      apiKeys,
      signal,
      onStatusUpdate: (s) => onStatusUpdate?.(`🔍 ${s}`),
    });

    const selected = parseRetrievalResponse(rawResponse);
    console.log(`[Agent #1] ✅ AI memverifikasi ${selected.length} passage relevan.`);

    // Hubungkan kembali dengan metadata asli (sitasi, dll)
    const enrichedSelected = selected.map(s => {
      const original = candidateChunks[s.chunkIndex];
      return {
        ...s,
        citation: original?.metadata?.sitasi || original?.sitasi || 'Unknown',
        halaman: original?.halaman || original?.startPage || '?'
      };
    });

    if (enrichedSelected.length > 0) {
      enrichedSelected.forEach((s, i) => {
        console.log(`[Agent #1]   [${i + 1}] chunk #${s.chunkIndex} (${s.citation}): "${s.passage.slice(0, 80)}..."`);
      });
    }

    return enrichedSelected;
  } catch (e) {
    console.error('[Agent #1] ❌ LLM Error:', e);
    // Minimal fallback: ambil chunk pertama
    return candidateChunks.slice(0, 1).map(c => ({
      chunkIndex: c.chunkIndex ?? 0,
      passage: c.content,
      source: 'fallback',
    }));
  }
}
