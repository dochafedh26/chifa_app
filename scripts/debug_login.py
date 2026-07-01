from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

opts = Options()
opts.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
driver = webdriver.Chrome(options=opts)

print("Current URL:", driver.current_url)

try:
    user = driver.find_element(By.ID, "form1:username")
    print('form1:username found, value:', repr(user.get_attribute("value")))
except Exception as e:
    print("form1:username NOT found:", e)

try:
    pwd = driver.find_element(By.ID, "form1:password")
    print("form1:password found, value:", repr(pwd.get_attribute("value")))
except Exception as e:
    print("form1:password NOT found:", e)

try:
    btn = driver.find_element(By.ID, "form1:btn_login")
    print("form1:btn_login found")
except Exception as e:
    print("form1:btn_login NOT found:", e)

print()
print("Page title:", driver.title)

forms = driver.find_elements(By.TAG_NAME, "form")
print(f"Found {len(forms)} forms")
for i, f in enumerate(forms):
    fid = f.get_attribute("id")
    act = f.get_attribute("action")
    print(f"  Form {i}: id={fid}, action={act}")

# Check all input elements
inputs = driver.find_elements(By.TAG_NAME, "input")
print(f"\nFound {len(inputs)} inputs")
for inp in inputs:
    iid = inp.get_attribute("id")
    itype = inp.get_attribute("type")
    iname = inp.get_attribute("name")
    ival = inp.get_attribute("value")
    if iid:
        print(f"  Input: id={iid}, type={itype}, name={iname}, value={repr(ival)}")

driver.quit()
