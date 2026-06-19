import requests
from bs4 import BeautifulSoup

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, http://www.vidal.fr/maladies/)"
}

url = "https://www.vidal.fr/maladies/coeur-circulation-veines/avc/traitements.html"
print(f"Fetching: {url}")
r = requests.get(url, headers=headers, timeout=10)
print(f"Status: {r.status_code}")
soup = BeautifulSoup(r.content, "html.parser")

for h in soup.find_all(['h2', 'h3', 'h4']):
    text = h.text.strip()
    print(f"\n[{h.name}] {text}")
    # Get content under this header
    content = []
    sibling = h.next_sibling
    while sibling:
        if sibling.name in ['h2', 'h3', 'h4']:
            break
        if sibling.name in ['p', 'ul', 'ol']:
            content.append(sibling.get_text().strip())
        sibling = sibling.next_sibling
    
    snippet = " | ".join(content)[:300]
    print(f"  -> Content snippet: {snippet}...")
