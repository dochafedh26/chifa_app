#!/usr/bin/env python3
import sys
import os
import io
import json
import time
import socket
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import subprocess

# 1. Proactively install/check required dependencies
try:
    import requests
    from google.oauth2 import service_account
    import google.auth.transport.requests
except ImportError:
    print("Installing Google Auth and Requests dependencies...", file=sys.stderr)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "requests", "google-auth"])
    import requests
    from google.oauth2 import service_account
    import google.auth.transport.requests

try:
    import pypdf
except ImportError:
    print("Installing pypdf dependency...", file=sys.stderr)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pypdf"])
    import pypdf

# Global timeout configuration
socket.setdefaulttimeout(15)

# Thread-safe index traversal
all_pdfs = []
pdfs_lock = threading.Lock()

def get_access_token(creds_path):
    scopes = ['https://www.googleapis.com/auth/drive.readonly']
    creds = service_account.Credentials.from_service_account_file(creds_path, scopes=scopes)
    req = google.auth.transport.requests.Request()
    creds.refresh(req)
    return creds.token

def scan_single_folder_http(token, creds_path, folder_id, path_prefix):
    url = "https://www.googleapis.com/drive/v3/files"
    headers = {"Authorization": f"Bearer {token}"}
    params = {
        "q": f"'{folder_id}' in parents and trashed = false",
        "fields": "files(id, name, mimeType, modifiedTime)",
        "pageSize": 1000
    }
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            res = requests.get(url, headers=headers, params=params, timeout=10)
            if res.status_code == 200:
                return res.json().get('files', [])
            elif res.status_code == 401:
                token = get_access_token(creds_path)
                headers = {"Authorization": f"Bearer {token}"}
            else:
                print(f"Error {res.status_code} scanning folder {folder_id}: {res.text}", file=sys.stderr, flush=True)
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(1 + attempt)
            else:
                print(f"Exception scanning folder {folder_id} ({path_prefix}): {e}", file=sys.stderr, flush=True)
    return []

def traverse_parallel_http(creds_path, root_ids):
    token = get_access_token(creds_path)
    queue = []
    
    # Resolve roots
    url = "https://www.googleapis.com/drive/v3/files/{}"
    headers = {"Authorization": f"Bearer {token}"}
    for root_id in root_ids:
        try:
            res = requests.get(url.format(root_id), headers=headers, params={"fields": "name"}, timeout=10)
            if res.status_code == 200:
                name = res.json().get("name", root_id)
                queue.append((root_id, name))
            else:
                queue.append((root_id, root_id))
        except Exception as e:
            queue.append((root_id, root_id))

    with ThreadPoolExecutor(max_workers=15) as executor:
        while queue:
            futures_to_path = {}
            current_token = get_access_token(creds_path)
            for folder_id, path_prefix in queue:
                fut = executor.submit(scan_single_folder_http, current_token, creds_path, folder_id, path_prefix)
                futures_to_path[fut] = path_prefix
            
            queue = []
            
            for future in as_completed(futures_to_path):
                path_prefix = futures_to_path[future]
                items = future.result()
                for item in items:
                    name = item['name']
                    fid = item['id']
                    mimetype = item['mimeType']
                    mtime = item.get('modifiedTime')
                    
                    current_path = f"{path_prefix}/{name}"
                    
                    if mimetype == 'application/vnd.google-apps.folder':
                        queue.append((fid, current_path))
                    elif mimetype == 'application/pdf':
                        with pdfs_lock:
                            all_pdfs.append({
                                "id": fid,
                                "name": name,
                                "path": current_path,
                                "modifiedTime": mtime
                            })
    return all_pdfs

def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    if len(sys.argv) < 4:
        print(json.dumps({
            "status": "error",
            "message": "Usage: python search_drive.py <query> <credentials_path> <folder_ids>"
        }))
        return

    query = sys.argv[1].strip()
    creds_path = sys.argv[2].strip()
    folder_ids_str = sys.argv[3].strip()

    if not query:
        print(json.dumps([]))
        return

    if not os.path.exists(creds_path):
        print(json.dumps({
            "status": "error",
            "message": f"Credentials file not found at: {creds_path}"
        }))
        return

    folder_ids = [fid.strip() for fid in folder_ids_str.split(",") if fid.strip()]
    if not folder_ids:
        print(json.dumps({
            "status": "error",
            "message": "No folder IDs specified"
        }))
        return

    # Paths configuration
    index_path = os.path.join("data", "guidelines", "drive_index.json")
    cache_path = os.path.join("data", "guidelines", "drive_cache.json")
    os.makedirs(os.path.dirname(index_path), exist_ok=True)

    # 1. Load or rebuild the PDF index
    pdfs = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                pdfs = json.load(f)
        except Exception as ie:
            print(f"Warning: Failed to load index: {ie}", file=sys.stderr)

    if not pdfs:
        print("Index not found or empty. Rebuilding index...", file=sys.stderr)
        try:
            pdfs = traverse_parallel_http(creds_path, folder_ids)
            with open(index_path, "w", encoding="utf-8") as f:
                json.dump(pdfs, f, ensure_ascii=False, indent=2)
        except Exception as build_err:
            print(json.dumps({
                "status": "error",
                "message": f"Failed to rebuild index: {build_err}"
            }))
            return

    # 2. Filter matching PDFs by filename keywords
    query_words = [w.lower() for w in query.split() if len(w) >= 2]
    matching_pdfs = []
    for pdf in pdfs:
        name_lower = pdf['name'].lower()
        if all(word in name_lower for word in query_words):
            matching_pdfs.append(pdf)

    # If no files matched the full query terms, try partial word matching
    if not matching_pdfs and len(query_words) > 1:
        for pdf in pdfs:
            name_lower = pdf['name'].lower()
            if any(word in name_lower for word in query_words):
                matching_pdfs.append(pdf)

    # Limit to top 5 files to avoid long download times
    matching_pdfs = matching_pdfs[:5]

    if not matching_pdfs:
        # Return empty list since no filename matched
        print(json.dumps([]))
        return

    # 3. Load page cache
    cache = {}
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                cache = json.load(f)
        except Exception as ce:
            print(f"Warning: Failed to load cache: {ce}", file=sys.stderr)

    excerpts = []
    token = None

    for pdf in matching_pdfs:
        fid = pdf['id']
        fname = pdf['name']
        f_mtime = pdf.get('modifiedTime')

        # Check cache
        cached_file = cache.get(fid)
        if cached_file and cached_file.get("modifiedTime") == f_mtime:
            pages_data = cached_file.get("pages", {})
        else:
            # Download and parse
            print(f"Downloading and parsing {fname} from Google Drive...", file=sys.stderr)
            try:
                if not token:
                    token = get_access_token(creds_path)
                
                url = f"https://www.googleapis.com/drive/v3/files/{fid}?alt=media"
                headers = {"Authorization": f"Bearer {token}"}
                
                res = requests.get(url, headers=headers, timeout=30)
                if res.status_code == 200:
                    fh = io.BytesIO(res.content)
                    reader = pypdf.PdfReader(fh)
                    pages_data = {}
                    for idx, page in enumerate(reader.pages):
                        page_text = page.extract_text()
                        if page_text:
                            pages_data[str(idx + 1)] = page_text
                    
                    # Update cache memory
                    cache[fid] = {
                        "name": fname,
                        "modifiedTime": f_mtime,
                        "pages": pages_data
                    }
                else:
                    print(f"Error {res.status_code} downloading {fname}: {res.text}", file=sys.stderr)
                    continue
            except Exception as de:
                print(f"Error downloading/parsing file {fname}: {de}", file=sys.stderr)
                continue

        # Search within extracted pages
        for page_num, text in pages_data.items():
            # Match query words inside the page text
            text_lower = text.lower()
            if any(word in text_lower for word in query_words) or query.lower() in text_lower:
                excerpts.append({
                    "source": fname,
                    "id": fid,
                    "page": int(page_num),
                    "text": text.strip()
                })

    # Save cache back
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except Exception as se:
        print(f"Warning: Failed to save cache: {se}", file=sys.stderr)

    print(json.dumps(excerpts, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
