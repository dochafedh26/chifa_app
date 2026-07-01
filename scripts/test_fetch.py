from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import Select
import time

opts = Options()
opts.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
driver = webdriver.Chrome(options=opts)

driver.get("https://pnc.cnas.dz/TABIBI/prescription.xhtml")
time.sleep(5)
print("URL:", driver.current_url)

try:
    btn = driver.find_element(By.ID, "form1:btn_ident_chifa")
    print("Chercher button found - on prescription page!")
except Exception as e:
    print("NOT on prescription page:", e)
    driver.quit()
    exit()

try:
    div_token = driver.find_element(By.ID, "div_token_out")
    token_style = div_token.get_attribute("style") or ""
    is_token_red = "display: none" not in token_style
    print(f"Token indicator red: {is_token_red}")
except Exception as e:
    print(f"Token indicator error: {e}")

try:
    div_carte = driver.find_element(By.ID, "div_carte_out")
    carte_style = div_carte.get_attribute("style") or ""
    is_carte_red = "display: none" not in carte_style
    print(f"Card indicator red: {is_carte_red}")
except Exception as e:
    print(f"Card indicator error: {e}")

time.sleep(2)
for attempt in range(1, 4):
    print(f"Clicking Chercher attempt {attempt}...")
    try:
        driver.find_element(By.ID, "form1:btn_ident_chifa").click()
    except Exception as e:
        print(f"Click error: {e}")
    time.sleep(5)
    try:
        alert = driver.switch_to.alert
        print(f"Alert: {alert.text[:100]}")
        alert.accept()
        time.sleep(2)
        continue
    except:
        print("No alert - checking for beneficiaries...")
        time.sleep(3)
        break

try:
    select_el = driver.find_element(By.ID, "form1:cb_benef")
    select = Select(select_el)
    options = [opt for opt in select.options if opt.get_attribute("value") != "-1"]
    print(f"Beneficiaries found: {len(options)}")
    for opt in options:
        val = opt.get_attribute("value")
        txt = opt.text.strip()
        print(f"  - {txt} (value: {val})")
except Exception as e:
    print(f"Beneficiaries NOT loaded: {e}")

driver.quit()
