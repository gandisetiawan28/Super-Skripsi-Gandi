/**
 * Zustand Global App Store
 * Central state management for the Super Skripsi Gandi Word Add-in
 *
 * v2: Dynamic model fetching — provider change triggers live API fetch
 */

import { create } from 'zustand';
import { fetchApiKeys, fetchDocuments, checkManagerConnection } from '../services/managerBridge';
import {
  getAvailableProviders,
  getModelsForProvider,
  detectLocalLLMs,
  fetchAvailableModels,
  sendToLLM,
} from '../services/llmRouter';
import { buildSystemPrompt, buildUserMessage, parseAIResponse } from '../services/promptBase';
import { getCandidateChunks, getDocumentMeta } from '../services/ragService';
import { selectVerbatimPassages } from '../services/retrievalAgent';

const useAppStore = create((set, get) => ({
  // ── Connection State ──
  isConnected: false,
  apiKeys: {},
  documents: [],

  // ── LLM Selection ──
  selectedProvider: '',
  selectedModel: '',
  availableProviders: [],
  availableModels: [],
  localLLMs: [],

  // ── Dynamic Model Fetch State ──
  isFetchingModels: false,
  modelFetchSource: 'fallback', // 'live' | 'fallback'

  // ── Document Selection ──
  selectedDocIds: [],
  selectedCategory: 'Semua Kategori',

  // ── Chat State ──
  messages: [],
  isLoading: false,
  thinkingStatus: '',
  abortController: null,
  error: null,

  // ── Initialize ──
  initialize: async () => {
    try {
      const connected = await checkManagerConnection();
      set({ isConnected: connected });

      if (connected) {
        const [keys, docs] = await Promise.all([
          fetchApiKeys(),
          fetchDocuments(),
        ]);
        set({ apiKeys: keys, documents: docs });
      }

      // Detect local LLMs
      const localLLMs = await detectLocalLLMs();
      set({ localLLMs });

      // Build provider list (only those with keys or local)
      const state = get();
      const cloudProviders = getAvailableProviders().filter(p => {
        if (p.includes('(Local)')) return false;
        return state.apiKeys[p] && state.apiKeys[p].length > 0;
      });
      const localProviderNames = localLLMs.map(l => l.provider);
      const allProviders = [...cloudProviders, ...localProviderNames];

      set({ availableProviders: allProviders });

      // Auto-select first provider dengan dynamic fetch
      if (allProviders.length > 0) {
        const firstProvider = allProviders[0];
        const localMatch = localLLMs.find(l => l.provider === firstProvider);

        if (localMatch) {
          set({
            selectedProvider: firstProvider,
            selectedModel: localMatch.models[0] || '',
            availableModels: localMatch.models,
            modelFetchSource: 'live',
          });
        } else {
          // Ambil API key untuk provider ini (gunakan key pertama)
          const keys = state.apiKeys[firstProvider] || [];
          const firstKey = Array.isArray(keys) ? keys[0] : keys;

          // Set fallback dulu agar UI langsung tampil
          const fallbackModels = getModelsForProvider(firstProvider);
          set({
            selectedProvider: firstProvider,
            selectedModel: fallbackModels[0] || '',
            availableModels: fallbackModels,
            modelFetchSource: 'fallback',
          });

          // Fetch live di background
          get()._fetchModelsForProvider(firstProvider, firstKey);
        }
      }
    } catch (e) {
      console.error('Init error:', e);
      set({ error: e.message });
    }
  },

  // ── Internal: fetch model list untuk provider ──
  _fetchModelsForProvider: async (provider, apiKey) => {
    set({ isFetchingModels: true });
    try {
      const { models, source } = await fetchAvailableModels(provider, apiKey);
      const currentProvider = get().selectedProvider;

      // Hanya update jika user masih di provider yang sama
      if (currentProvider === provider && models.length > 0) {
        const currentModel = get().selectedModel;
        // Pertahankan model yang dipilih jika ada di list live, else ambil pertama
        const nextModel = models.includes(currentModel) ? currentModel : models[0];
        set({
          availableModels: models,
          selectedModel: nextModel,
          modelFetchSource: source,
        });
      }
    } catch (e) {
      console.warn('[Store] fetchModels error:', e);
    } finally {
      set({ isFetchingModels: false });
    }
  },

  // ── Refresh connection ──
  refreshConnection: async () => {
    const connected = await checkManagerConnection();
    set({ isConnected: connected });
    if (connected) {
      const [keys, docs] = await Promise.all([
        fetchApiKeys(),
        fetchDocuments(),
      ]);
      set({ apiKeys: keys, documents: docs });
    }
  },

  // ── Provider selection — triggers live model fetch ──
  setProvider: (provider) => {
    const state = get();
    const localMatch = state.localLLMs.find(l => l.provider === provider);

    if (localMatch) {
      set({
        selectedProvider: provider,
        selectedModel: localMatch.models[0] || '',
        availableModels: localMatch.models,
        modelFetchSource: 'live',
        isFetchingModels: false,
      });
      return;
    }

    // Set fallback model list segera (UX: dropdown tidak kosong)
    const fallbackModels = getModelsForProvider(provider);
    set({
      selectedProvider: provider,
      selectedModel: fallbackModels[0] || '',
      availableModels: fallbackModels,
      modelFetchSource: 'fallback',
    });

    // Ambil API key dan trigger dynamic fetch
    const keys = state.apiKeys[provider] || [];
    const firstKey = Array.isArray(keys) ? keys[0] : keys;
    get()._fetchModelsForProvider(provider, firstKey);
  },

  setModel: (model) => set({ selectedModel: model }),

  // ── Document selection ──
  toggleDocument: (docId) => {
    const current = get().selectedDocIds;
    const updated = current.includes(docId)
      ? current.filter(id => id !== docId)
      : [...current, docId];
    set({ selectedDocIds: updated });
  },

  clearDocuments: () => set({ selectedDocIds: [] }),

  setCategory: (category) => set({ selectedCategory: category }),

  // ── Send message (Now Step 1: Find Citations) ──
  sendMessage: async (userQuery) => {
    const state = get();
    if (!userQuery.trim() || state.isLoading) return;

    const userMsg = { role: 'user', content: userQuery, timestamp: Date.now() };
    const controller = new AbortController();
    set(s => ({
      messages: [...s.messages, userMsg],
      isLoading: true,
      abortController: controller,
      error: null,
    }));

    try {
      let selectedPassages = [];
      let ragContext = '';
      let docMeta = null;

      if (state.selectedDocIds.length > 0) {
        // ── TAHAP 1: Ambil kandidat chunk dari Vector Store ──
        set({ thinkingStatus: '🧠 Melakukan Vector Search (ChromaDB)...' });
        const candidateChunks = await getCandidateChunks(userQuery, state.selectedDocIds);

        // ── TAHAP 2: Retrieval Agent (LLM Call #1) ──
        const apiKeysForAgent = state.apiKeys[state.selectedProvider] || [];
        selectedPassages = await selectVerbatimPassages(
          userQuery,
          candidateChunks,
          {
            provider: state.selectedProvider,
            model: state.selectedModel,
            apiKeys: Array.isArray(apiKeysForAgent) ? apiKeysForAgent : [apiKeysForAgent],
            signal: controller.signal,
            sendToLLM,
            onStatusUpdate: (s) => set({ thinkingStatus: s }),
            selectedDocIds: state.selectedDocIds,
          }
        );

        if (selectedPassages.length === 0) {
          console.warn('[App] Agent #1 gagal memilih passage. Fallback ke context blob.');
          ragContext = candidateChunks
            .slice(0, 5)
            .map(c => `--- [Chunk #${c.index}] ---\n${c.content.trim()}`)
            .join('\n\n');
        }

        // ── Metadata dokumen untuk sitasi ──
        set({ thinkingStatus: '🔍 Mengekstrak metadata dokumen...' });
        docMeta = await getDocumentMeta(state.selectedDocIds[0]);
      }

      // Simpan hasil pencarian ke pesan (Tanpa parafrase dulu)
      const aiMsg = {
        id: `msg_${Date.now()}`,
        role: 'assistant',
        type: 'citation_search', // Mark sebagai hasil pencarian
        content: selectedPassages.length > 0 
          ? `Ditemukan ${selectedPassages.length} kutipan relevan.` 
          : 'Tidak ditemukan kutipan spesifik, namun ada teks yang berkaitan.',
        selectedPassages,
        ragContext,
        docMeta,
        options: selectedPassages.map(p => ({
          verbatim: p.passage,
          paraphrase: '', // Kosong, menunggu tombol diklik
          bibliography: '',
          citation: p.citation,
          halaman: p.halaman,
          isPending: true // Flag untuk menunjukkan butuh parafrase
        })),
        timestamp: Date.now(),
      };

      set(s => ({
        messages: [...s.messages, aiMsg],
        isLoading: false,
        thinkingStatus: '',
        abortController: null,
      }));
    } catch (e) {
      console.error('Send error:', e);
      set(s => ({
        messages: [...s.messages, {
          role: 'assistant',
          content: `Error: ${e.message}`,
          options: null,
          timestamp: Date.now(),
          isError: true,
        }],
        isLoading: false,
        thinkingStatus: '',
        abortController: null,
        error: e.name === 'AbortError' ? 'Generation stopped by user' : e.message,
      }));
    }
  },

  // ── Start Paraphrase (Step 2: Generate) ──
  startParaphrase: async (messageId, optionIndex) => {
    const state = get();
    const msgIndex = state.messages.findIndex(m => m.id === messageId);
    if (msgIndex === -1 || state.isLoading) return;

    const msg = state.messages[msgIndex];
    const option = msg.options[optionIndex];
    const controller = new AbortController();

    set({ isLoading: true, abortController: controller, thinkingStatus: '🧠 Memulai parafrase akademik...' });

    try {
      const systemPrompt = buildSystemPrompt();
      
      // Gunakan hanya 1 passage spesifik untuk efisiensi token
      const singlePassage = [{
        passage: option.verbatim,
        citation: option.citation,
        halaman: option.halaman
      }];

      const userQuery = state.messages.findLast((m, i) => i < msgIndex && m.role === 'user')?.content || '';
      const enrichedMessage = buildUserMessage(userQuery, msg.docMeta, singlePassage, '');

      const apiKeys = state.apiKeys[state.selectedProvider] || [];
      const rawResponse = await sendToLLM({
        provider: state.selectedProvider,
        model: state.selectedModel,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: enrichedMessage }
        ],
        apiKeys: Array.isArray(apiKeys) ? apiKeys : [apiKeys],
        signal: controller.signal,
        onStatusUpdate: (status) => set({ thinkingStatus: status }),
      });

      const parsed = parseAIResponse(rawResponse);
      const result = parsed[0] || { paraphrase: 'Gagal parafrase', bibliography: '' };

      // Update message options
      const updatedMessages = [...state.messages];
      updatedMessages[msgIndex] = {
        ...msg,
        options: msg.options.map((opt, i) => i === optionIndex ? {
          ...opt,
          paraphrase: result.paraphrase,
          bibliography: result.bibliography,
          isPending: false
        } : opt)
      };

      set({
        messages: updatedMessages,
        isLoading: false,
        thinkingStatus: '',
        abortController: null
      });
    } catch (e) {
      console.error('Paraphrase error:', e);
      set({ isLoading: false, thinkingStatus: '', error: e.message });
    }
  },

  // ── Stop generation ──
  stopGeneration: () => {
    const { abortController, isLoading } = get();
    if (isLoading && abortController) {
      abortController.abort();
      set({
        isLoading: false,
        thinkingStatus: 'Generation stopped by user',
        abortController: null,
      });
    }
  },

  // ── Clear chat ──
  clearChat: () => set({ messages: [], error: null }),
}));

export default useAppStore;
