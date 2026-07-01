import os
import subprocess
import time
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_AUTO_PROFILE = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\AutomationProfile")

subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"], capture_output=True)
time.sleep(2)

os.makedirs(CHROME_AUTO_PROFILE, exist_ok=True)
args = [
    CHROME_EXE,
    "--remote-debugging-port=9222",
    f"--user-data-dir={CHROME_AUTO_PROFILE}",
    "--no-first-run",
    "--no-default-browser-check",
    "https://pnc.cnas.dz/TABIBI/accueil.xhtml",
]
subprocess.Popen(args)

for _ in range(30):
    try:
        r = requests.get("http://127.0.0.1:9222/json/version", timeout=2)
        if r.status_code == 200:
            break
    except:
        pass
    time.sleep(1)

opts = Options()
opts.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
driver = webdriver.Chrome(options=opts)
time.sleep(4)

print("1. URL:", driver.current_url)
print("2. Page title:", driver.title)

# Get all form elements
forms = driver.find_elements(By.TAG_NAME, "form")
print(f"3. Forms found: {len(forms)}")
for f in forms:
    fid = f.get_attribute("id")
    print(f"   Form id={fid}")

# Get all inputs
inputs = driver.find_elements(By.TAG_NAME, "input")
print(f"4. Inputs found: {len(inputs)}")
for inp in inputs:
    iid = inp.get_attribute("id")
    itype = inp.get_attribute("type")
    if iid:
        print(f"   Input: id={iid}, type={itype}")

# Get page text (first 1000 chars)
body = driver.find_element(By.TAG_NAME, "body")
print(f"5. Body text (first 500): {body.text[:500]}")

driver.quit()
