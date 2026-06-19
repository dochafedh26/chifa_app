import requests
from bs4 import BeautifulSoup
import re

url = "https://www.vidal.fr/medicaments/gammes/a-313-2.html"
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

try:
    response = requests.get(url, headers=headers, timeout=10)
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, "html.parser")
        
        # Print all headings to see the layout
        print("\n--- Headings Found ---")
        for h in soup.find_all(['h1', 'h2', 'h3', 'h4']):
            text = h.get_text().strip()
            print(f"{h.name}: {text}")
            
        # Look for posology keywords in sections
        print("\n--- Posology Section Check ---")
        # Find sections, divs or paragraphs mentioning posologie
        poso_headers = soup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
        for ph in poso_headers:
            print(f"Header: {ph.name} -> {ph.get_text().strip()}")
            # Get sibling paragraphs
            curr = ph.next_sibling
            paragraphs = []
            while curr and getattr(curr, 'name', None) not in ['h2', 'h3', 'h4']:
                if getattr(curr, 'name', None) in ['p', 'ul', 'ol', 'div']:
                    paragraphs.append(curr.get_text().strip())
                curr = curr.next_sibling
            print("\nContent:")
            print("\n".join(paragraphs[:5]))
            print("-" * 50)
            
except Exception as e:
    print(f"Error: {e}")
