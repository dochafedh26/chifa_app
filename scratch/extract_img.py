import sys
import pypdf
import os

def extract_images(pdf_path, output_dir):
    try:
        reader = pypdf.PdfReader(pdf_path)
        os.makedirs(output_dir, exist_ok=True)
        count = 0
        for page_num, page in enumerate(reader.pages):
            for img_name in page.images:
                img = page.images[img_name]
                img_path = os.path.join(output_dir, f"{os.path.basename(pdf_path)}_p{page_num}_{img_name}")
                with open(img_path, "wb") as f:
                    f.write(img.data)
                print(f"Extracted image: {img_path}")
                count += 1
        if count == 0:
            print("No images found in the PDF.")
    except Exception as e:
        print(f"Error extracting images: {e}")

if __name__ == '__main__':
    if len(sys.argv) > 2:
        extract_images(sys.argv[1], sys.argv[2])
    else:
        print("Usage: python extract_img.py <path_to_pdf> <output_dir>")
