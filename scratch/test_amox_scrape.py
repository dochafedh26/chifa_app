import requests
from bs4 import BeautifulSoup
import re

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def clean_medic_name(name):
    # Remove text in parentheses/brackets
    name = re.sub(r'\(.*?\)', '', name)
    name = re.sub(r'\[.*?\]', '', name)
    # Split on numbers
    parts = re.split(r'\d', name)
    brand = parts[0].strip()
    # Also split on common formulation suffixes
    suffixes = r'\b(CP|GEL|GELULE|SACHET|AMPOULE|FLACON|PDRE|LYOPH|INJ|SUSPENSION|SOL|SOLUT|SIROP|COMP|COMPRIME)\b'
    brand = re.split(suffixes, brand, flags=re.IGNORECASE)[0].strip()
    return brand

def scrape_posology(medic_name):
    brand = clean_medic_name(medic_name)
    print(f"Cleaned brand: '{brand}'")
    if not brand:
        return None, None
    
    first_char = brand[0].lower()
    if first_char.isdigit():
        letter = "0-9"
    elif first_char.isalpha():
        letter = first_char
    else:
        return None, None
        
    index_url = f"https://www.vidal.fr/medicaments/gammes/liste-{letter}.html"
    print(f"Index URL: {index_url}")
    
    try:
        r = requests.get(index_url, headers=headers, timeout=10)
        print(f"Index response: {r.status_code}")
        if r.status_code != 200:
            return None, None
            
        soup = BeautifulSoup(r.content, "html.parser")
        links = soup.find_all('a')
        
        target = brand.lower()
        matching_href = None
        
        # 1. Exact match
        for link in links:
            href = link.get('href')
            if href and ('gammes/' in href or 'gamme' in href) and 'liste-' not in href:
                text = link.get_text().strip().lower()
                if len(text) > 1 and text == target:
                    matching_href = href
                    print(f"Exact match: '{text}' -> '{href}'")
                    break
                    
        # 2. Starts with/prefix match
        if not matching_href:
            combination_indicators = ['/', '+', 'acide clavulanique', 'clavulan']
            is_target_combo = any(ind in target for ind in combination_indicators)
            for link in links:
                href = link.get('href')
                if href and ('gammes/' in href or 'gamme' in href) and 'liste-' not in href:
                    text = link.get_text().strip().lower()
                    if len(text) > 1 and (text.startswith(target) or target.startswith(text)):
                        is_link_combo = any(ind in text for ind in combination_indicators)
                        if is_target_combo == is_link_combo:
                            matching_href = href
                            print(f"Prefix match (filtered): '{text}' -> '{href}'")
                            break
                        
        if not matching_href:
            print("No matching link found.")
            return None, None
            
        # Build detail page URL
        detail_url = matching_href
        if not detail_url.startswith('http'):
            if detail_url.startswith('/'):
                detail_url = "https://www.vidal.fr" + detail_url
            else:
                detail_url = "https://www.vidal.fr/" + detail_url
                
        print(f"Fetching detail URL: {detail_url}")
        rd = requests.get(detail_url, headers=headers, timeout=10)
        print(f"Detail page response: {rd.status_code}")
        if rd.status_code != 200:
            return None, None
            
        dsoup = BeautifulSoup(rd.content, "html.parser")
        
        # Find posology header
        poso_headers = dsoup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
        print(f"Found {len(poso_headers)} posology headers.")
        
        poso_texts = []
        for ph in poso_headers:
            print(f"  Header: {ph.name} -> {ph.get_text().strip()}")
            curr = ph.next_sibling
            while curr and getattr(curr, 'name', None) not in ['h2', 'h3', 'h4']:
                if getattr(curr, 'name', None) in ['p', 'ul', 'ol', 'div']:
                    txt = curr.get_text().strip()
                    if txt:
                        poso_texts.append(txt)
                curr = curr.next_sibling
                
        full_poso_text = "\n".join(poso_texts).strip()
        print(f"Full poso text length: {len(full_poso_text)}")
        if not full_poso_text:
            return None, None
            
        return "Adult", "Pediatric"
        
    except Exception as e:
        print(f"Exception: {e}")
        return None, None

scrape_posology("AMOXICILLINE")
