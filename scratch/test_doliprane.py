import requests
from bs4 import BeautifulSoup
import re

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# 1. Search for Doliprane in liste-d.html
list_url = "https://www.vidal.fr/medicaments/gammes/liste-d.html"
try:
    response = requests.get(list_url, headers=headers, timeout=10)
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, "html.parser")
        links = soup.find_all('a', href=re.compile(r'/medicaments/gammes/'))
        print("Found links matching 'doliprane':")
        doliprane_link = None
        for link in links:
            text = link.get_text().strip()
            href = link.get('href')
            if 'doliprane' in text.lower():
                print(f"  Text: {text} -> Href: {href}")
                if not doliprane_link:
                    doliprane_link = "https://www.vidal.fr" + href if href.startswith('/') else href
        
        if doliprane_link:
            print(f"\nFetching Doliprane details from: {doliprane_link}")
            resp = requests.get(doliprane_link, headers=headers, timeout=10)
            if resp.status_code == 200:
                dsoup = BeautifulSoup(resp.content, "html.parser")
                
                # Print posology sections
                print("\n--- Doliprane Posology ---")
                poso_headers = dsoup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
                for ph in poso_headers:
                    print(f"Header: {ph.name} -> {ph.get_text().strip()}")
                    curr = ph.next_sibling
                    paragraphs = []
                    while curr and getattr(curr, 'name', None) not in ['h2', 'h3', 'h4']:
                        if getattr(curr, 'name', None) in ['p', 'ul', 'ol', 'div']:
                            txt = curr.get_text().strip()
                            if txt:
                                paragraphs.append(txt)
                        curr = curr.next_sibling
                    print("\n".join(paragraphs))
                    print("-" * 50)
except Exception as e:
    print(f"Error: {e}")
