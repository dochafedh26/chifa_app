import sys
import pypdf

def detailed_inspect_pdf(path):
    try:
        reader = pypdf.PdfReader(path)
        print(f"File: {path}")
        print(f"Number of pages: {len(reader.pages)}")
        for idx, page in enumerate(reader.pages):
            print(f"--- Page {idx+1} ---")
            print("Images on page:")
            for img_name in page.images:
                img = page.images[img_name]
                print(f"  Name: {img_name}, Size: {len(img.data)} bytes, Mode: {img.name}")
            print("Resources:", page.resources.keys())
    except Exception as e:
        print(f"Error reading {path}: {e}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        detailed_inspect_pdf(sys.argv[1])
    else:
        print("Usage: python read_pdf.py <path_to_pdf>")
