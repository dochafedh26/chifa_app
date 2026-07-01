from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

opts = Options()
opts.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
driver = webdriver.Chrome(options=opts)

# Go to login page
driver.get("https://pnc.cnas.dz/TABIBI/accueil.xhtml")
time.sleep(4)
print("URL:", driver.current_url)

# Fill credentials
wait = WebDriverWait(driver, 10)
user = wait.until(EC.presence_of_element_located((By.ID, "form1:username")))
pwd = driver.find_element(By.ID, "form1:password")
otp = driver.find_element(By.ID, "form1:userotp")
btn = driver.find_element(By.ID, "form1:btn_login")

user.clear()
user.send_keys("herhourm")
pwd.clear()
pwd.send_keys("Cnas26med@+")
btn.click()
time.sleep(5)

print("After login URL:", driver.current_url)

# Check for error messages
body = driver.find_element(By.TAG_NAME, "body")
page_html = body.get_attribute("innerHTML")

# Look for error dialog
import re
errors = re.findall(r'(?:Erreur|erreur|alert).*?</div>', page_html, re.IGNORECASE | re.DOTALL)
for e in errors:
    print("Error element:", e[:200])

# Check all divs with class containing error/alert
err_divs = driver.find_elements(By.XPATH, "//*[contains(@class, 'error') or contains(@class, 'alert') or contains(@class, 'Erreur')]")
for d in err_divs:
    print(f"Error div: {d.text[:200]}")

# Look for the dialog text
dialogs = driver.find_elements(By.CLASS_NAME, "ui-dialog-content")
for d in dialogs:
    print(f"Dialog: {d.text[:300]}")

alerts = driver.find_elements(By.CLASS_NAME, "ui-messages-error")
for a in alerts:
    print(f"Alert message: {a.text[:300]}")

driver.quit()
