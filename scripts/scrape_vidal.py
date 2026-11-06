import sys
import re
import json
import requests
from bs4 import BeautifulSoup
import pymysql

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

def split_posology(text):
    text = text.strip()
    if not text:
        return "", ""
    
    # Try to find split point for "Enfant"
    lines = text.split('\n')
    split_idx = -1
    for idx, line in enumerate(lines):
        clean_line = line.strip().lower()
        if (clean_line.startswith("enfant") or clean_line.startswith("nourrisson") or "enfant :" in clean_line or "nourrisson :" in clean_line) and "adulte et" not in clean_line:
            split_idx = idx
            break
            
    if split_idx != -1:
        adult = "\n".join(lines[:split_idx]).strip()
        pediatric = "\n".join(lines[split_idx:]).strip()
        if not adult:
            adult = text
        return adult, pediatric
    else:
        # Fallback: check if we can split by sentence
        sentences = re.split(r'(?<=[.!?])\s+', text)
        split_s_idx = -1
        for idx, s in enumerate(sentences):
            clean_s = s.strip().lower()
            if (clean_s.startswith("enfant") or clean_s.startswith("nourrisson") or "enfant :" in clean_s or "nourrisson :" in clean_s) and "adulte et" not in clean_s:
                split_s_idx = idx
                break
        if split_s_idx != -1:
            adult = " ".join(sentences[:split_s_idx]).strip()
            pediatric = " ".join(sentences[split_s_idx:]).strip()
            if not adult:
                adult = text
            return adult, pediatric

    return text, text

def extract_formula(text):
    if not text:
        return None
    # Look for patterns like "50 à 100 mg par kg", "50-100 mg/kg", "60 mg par kg", etc.
    # Pattern 1: A à/ou/- B mg par kg / mg/kg
    pat1 = re.search(r'(\d+)\s*(?:-|à|ou)\s*(\d+)\s*(?:mg par kg|mg/kg|mg\s*/\s*kg)', text, re.IGNORECASE)
    if pat1:
        return f"{pat1.group(1)}-{pat1.group(2)}mg/kg"
    # Pattern 2: A mg par kg / mg/kg
    pat2 = re.search(r'(\d+)\s*(?:mg par kg|mg/kg|mg\s*/\s*kg)', text, re.IGNORECASE)
    if pat2:
        return f"{pat2.group(1)}mg/kg"
    return None

def scrape_posology(medic_name):
    brand = clean_medic_name(medic_name)
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
    
    try:
        r = requests.get(index_url, headers=headers, timeout=10)
        if r.status_code != 200:
            return None, None
            
        soup = BeautifulSoup(r.content, "html.parser")
        links = soup.find_all('a')
        
        target = brand.lower()
        candidate_hrefs = []
        
        # 1. Exact match
        for link in links:
            href = link.get('href')
            if href and ('gammes/' in href or 'gamme' in href) and 'liste-' not in href:
                text = link.get_text().strip().lower()
                if len(text) > 1 and text == target:
                    if href not in candidate_hrefs:
                        candidate_hrefs.append(href)
                        
        # 2. Starts with/prefix match
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
            
        print(f"Candidate URLs found: {candidate_hrefs}", file=sys.stderr)
        
        # Iterate over candidates until we find one with posology sections
        for href in candidate_hrefs:
            detail_url = href
            if not detail_url.startswith('http'):
                detail_url = "https://www.vidal.fr/" + detail_url.lstrip('/')
                
            print(f"Trying detail URL: {detail_url}", file=sys.stderr)
            try:
                rd = requests.get(detail_url, headers=headers, timeout=10)
                if rd.status_code != 200:
                    continue
                    
                dsoup = BeautifulSoup(rd.content, "html.parser")
                
                # Find posology headers
                poso_headers = dsoup.find_all(lambda tag: tag.name in ['h2', 'h3', 'h4'] and 'posologie' in tag.get_text().lower())
                
                if not poso_headers:
                    print(f"No posology headers on {detail_url}, trying next candidate...", file=sys.stderr)
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
                if not full_poso_text:
                    continue
                    
                adult, pediatric = split_posology(full_poso_text)
                print(f"Successfully scraped posology from {detail_url}!", file=sys.stderr)
                return adult, pediatric
            except Exception as e:
                print(f"Exception while scraping {detail_url}: {e}", file=sys.stderr)
                continue
                
        return None, None
        
    except Exception as e:
        print(f"Exception: {e}", file=sys.stderr)
        return None, None

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Missing medication name or ID"}))
        return

    input_param = sys.argv[1]
    
    # Connect to MySQL (chifa_app specific DB settings)
    try:
        connection = pymysql.connect(
            host='127.0.0.1',
            user='chiffa',
            password=os.getenv('LOCAL_DB_PASSWORD', ''),
            database='clinic',
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"Database connection error: {str(e)}"}))
        return

    try:
        medic_name = None
        medic_id = None
        dci_name = None
        
        # Determine if input_param is ID or Name
        if input_param.isdigit():
            medic_id = int(input_param)
            with connection.cursor() as cursor:
                cursor.execute("SELECT id, name, dci, posologie_adulte, posologie_pediatrique, posologie FROM medalgeriemedics WHERE id = %s", (medic_id,))
                row = cursor.fetchone()
                if row:
                    medic_name = row['name']
                    dci_name = row['dci']
                    # If already has posology, return it immediately
                    if row['posologie_adulte'] and row['posologie_pediatrique']:
                        print(json.dumps({
                            "status": "success",
                            "posologie_adulte": row['posologie_adulte'],
                            "posologie_pediatrique": row['posologie_pediatrique'],
                            "posologie": row['posologie']
                        }))
                        return
        else:
            medic_name = input_param
            # Try to find it in DB by exact or partial name
            with connection.cursor() as cursor:
                cursor.execute("SELECT id, name, dci, posologie_adulte, posologie_pediatrique, posologie FROM medalgeriemedics WHERE name = %s OR name LIKE %s LIMIT 1", (medic_name, f"%{medic_name}%"))
                row = cursor.fetchone()
                if row:
                    medic_id = row['id']
                    medic_name = row['name']
                    dci_name = row['dci']
                    if row['posologie_adulte'] and row['posologie_pediatrique']:
                        print(json.dumps({
                            "status": "success",
                            "posologie_adulte": row['posologie_adulte'],
                            "posologie_pediatrique": row['posologie_pediatrique'],
                            "posologie": row['posologie']
                        }))
                        return
        
        if not medic_name:
            print(json.dumps({"status": "error", "message": "Medication not found in database"}))
            return

        # Search Vidal by DCI only
        search_query = None
        if dci_name:
            # First, check if "exprime en" is in DCI to isolate the base molecule
            if 'exprime en' in dci_name.lower():
                dci_name = dci_name.lower().split('exprime en')[1].strip()
            # Clean DCI name: split by + or / or ; or , or " associe " or " et " to get the first molecule
            # Do NOT split by spaces because multi-word molecules exist (e.g., "acide clavulanique")
            parts = re.split(r'[+/;,]|\bassocie\b|\bet\b', dci_name, flags=re.IGNORECASE)
            dci_first = parts[0].strip()
            # Strip common salt/form/formulation suffixes at the end of the DCI words
            salts = r'\b(fumarate|benzoate|trihydrate|sodique|potassique|chlorhydrate|phosphate|maleate|sulfate|mesilate|tartrate|calcique|zinc|magnesique|bromhydrate|acetate|citrate|gluconate|lactate|carbonate|halde|dihydrate|monohydrate|hemihydrate|pentahydrate|base|valerate|propionate|dipropionate|butyrate|acetonide|hexanicotinate|sodium|potassium|calcium|magnesium|de|d\')\b'
            search_query = re.sub(salts, '', dci_first, flags=re.IGNORECASE).strip()
            search_query = re.sub(r'\s+', ' ', search_query)
        else:
            # Fallback to brand name only if DCI is missing in the database
            search_query = medic_name

        if search_query:
            print(f"Searching Vidal by DCI: '{search_query}'", file=sys.stderr)
            adult_poso, pediatric_poso = scrape_posology(search_query)
        else:
            adult_poso, pediatric_poso = None, None
        
        if adult_poso and pediatric_poso:
            # Try to extract a weight-based formula from the pediatric text
            extracted_poso = extract_formula(pediatric_poso)
            
            # Update database
            with connection.cursor() as cursor:
                if medic_id:
                    if extracted_poso:
                        cursor.execute("""
                            UPDATE medalgeriemedics 
                            SET posologie_adulte = %s, posologie_pediatrique = %s, posologie = %s 
                            WHERE id = %s
                        """, (adult_poso, pediatric_poso, extracted_poso, medic_id))
                    else:
                        cursor.execute("""
                            UPDATE medalgeriemedics 
                            SET posologie_adulte = %s, posologie_pediatrique = %s 
                            WHERE id = %s
                        """, (adult_poso, pediatric_poso, medic_id))
                else:
                    if extracted_poso:
                        cursor.execute("""
                            UPDATE medalgeriemedics 
                            SET posologie_adulte = %s, posologie_pediatrique = %s, posologie = %s 
                            WHERE name = %s
                        """, (adult_poso, pediatric_poso, extracted_poso, medic_name))
                    else:
                        cursor.execute("""
                            UPDATE medalgeriemedics 
                            SET posologie_adulte = %s, posologie_pediatrique = %s 
                            WHERE name = %s
                        """, (adult_poso, pediatric_poso, medic_name))
                connection.commit()
                
            print(json.dumps({
                "status": "success",
                "posologie_adulte": adult_poso,
                "posologie_pediatrique": pediatric_poso,
                "posologie": extracted_poso
            }))
        else:
            print(json.dumps({"status": "error", "message": f"Failed to retrieve posology from Vidal by DCI '{search_query}' for '{medic_name}' (DCI: '{dci_name}')"}))
            
    finally:
        connection.close()

if __name__ == "__main__":
    main()
