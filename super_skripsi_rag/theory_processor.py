import json
import re
import httpx
import asyncio
from typing import List, Dict, Optional, Callable


def repair_json_string(text: str) -> str:
    """Mencoba memperbaiki JSON yang rusak atau terpotong dari respons AI."""
    if not text: return "[]"
    
    # 1. Hapus markdown code fences jika ada
    text = text.strip()
    if text.startswith("```"):
        # Cari baris pertama setelah ```json atau ```
        lines = text.splitlines()
        if len(lines) > 2:
            if lines[0].startswith("```"):
                # Buang baris pertama dan terakhir (```)
                if lines[-1].startswith("```"):
                    text = "\n".join(lines[1:-1])
                else:
                    text = "\n".join(lines[1:])
    
    # 2. Cari bracket pertama dan terakhir untuk mengambil array/object
    # Kita prioritaskan Array [] karena itu yang kita harapkan
    start_arr = text.find('[')
    end_arr = text.rfind(']')
    
    start_obj = text.find('{')
    end_obj = text.rfind('}')

    # Pilih yang paling luar
    start = start_arr if (start_arr != -1 and (start_obj == -1 or start_arr < start_obj)) else start_obj
    end = end_arr if (end_arr != -1 and (end_obj == -1 or end_arr > end_obj)) else end_obj

    if start == -1: return "[]"
    
    # Ambil bagian JSON saja
    if end == -1 or end < start:
        text = text[start:]
    else:
        text = text[start:end+1]
        
    # 3. Hapus karakter kontrol ilegal (0-31) kecuali whitespace standar
    text = "".join(char for char in text if ord(char) >= 32 or char in "\n\r\t")
    
    # 4. Hapus trailing commas yang merusak json.loads
    text = re.sub(r',\s*([\]}])', r'\1', text)
    
    # 5. Jika terpotong di tengah, coba tutup seadanya
    open_braces = text.count('{') - text.count('}')
    open_brackets = text.count('[') - text.count(']')
    
    if open_braces > 0: text += "}" * open_braces
    if open_brackets > 0: text += "]" * open_brackets
    
    return text.strip()

async def extract_structured_theories(
    text: str, 
    api_keys_str: str, 
    provider: str, 
    model: Optional[str] = None,
    judul_skripsi: str = "",
    lokasi_penelitian: str = "",
    kerangka_skripsi: str = "",
    doc_title: str = "Tidak diketahui",
    doc_authors: str = "Tidak diketahui",
    doc_year: str = "n/a",
    doc_journal: str = "Tidak tersedia",
    custom_prompt: str = "",
    check_abort: Optional[Callable] = None # NEW
) -> Dict:
    """
    Menggunakan AI untuk membedah teks PDF menjadi daftar teori terstruktur (JSON).
    Mendukung rotasi kunci API jika satu kunci limit/error.
    """
    if not api_keys_str:
        print("[TheoryProcessor] ❌ API Key kosong.")
        return {"metadata": {}, "theories": []}

    keys = [k.strip() for k in api_keys_str.split(',') if k.strip()]
    if not keys: return {"metadata": {}, "theories": []}

    prov = provider.lower()
    if "gemini" in prov: prov = "gemini"
    elif "openai" in prov: prov = "openai"
    elif "groq" in prov: prov = "groq"
    elif "cerebras" in prov: prov = "cerebras"

    final_model = model if (model and model.strip()) else None
    if not final_model:
      if prov == "gemini": final_model = "gemini-1.5-flash"
      elif prov == "openai": final_model = "gpt-4o-mini"
      elif prov == "groq": final_model = "llama-3.3-70b-versatile"
      elif prov == "cerebras": final_model = "llama3.3-70b"
      else: final_model = "gpt-4o-mini"

    # 1. Pilih system prompt (WAJIB dari Dart UI)
    if custom_prompt and custom_prompt.strip():
        print("[RAG] 🎯 Menggunakan Prompt kustom dari UI Dart.")
        system_prompt = custom_prompt
    else:
        raise ValueError("[TheoryProcessor] ❌ Error: Tidak ada prompt yang diberikan dari Flutter. Proses dihentikan.")
    
    user_prompt = f"""DOKUMEN SUMBER:
---
{text[:300000]}
---

Tugas Anda:
Ekstrak daftar teori/sitasi (JSON ARRAY) sesuai instruksi sistem.
Pastikan metadata sitasi akurat sesuai isi dokumen.
Gunakan format JSON yang valid. Jika tidak ada yang relevan, hasilkan [].
Mulai langsung dengan '['."""

    max_retries = 5
    for i, api_key in enumerate(keys):
        print(f"[TheoryProcessor] 🔄 Mencoba Kunci #{i+1}/{len(keys)} (Provider: {prov}, Model: {final_model})")
        retry_count = 0
        
        while retry_count < max_retries:
            if check_abort and check_abort():
                print("[TheoryProcessor] 🛑 Proses dihentikan (Aborted by user).")
                return {"metadata": {}, "theories": []}
                
            try:
                # Naikkan timeout ke 1200 detik (20 menit) agar sinkron dengan Flutter
                async with httpx.AsyncClient(timeout=1200.0) as client:
                    headers = {"Content-Type": "application/json"}
                    
                    # ... (logic payload sama)
                    if prov == "gemini":
                        # ... (keep existing gemini payload)
                        url = f"https://generativelanguage.googleapis.com/v1beta/models/{final_model}:generateContent?key={api_key}"
                        payload = {
                            "system_instruction": {"parts": [{"text": system_prompt}]},
                            "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
                            "generationConfig": {
                                "temperature": 0.1,
                                "maxOutputTokens": 16384,
                                "response_mime_type": "application/json" if "1.5" in final_model else "text/plain"
                            },
                            "safetySettings": [
                                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
                            ]
                        }
                    elif prov == "localhost":
                        base_url = api_key if api_key.startswith("http") else "http://localhost:11434"
                        
                        if ":3000" in base_url or "/api/" in base_url:
                            target = final_model.lower() if final_model and final_model != "auto-detect" else "gemini"
                            url = base_url if "/api/" in base_url else f"{base_url.rstrip('/')}/api/{target}"
                            payload = {
                                "prompt": f"{system_prompt}\n\n{user_prompt}",
                                "model": final_model,
                                "max_tokens": 16384,
                                "stream": False
                            }
                        else:
                            url = base_url.rstrip("/") + "/v1/chat/completions"
                            payload = {
                                "model": final_model,
                                "messages": [
                                    {"role": "system", "content": system_prompt},
                                    {"role": "user", "content": user_prompt}
                                ],
                                "temperature": 0.1,
                                "max_tokens": 16384,
                                "stream": False
                            }
                    else:
                        # ... (keep existing cloud payload)
                        if prov == "openai": url = "https://api.openai.com/v1/chat/completions"
                        elif prov == "groq": url = "https://api.groq.com/openai/v1/chat/completions"
                        elif prov == "cerebras": url = "https://api.cerebras.ai/v1/chat/completions"
                        else:
                            print(f"[TheoryProcessor] ❌ Provider tidak didukung: {prov}")
                            break
                        
                        payload = {
                            "model": final_model,
                            "messages": [
                                {"role": "system", "content": system_prompt},
                                {"role": "user", "content": user_prompt}
                            ],
                            "temperature": 0.1,
                            "max_tokens": 16384,
                            "stream": False
                        }

                    if prov not in ["localhost", "gemini"]:
                        headers["Authorization"] = f"Bearer {api_key}"

                    resp = await client.post(url, json=payload, headers=headers)
                    
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_text = ""
                        
                        if "choices" in data: raw_text = data["choices"][0]["message"]["content"]
                        elif "candidates" in data:
                            candidate = data["candidates"][0]
                            if "content" in candidate:
                                raw_text = candidate["content"]["parts"][0]["text"]
                            else:
                                finish_reason = candidate.get("finishReason", "UNKNOWN")
                                print(f"[TheoryProcessor] ⚠️ Gemini gagal menghasilkan konten. Reason: {finish_reason}")
                                if finish_reason == "SAFETY":
                                    print("[TheoryProcessor] 🛡️ Terblokir filter keamanan Google. Mencoba prompt lebih lunak...")
                                retry_count += 1
                                continue
                        elif "result" in data: raw_text = data["result"]
                        elif "message" in data and "content" in data["message"]: raw_text = data["message"]["content"]
                        elif "response" in data: raw_text = data["response"]
                        elif "content" in data: raw_text = data["content"]
                        else:
                            for k, v in data.items():
                                if isinstance(v, str) and len(v) > 10:
                                    raw_text = v
                                    break
                            
                        # Debug Log untuk melihat apa yang sebenarnya dikirim AI
                        print(f"[TheoryProcessor] 📄 Raw AI Response Snippet: {str(raw_text)[:200]}...")

                        if not raw_text or len(str(raw_text).strip()) < 5:
                            print(f"[TheoryProcessor] ⚠️ AI memberikan respons kosong. Mencoba lagi... ({retry_count+1}/{max_retries})")
                            retry_count += 1
                            continue

                        try:
                            clean_text = repair_json_string(raw_text)
                            result = json.loads(clean_text)
                            
                            # Handle both old (list) and new (dict) formats
                            metadata = {}
                            theories = []

                            if isinstance(result, dict):
                                metadata = result.get("metadata", {})
                                theories = result.get("theories", [])
                            elif isinstance(result, list):
                                theories = result
                            
                            if theories:
                                # Clean up metadata values (strip whitespace)
                                for item in theories:
                                    if isinstance(item, dict):
                                        for k, v in item.items():
                                            if isinstance(v, str):
                                                item[k] = v.strip()
                                                
                                print(f"[TheoryProcessor] ✅ Sukses! Mengekstrak {len(theories)} item.")
                                return {"metadata": metadata, "theories": theories}
                            elif isinstance(theories, list) and len(theories) == 0:
                                print(f"[TheoryProcessor] ⚠️ AI menghasilkan list kosong. Mencoba lagi...")
                                retry_count += 1
                                continue
                            else:
                                print(f"[TheoryProcessor] ⚠️ Hasil bukan format yang didukung: {type(result)}")
                                break
                        except Exception as json_err:
                            print(f"[TheoryProcessor] ❌ Parsing Gagal: {json_err}")
                            retry_count += 1
                            continue
                    else:
                        print(f"[TheoryProcessor] ⚠️ Kunci #{i+1} Gagal ({resp.status_code}): {resp.text[:150]}")
                        break
                
            except (httpx.ConnectError, httpx.RemoteProtocolError) as conn_err:
                retry_count += 1
                if retry_count < max_retries:
                    print(f"[TheoryProcessor] ⏳ Server belum siap ({conn_err}). Mencoba lagi dalam 2 detik... ({retry_count}/{max_retries})")
                    await asyncio.sleep(2)
                else:
                    print(f"[TheoryProcessor] ❌ Gagal menghubungi server setelah {max_retries} percobaan.")
                    break
            except Exception as e:
                print(f"[TheoryProcessor] ❌ Error Tak Terduga: {e}")
                retry_count += 1
                if retry_count < max_retries:
                    print(f"[TheoryProcessor] ⏳ Menunggu 5 detik sebelum retry... ({retry_count}/{max_retries})")
                    await asyncio.sleep(5)
                else:
                    break
            
            await asyncio.sleep(0.5)

    print(f"[TheoryProcessor] 💀 Gagal total setelah {max_retries} percobaan atau list kosong.")
    return {"metadata": {}, "theories": []}
