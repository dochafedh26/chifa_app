import sys
import pypdf

def inspect_operators(path):
    try:
        reader = pypdf.PdfReader(path)
        page = reader.pages[0]
        contents = page.get('/Contents')
        if contents:
            streams = contents if isinstance(contents, list) else [contents]
            for idx, stream in enumerate(streams):
                obj = stream.get_object()
                data = obj.get_data()
                print(f"--- Stream {idx+1} (length {len(data)}) ---")
                print(data[:1500].decode('utf-8', errors='ignore'))
    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        inspect_operators(sys.argv[1])
