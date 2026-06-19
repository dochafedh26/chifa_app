import sys
import pypdf

def extract_text_from_array(path):
    try:
        reader = pypdf.PdfReader(path)
        page = reader.pages[0]
        contents = page.get('/Contents')
        if contents:
            # If contents is a list/array
            streams = contents if isinstance(contents, list) else [contents]
            print(f"Number of content streams: {len(streams)}")
            all_text = []
            for idx, stream in enumerate(streams):
                obj = stream.get_object()
                data = obj.get_data()
                decoded = data.decode('utf-8', errors='ignore')
                all_text.append(decoded)
            
            merged = "\n".join(all_text)
            print("Merged content length:", len(merged))
            # Let's extract any text inside parenthesized TJ/Tj operators
            import re
            strings = re.findall(r'\((.*?)\)\s*T[jJ]', merged)
            if strings:
                print("Found strings in PDF stream:")
                for s in strings:
                    print("  ", s)
            else:
                print("No string operators found in PDF stream.")
        else:
            print("No contents stream found.")
    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        extract_text_from_array(sys.argv[1])
