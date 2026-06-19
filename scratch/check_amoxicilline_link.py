import requests
from bs4 import BeautifulSoup

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}
url = "https://www.vidal.fr/medicaments/gammes/liste-a.html"

try:
    response = requests.get(url, headers=headers, timeout=10)
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, "html.parser")
        links = soup.find_all('a')
        print(f"Total links: {len(links)}")
        count = 0
        for i, link in enumerate(links):
            href = link.get('href')
            text = link.get_text().strip()
            if href and 'gammes/' in href:
                if 'amox' in text.lower():
                    print(f"Link {i}: '{text}' -> '{href}'")
                    count += 1
        print(f"Found {count} links matching 'amox'.")
except Exception as e:
    print(f"Error: {e}")
