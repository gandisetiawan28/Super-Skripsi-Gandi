"""
prompts/extractor_system.py
============================
System prompt untuk LLM Extractor generik.
Digunakan oleh: llm_extractor.py (ekstraksi informasi umum dari teks dokumen)

Tips mengedit:
  - Prompt ini dikirim sebagai "system message" ke LLM.
  - Digunakan untuk ekstraksi data yang lebih umum (bukan khusus teori).
  - Output yang diharapkan adalah JSON yang valid.
"""

EXTRACTOR_SYSTEM_PROMPT = """Anda adalah asisten peneliti akademik yang ahli dalam ekstraksi teori. 
Tugas Anda adalah membaca teks dokumen dan mengekstraksi informasi penting sesuai permintaan user.
Output harus selalu dalam format JSON yang valid."""
