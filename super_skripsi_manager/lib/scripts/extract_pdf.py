import sys
import re
import json
import pdfplumber

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

def clean_text(text: str) -> str:
    """Bersihkan artefak PDF: hyphen baris, ligature, spasi berlebih."""
    text = text.replace('\u00ad', '')  # Soft hyphen
    for lig, r in {'\ufb01':'fi','\ufb02':'fl','\ufb00':'ff','\ufb03':'ffi','\ufb04':'ffl'}.items():
        text = text.replace(lig, r)
    text = re.sub(r'-\n(\S)', r'\1', text)         # Sambung kata yang dipotong hyphen
    text = re.sub(r'(?<!\n)\n(?!\n)', ' ', text)   # Newline tunggal → spasi
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def extract_text(pdf_path):
    try:
        full_text = ""
        page_texts = {}

        with pdfplumber.open(pdf_path) as pdf:
            for i, page in enumerate(pdf.pages):
                raw = page.extract_text() or ''
                cleaned = clean_text(raw)
                full_text += cleaned + "\n\n"
                page_texts[i + 1] = cleaned

        result = {
            "full_text": full_text.strip(),
            "page_texts": page_texts
        }
        print(json.dumps(result, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python extract_pdf.py <path_to_pdf>")
        sys.exit(1)
    extract_text(sys.argv[1])
