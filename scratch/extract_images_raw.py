import sys
import pypdf

def extract_raw_images(path):
    try:
        reader = pypdf.PdfReader(path)
        page = reader.pages[0]
        resources = page.get('/Resources')
        if resources and '/XObject' in resources:
            xobjects = resources['/XObject']
            for name in xobjects:
                obj = xobjects[name]
                if obj.get('/Subtype') == '/Image':
                    print(f"Found image: {name}")
                    print(f"  Width: {obj.get('/Width')}, Height: {obj.get('/Height')}")
                    print(f"  ColorSpace: {obj.get('/ColorSpace')}")
                    print(f"  Filter: {obj.get('/Filter')}")
                    
                    try:
                        data = obj.get_data()
                        filter_name = str(obj.get('/Filter', ''))
                        ext = 'jpg' if 'DCT' in filter_name else 'png'
                        out_name = f"assets/templates/{name[1:]}.{ext}"
                        with open(out_name, "wb") as f:
                            f.write(data)
                        print(f"  Saved raw data to {out_name}")
                    except Exception as ie:
                        print(f"  Failed to extract data: {ie}")
    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        extract_raw_images(sys.argv[1])
