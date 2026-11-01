import sys
import json
import re
import urllib.parse
import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util import Retry

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def get_session():
    session = requests.Session()
    retries = Retry(total=3, backoff_factor=0.5, status_forcelist=[500, 502, 503, 504])
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
    })
    return session

def login_vidal(session, email="doc.hafedh14@gmail.com", password="MyNewPass@2024"):
    try:
        login_init_url = "https://www.vidal.fr/login.html?redirect=https%3A%2F%2Fwww.vidal.fr%2Fmedicaments%2Findication.html"
        res_init = session.get(login_init_url, timeout=10)
        
        login_data = {
            "login[email]": email,
            "login[password]": password,
            "login[submit]": "Se connecter"
        }
        res_login = session.post(res_init.url, data=login_data, timeout=15)
        return res_login.status_code == 200
    except Exception as e:
        sys.stderr.write(f"Login error: {e}\n")
        return False

def clean_med_name(text):
    text = re.sub(r'^(?:#\s*)?(?:M[ée\?a-zA-Z]*dicament|Reco)\s*', '', text, flags=re.IGNORECASE)
    return text.strip()

def search_indications(session, query):
    encoded_query = urllib.parse.quote(query)
    url = f"https://www.vidal.fr/medicaments/indication.html?q={encoded_query}"
    
    try:
        res = session.get(url, timeout=15)
        if res.status_code != 200:
            return []
            
        soup = BeautifulSoup(res.content.decode('utf-8', 'ignore'), 'html.parser')
        
        title = soup.title.get_text() if soup.title else ""
        if "404" in title or "401" in title or "Page introuvable" in title:
            return []
            
        indications = []
        for a in soup.find_all('a'):
            href = a.get('href', '')
            t = a.get_text(strip=True)
            if 'indication-' in href and t:
                full_url = href if href.startswith('http') else "https://www.vidal.fr/" + href.lstrip('/')
                indications.append({
                    "title": t,
                    "url": full_url
                })
                
        # Deduplicate
        seen = set()
        unique = []
        for item in indications:
            key = (item['title'], item['url'])
            if key not in seen:
                seen.add(key)
                unique.append(item)
        return unique
    except Exception as e:
        sys.stderr.write(f"Search indications error: {e}\n")
        return []

def fetch_medications_for_indication(session, ind_url):
    if 'tab=list_spe' not in ind_url:
        delim = '&' if '?' in ind_url else '?'
        ind_url += f"{delim}market_statuses_not=supprimesansinfo&tab=list_spe"
        
    try:
        res = session.get(ind_url, timeout=15)
        if res.status_code != 200:
            return []
            
        soup = BeautifulSoup(res.content.decode('utf-8', 'ignore'), 'html.parser')
        
        title = soup.title.get_text() if soup.title else ""
        if "404" in title or "401" in title or "Page introuvable" in title:
            return []

        # Target main content block exclusively to avoid sidebar/footer 404 links
        main_content = (
            soup.find('div', id='search_results') or 
            soup.find('div', class_='content-results') or 
            soup.find('div', class_='results') or
            soup.find('main')
        )
        
        medications = []
        ignored_keywords = [
            'indication', 'recherche', 'substance', 'gamme', 'param', 'login',
            'auth', 'deconnexion', 'laboratoire', 'utiliser', 'par-nom', 'maladies',
            'utilisation'
        ]
        
        target_el = main_content if main_content else soup
        
        for a in target_el.find_all('a'):
            href = a.get('href', '')
            text = a.get_text(strip=True)
            if 'medicaments/' in href and '.html' in href and text:
                if not any(k in href for k in ignored_keywords):
                    name = clean_med_name(text)
                    if name and len(name) > 2 and 'Bien utiliser' not in name:
                        full_url = href if href.startswith('http') else "https://www.vidal.fr/" + href.lstrip('/')
                        medications.append({
                            "name": name,
                            "url": full_url
                        })
                    
        # Filter static sidebar fallback list if present
        fallback_sidebar_names = {"MERONEM 1 g pdre p sol inj/p perf", "MEROPENEM ARROW 1 g pdre p sol inj/p perf", "FORTUM 1 g pdre p sol inj/p perf IM IV", "MEROPENEM ACS DOBFAR 1 g pdre p sol inj/p perf", "RIFADINE 2 pour cent susp buv", "DEXAMETHASONE KRKA 4 mg ml sol inj p perf", "ROCEPHINE 1 g/10 ml pdre/solv p sol inj IV", "ISOPTINE 5 mg/2 ml sol inj"}
        
        filtered_meds = [m for m in medications if m['name'] not in fallback_sidebar_names]
        
        # Deduplicate by name
        seen = set()
        unique_meds = []
        for m in filtered_meds:
            if m['name'] not in seen:
                seen.add(m['name'])
                unique_meds.append(m)
        return unique_meds
    except Exception as e:
        sys.stderr.write(f"Fetch medications error: {e}\n")
        return []

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Query parameter missing"}))
        return
        
    query = sys.argv[1]
    target_ind_url = sys.argv[2] if len(sys.argv) > 2 else None
    
    session = get_session()
    login_vidal(session)
    
    if target_ind_url:
        meds = fetch_medications_for_indication(session, target_ind_url)
        output = {
            "status": "success",
            "type": "medications",
            "indication_url": target_ind_url,
            "medications": meds
        }
    else:
        indications = search_indications(session, query)
        meds = []
        selected_ind = None
        
        if indications:
            selected_ind = indications[0]['title']
            meds = fetch_medications_for_indication(session, indications[0]['url'])
            
        output = {
            "status": "success",
            "type": "search_result",
            "query": query,
            "selected_indication": selected_ind,
            "indications": indications,
            "medications": meds
        }
        
    print(json.dumps(output, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
