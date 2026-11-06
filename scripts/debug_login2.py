from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
import time

opts = Options()
opts.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
driver = webdriver.Chrome(options=opts)

print("1. Current URL:", driver.current_url)

# Navigate to login
driver.get("https://pnc.cnas.dz/TABIBI/accueil.xhtml")
time.sleep(3)
print("2. After navigation:", driver.current_url)

# Fill login
wait = WebDriverWait(driver, 10)
user = wait.until(EC.presence_of_element_located((By.ID, "form1:username")))
pwd = driver.find_element(By.ID, "form1:password")
otp = driver.find_element(By.ID, "form1:userotp")
btn = driver.find_element(By.ID, "form1:btn_login")

print(f"3. Username value before: '{user.get_attribute('value')}'")
print(f"   OTP value before: '{otp.get_attribute('value')}'")

user.clear()
user.send_keys("herhourm")
pwd.clear()
pwd.send_keys(os.getenv("CNAS_PASS", ""))

print("4. Filled credentials, clicking login...")
btn.click()
time.sleep(5)

print("5. After login click URL:", driver.current_url)

# Check page content for error
page_text = driver.find_element(By.TAG_NAME, "body").text[:500]
print(f"6. Page text: {page_text}")

# Check if login fields still visible
try:
    user2 = driver.find_element(By.ID, "form1:username")
    print(f"7. Login form still visible, username value: '{user2.get_attribute('value')}'")
except:
    print("7. Login form NOT visible - login succeeded!")

driver.quit()
