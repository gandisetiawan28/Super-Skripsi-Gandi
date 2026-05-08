import fitz  # PyMuPDF
import sys
import json
import os

def update_metadata(input_path, output_path, meta_data):
    try:
        if not os.path.exists(input_path):
            print(f"Error: Input file not found: {input_path}", file=sys.stderr)
            return False
            
        doc = fitz.open(input_path)
        
        # Get current metadata
        metadata = doc.metadata
        
        # Update allowed fields
        if "title" in meta_data and meta_data["title"]:
            metadata["title"] = meta_data["title"]
        
        if "author" in meta_data and meta_data["author"]:
            metadata["author"] = meta_data["author"]
            
        if "subject" in meta_data and meta_data["subject"]:
            metadata["subject"] = meta_data["subject"]
            
        if "keywords" in meta_data and meta_data["keywords"]:
            metadata["keywords"] = meta_data["keywords"]
        
        # Note: We are explicitly NOT updating 'creator' or 'producer' 
        # as per user request to keep original tool info.
        
        doc.set_metadata(metadata)
        
        # Save to output path
        # encryption=fitz.PDF_ENCRYPT_KEEP preserves encryption if any
        doc.save(output_path, garbage=3, deflate=True)
        doc.close()
        return True
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: py update_pdf_metadata.py <input> <output> <metadata_json>")
        sys.exit(1)
        
    input_pdf = sys.argv[1]
    output_pdf = sys.argv[2]
    
    try:
        meta_json = json.loads(sys.argv[3])
    except Exception as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
    
    success = update_metadata(input_pdf, output_pdf, meta_json)
    if success:
        print("Success")
        sys.exit(0)
    else:
        sys.exit(1)
