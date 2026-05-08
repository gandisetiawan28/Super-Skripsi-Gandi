/**
 * LLM Router Service
 * Routes requests to different AI providers based on user selection.
 *
 * v2: Dynamic model fetching via GET /models proxy on RAG service.
 *     Fallback ke daftar statis jika RAG offline atau fetch gagal.
 */

const RAG_URL = 'http://localhost:28146';

// ── Provider key mapping (nama UI → id untuk proxy endpoint) ──────────────────
const PROVIDER_KEY_MAP = {
  'Google Gemini':    'gemini',
  'OpenAI':           'openai',
  'Anthropic Claude': 'anthropic',
  'Groq':             'groq',
  'Cerebras':         'cerebras',
  'DeepSeek':         'deepseek',
  'xAI Grok':         'xai',
  'Localhost':        'localhost',
};

const FALLBACK_MODELS = {
  'Google Gemini': ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  'OpenAI': ['gpt-4o', 'gpt-4o-mini', 'o1-preview', 'o1-mini'],
  'Cerebras': ['llama3.3-70b', 'llama-3.1-8b', 'llama-3.1-70b'],
  'Groq': ['llama-3.3-70b-versatile', 'llama3-70b-8192', 'mixtral-8x7b-32768'],
  'DeepSeek': ['deepseek-chat', 'deepseek-reasoner'],
  'Ollama (Local)': ['auto-detect'],
  'LM Studio (Local)': ['auto-detect'],
  'Localhost': ['llama3', 'mistral', 'phi3'],
};

// ── Provider config (untuk sendToLLM) ─────────────────────────────────────────
const PROVIDERS = {
  'Google Gemini': {
    buildRequest: (model, messages, key) => ({
      url: `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
      body: {
        contents: messages
          .filter(m => m.role !== 'system')
          .map(m => ({
            role: m.role === 'assistant' ? 'model' : 'user',
            parts: [{ text: m.content }],
          })),
        systemInstruction: messages.find(m => m.role === 'system')
          ? { parts: [{ text: messages.find(m => m.role === 'system').content }] }
          : undefined,
        generationConfig: { temperature: 0.7 },
      },
      parseResponse: (data) => data.candidates?.[0]?.content?.parts?.[0]?.text || '',
    }),
  },
  'OpenAI': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.openai.com/v1/chat/completions',
      headers: { 'Authorization': `Bearer ${key}` },
      body: { model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'Anthropic Claude': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.anthropic.com/v1/messages',
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: {
        model,
        max_tokens: 8096,
        messages: messages.filter(m => m.role !== 'system'),
        system: messages.find(m => m.role === 'system')?.content || '',
      },
      parseResponse: (data) => data.content?.[0]?.text || '',
    }),
  },
  'Groq': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.groq.com/openai/v1/chat/completions',
      headers: { 'Authorization': `Bearer ${key}` },
      body: { model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'Cerebras': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.cerebras.ai/v1/chat/completions',
      headers: { 'Authorization': `Bearer ${key}` },
      body: { model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'DeepSeek': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.deepseek.com/v1/chat/completions',
      headers: { 'Authorization': `Bearer ${key}` },
      body: { model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'xAI Grok': {
    buildRequest: (model, messages, key) => ({
      url: 'https://api.x.ai/v1/chat/completions',
      headers: { 'Authorization': `Bearer ${key}` },
      body: { model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'Ollama (Local)': {
    buildRequest: (model, messages, _key) => ({
      url: 'http://localhost:11434/api/chat',
      body: {
        model: model === 'auto-detect' ? 'llama3.2' : model,
        messages,
        stream: false,
      },
      parseResponse: (data) => data.message?.content || '',
    }),
  },
  'LM Studio (Local)': {
    buildRequest: (model, messages, _key) => ({
      url: 'http://localhost:1234/v1/chat/completions',
      body: { model: model === 'auto-detect' ? 'default' : model, messages, temperature: 0.7 },
      parseResponse: (data) => data.choices?.[0]?.message?.content || '',
    }),
  },
  'Localhost': {
    buildRequest: (model, messages, key) => {
      const baseUrl = key && key.startsWith('http') ? key.replace(/\/+$/, '') : 'http://localhost:3000/api/gemini';
      
      // Case 1: Full Gemini Flow API Bridge URL (e.g. http://localhost:3000/api/gemini)
      if (baseUrl.includes('/api/')) {
        const prompt = messages.map(m => `[${m.role}] ${m.content}`).join('\n\n');
        return {
          url: baseUrl,
          body: { prompt },
          parseResponse: (data) => data.result || '',
        };
      }

      // Case 2: Port 3000 but no /api/ (Legacy fallback)
      if (baseUrl.includes(':3000')) {
        const prompt = messages.map(m => `[${m.role}] ${m.content}`).join('\n\n');
        const provider = model && model !== 'auto-detect' ? model : 'gemini'; 
        return {
          url: `${baseUrl}/api/${provider}`,
          body: { prompt },
          parseResponse: (data) => data.result || '',
        };
      }

      // Case 3: OpenAI-compatible (Ollama/LM Studio/etc)
      return {
        url: baseUrl + '/chat/completions',
        body: { model: model || 'llama3', messages, temperature: 0.7 },
        parseResponse: (data) => data.choices?.[0]?.message?.content || '',
      };
    },
  },
};

// ── Public helpers ─────────────────────────────────────────────────────────────

export function getAvailableProviders() {
  return Object.keys(PROVIDERS);
}

export function getModelsForProvider(provider) {
  return FALLBACK_MODELS[provider] || [];
}

export async function fetchAvailableModels(provider, apiKey) {
  const providerKey = PROVIDER_KEY_MAP[provider];

  // Provider lokal: langsung pakai deteksi
  if (!providerKey) {
    return { models: FALLBACK_MODELS[provider] || [], source: 'fallback' };
  }

  // Jika tidak ada API key, kembalikan fallback
  if (!apiKey || !apiKey.trim()) {
    return { models: FALLBACK_MODELS[provider] || [], source: 'fallback' };
  }

  try {
    let liveModels = [];

    // 1. Coba Native Direct Fetch (Bypassing RAG proxy agar tetap jalan jika RAG offline)
    try {
      if (providerKey === 'openai') {
        const r = await fetch('https://api.openai.com/v1/models', { headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).data.map(m => m.id).filter(m => m.includes('gpt') || m.includes('o1') || m.includes('o3') || m.includes('o4'));
      } else if (providerKey === 'groq') {
        const r = await fetch('https://api.groq.com/openai/v1/models', { headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).data.map(m => m.id).filter(m => !m.endsWith('-tool-use') && !m.includes('whisper'));
      } else if (providerKey === 'cerebras') {
        const r = await fetch('https://api.cerebras.ai/v1/models', { headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).data.map(m => m.id);
      } else if (providerKey === 'deepseek') {
        const r = await fetch('https://api.deepseek.com/v1/models', { headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).data.map(m => m.id);
      } else if (providerKey === 'xai') {
        const r = await fetch('https://api.x.ai/v1/models', { headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).data.map(m => m.id);
      } else if (providerKey === 'gemini') {
        const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`, { signal: AbortSignal.timeout(6000) });
        if (r.ok) liveModels = (await r.json()).models.filter(m => m.supportedGenerationMethods?.includes('generateContent')).map(m => m.name.replace('models/', ''));
      }
    } catch (directError) {
      console.warn(`[fetchModels] Direct fetch failed for ${provider}:`, directError.message);
    }

    // Jika native fetch berhasil, langsung kembalikan
    if (liveModels && liveModels.length > 0) {
      liveModels.sort();
      console.info(`[fetchModels] ✅ ${provider}: ${liveModels.length} model live (Direct)`);
      return { models: liveModels, source: 'live' };
    }

    // 2. Jika gagal (misal CORS Authropic), Fallback ke RAG Proxy
    console.info(`[fetchModels] Native fetch gagal/kosong, mencoba via RAG Proxy...`);
    const params = new URLSearchParams({ provider: providerKey, api_key: apiKey });
    const res = await fetch(`${RAG_URL}/models?${params}`, {
      signal: AbortSignal.timeout(6000),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.models && data.models.length > 0) {
        console.info(`[fetchModels] ✅ ${provider}: ${data.models.length} model live (Proxy)`);
        return { models: data.models, source: 'live' };
      }
    }

    return { models: FALLBACK_MODELS[provider] || [], source: 'fallback' };
  } catch (e) {
    console.warn(`[fetchModels] RAG offline or timeout, using fallback:`, e.message);
    return { models: FALLBACK_MODELS[provider] || [], source: 'fallback' };
  }
}

export async function detectLocalLLMs() {
  const results = [];

  // Check Ollama
  try {
    const res = await fetch('http://localhost:11434/api/tags', { signal: AbortSignal.timeout(2000) });
    if (res.ok) {
      const data = await res.json();
      const models = (data.models || []).map(m => m.name);
      results.push({ provider: 'Ollama (Local)', models: models.length ? models : ['auto-detect'] });
    }
  } catch { /* Ollama not running */ }

  // Check LM Studio
  try {
    const res = await fetch('http://localhost:1234/v1/models', { signal: AbortSignal.timeout(2000) });
    if (res.ok) {
      const data = await res.json();
      const models = (data.data || []).map(m => m.id);
      results.push({ provider: 'LM Studio (Local)', models: models.length ? models : ['auto-detect'] });
    }
  } catch { /* LM Studio not running */ }

  return results;
}

/**
 * Send a chat request to the selected LLM with retry & key rotation logic.
 */
export async function sendToLLM({ provider, model, messages, apiKeys, signal, onStatusUpdate }) {
  const config = PROVIDERS[provider];
  if (!config) throw new Error(`Unknown provider: ${provider}`);

  const maxAttempts = 6;
  const retryDelay = 5000;
  let lastError = null;

  // Ensure we have at least one key
  const keys = apiKeys && apiKeys.length > 0 ? apiKeys : [''];
  const isRotating = keys.length > 1;

  if (isRotating) {
    onStatusUpdate?.(`🔑 Terdeteksi ${keys.length} API Key untuk ${provider}.`);
  }

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    if (signal?.aborted) throw new Error('AbortError');

    // Round-robin key selection
    const keyIndex = (attempt - 1) % keys.length;
    const currentKey = keys[keyIndex];

    try {
      const { url, headers = {}, body, parseResponse } = config.buildRequest(model, messages, currentKey);

      if (isRotating && attempt > 1) {
        onStatusUpdate?.(`🔄 Mencoba Key #${keyIndex + 1} (Percobaan ${attempt}/${maxAttempts})...`);
      }

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...headers },
        body: JSON.stringify(body),
        signal,
      });

      if (!response.ok) {
        const errorText = await response.text();
        const status = response.status;

        if ([401, 403, 429, 500, 503].includes(status)) {
          let errorMsg = `Error ${status}`;
          if (status === 429) errorMsg = 'Rate Limit (Limit Habis)';
          if (status === 401 || status === 403) errorMsg = 'Auth Error (Key Mati/Salah)';
          if (status >= 500) errorMsg = 'Server Error (AI Sibuk)';

          const logStatus = `⏳ ${errorMsg} di Percobaan ${attempt}. ${isRotating ? 'Mencoba key lain...' : 'Menunggu 5 detik...'}`;
          console.warn(`${provider}: ${logStatus}`, errorText);
          onStatusUpdate?.(logStatus);

          if (attempt < maxAttempts) {
            await new Promise((resolve, reject) => {
              const timer = setTimeout(resolve, retryDelay);
              signal?.addEventListener('abort', () => { clearTimeout(timer); reject(new Error('AbortError')); });
            });
            continue;
          }
        }
        throw new Error(`${provider} API error (${status}): ${errorText}`);
      }

      const data = await response.json();
      let parsed = parseResponse(data);
      
      // Bersihkan tag <think>...</think> dari model reasoning (seperti Qwen/DeepSeek)
      parsed = parsed.replace(/<think>[\s\S]*?<\/think>\n*/gi, '').trim();
      
      // Bersihkan teks "thinking" manual dari model bawel yang menggunakan "Result:"
      if (/Result:|Hasil:|Hasil Parafrase:/i.test(parsed)) {
        parsed = parsed.replace(/[\s\S]*?(Result:|Hasil:|Hasil Parafrase:)\s*/i, '').trim();
      }
      
      // Bersihkan tanda kutip ganda/tunggal di awal dan akhir jika model menambahkannya
      parsed = parsed.replace(/^["']|["']$/g, '').trim();
      
      return parsed;

    } catch (e) {
      if (e.name === 'AbortError' || e.message === 'AbortError') throw e;

      lastError = e;
      const status = `⚠️ Koneksi Gagal (Percobaan ${attempt}). ${isRotating ? 'Mencoba key lain...' : 'Menunggu 5 detik...'}`;
      console.warn(`${provider}: ${status}`, e);
      onStatusUpdate?.(status);

      if (attempt < maxAttempts) {
        await new Promise((resolve, reject) => {
          const timer = setTimeout(resolve, retryDelay);
          signal?.addEventListener('abort', () => { clearTimeout(timer); reject(new Error('AbortError')); });
        });
        continue;
      }
      break;
    }
  }

  throw lastError || new Error(`Gagal setelah ${maxAttempts} percobaan.`);
}
