import os
import json
import litellm
import requests
from ris_generator import to_ris

# Disable logging for LiteLLM
litellm.set_verbose = False

from prompts import EXTRACTOR_SYSTEM_PROMPT

def extract_with_llm(text, system_prompt, provider, api_key, model=None):
    """
    Mengekstrak informasi dari teks menggunakan LLM.
    Mendukung provider cloud (Gemini, OpenAI, dsb) dan Localhost (Ollama, LM Studio, Gemini Flow).
    """
    user_prompt = f"TEKS DOKUMEN:\n{text}\n\nINSTRUKSI: {system_prompt}"
    
    raw = ""
    
    # Handle Localhost (Ollama / LM Studio / Gemini Flow Bridge)
    if provider.lower() == 'localhost':
        api_base = api_key if api_key.startswith('http') else "http://localhost:11434/v1"
        
        # Detection for Gemini Flow API Bridge (Port 3000 or /api/ endpoint)
        if ":3000" in api_base or "/api/" in api_base:
            if "/api/" in api_base:
                url = api_base
            else:
                # Use selected model for routing (e.g. deepseek, claude, etc.)
                target_provider = model.lower() if model and model != "auto-detect" else "gemini"
                url = f"{api_base.rstrip('/')}/api/{target_provider}"
            print(f"[RAG] Routing to Gemini Flow: {url}")
            resp = requests.post(url, json={"prompt": f"{EXTRACTOR_SYSTEM_PROMPT}\n\n{user_prompt}"}, timeout=60)
            if resp.status_code == 200:
                raw = resp.json().get('result', '')
            else:
                raise Exception(f"Gemini Flow Bridge Error ({resp.status_code}): {resp.text}")
        else:
            # Standard OpenAI-compatible (Ollama, LM Studio, etc.)
            response = litellm.completion(
                model=f"openai/{model}" if model and model != "auto-detect" else "openai/llama3",
                messages=[
                    {"role": "system", "content": EXTRACTOR_SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                api_base=api_base,
                api_key="none",
                temperature=0.1
            )
            raw = response.choices[0].message.content or ""
    
    # Handle Cloud Providers
    else:
        completion_kwargs = {
            "model": model,
            "messages": [
                {"role": "system", "content": EXTRACTOR_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "api_key": api_key,
            "temperature": 0.1,
            "max_tokens": 2000,
        }
        response = litellm.completion(**completion_kwargs)
        raw = response.choices[0].message.content or ""

    return _parse_extractions(raw)

def _parse_extractions(raw_text):
    """Membersihkan dan parse JSON dari output LLM."""
    try:
        # Bersihkan markdown code blocks
        clean_text = raw_text.replace("```json", "").replace("```", "").strip()
        return json.loads(clean_text)
    except Exception as e:
        print(f"Error parsing LLM response: {e}")
        # Return fallback structure
        return {"error": "Failed to parse JSON", "raw": raw_text}

def extract_ris_metadata(text, provider, api_key, model=None):
    """Ekstraksi khusus untuk metadata RIS."""
    prompt = "Ekstrak metadata sitasi (judul, penulis, tahun, jurnal) dari teks ini untuk format RIS."
    data = extract_with_llm(text, prompt, provider, api_key, model)
    return to_ris(data)

def extract_from_chunks(query, chunks, doc_meta, api_key, provider, model=None):
    """
    Mengekstrak informasi spesifik berdasarkan query dari kumpulan chunks.
    Digunakan oleh endpoint /extract.
    """
    # 1. Gabungkan isi chunk menjadi satu konteks
    context = ""
    for i, c in enumerate(chunks):
        context += f"[Chunk {i+1} - Hal {c.get('page_start', '?')}]\n{c['content']}\n\n"
    
    # 2. Bangun Prompt
    system_prompt = f"""Anda adalah asisten peneliti yang membantu menjawab pertanyaan berdasarkan dokumen.
PERTANYAAN USER: {query}

DATA DOKUMEN:
Judul: {doc_meta.get('title', 'Unknown')}
Penulis: {', '.join(doc_meta.get('authors', []))}
Tahun: {doc_meta.get('year', 'n/a')}

INSTRUKSI:
1. Jawab pertanyaan hanya berdasarkan DATA DOKUMEN di atas.
2. Jika tidak ada informasi yang relevan di data tersebut, katakan tidak ditemukan.
3. Berikan jawaban dalam format JSON LIST of objects:
   [
     {{
       "kutipan": "teks verbatim dari dokumen",
       "analisis": "penjelasan singkat mengapa ini relevan",
       "halaman": "nomor halaman"
     }}
   ]
"""
    
    # 3. Panggil LLM
    raw_data = extract_with_llm(context, system_prompt, provider, api_key, model)
    
    # 4. Bungkus dalam struktur yang diharapkan main.py
    return {
        "extractions": raw_data if isinstance(raw_data, list) else [],
        "doc_meta": doc_meta,
        "ris": to_ris(doc_meta)
    }
