import os
import sys
import time
import json
import argparse
import subprocess
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC

# Set UTF-8 encoding for stdout/stderr to avoid print crashes on Windows
try:
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
except AttributeError:
    pass

REMOTE_DEBUG_PORT = 9222
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
# Using AutomationProfile instead of the main User Data profile to ensure debugging opens successfully
CHROME_PROFILE = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\AutomationProfile")

def is_chrome_debugging_open():
    try:
        r = requests.get(f"http://127.0.0.1:{REMOTE_DEBUG_PORT}/json/version", timeout=0.5)
        if r.status_code == 200:
            return True
    except Exception:
        pass
    return False

def launch_chrome():
    os.makedirs(CHROME_PROFILE, exist_ok=True)
    args = [
        CHROME_EXE,
        f"--remote-debugging-port={REMOTE_DEBUG_PORT}",
        f"--user-data-dir={CHROME_PROFILE}",
        "--no-first-run",
        "--no-default-browser-check",
        "https://pnc.cnas.dz/TABIBI/index.xhtml",
    ]
    subprocess.Popen(args)
    for _ in range(20):
        time.sleep(1)
        if is_chrome_debugging_open():
            return
    raise Exception("Chrome did not start within 20s")

def get_driver():
    if not is_chrome_debugging_open():
        launch_chrome()
    opts = Options()
    opts.add_experimental_option("debuggerAddress", f"127.0.0.1:{REMOTE_DEBUG_PORT}")
    driver = webdriver.Chrome(options=opts)
    return driver

def login(driver):
    driver.get("https://pnc.cnas.dz/TABIBI/index.xhtml")
    
    # Check if we are already logged in (no username field)
    try:
        username = driver.find_element(By.ID, "form1:username")
    except Exception:
        # Already logged in or on dashboard page
        return

    wait = WebDriverWait(driver, 15)
    username = wait.until(EC.presence_of_element_located((By.ID, "form1:username")))
    password = driver.find_element(By.ID, "form1:password")
    button = driver.find_element(By.ID, "form1:btn_login")
    
    username.clear()
    username.send_keys(os.getenv("CNAS_USER", ""))
    password.clear()
    password.send_keys(os.getenv("CNAS_PASS", ""))
    button.click()
    time.sleep(5)

def search_patient(driver, assurance):
    # Navigate to prescription page
    driver.get("https://pnc.cnas.dz/TABIBI/prescription.xhtml")
    time.sleep(5)
    
    # Dismiss any initial alert (e.g. card reader connection warnings)
    try:
        alert = driver.switch_to.alert
        alert.accept()
        time.sleep(2)
    except Exception:
        pass

    # Perform Search
    if assurance:
        # Distance Search
        assure_num_field = driver.find_element(By.ID, "form1:input_assure_num")
        assure_num_field.clear()
        assure_num_field.send_keys(assurance)
        
        # Click remote/distance search button
        driver.execute_script("document.getElementById('form1:btn_ident_distance').click();")
    else:
        # Local physical card search
        try:
            div_token_in = driver.find_element(By.ID, "div_token_in")
            token_in_style = div_token_in.get_attribute("style") or ""
            is_token_green = "display: none" not in token_in_style
            
            div_carte_in = driver.find_element(By.ID, "div_carte_in")
            carte_in_style = div_carte_in.get_attribute("style") or ""
            is_carte_green = "display: none" not in carte_in_style
            
            if not is_token_green or not is_carte_green:
                raise Exception("Le lecteur de carte CHIFA ou la carte n'est pas détecté(e) (indicateurs au rouge). Veuillez renseigner le numéro d'assurance du patient dans son dossier pour effectuer une recherche à distance.")
        except Exception as e:
            if "indicateurs au rouge" in str(e):
                raise e
            pass

        driver.find_element(By.ID, "form1:btn_ident_chifa").click()
        
    time.sleep(8)
    
    # Dismiss any alerts generated during search
    try:
        alert = driver.switch_to.alert
        alert_text = alert.text
        alert.accept()
        time.sleep(2)
        if "valide" in alert_text.lower() or "erreur" in alert_text.lower() or "invalide" in alert_text.lower() or "aucun" in alert_text.lower():
            raise Exception(f"Erreur de recherche CNAS: {alert_text}")
    except Exception as e:
        if "Erreur de recherche CNAS" in str(e) or "indicateurs au rouge" in str(e):
            raise e
        pass

    # Check for on-page error messages
    try:
        error_elements = driver.find_elements(By.CLASS_NAME, "ui-messages-error")
        for el in error_elements:
            txt = el.text.strip()
            if txt:
                raise Exception(f"Erreur CNAS: {txt}")
    except Exception as e:
        if "Erreur CNAS" in str(e):
            raise e
        pass

def mode_fetch(driver, assurance):
    search_patient(driver, assurance)
    
    # Wait for beneficiaries dropdown to load options
    select_el = None
    for _ in range(15):
        try:
            select_el = driver.find_element(By.ID, "form1:cb_benef")
            select = Select(select_el)
            # Ensure options are populated (more than just the default select one)
            options = [opt for opt in select.options if opt.get_attribute("value") != "-1"]
            if len(options) > 0:
                break
        except Exception:
            pass
        time.sleep(1)

    if not select_el:
        raise Exception("Beneficiary dropdown did not load options.")

    select = Select(select_el)
    raw_options = [opt for opt in select.options if opt.get_attribute("value") != "-1"]
    
    beneficiaries = []
    for opt in raw_options:
        opt_val = opt.get_attribute("value")
        opt_text = opt.text.strip()
        
        # Select the beneficiary and trigger change event to fetch rights details (DFD)
        driver.execute_script("""
        var selectEl = document.getElementById('form1:cb_benef');
        selectEl.value = arguments[0];
        var event = new Event('change', { bubbles: true });
        selectEl.dispatchEvent(event);
        """, opt_val)
        
        time.sleep(4) # Wait for AJAX response
        
        # Check if selecting this beneficiary triggered an alert
        status = "valid"
        dfd = ""
        try:
            alert = driver.switch_to.alert
            alert_text = alert.text
            alert.accept()
            time.sleep(1)
            
            # Analyze alert message for rights status
            if "expire" in alert_text.lower() or "droit" in alert_text.lower():
                status = "expired"
            elif "deja" in alert_text.lower() or "déjà" in alert_text.lower():
                status = "already_consulted"
            else:
                status = "invalid"
        except Exception:
            pass
            
        # Get Date Fin Droit
        if status == "valid":
            try:
                dfd_el = driver.find_element(By.ID, "form1:input_benef_dfd")
                dfd = dfd_el.get_attribute("value") or ""
            except Exception:
                pass
                
        beneficiaries.append({
            "value": opt_val,
            "text": opt_text,
            "dfd": dfd,
            "status": status
        })
        
    print(json.dumps({"status": "success", "beneficiaries": beneficiaries}))

def mode_prescribe(driver, assurance, beneficiary_value, medicines):
    search_patient(driver, assurance)
    
    # Select beneficiary
    driver.execute_script("""
    var selectEl = document.getElementById('form1:cb_benef');
    selectEl.value = arguments[0];
    var event = new Event('change', { bubbles: true });
    selectEl.dispatchEvent(event);
    """, beneficiary_value)
    
    time.sleep(5)
    
    # Accept rights warnings or already consulted alerts if any
    try:
        alert = driver.switch_to.alert
        alert.accept()
        time.sleep(2)
    except Exception:
        pass

    # Add each medicine
    for med in medicines:
        # Enter medicine name in autocomplete input
        medic_input = driver.find_element(By.ID, "form1:cb_medic_input")
        medic_input.clear()
        medic_input.send_keys(med)
        time.sleep(5) # Wait for suggestions
        
        # Find suggestions list
        suggestions = driver.find_elements(By.CLASS_NAME, "ui-autocomplete-item")
        if not suggestions:
            raise Exception(f"Medicine suggestions not found for: '{med}'")
            
        # Select exact suggestion match or fallback to the first
        selected = False
        for sug in suggestions:
            if med.lower() in sug.text.lower():
                sug.click()
                selected = True
                break
        if not selected:
            suggestions[0].click()
            
        time.sleep(3)
        
        # Fill posology defaults
        driver.find_element(By.ID, "form1:input_compoenent_posologie_nb_unite_str").send_keys("1")
        Select(driver.find_element(By.ID, "form1:cb_compoenent_posologie_unite")).select_by_value("7") # Comprime
        driver.find_element(By.ID, "form1:input_compoenent_posologie_nb_fois").send_keys("3")
        Select(driver.find_element(By.ID, "form1:cb_compoenent_posologie_periodicite")).select_by_value("0") # Par jour
        
        qte_field = driver.find_element(By.ID, "form1:input_ord_qte")
        qte_field.clear()
        qte_field.send_keys("1")
        
        # Click Valider line
        driver.find_element(By.ID, "form1:btn_valider_ligne").click()
        time.sleep(6)
        
        # Check for any alerts after adding the line (e.g. non authorized medicine)
        try:
            alert = driver.switch_to.alert
            alert_text = alert.text
            alert.accept()
            if "non autorisé" in alert_text.lower() or "erreur" in alert_text.lower():
                raise Exception(f"Validation error for {med}: {alert_text}")
        except Exception as ex:
            if "Validation error" in str(ex):
                raise ex

    # Submit/Register Prescription
    driver.find_element(By.ID, "form1:btn_valider_ord").click()
    time.sleep(4)
    
    # Confirm "Oui" on save dialog
    try:
        yes_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//div[contains(@class, 'ui-dialog') and .//span[contains(text(), 'enregistrer cette ordonnance')]]//input[@value='Oui']"))
        )
        yes_btn.click()
    except Exception:
        driver.execute_script("document.getElementById('form1:j_idt142').click();")
    time.sleep(8)
    
    # Accept final success alert
    try:
        alert = driver.switch_to.alert
        alert.accept()
        time.sleep(2)
    except Exception:
        pass

    # Reject "Non" on printing prompt dialog
    try:
        no_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//div[contains(@class, 'ui-dialog') and .//span[contains(text(), 'enregistrée avec succès')]]//input[@value='Non']"))
        )
        no_btn.click()
    except Exception:
        driver.execute_script("document.getElementById('form1:j_idt151').click();")
    time.sleep(4)
    
    print(json.dumps({"status": "success"}))

def main():
    parser = argparse.ArgumentParser(description="CNAS Prescription Automation Flow")
    parser.add_argument("--mode", required=True, choices=["fetch", "prescribe"], help="Flow execution mode")
    parser.add_argument("--assurance", default="", help="National assurance ID")
    parser.add_argument("--beneficiary", default="0", help="Beneficiary dropdown option value")
    parser.add_argument("--medicines", default="[]", help="JSON array of medicine names")
    
    # Temporary fallback if script run without arguments (for manual/backward compatibility testing)
    args = parser.parse_args()
    
    driver = None
    try:
        driver = get_driver()
        login(driver)
        
        if args.mode == "fetch":
            mode_fetch(driver, args.assurance)
        elif args.mode == "prescribe":
            try:
                meds_list = json.loads(args.medicines)
            except Exception:
                raise Exception("Invalid medicines JSON list provided.")
            mode_prescribe(driver, args.assurance, args.beneficiary, meds_list)
            
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}))
        sys.exit(1)
    finally:
        if driver:
            try:
                driver.quit()
            except Exception:
                pass

if __name__ == "__main__":
    main()
