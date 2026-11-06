import os
import subprocess
import time
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_AUTO_PROFILE = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\AutomationProfile")

subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"], capture_output=True)
time.sleep(2)

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
time.sleep(3)

print("URL:", driver.current_url)

wait = WebDriverWait(driver, 10)
user = wait.until(EC.presence_of_element_located((By.ID, "form1:username")))
pwd = driver.find_element(By.ID, "form1:password")
btn = driver.find_element(By.ID, "form1:btn_login")

print("Username pre-filled:", repr(user.get_attribute("value")))
print("Password pre-filled:", repr(pwd.get_attribute("value")))

user.clear()
user.send_keys("herhourm")
pwd.clear()
pwd.send_keys(os.getenv("CNAS_PASS", ""))
btn.click()
time.sleep(6)

print("URL after login:", driver.current_url)

try:
    err = driver.find_element(By.CLASS_NAME, "ui-dialog-content")
    print("Dialog:", err.text[:200])
except:
    pass

try:
    msgs = driver.find_elements(By.CLASS_NAME, "ui-messages-error")
    for m in msgs:
        print("Error msg:", m.text[:200])
except:
    pass

try:
    driver.find_element(By.ID, "form1:username")
    print("Still on login page - login FAILED")
except:
    print("Login form NOT found - login SUCCEEDED")

driver.quit()
