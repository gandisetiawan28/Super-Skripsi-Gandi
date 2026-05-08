/**
 * prompts/retrieval_prompt.js
 * ============================
 * Prompt untuk Retrieval Agent (LLM Call #1).
 * Digunakan untuk memilih potongan teks paling relevan dari kandidat chunks.
 */

export function buildRetrievalPrompt(query, chunks) {
  const chunkBlocks = chunks.map((c, i) => {
    const pageInfo = (c.startPage != null || c.halaman != null) ? ` page="${c.startPage || c.halaman}"` : '';
    const citation = c.metadata?.sitasi || c.sitasi || 'Unknown';
    return `<candidate index="${i}"${pageInfo} citation="${citation}">\n${c.content.trim()}\n</candidate>`;
  }).join('\n');

  return `Kamu adalah "Retrieval Specialist". Tugasmu adalah memilah kliping teks yang paling relevan dengan klaim, topik, atau kata kunci dari user.
 
 # DATA INPUT:
 <candidates count="${chunks.length}">
 ${chunkBlocks}
 </candidates>
 
 # QUERY/TOPIK USER:
 "${query}"
 
 # INSTRUKSI:
 1. Analisis seluruh <candidate> di atas.
 2. Pilih 1-5 candidate yang paling relevan dengan topik atau menjawab pertanyaan user.
 3. Jika query berupa potongan kalimat (seperti "harga adalah"), cari teks yang mendefinisikan atau membahas topik tersebut.
 4. SALIN TEKSNYA PERSIS dari dalam tag <candidate>.
 5. Jika benar-benar tidak ada yang berkaitan, kembalikan array kosong.
 
 # FORMAT OUTPUT (JSON):
 {
   "selected": [
     {
       "chunkIndex": <nomor index>,
       "passage": "<teks disalin persis>"
     }
   ]
 }

JANGAN berikan komentar apapun, langsung JSON.`;
}
