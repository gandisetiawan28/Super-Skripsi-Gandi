/* =============================================
   Gemini Auto-Flow — Popup Controller
   Handles UI, file parsing, and message passing
   ============================================= */

(function () {
  'use strict';

  // --- DOM Elements ---
  const $ = (sel) => document.querySelector(sel);
  const statusBadge = $('#statusBadge');
  const statusText = $('#statusText');
  const tabUpload = $('#tabUpload');
  const tabManual = $('#tabManual');
  const panelUpload = $('#panelUpload');
  const panelManual = $('#panelManual');
  const dropZone = $('#dropZone');
  const fileInput = $('#fileInput');
  const fileInfo = $('#fileInfo');
  const fileName = $('#fileName');
  const filePrompts = $('#filePrompts');
  const fileRemove = $('#fileRemove');
  const manualInput = $('#manualInput');
  const lineCount = $('#lineCount');
  const columnSelector = $('#columnSelector');
  const columnCheckboxes = $('#columnCheckboxes');
  const delaySlider = $('#delaySlider');
  const delayDisplay = $('#delayDisplay');
  const progressCount = $('#progressCount');
  const progressFill = $('#progressFill');
  const btnStart = $('#btnStart');
  const btnStop = $('#btnStop');
  const logToggle = $('#logToggle');
  const logBody = $('#logBody');
  const logEntries = $('#logEntries');
  const btnReset = $('#btnReset');
  
  // API Bridge Elements
  const tabAPI = $('#tabAPI');
  const panelAPI = $('#panelAPI');
  const apiToggle = $('#apiToggle');
  const apiUrl = $('#apiUrl');
  const apiIndicator = $('#apiIndicator');
  const apiStatusText = $('#apiStatusText');
  const apiEndpointText = $('#apiEndpointText');
  const providerSelect = $('#providerSelect');

  // --- Constants ---
  const DEFAULT_PORTS = {
    gemini: 3000,
    chatgpt: 3000,
    claude: 3000,
    deepseek: 3000
  };
  const DOMAINS = {
    gemini: 'gemini.google.com',
    chatgpt: 'chatgpt.com',
    claude: 'claude.ai',
    deepseek: 'chat.deepseek.com'
  };

  // --- State ---
  let prompts = [];
  let parsedWorkbook = null;
  let isRunning = false;
  let currentMode = 'upload'; // 'upload' | 'manual'
  let selectedProvider = 'gemini';
  let recordedResults = []; // Stores { Timestamp, Prompt, Response }
  let selectedIndices = [0]; // Default to first column selected

  // --- Constants ---
  const CACHE_TTL_MS = 3 * 24 * 60 * 60 * 1000; // 3 days in ms

  // --- Init ---
  init();

  function init() {
    loadState();
    setupTabs();
    setupDropZone();
    setupManualInput();
    setupSlider();
    setupControls();
    setupLog();
    setupMessageListener();
    setupAPI();
    cleanExpiredCache();
    loadFileCache();
    setupExport();
    syncWithContentScript();
  }

  // ========================
  // EXPORT TO EXCEL / CSV / WORD
  // ========================
  function setupExport() {
    const btnExport = $('#btnExport');
    const exportFormat = $('#exportFormat');

    btnExport.addEventListener('click', () => {
      if (recordedResults.length === 0) return;
      const format = exportFormat.value;
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

      try {
        if (format === 'xlsx' || format === 'csv') {
          const ws = XLSX.utils.json_to_sheet(recordedResults);
          const wb = XLSX.utils.book_new();
          XLSX.utils.book_append_sheet(wb, ws, 'Results');

          if (format === 'xlsx') {
            ws['!cols'] = [{ wch: 20 }, { wch: 50 }, { wch: 100 }];
            XLSX.writeFile(wb, `Gemini_Results_${timestamp}.xlsx`);
          } else {
            XLSX.writeFile(wb, `Gemini_Results_${timestamp}.csv`);
          }
        } else if (format === 'doc') {
          exportToWord(`Gemini_Results_${timestamp}.doc`);
        }
        addLog(`Exported ${recordedResults.length} results as ${format.toUpperCase()}`, 'success');
      } catch (err) {
        addLog('Failed to export results: ' + err.message, 'error');
      }
    });
  }

  function exportToWord(filename) {
    let content = `
      <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
      <head><meta charset='utf-8'><title>Gemini Results</title></head><body>
    `;

    recordedResults.forEach((res, index) => {
      content += `
        <h2 style="color:#0052CC; font-family:Arial, sans-serif;">Prompt ${index + 1}: ${escapeHtml(res.Prompt)}</h2>
        <p style="color:#666; font-size:12px;"><em>Waktu: ${res.Waktu}</em></p>
        <div style="font-family:Arial, sans-serif; font-size:14px; margin-bottom: 24px; border-bottom: 1px solid #ccc; padding-bottom: 24px;">
          ${(res.Response || '').replace(/\n/g, '<br>')}
        </div>
      `;
    });

    content += `</body></html>`;

    const blob = new Blob([content], { type: 'application/msword;charset=utf-8' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  // ========================
  // TAB SWITCHING
  // ========================
  function setupTabs() {
    tabUpload.addEventListener('click', () => switchTab('upload'));
    tabManual.addEventListener('click', () => switchTab('manual'));
    tabAPI.addEventListener('click', () => switchTab('api'));
  }

  function switchTab(tab) {
    currentMode = tab;
    tabUpload.classList.toggle('active', tab === 'upload');
    tabManual.classList.toggle('active', tab === 'manual');
    tabAPI.classList.toggle('active', tab === 'api');
    
    panelUpload.classList.toggle('active', tab === 'upload');
    panelManual.classList.toggle('active', tab === 'manual');
    panelAPI.classList.toggle('active', tab === 'api');
    
    columnSelector.classList.toggle('hidden', tab !== 'upload' || !parsedWorkbook);
    updatePrompts();
  }

  // ========================
  // FILE UPLOAD / DROP ZONE
  // ========================
  function setupDropZone() {
    // Click to browse
    dropZone.addEventListener('click', () => fileInput.click());

    // File input change
    fileInput.addEventListener('change', (e) => {
      if (e.target.files.length) handleFile(e.target.files[0]);
    });

    // Drag events
    ['dragenter', 'dragover'].forEach((evt) => {
      dropZone.addEventListener(evt, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.add('drag-over');
      });
    });

    ['dragleave', 'drop'].forEach((evt) => {
      dropZone.addEventListener(evt, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.remove('drag-over');
      });
    });

    dropZone.addEventListener('drop', (e) => {
      const file = e.dataTransfer.files[0];
      if (file) handleFile(file);
    });

    // Remove file
    fileRemove.addEventListener('click', (e) => {
      e.stopPropagation();
      clearFile();
    });
  }

  function handleFile(file) {
    const ext = file.name.split('.').pop().toLowerCase();
    if (!['xlsx', 'csv'].includes(ext)) {
      addLog('Unsupported file format. Use .xlsx or .csv', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        parsedWorkbook = workbook;

        // Populate column selector
        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const json = XLSX.utils.sheet_to_json(sheet, { header: 1 });

        if (json.length === 0) {
          addLog('File is empty', 'error');
          return;
        }

        // Build column options as checkboxes
        const headers = json[0];
        columnCheckboxes.innerHTML = '';
        headers.forEach((h, i) => {
          const label = document.createElement('label');
          label.className = 'column-checkbox-item';
          
          const checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.value = i;
          
          // Use cached selectedIndices if available
          if (selectedIndices.includes(i)) checkbox.checked = true;
          
          checkbox.onchange = () => extractPromptsFromWorkbook();
          
          const span = document.createElement('span');
          span.textContent = h || `Column ${i + 1}`;
          
          label.appendChild(checkbox);
          label.appendChild(span);
          columnCheckboxes.appendChild(label);
        });

        columnSelector.classList.remove('hidden');
        extractPromptsFromWorkbook();

        // Show file info
        fileName.textContent = file.name;
        dropZone.classList.add('hidden');
        fileInfo.classList.remove('hidden');

        // Cache the file data for persistence (3-day TTL)
        saveFileCache(file.name, json);

        addLog(`Loaded "${file.name}"`, 'success');
      } catch (err) {
        addLog('Failed to parse file: ' + err.message, 'error');
      }
    };
    reader.readAsArrayBuffer(file);
  }

  function extractPromptsFromWorkbook() {
    if (!parsedWorkbook) return;
    const sheet = parsedWorkbook.Sheets[parsedWorkbook.SheetNames[0]];
    const json = XLSX.utils.sheet_to_json(sheet, { header: 1 });
    
    // Get all selected column indices
    const newSelectedIndices = Array.from(columnCheckboxes.querySelectorAll('input[type="checkbox"]:checked'))
      .map(cb => parseInt(cb.value, 10));

    // If selection changed, clear previous results to maintain consistency
    if (JSON.stringify(newSelectedIndices) !== JSON.stringify(selectedIndices)) {
      if (recordedResults.length > 0) {
        recordedResults = [];
        addLog('Column selection changed. Previous results cleared.', 'warning');
      }
      selectedIndices = newSelectedIndices;
      saveState();
    }

    if (selectedIndices.length === 0) {
      prompts = [];
      filePrompts.textContent = `0 prompts (no column selected)`;
      updateProgress(0, 0);
      updateStartButton();
      saveState();
      return;
    }

    // Skip header row, combine selected columns
    prompts = json
      .slice(1)
      .map((row) => {
        // Collect values from all selected columns, filter out undefined/null, join with space
        return selectedIndices
          .map(idx => (row[idx] || '').toString().trim())
          .filter(val => val.length > 0)
          .join(' ');
      })
      .filter((line) => line.length > 0);

    filePrompts.textContent = `${prompts.length} prompts`;
    updateProgress(recordedResults.length, prompts.length);
    
    const selectedNames = selectedIndices
      .map(idx => {
        const item = columnCheckboxes.querySelector(`input[value="${idx}"]`).nextElementSibling;
        return item ? item.textContent : `Col ${idx + 1}`;
      })
      .join(', ');
      
    addLog(`Extracted ${prompts.length} prompts from columns: [${selectedNames}]`, 'info');
    updateStartButton();
  }

  function clearFile() {
    parsedWorkbook = null;
    prompts = [];
    fileInput.value = '';
    dropZone.classList.remove('hidden');
    fileInfo.classList.add('hidden');
    columnSelector.classList.add('hidden');
    updateProgress(0, 0);
    clearFileCache();
    // Clear results too
    recordedResults = [];
    selectedIndices = [0];
    saveState();
  }

  // ========================
  // FILE CACHE (3-day TTL)
  // ========================

  /**
   * Save parsed file data to chrome.storage.local
   */
  function saveFileCache(name, jsonData) {
    chrome.storage.local.set({
      fileCache: {
        name: name,
        data: jsonData,
        timestamp: Date.now(),
      },
    });
  }

  /**
   * Load cached file on popup open
   */
  function loadFileCache() {
    chrome.storage.local.get(['fileCache'], (result) => {
      const cache = result.fileCache;
      if (!cache || !cache.data || !cache.name) return;

      // Check if cache is still valid (within 3 days)
      const age = Date.now() - cache.timestamp;
      if (age > CACHE_TTL_MS) {
        clearFileCache();
        return;
      }

      try {
        const json = cache.data;
        if (json.length === 0) return;

        // Rebuild workbook from cached JSON
        const ws = XLSX.utils.aoa_to_sheet(json);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, 'CachedSheet');
        parsedWorkbook = wb;

        // Build column options as checkboxes
        const headers = json[0];
        columnCheckboxes.innerHTML = '';
        headers.forEach((h, i) => {
          const label = document.createElement('label');
          label.className = 'column-checkbox-item';
          
          const checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.value = i;
          
          // Restore previous selection
          if (selectedIndices.includes(i)) checkbox.checked = true;
          
          checkbox.onchange = () => extractPromptsFromWorkbook();
          
          const span = document.createElement('span');
          span.textContent = h || `Column ${i + 1}`;
          
          label.appendChild(checkbox);
          label.appendChild(span);
          columnCheckboxes.appendChild(label);
        });

        columnSelector.classList.remove('hidden');
        extractPromptsFromWorkbook();

        // Show file info
        const daysLeft = Math.ceil((CACHE_TTL_MS - age) / (24 * 60 * 60 * 1000));
        fileName.textContent = cache.name;
        filePrompts.textContent = `${prompts.length} prompts`;
        dropZone.classList.add('hidden');
        fileInfo.classList.remove('hidden');

        addLog(`Restored cached file "${cache.name}" (expires in ${daysLeft}d)`, 'info');
      } catch (err) {
        addLog('Failed to restore cached file', 'error');
        clearFileCache();
      }
    });
  }

  /**
   * Remove cached file from storage
   */
  function clearFileCache() {
    chrome.storage.local.remove('fileCache');
  }

  /**
   * Clean expired cache entries on startup
   */
  function cleanExpiredCache() {
    chrome.storage.local.get(['fileCache'], (result) => {
      const cache = result.fileCache;
      if (cache && cache.timestamp) {
        const age = Date.now() - cache.timestamp;
        if (age > CACHE_TTL_MS) {
          chrome.storage.local.remove('fileCache');
        }
      }
    });
  }

  // ========================
  // MANUAL INPUT
  // ========================
  function setupManualInput() {
    manualInput.addEventListener('input', () => {
      updatePrompts();
    });
  }

  function updatePrompts() {
    if (currentMode === 'manual') {
      const lines = manualInput.value
        .split('\n')
        .map((l) => l.trim())
        .filter((l) => l.length > 0);
      
      // If manual content changed, we might want to reset results
      if (JSON.stringify(lines) !== JSON.stringify(prompts)) {
        recordedResults = [];
        prompts = lines;
        saveState();
      }
      
      lineCount.textContent = lines.length;
      updateProgress(recordedResults.length, lines.length);
      updateStartButton();
    }
  }

  // ========================
  // DELAY SLIDER
  // ========================
  function setupSlider() {
    delaySlider.addEventListener('input', () => {
      delayDisplay.textContent = delaySlider.value + 's';
      saveState();
    });
  }

  // ========================
  // CONTROLS
  // ========================
  function setupControls() {
    btnStart.addEventListener('click', startLoop);
    btnStop.addEventListener('click', stopLoop);
    btnReset.addEventListener('click', resetProgress);
  }

  async function resetProgress() {
    if (isRunning) return;
    
    const confirmReset = confirm('Are you sure you want to clear all progress and results? This action cannot be undone.');
    if (!confirmReset) return;

    recordedResults = [];
    // Clear storage
    chrome.storage.local.set({ recordedResults: [] }, () => {
      updateProgress(0, prompts.length);
      updateStartButton();
      $('#btnExport').disabled = true;
      $('#exportFormat').disabled = true;
      addLog('Progress reset by user', 'warning');
      saveState();
    });
  }

  async function startLoop() {
    if (prompts.length === 0) {
      addLog('No prompts to send. Upload a file or enter text.', 'error');
      return;
    }

    // Check active tab matches selected provider
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const targetDomain = DOMAINS[selectedProvider];
    
    if (!tab || !tab.url || !tab.url.includes(targetDomain)) {
      const providerName = providerSelect.options[providerSelect.selectedIndex].text;
      addLog(`Please open ${targetDomain} (${providerName}) first!`, 'error');
      return;
    }

    isRunning = true;
    setStatus('running', 'Running');
    btnStart.disabled = true;
    btnStop.disabled = false;
    
    // Lock UI
    toggleUILock(true);
    
    // Handle Restart case
    if (recordedResults.length >= prompts.length && prompts.length > 0) {
      recordedResults = [];
      addLog('Restarting from the beginning...', 'info');
      updateProgress(0, prompts.length);
    }
    
    saveState();

    const delay = parseInt(delaySlider.value, 10) * 1000;

    addLog(`Starting loop: ${prompts.length} prompts, ${delaySlider.value}s delay`, 'info');

    // Send to content script
    try {
      await chrome.tabs.sendMessage(tab.id, {
        type: 'START_LOOP',
        prompts: prompts,
        delay: delay,
        startIndex: recordedResults.length,
      });
    } catch (err) {
      addLog('Failed to connect to Gemini tab. Reload the page and try again.', 'error');
      resetControls();
    }
  }

  async function stopLoop() {
    // Immediately update UI for instant feedback
    btnStop.disabled = true;
    setStatus('', 'Stopping...');
    addLog('Stop requested...', 'info');

    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab) {
        await chrome.tabs.sendMessage(tab.id, { type: 'STOP_LOOP' });
      }
    } catch (err) {
      addLog('Could not reach content script. It may have already stopped.', 'error');
      resetControls();
    }
  }

  /**
   * Reset UI to idle state
   * @param {string} statusLabel - 'done' | 'error' | ''
   * @param {string} customStatusText - optional custom status message
   */
  function resetUIState(statusLabel = '', customStatusText = '') {
    stopApiStatusPoller();
    isRunning = false;
    
    // Set status badge and text
    if (customStatusText) {
      setStatus(statusLabel, customStatusText);
    } else {
      setStatus(statusLabel, statusLabel === 'done' ? 'Done' : (statusLabel === 'error' ? 'Error' : 'Stopped'));
    }

    btnStart.disabled = false;
    btnStop.disabled = true;
    toggleUILock(false);
    updateStartButton();
    saveState();
  }

  // Legacy wrappers for backward compatibility
  function resetControls() { resetUIState(); }
  function resetAPIMode(statusLabel = 'done') { resetUIState(statusLabel); }

  function toggleUILock(lock) {
    // Disable checkboxes
    columnCheckboxes.querySelectorAll('input').forEach(cb => cb.disabled = lock);
    // Disable delay slider
    delaySlider.disabled = lock;
    // Disable file removal
    fileRemove.disabled = lock;
    fileRemove.style.opacity = lock ? '0.3' : '1';
    fileRemove.style.pointerEvents = lock ? 'none' : 'auto';
    // Disable manual textarea
    manualInput.disabled = lock;
  }

  function updateStartButton() {
    if (isRunning) return;
    
    const total = prompts.length;
    const current = recordedResults.length;
    
    let text = 'Start';
    if (current > 0) {
      if (current >= total) {
        text = 'Restart';
      } else {
        text = 'Resume';
      }
    }
    
    // Update button text (keeping SVG)
    btnStart.innerHTML = `
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <polygon points="5 3 19 12 5 21 5 3"/>
      </svg>
      ${text}
    `;

    // Show reset button only if there are results and NOT running
    btnReset.classList.toggle('hidden', current === 0 || isRunning);
  }

  // ========================
  // PROGRESS
  // ========================
  function updateProgress(current, total) {
    progressCount.textContent = `${current} / ${total} prompts`;
    const pct = total > 0 ? (current / total) * 100 : 0;
    progressFill.style.width = pct + '%';
  }

  // ========================
  // STATUS
  // ========================
  function setStatus(state, text) {
    statusBadge.className = 'status-badge ' + state;
    statusText.textContent = text;
  }

  // ========================
  // ACTIVITY LOG
  // ========================
  function setupLog() {
    logToggle.addEventListener('click', () => {
      logBody.classList.toggle('hidden');
      logToggle.classList.toggle('open');
    });
  }

  function addLog(msg, type = '') {
    const now = new Date();
    const time = now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `
      <span class="log-time">${time}</span>
      <span class="log-msg ${type}">${escapeHtml(msg)}</span>
    `;

    logEntries.prepend(entry);

    // Keep max 50 entries
    while (logEntries.children.length > 50) {
      logEntries.removeChild(logEntries.lastChild);
    }
  }

  // ========================
  // MESSAGE LISTENER
  // ========================
  function setupMessageListener() {
    chrome.runtime.onMessage.addListener((msg) => {
      switch (msg.type) {
        case 'PROGRESS_UPDATE':
          updateProgress(msg.current, msg.total);
          addLog(`Sent prompt ${msg.current}/${msg.total}: "${truncate(msg.promptText, 40)}"`, 'info');
          break;

        case 'WAITING_RESPONSE':
          addLog(`Waiting for Gemini response...`, '');
          break;

        case 'RESPONSE_RECEIVED':
          // Update local state and UI
          // Note: content.js now handles the actual storage persistence
          recordedResults.push({
            Waktu: new Date().toLocaleString('id-ID'),
            Prompt: msg.promptText,
            Hasil_Gemini: msg.responseText || '(Tidak ada response)'
          });
          $('#btnExport').disabled = false;
          $('#exportFormat').disabled = false;
          addLog(`Gemini responded. Waiting ${delaySlider.value}s...`, 'success');
          updateProgress(recordedResults.length, prompts.length);
          // We don't call saveState() here anymore to avoid race conditions with content.js
          break;

        case 'LOOP_COMPLETE':
          setStatus('done', 'Done!');
          addLog(`All ${msg.total} prompts completed! 🎉`, 'success');
          resetControls();
          break;

        case 'LOOP_STOPPED':
          setStatus('', 'Stopped');
          addLog(`Loop stopped at prompt ${msg.current}/${msg.total}`, 'error');
          resetControls();
          break;

        case 'ERROR':
          setStatus('error', 'Error');
          addLog(`Error: ${msg.message}`, 'error');
          resetControls();
          break;
        case 'API_START':
          // n8n is sending a prompt — lock UI
          isRunning = true;
          setStatus('running', 'API: Processing...');
          btnStart.disabled = true;
          btnStop.disabled = false;
          toggleUILock(true);
          addLog('API: Sending prompt to AI...', 'info');
          // Start polling content script status as reliable backup
          startApiStatusPoller();
          break;

        case 'API_END':
          // n8n prompt done — unlock UI
          resetUIState('done', 'API: Done');
          addLog('API: Response received and sent to n8n.', 'success');
          break;

        case 'STATUS_UPDATE':
          updateApiStatusUI(msg.status);
          break;
      }
    });
  }

  // ========================
  // API STATUS POLLER
  // Polls content script every 1.5s when in API running mode.
  // More reliable than relying solely on API_END message.
  // ========================
  let apiStatusPollInterval = null;

  function startApiStatusPoller() {
    stopApiStatusPoller();
    apiStatusPollInterval = setInterval(async () => {
      try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!tab) return;
        chrome.tabs.sendMessage(tab.id, { type: 'GET_STATUS' }, (response) => {
          if (chrome.runtime.lastError) return;
          if (response && !response.isRunning && isRunning) {
            // Content script says it's done — reset UI
            resetUIState('done');
            addLog('Automation process completed.', 'success');
          }
        });
      } catch (e) { /* popup might be closing */ }
    }, 1500);
  }

  function stopApiStatusPoller() {
    if (apiStatusPollInterval) {
      clearInterval(apiStatusPollInterval);
      apiStatusPollInterval = null;
    }
  }

  function resetAPIMode(statusLabel = 'done') {
    resetUIState(statusLabel);
  }

  function setupAPI() {
    // Load initial state
    chrome.storage.local.get(['apiConfigs', 'apiStatus'], (data) => {
      const config = data.apiConfigs ? data.apiConfigs[selectedProvider] : null;
      if (config) {
        apiToggle.checked = config.enabled;
        apiUrl.value = config.url || 'http://localhost:3000';
        updateApiEndpointHint();
        if (config.enabled) {
          chrome.runtime.sendMessage({ type: 'FORCE_RECONNECT' });
        }
      }
      // Fix bug: always read saved status from storage on popup open
      if (data.apiStatus) {
        updateApiStatusUI(data.apiStatus);
      } else {
        updateApiStatusUI('disabled');
      }
    });

    // Listen for changes
    apiToggle.addEventListener('change', saveApiConfig);
    apiUrl.addEventListener('input', () => {
      saveApiConfig();
      updateApiEndpointHint();
    });

    providerSelect.addEventListener('change', () => {
      selectedProvider = providerSelect.value;
      const providerName = providerSelect.options[providerSelect.selectedIndex].text;
      $('.api-title').textContent = `${providerName} Bridge`;
      $('#apiProviderName').textContent = providerName;
      addLog(`Switched provider to: ${selectedProvider.toUpperCase()}`, 'info');
      
      // Update UI for the new provider
      loadProviderConfig(selectedProvider);
      updateApiEndpointHint();
      updateStartButton();
      saveState();
    });

    // Monitor status changes from background
    chrome.storage.onChanged.addListener((changes) => {
      if (changes.apiStatus) {
        updateApiStatusUI(changes.apiStatus.newValue);
      }
    });
  }

  function loadProviderConfig(provider) {
    chrome.storage.local.get(['apiConfigs'], (data) => {
      const configs = data.apiConfigs || {};
      const config = configs[provider] || {
        enabled: false,
        url: `http://localhost:${DEFAULT_PORTS[provider] || 3000}`
      };
      
      apiToggle.checked = config.enabled;
      apiUrl.value = config.url;
      
      // Also update the global apiConfig (used by background)
      chrome.storage.local.set({ 
        apiConfig: { ...config, provider: provider } 
      });
    });
  }

  function saveApiConfig() {
    const provider = providerSelect.value;
    const config = {
      enabled: apiToggle.checked,
      url: apiUrl.value.trim() || `http://localhost:${DEFAULT_PORTS[provider] || 3000}`
    };

    chrome.storage.local.get(['apiConfigs'], (data) => {
      const configs = data.apiConfigs || {};
      configs[provider] = config;
      
      chrome.storage.local.set({ 
        apiConfigs: configs,
        apiConfig: { ...config, provider: provider } // Current active config
      });
      
      if (config.enabled) {
        addLog(`API Bridge enabled for ${provider.toUpperCase()}: ${config.url}`, 'info');
        // Let background try to connect
        chrome.runtime.sendMessage({ type: 'FORCE_RECONNECT' });
      } else {
        addLog(`API Bridge disabled for ${provider.toUpperCase()}`, 'warning');
        updateApiStatusUI('disabled');
        // Persist the disabled status in storage so it survives popup close
        chrome.storage.local.set({ apiStatus: 'disabled' });
      }
    });
  }

  function updateApiStatusUI(status) {
    const indicator = apiIndicator;
    indicator.className = 'status-indicator ' + (status || 'disabled');
    
    let text = 'Status: ';
    switch(status) {
      case 'connected':
        text += 'Connected';
        addLog('API Bridge: Connected to server', 'success');
        break;
      case 'connecting':
        text += 'Connecting...';
        break;
      case 'disconnected':
        text += 'Disconnected';
        addLog('API Bridge: Connection lost', 'warning');
        break;
      case 'error':
        text += 'Connection Error';
        addLog('API Bridge: Error connecting. Is node server.js running?', 'error');
        break;
      case 'disabled':
        text += 'Disabled';
        break;
      default:
        text += status || 'Unknown';
    }
    apiStatusText.textContent = text;
  }

  function updateApiEndpointHint() {
    const base = apiUrl.value.trim() || 'http://localhost:3000';
    const provider = selectedProvider || 'gemini';
    apiEndpointText.textContent = `${base}/api/${provider}`;
  }

  // ========================
  // PERSISTENCE
  // ========================
  function saveState() {
    chrome.storage.local.set({
      delay: delaySlider.value,
      isRunning: isRunning,
      recordedResults: recordedResults,
      selectedIndices: selectedIndices,
      selectedProvider: selectedProvider
    });
  }

  function loadState() {
    chrome.storage.local.get(['delay', 'isRunning', 'recordedResults', 'selectedIndices', 'selectedProvider'], (data) => {
      if (data.selectedProvider) {
        selectedProvider = data.selectedProvider;
        providerSelect.value = selectedProvider;
        const providerName = providerSelect.options[providerSelect.selectedIndex].text;
        $('.api-title').textContent = `${providerName} Bridge`;
        $('#apiProviderName').textContent = providerName;
      }
      
      // Load API config for the selected provider
      loadProviderConfig(selectedProvider);

      if (data.delay) {
        delaySlider.value = data.delay;
        delayDisplay.textContent = data.delay + 's';
      }
      
      if (data.recordedResults) {
        recordedResults = data.recordedResults;
        if (recordedResults.length > 0) {
          $('#btnExport').disabled = false;
          $('#exportFormat').disabled = false;
          addLog(`Restored ${recordedResults.length} previous results`, 'info');
          updateStartButton();
        }
      }
      
      if (data.selectedIndices) {
        selectedIndices = data.selectedIndices;
      }
    });
  }

  // ========================
  // UTILS
  // ========================
  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function truncate(str, len) {
    return str.length > len ? str.slice(0, len) + '...' : str;
  }

  async function syncWithContentScript() {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab || !tab.url) return;

      let matchedProvider = null;
      for (const [p, domain] of Object.entries(DOMAINS)) {
        if (tab.url.includes(domain)) {
          matchedProvider = p;
          break;
        }
      }

      if (!matchedProvider) return;

      chrome.tabs.sendMessage(tab.id, { type: 'GET_STATUS' }, (response) => {
        if (chrome.runtime.lastError) return;

        if (response && response.isRunning) {
          // AI is busy — lock UI regardless of how it got started (manual or API)
          isRunning = true;
          setStatus('running', 'Running...');
          btnStart.disabled = true;
          btnStop.disabled = false; 
          toggleUILock(true);
          addLog('Re-synced: AI is currently processing', 'info');
          
          // Start polling to detect when it finishes
          startApiStatusPoller();
        } else if (isRunning) {
          // Popup thinks it's running but content script says no — sync back to idle
          console.log('Re-sync: AI is idle, resetting popup state.');
          resetUIState();
        }
      });
    } catch (err) {
      console.error('Sync failed:', err);
    }
  }

})();
