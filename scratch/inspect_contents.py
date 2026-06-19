import sys
import pypdf

def inspect_contents(path):
    try:
        reader = pypdf.PdfReader(path)
        page = reader.pages[0]
        print("Page Keys:")
        for k, v in page.items():
            print(f"  {k}: {type(v)}")
            if k == '/Resources':
                print("  Resources details:")
                for rk, rv in v.items():
                    print(f"    {rk}: {rv}")
    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        inspect_contents(sys.argv[1])
