#!/usr/bin/env python3
import sys
import re
import json
import requests
import urllib.parse
import unicodedata
from bs4 import BeautifulSoup

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def normalize_text(text):
    if not text:
        return ""
    # Lowercase, remove accents
    text = text.lower()
    text = "".join(
        c for c in unicodedata.normalize('NFD', text)
        if unicodedata.category(c) != 'Mn'
    )
    # Replace non-alphanumeric chars with spaces
    text = re.sub(r'[^\w\s]', ' ', text)
    # Normalize multiple spaces
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def get_pathology_list():
    index_url = "https://www.vidal.fr/maladies/a-z.html"
    try:
        r = requests.get(index_url, headers=headers, timeout=15)
        if r.status_code != 200:
            return None, f"Failed to load Vidal index: HTTP {r.status_code}"
        
        soup = BeautifulSoup(r.content, "html.parser")
        links = soup.find_all('a', href=True)
        
        # Matches paths like: maladies/coeur-circulation-veines/avc.html
        # Avoids: maladies/a-z.html, maladies/chez-adulte.html, maladies/recommandations/...
        disease_pattern = re.compile(r"^maladies/[^/]+/[^/]+\.html$")
        
        candidates = []
        for link in links:
            href = link['href']
            # Clean href path
            match_path = href.lstrip('/')
            if disease_pattern.match(match_path):
                title = link.get_text().strip()
                if title:
                    candidates.append({
                        "title": title,
                        "href": match_path
                    })
        return candidates, None
    except Exception as e:
        return None, f"Exception during index retrieval: {str(e)}"

def search_pathology(query, candidates):
    norm_query = normalize_text(query)
    if not norm_query:
        return []
        
    results = []
    for c in candidates:
        norm_title = normalize_text(c['title'])
        score = 0
        
        if norm_title == norm_query:
            score = 100
        elif norm_title.startswith(norm_query):
            score = 80
        elif norm_query in norm_title:
            score = 60
        else:
            # Word-level overlap
            query_words = set(norm_query.split())
            title_words = set(norm_title.split())
            overlap = query_words.intersection(title_words)
            if overlap:
                score = 20 * len(overlap)
                
        if score > 0:
            results.append({
                "title": c['title'],
                "href": c['href'],
                "score": score
            })
            
    # Sort by score desc, then by title length asc (favor shorter, more specific titles)
    results.sort(key=lambda x: (-x['score'], len(x['title'])))
    return results

def extract_section_content(header):
    content = []
    sibling = header.next_sibling
    while sibling:
        if sibling.name in ['h2', 'h3', 'h4']:
            break
        if sibling.name == 'p':
            txt = sibling.get_text().strip()
            if txt:
                content.append(txt)
        elif sibling.name in ['ul', 'ol']:
            list_items = []
            for li in sibling.find_all('li'):
                li_txt = li.get_text().strip()
                if li_txt:
                    list_items.append(f"- {li_txt}")
            if list_items:
                content.append("\n".join(list_items))
        sibling = sibling.next_sibling
    return "\n\n".join(content).strip()

def classify_header(header_text, url):
    h_clean = header_text.lower()
    
    # Check skip list to ignore navigation, footer, and sources headers
    skip_keywords = ["source", "référence", "bibliographie", "santebd", "partager", "lire aussi", "commentaire", "newsletter", "publicité", "a propos"]
    if any(k in h_clean for k in skip_keywords):
        return None
        
    # Explicit section keywords
    if any(k in h_clean for k in ["symptôme", "symptome", "signe", "manifestation", "comment se manifeste", "reconnaitre", "reconnaître"]):
        return "symptomes"
    if any(k in h_clean for k in ["diagnostic", "diagnostique", "diagnostiqu", "examen", "test", "détecter", "dépister"]):
        return "diagnostic"
    if any(k in h_clean for k in ["traitement", "prise en charge", "soigner", "médicament", "chirurgie", "thérapeutique", "prévention", "que faire"]):
        return "traitements"
        
    # URL-based fallback for general headers on subpages
    url_clean = url.lower()
    if "traitements" in url_clean or "traitement" in url_clean:
        return "traitements"
    if "symptomes" in url_clean or "symptome" in url_clean:
        return "symptomes"
    if "diagnostic" in url_clean or "diagnostique" in url_clean:
        return "diagnostic"
        
    return None

def scrape_pathology_details(disease_href):
    main_url = f"https://www.vidal.fr/{disease_href}"
    
    sections = {
        "definition": [],
        "symptomes": [],
        "diagnostic": [],
        "traitements": []
    }
    raw_texts = []
    
    try:
        # 1. Fetch main page
        r = requests.get(main_url, headers=headers, timeout=15)
        if r.status_code != 200:
            return None, f"Failed to fetch pathology main page: HTTP {r.status_code}"
            
        soup = BeautifulSoup(r.content, "html.parser")
        
        # 2. Extract subpage links from the main page
        # Slug is the disease name, e.g. "avc" from "maladies/coeur-circulation-veines/avc.html"
        slug = disease_href.split('/')[-1].replace('.html', '')
        
        subpage_urls = []
        for a in soup.find_all('a', href=True):
            href = a['href']
            # Match subfolders like /avc/causes.html
            if f"/{slug}/" in href or f"{slug}/" in href:
                sub_url = urllib.parse.urljoin("https://www.vidal.fr/", href)
                if sub_url not in subpage_urls and sub_url != main_url:
                    subpage_urls.append(sub_url)
                    
        # List of pages to parse (main page first, then subpages)
        pages_to_parse = [(main_url, soup)]
        for sub_url in subpage_urls:
            try:
                sub_r = requests.get(sub_url, headers=headers, timeout=10)
                if sub_r.status_code == 200:
                    pages_to_parse.append((sub_url, BeautifulSoup(sub_r.content, "html.parser")))
            except Exception:
                pass # Continue if a subpage fails to load
                
        # 3. Parse each page
        for url, page_soup in pages_to_parse:
            # Clean page: remove menus, sidebar, footer, etc.
            for el in page_soup.find_all(['nav', 'footer', 'header', 'aside', 'form']):
                el.decompose()
            for el in page_soup.find_all(class_=lambda c: c and any(word in c.lower() for word in ['sidebar', 'footer', 'header', 'nav', 'menu', 'comments', 'share', 'social', 'breadcrumb', 'banner', 'pub', 'publicite'])):
                el.decompose()
                
            # Accumulate raw text from the cleaned page for AI extraction
            page_raw_content = []
            h1 = page_soup.find('h1')
            if h1:
                title_txt = h1.get_text().strip()
                if title_txt:
                    page_raw_content.append(f"# {title_txt}\n")
            
            for el in page_soup.find_all(['h2', 'h3', 'h4', 'p', 'ul', 'ol']):
                if el.name in ['h2', 'h3', 'h4']:
                    header_txt = el.get_text().strip()
                    if header_txt:
                        page_raw_content.append(f"\n## {header_txt}\n")
                elif el.name == 'p':
                    p_txt = el.get_text().strip()
                    if p_txt:
                        page_raw_content.append(p_txt)
                elif el.name in ['ul', 'ol']:
                    list_items = []
                    for li in el.find_all('li'):
                        li_txt = li.get_text().strip()
                        if li_txt:
                            list_items.append(f"- {li_txt}")
                    if list_items:
                        page_raw_content.append("\n".join(list_items))
            
            if page_raw_content:
                raw_texts.append(f"=== Source: {url} ===\n" + "\n\n".join(page_raw_content))
                
            # Extract introduction (all paragraphs before the first h2/h3 header)
            first_header = page_soup.find(['h2', 'h3'])
            intro_elements = []
            if first_header:
                curr = first_header.previous_sibling
                while curr:
                    if curr.name in ['p', 'ul', 'ol']:
                        intro_elements.insert(0, curr)
                    curr = curr.previous_sibling
            else:
                intro_elements = page_soup.find_all(['p', 'ul', 'ol'])
                
            intro_content = []
            for el in intro_elements:
                if el.name == 'p':
                    txt = el.get_text().strip()
                    if txt:
                        intro_content.append(txt)
                elif el.name in ['ul', 'ol']:
                    list_items = [f"- {li.get_text().strip()}" for li in el.find_all('li') if li.get_text().strip()]
                    if list_items:
                        intro_content.append("\n".join(list_items))
                        
            intro_text = "\n\n".join(intro_content).strip()
            
            # Map introduction to correct section
            if intro_text:
                url_clean = url.lower()
                is_subpage = any(word in url_clean for word in ["traitements", "traitement", "symptomes", "symptome", "diagnostic", "diagnostique", "causes", "cause"])
                if not is_subpage:
                    sections["definition"].append(intro_text)
                else:
                    if "traitements" in url_clean or "traitement" in url_clean:
                        sections["traitements"].append(intro_text)
                    elif "symptomes" in url_clean or "symptome" in url_clean:
                        sections["symptomes"].append(intro_text)
                    elif "diagnostic" in url_clean or "diagnostique" in url_clean:
                        sections["diagnostic"].append(intro_text)
                        
            # Parse headings and sections
            for h in page_soup.find_all(['h2', 'h3']):
                h_text = h.get_text().strip()
                sec_type = classify_header(h_text, url)
                if sec_type:
                    sec_content = extract_section_content(h)
                    if sec_content:
                        combined_content = f"### {h_text}\n\n{sec_content}"
                        sections[sec_type].append(combined_content)
                        
        # 4. Consolidate results
        response = {
            "status": "success",
            "url": main_url,
            "raw_content": "\n\n".join(raw_texts).strip(),
            "definition": "\n\n".join(sections["definition"]).strip(),
            "symptomes": "\n\n".join(sections["symptomes"]).strip(),
            "diagnostic": "\n\n".join(sections["diagnostic"]).strip(),
            "traitements": "\n\n".join(sections["traitements"]).strip()
        }
        return response, None
        
    except Exception as e:
        return None, f"Exception during scraping: {str(e)}"

def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Usage: python scrape_pathology.py <pathology_name>"}))
        return

    query = sys.argv[1]
    
    # 1. Fetch index and candidates
    candidates, err = get_pathology_list()
    if err:
        print(json.dumps({"status": "error", "message": err}))
        return
        
    # 2. Search candidates matching the query
    matches = search_pathology(query, candidates)
    if not matches:
        print(json.dumps({
            "status": "error", 
            "message": f"No matching pathology found for query: '{query}'"
        }))
        return
        
    # Top match
    best_match = matches[0]
    
    # 3. Scrape details
    data, err = scrape_pathology_details(best_match['href'])
    if err:
        print(json.dumps({"status": "error", "message": err}))
        return
        
    # 4. Attach suggestions
    suggestions = [m['title'] for m in matches[1:6]]
    data["matched_pathology"] = best_match['title']
    data["suggestions"] = suggestions
    
    # Output the result as formatted JSON to stdout
    print(json.dumps(data, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
