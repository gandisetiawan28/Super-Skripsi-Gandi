/**
 * Prompt Base Service
 * Builds structured prompts for the "Academic Writing Assistant" persona.
 * Handles complex citation logic and human-like paraphrasing.
 */

export { buildSystemPrompt } from '../prompts/system_prompt';


/**
 * Build user message with RAG context.
 *
 * @param {string} query             - Pertanyaan pengguna
 * @param {string} ragContext        - Konteks mentah (fallback jika passages kosong)
 * @param {Array}  selectedPassages  - Passage terpilih dari Retrieval Agent #1
 *                                    [{chunkIndex, passage}]
 */
export function buildUserMessage(query, documentContext, selectedPassages = [], ragContext = '') {
  const authors = documentContext?.authors || ['Author'];
  let primaryAuthor = 'Author';
  if (authors.length === 1) {
    primaryAuthor = authors[0].split(',')[0].split(' ').pop();
  } else if (authors.length === 2) {
    const a1 = authors[0].split(',')[0].split(' ').pop();
    const a2 = authors[1].split(',')[0].split(' ').pop();
    primaryAuthor = `${a1} & ${a2}`;
  } else if (authors.length > 2) {
    const a1 = authors[0].split(',')[0].split(' ').pop();
    primaryAuthor = `${a1} et al.`;
  }

  const metaXml = documentContext
    ? `<document_metadata>\n` +
      `  <title>${documentContext.title}</title>\n` +
      `  <year>${documentContext.year || '?'}</year>\n` +
      `  <primary_author>${primaryAuthor}</primary_author>\n` +
      `</document_metadata>\n\n`
    : '';

  let contextXml = '';
  if (selectedPassages && selectedPassages.length > 0) {
    contextXml = `<selected_passages>\n` +
      selectedPassages.map((p, i) => 
        `<passage index="${i + 1}" citation="${p.citation || 'Unknown'}" page="${p.halaman || '?'}">\n${p.passage.trim()}\n</passage>`
      ).join('\n') +
      `\n</selected_passages>\n\n`;
  } else if (ragContext) {
    contextXml = `<document_context>\n${ragContext}\n</document_context>\n\n`;
  }

  return `# DATA INPUT:
${metaXml}
${contextXml}

# PERTANYAAN USER:
"${query}"

# ARAHAN:
1. Pilih kutipan verbatim HANYA dari dalam tag <passage> (atau <document_context> jika ada). JANGAN TULIS TAG-NYA di hasil akhir!
2. Jika perlu sitasi bertingkat, gunakan info dari <document_metadata> (Nama penulis utama: ${primaryAuthor}).
3. DILARANG KERAS mengutip judul atau metadata sistem sebagai verbatim.
4. Pastikan hasil parafrase natural dan autentik.`;
}

/**
 * Clean raw LLM response
 */
export function cleanLLMResponse(rawText) {
  if (!rawText || typeof rawText !== 'string') return rawText;

  let cleaned = rawText;
  cleaned = cleaned.replace(/```json\s*/gi, '');
  cleaned = cleaned.replace(/```\s*/g, '');
  cleaned = cleaned.trim();

  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');
  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
    cleaned = cleaned.substring(firstBrace, lastBrace + 1);
  }

  return cleaned;
}

/**
 * Parse the structured response
 */
export function parseAIResponse(rawText) {
  const cleaned = cleanLLMResponse(rawText);

  // Pola metadata sistem yang TIDAK boleh ada sebagai verbatim
  const META_PATTERNS = [
    /^dokumen aktif:/i,
    /^sitasi utama:/i,
    /^\[metadata sistem/i,
    /^chunk #\d+/i,
    /^--- \[chunk/i,
    /^penulis sesuai aturan sitasi:/i,
    /^\s*# (DATA|INSTRUKSI|PERTANYAAN|ARAHAN)/i, // Headers leakage
  ];

  // Apakah teks tampak seperti judul all-caps (bukan kalimat isi)?
  const isAllCapsTitle = (text) => {
    if (!text || text.length < 10) return false;
    const words = text.trim().split(/\s+/);
    const capsCount = words.filter(w => w === w.toUpperCase() && /[A-Z]/.test(w)).length;
    return capsCount / words.length > 0.7 && words.length <= 20;
  };

  const isMetaBocor = (text) =>
    !text ||
    META_PATTERNS.some(p => p.test(text.trim())) ||
    isAllCapsTitle(text);

  // Fungsi untuk membuang tag XML yang mungkin terbawa
  const stripXML = (text) => text.replace(/<\/?(?:document|passage|metadata|selected|candidate|context)[^>]*>/gi, '').trim();

  try {
    const data = JSON.parse(cleaned);

    if (data.options && Array.isArray(data.options)) {
      return data.options.map(opt => {
        let verb = opt.verbatim || '';
        if (verb !== 'null') {
          verb = stripXML(verb);  // Bersihkan tag XML dulu
          if (isMetaBocor(verb)) {
            verb = '';  // Jika yang tersisa masih terbaca sebagai metadata/header, kosongkan
          }
        } else {
          verb = '';
        }

        return {
          verbatim: verb,
          paraphrase: opt.paraphrase || '',
          bibliography: opt.bibliography || '',
          citation: '',
        };
      });
    }

    return [{
      verbatim: rawText,
      paraphrase: 'Gagal memproses detail. Silakan coba lagi.',
      bibliography: '',
      citation: '',
    }];
  } catch (e) {
    console.error('Parse error:', e);
    return [{
      verbatim: rawText,
      paraphrase: 'Response AI tidak valid. Pastikan provider AI aktif.',
      bibliography: '',
      citation: '',
    }];
  }
}
