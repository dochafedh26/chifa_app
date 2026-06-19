import sys
import os

try:
    import pypdf
except ImportError:
    print("pypdf not installed")
    sys.exit(1)

pdf_path = "assets/templates/ordonnance_template_2_PAGE.pdf"
if not os.path.exists(pdf_path):
    print(f"File {pdf_path} not found")
    sys.exit(1)

with open(pdf_path, "rb") as f:
    reader = pypdf.PdfReader(f)
    print(f"Pages: {len(reader.pages)}")
    for i, page in enumerate(reader.pages):
        print(f"--- Page {i+1} Text Content ---")
        print(page.extract_text())
