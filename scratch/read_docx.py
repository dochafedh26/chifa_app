import zipfile
import xml.etree.ElementTree as ET
import sys

def get_docx_text(path):
    try:
        doc = zipfile.ZipFile(path)
        xml_content = doc.read('word/document.xml')
        root = ET.fromstring(xml_content)
        
        # Define namespaces
        namespaces = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
        
        paragraphs = []
        for paragraph in root.findall('.//w:p', namespaces):
            texts = [node.text for node in paragraph.findall('.//w:t', namespaces) if node.text]
            if texts:
                paragraphs.append("".join(texts))
        return "\n".join(paragraphs)
    except Exception as e:
        return f"Error reading {path}: {e}"

if __name__ == '__main__':
    if len(sys.argv) > 1:
        text = get_docx_text(sys.argv[1])
        out_path = sys.argv[1] + ".txt"
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"Extracted to {out_path}")
    else:
        print("Usage: python read_docx.py <path_to_docx>")
