import requests
from bs4 import BeautifulSoup
import re
import sys

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def clean_medic_name(name):
    name = re.sub(r'\(.*?\)', '', name)
    name = re.sub(r'\[.*?\]', '', name)
    parts = re.split(r'\d', name)
    brand = parts[0].strip()
    suffixes = r'\b(CP|GEL|GELULE|SACHET|AMPOULE|FLACON|PDRE|LYOPH|INJ|SUSPENSION|SOL|SOLUT|SIROP|COMP|COMPRIME)\b'
    brand = re.split(suffixes, brand, flags=re.IGNORECASE)[0].strip()
    return brand

def split_posology(text):
    text = text.strip()
    if not text:
        return "", ""
    lines = text.split('\n')
    split_idx = -1
    for idx, line in enumerate(lines):
        clean_line = line.strip().lower()
        if (clean_line.startswith("enfant") or clean_line.startswith("nourrisson") or "enfant :" in clean_line or "nourrisson :" in clean_line) and "adulte et" not in clean_line:
            split_idx = idx
            break
    if split_idx != -1:
        return "\n".join(lines[:split_idx]).strip(), "\n".join(lines[split_idx:]).strip()
    return text, text

def scrape_posology(medic_name):
    brand = clean_medic_name(medic_name)
    if not brand:
        return None, None
    first_char = brand[0].lower()
    index_url = f"https://www.vidal.fr/medicaments/gammes/liste-{first_char}.html"
    
    r = requests.get(index_url, headers=headers, timeout=10)
    soup = BeautifulSoup(r.content, "html.parser")
    links = soup.find_all('a')
    
    target = brand.lower()
    candidate_hrefs = []
    
    # 1. Exact
    for link in links:
        href = link.get('href')
        if href and ('gammes/' in href or 'gamme' in href) and 'liste-' not in href:
            text = link.get_text().strip().lower()
            if len(text) > 1 and text == target:
                if href not in candidate_hrefs:
                    candidate_hrefs.append(href)
                    
    # 2. Prefix
    combination_indicators = ['/', '+', 'acide clavulanique', 'clavulan']
    is_target_combo = any(ind in target for ind in combination_indicators)
    for link in links:
        href = link.get('href')
        if href and ('gammes/' in href or 'gamme' in href) and 'liste-' not in href:
            text = link.get_text().strip().lower()
            if len(text) > 1 and (text.startswith(target) or target.startswith(text)):
                is_link_combo = any(ind in text for ind in combination_indicators)
                if is_target_combo == is_link_combo:
                    if href not in candidate_hrefs:
                        candidate_hrefs.append(href)
                        
    if not candidate_hrefs:
        return None, None
        
    for href in candidate_hrefs:
        detail_url = href
        if not detail_url.startswith('http'):
            detail_url = "https://www.vidal.fr/" + detail_url.lstrip('/')
            
        print(f"Trying candidate URL: {detail_url}")
        try:
            rd = requests.get(detail_url, headers=headers, timeout=10)
            if rd.status_code != 200:
                continue
            dsoup = BeautifulSoup(rd.content, "html.parser")
            poso_headers = dsoup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
            
            if not poso_headers:
                print(f"-> No posology headers on {detail_url}, checking next...")
                continue
                
            poso_texts = []
            for ph in poso_headers:
                curr = ph.next_sibling
                while curr and getattr(curr, 'name', None) not in ['h2', 'h3', 'h4']:
                    if getattr(curr, 'name', None) in ['p', 'ul', 'ol', 'div']:
                        txt = curr.get_text().strip()
                        if txt:
                            poso_texts.append(txt)
                    curr = curr.next_sibling
            full_poso_text = "\n".join(poso_texts).strip()
            if full_poso_text:
                adult, pediatric = split_posology(full_poso_text)
                print(f"-> SUCCESS on {detail_url}!")
                return adult, pediatric
        except Exception as e:
            print(f"Error: {e}")
    return None, None

# Test DCI cleaning
dci_name = "METRONIDAZOLE BENZOATE EXPRIME EN METRONIDAZOLE"
if 'exprime en' in dci_name.lower():
    dci_name = dci_name.lower().split('exprime en')[1].strip()
parts = re.split(r'[+/;,]|\bassocie\b|\bet\b', dci_name, flags=re.IGNORECASE)
search_query = parts[0].strip()
print(f"Cleaned DCI: '{search_query}'")

# Run search
adult, pediatric = scrape_posology(search_query)
print("Result:", "Found!" if adult else "Not Found")
