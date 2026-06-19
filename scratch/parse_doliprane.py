import requests
from bs4 import BeautifulSoup

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}
url = "https://www.vidal.fr/medicaments/gammes/doliprane-2962.html"

try:
    response = requests.get(url, headers=headers, timeout=10)
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, "html.parser")
        poso_headers = soup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
        for ph in poso_headers:
            print(f"\nHeader: {ph.name} -> {ph.get_text().strip()}")
            curr = ph.next_sibling
            paragraphs = []
            while curr and getattr(curr, 'name', None) not in ['h2', 'h3', 'h4']:
                if getattr(curr, 'name', None) in ['p', 'ul', 'ol', 'div']:
                    txt = curr.get_text().strip()
                    if txt:
                        paragraphs.append(txt)
                curr = curr.next_sibling
            print("Content:")
            print("\n".join(paragraphs))
            print("-" * 50)
except Exception as e:
    print(f"Error: {e}")
