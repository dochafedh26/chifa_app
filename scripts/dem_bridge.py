#!/usr/bin/env python3
"""
DEM Bridge - Fetches patient data from DEM system for duty reports
Usage: python dem_bridge.py <command> [args]
Commands:
  login           - Login to DEM system
  get-patients    - Get patients in a service
  get-observation - Get latest observation for a patient
  get-lab-results - Get lab results for a patient
  full-report     - Get full duty report data for a service
  create-observation <patient_id> <remark> - Create observation in DEM
  export-duty-report - Export duty report to DEM (reads JSON from stdin)
"""

import sys
import json
import subprocess
import os
import re
import html
from datetime import datetime

import tempfile
DEM_URL = "http://192.168.1.13"
DEM_COOKIE_FILE = os.path.join(tempfile.gettempdir(), "dem_session.txt")

CREDENTIALS = {
    "user": "hafedh14",
    "password": "1986"
}

def run_curl(args):
    """Run curl command and return output"""
    cmd = ["curl", "-s", "-b", DEM_COOKIE_FILE, "-c", DEM_COOKIE_FILE] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout

def dem_login(quiet=False):
    """Login to DEM system"""
    cmd = [
        "curl", "-s", "-c", DEM_COOKIE_FILE,
        "-X", "POST", f"{DEM_URL}/login/verif",
        "-d", f"user={CREDENTIALS['user']}&password={CREDENTIALS['password']}"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if "Bienvenue" in result.stdout:
        if not quiet:
            print(json.dumps({"status": "success", "message": "Logged in to DEM"}))
        return True
    else:
        if not quiet:
            print(json.dumps({"status": "error", "message": "Login failed"}))
        return False

def get_service_patients(service_id="125", quiet=False):
    """Get patients in a specific service"""
    if not os.path.exists(DEM_COOKIE_FILE):
        dem_login(quiet=True)
    
    output = run_curl([f"{DEM_URL}/service/lits/service/{service_id}"])
    
    patients = []
    pattern1 = r'patient/resume/(\d+).*?<span>([^<]+)</span>'
    matches1 = re.findall(pattern1, output, re.DOTALL)
    
    for patient_id, name in matches1:
        patients.append({
            "id": patient_id,
            "name": name.strip()
        })
    
    seen = set()
    unique_patients = []
    for p in patients:
        if p['id'] not in seen:
            seen.add(p['id'])
            unique_patients.append(p)
    
    if not quiet:
        print(json.dumps({"status": "success", "patients": unique_patients}))
    return unique_patients

def extract_dob_from_html(html_text):
    """Extract DOB and age from HTML content.
    Expected formats:
      - 'Né le 1966-01-01  ( 60 ) ans'
      - 'N&eacute; le 1966-01-01  ( 60 ) ans'
      - 'Date de naissance: 1966-01-01'
      - '60 ans' (age only)
    Returns (dob_string, age) or (None, None)
    """
    decoded = html.unescape(html_text)
    
    # Pattern 1: 'Né le YYYY-MM-DD ( XX ) ans'
    dob_pattern = r'N[eé]\s+le\s+(\d{4}-\d{2}-\d{2})\s*[\(\[]?\s*(\d+)\s*[\)\]]?\s*ans'
    match = re.search(dob_pattern, decoded, re.IGNORECASE)
    if match:
        dob_str = match.group(1).strip()
        age = int(match.group(2))
        if dob_str != "0000-00-00":
            return dob_str, age
        else:
            return None, age
    
    # Pattern 2: 'Date de naissance: YYYY-MM-DD'
    dob_pattern2 = r'[Dd]ate\s+de\s+naissance[:\s]+(\d{4}-\d{2}-\d{2})'
    match2 = re.search(dob_pattern2, decoded, re.IGNORECASE)
    if match2:
        dob_str = match2.group(1).strip()
        if dob_str != "0000-00-00":
            # Calculate age from DOB
            try:
                dob_date = datetime.strptime(dob_str, "%Y-%m-%d")
                age = (datetime.now() - dob_date).days // 365
                return dob_str, age
            except:
                return dob_str, 0
    
    # Pattern 3: 'XX ans' standalone (age only, typically in a span)
    age_pattern = r'[\(\[]\s*(\d{1,3})\s*[\)\]]\s*ans\b'
    match3 = re.search(age_pattern, decoded)
    if match3:
        age = int(match3.group(1))
        if 0 < age < 120:
            return None, age
    
    # Pattern 4: 'agé de XX ans' or 'âge XX ans'
    age_pattern2 = r'(?:ag[eé]|âge)\s+(?:de\s+)?(\d{1,3})\s*ans'
    match4 = re.search(age_pattern2, decoded, re.IGNORECASE)
    if match4:
        age = int(match4.group(1))
        if 0 < age < 120:
            return None, age
    
    return None, None

def calculate_dob_from_age(age):
    """Calculate approximate DOB from age (assumes Jan 1st of that year)."""
    current_year = datetime.now().year
    birth_year = current_year - age
    return f"{birth_year}-01-01"

def extract_age_from_observations(observations):
    """Extract age from observation text.
    Looks for patterns like '72 ans', 'âge de 72 ans', 'agé de 72 ans', 'patiente âgée de 72 ans'
    Returns age as int or None.
    """
    age_patterns = [
        r'(?:patien\w+\s+)?ag[eé]e?\s+de\s+(\d{1,3})\s*ans',
        r'(?:âge|age)\s+(?:de\s+)?(\d{1,3})\s*ans',
        r'\b(\d{1,3})\s*ans\b',
    ]
    for obs in observations:
        exam_text = obs.get('exam', '')
        for pattern in age_patterns:
            match = re.search(pattern, exam_text, re.IGNORECASE)
            if match:
                age = int(match.group(1))
                if 0 < age < 120:
                    return age
    return None

def get_patient_data(patient_id, quiet=False):
    """Get full patient data including observations and lab results"""
    if not os.path.exists(DEM_COOKIE_FILE):
        dem_login(quiet=True)
    
    result = {
        "patient_id": patient_id,
        "name": "",
        "observations": [],
        "lab_results": [],
        "vitals": {},
        "diagnosis": "",
        "admission_date": "",
        "date_of_birth": "",
        "age": 0
    }
    
    output = run_curl([f"{DEM_URL}/patient/resume/{patient_id}"])
    
    # Extract full name from resume page
    name_match = re.search(r'class="info-box-content">\s*<span class="info-box-number">([^<]+)</span>', output)
    if name_match:
        result["name"] = name_match.group(1).strip()
    
    date_pattern = r"Date d'admission.*?(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})"
    date_match = re.search(date_pattern, output)
    if date_match:
        date_str = date_match.group(1).strip()
        result["admission_date"] = date_str.replace(" ", "T")
    
    diag_pattern = r"Motif d'admission.*?<c[^>]*>([^<]+)"
    diag_match = re.search(diag_pattern, output)
    if diag_match:
        result["diagnosis"] = diag_match.group(1).replace("&nbsp;", " ").strip()
    
    # Extract DOB from resume page
    dob_str, age_from_resume = extract_dob_from_html(output)
    print(f"DEBUG: extract_dob_from_html -> dob={dob_str}, age={age_from_resume}", file=sys.stderr)
    
    obs_output = run_curl([f"{DEM_URL}/patient/fiche_suivi/index/{patient_id}"])
    
    obs_pattern = r'<td width="80px">(\d+)</td>.*?<td>(\d{4}-\d{2}-\d{2}[^<]*)</td>.*?<td>([^<]*)</td>.*?<td>([^<]+)</td>'
    obs_matches = re.findall(obs_pattern, obs_output, re.DOTALL)
    
    for num, date, exam, doctor in obs_matches[:5]:
        result["observations"].append({
            "number": num.strip(),
            "date": date.strip(),
            "doctor": doctor.strip(),
            "exam": exam.strip()[:800]
        })
    
    # Also try to extract DOB/age from fiche_suivi page (sometimes it's there)
    dob_from_fiche, age_from_fiche = extract_dob_from_html(obs_output)
    if dob_from_fiche and not dob_str:
        dob_str = dob_from_fiche
        print(f"DEBUG: DOB found in fiche_suivi: {dob_str}", file=sys.stderr)
    if age_from_fiche and not age_from_resume:
        age_from_resume = age_from_fiche
        print(f"DEBUG: Age found in fiche_suivi: {age_from_resume}", file=sys.stderr)
    
    # Handle DOB: if valid, use it; if 0000-00-00 or missing, try fallbacks
    if dob_str and dob_str != "0000-00-00":
        result["date_of_birth"] = dob_str
        result["age"] = age_from_resume or 0
        print(f"DEBUG: DOB from page: {dob_str}, age: {result['age']}", file=sys.stderr)
    elif age_from_resume and 0 < age_from_resume < 120:
        # Have age but no valid DOB - calculate DOB
        calculated_dob = calculate_dob_from_age(age_from_resume)
        result["date_of_birth"] = calculated_dob
        result["age"] = age_from_resume
        print(f"DEBUG: DOB calculated from age {age_from_resume}: {calculated_dob}", file=sys.stderr)
    else:
        # No DOB or age from pages, try observations
        age_from_obs = extract_age_from_observations(result["observations"])
        if age_from_obs and 0 < age_from_obs < 120:
            calculated_dob = calculate_dob_from_age(age_from_obs)
            result["date_of_birth"] = calculated_dob
            result["age"] = age_from_obs
            print(f"DEBUG: DOB calculated from observation age {age_from_obs}: {calculated_dob}", file=sys.stderr)
        else:
            result["date_of_birth"] = ""
            result["age"] = 0
            print(f"DEBUG: Could not determine DOB or age for patient {patient_id}", file=sys.stderr)
    
    dossier_pattern = r"N° dossier patient.*?(\d+)"
    dossier_match = re.search(dossier_pattern, output)
    patient_dossier_id = patient_id
    if dossier_match:
        patient_dossier_id = dossier_match.group(1)
    
    feuille_output = run_curl([f"{DEM_URL}/patient/feuille/{patient_dossier_id}"])
    
    lab_pattern = r'res_labo/(\d+)/(\d{4}-\d{2}-\d{2})'
    lab_matches = re.findall(lab_pattern, feuille_output)
    
    seen_dates = set()
    for pid, date in lab_matches:
        if date not in seen_dates:
            seen_dates.add(date)
            result["lab_results"].append({
                "date": date,
                "admission_id": pid
            })
    
    result["lab_results"].sort(key=lambda x: x['date'], reverse=True)
    result["lab_results"] = result["lab_results"][:5]
    
    if not quiet:
        print(json.dumps({"status": "success", "data": result}))
    return result

def get_full_duty_report(service_id="125"):
    """Get full duty report data for all patients in a service"""
    if not os.path.exists(DEM_COOKIE_FILE):
        dem_login(quiet=True)
    
    patients = get_service_patients(service_id, quiet=True)
    if isinstance(patients, str):
        patients = json.loads(patients).get("patients", [])
    elif isinstance(patients, dict):
        patients = patients.get("patients", [])
    
    report = {
        "service": "Maladie infectieuses",
        "date": datetime.now().strftime("%Y-%m-%d"),
        "service_id": service_id,
        "patients": []
    }
    
    for patient in patients:
        pdata = get_patient_data(patient["id"], quiet=True)
        if isinstance(pdata, str):
            pdata = json.loads(pdata).get("data", {})
        
        all_observations = pdata.get("observations", [])
        admitting_doctor = ""
        if all_observations:
            admitting_doctor = all_observations[-1].get("doctor", "")
        
        report["patients"].append({
            "name": pdata.get("name") or patient["name"],
            "id": patient["id"],
            "admission_date": pdata.get("admission_date", ""),
            "diagnosis": pdata.get("diagnosis", ""),
            "admitting_doctor": admitting_doctor,
            "latest_observation": all_observations[0] if all_observations else {},
            "all_observations": all_observations[:5],
            "lab_results": pdata.get("lab_results", [])[:1],
            "observations_count": len(all_observations),
            "date_of_birth": pdata.get("date_of_birth", ""),
            "age": pdata.get("age", 0)
        })
    
    print(json.dumps({"status": "success", "report": report}))
    return report

def create_observation(patient_id, remark, doctor_name="CHIKH TOUAMI HAFEDH"):
    """Create a new observation for a patient in DEM, or update today's if exists"""
    print(f"DEBUG: create_observation called with patient_id={patient_id}, remark_length={len(remark)}", file=sys.stderr)
    
    try:
        if not os.path.exists(DEM_COOKIE_FILE):
            login_success = dem_login(quiet=True)
            if not login_success:
                return {"status": "error", "message": "Échec de connexion à DEM"}
        
        today = datetime.now().strftime("%Y-%m-%d")
        
        # Get observation list page to find today's observation ID
        observations_page = run_curl([f"{DEM_URL}/patient/fiche_suivi/index/{patient_id}"])
        
        if not observations_page or len(observations_page) < 100:
            print(f"DEBUG: Failed to fetch observations page for patient {patient_id}", file=sys.stderr)
            return {"status": "error", "message": f"Patient {patient_id} non trouvé dans DEM"}
        
        # Find observation IDs from "M A J" links - these are the actual observation IDs
        # Pattern: href="/patient/fiche_suivi/update/28098"
        update_link_pattern = r'fiche_suivi/update/(\d+)'
        update_matches = re.findall(update_link_pattern, observations_page)
        
        # Now map observation numbers (1, 2, 3) to actual IDs by finding rows
        # Get table rows with both number and date
        row_pattern = r'<td[^>]*>(\d+)</td>\s*<td[^>]*>(\d{4}-\d{2}-\d{2})'
        row_matches = re.findall(row_pattern, observations_page, re.DOTALL)
        
        # Build a mapping from observation number to actual observation ID
        # Update links appear in order after the rows
        observation_ids = {}  # number -> actual_id
        for i, (row_no, date) in enumerate(row_matches):
            if i < len(update_matches):
                observation_ids[row_no] = update_matches[i]
        
        # Find today's observation ID
        observation_id = None
        for row_no, date in row_matches:
            if date == today:
                observation_id = observation_ids.get(row_no)
                break
        
        if observation_id:
            print(f"DEBUG: Found today's observation ID: {observation_id} (row {row_no})", file=sys.stderr)
            return update_observation(observation_id, patient_id, remark, doctor_name)
        else:
            print(f"DEBUG: No observation found for today ({today}), creating new", file=sys.stderr)
            return _create_new_observation(patient_id, remark, doctor_name)
    except Exception as e:
        print(f"ERROR in create_observation: {str(e)}", file=sys.stderr)
        return {"status": "error", "message": f"Erreur: {str(e)}"}

def update_observation(observation_id, patient_id, remark, doctor_name):
    """Update an existing observation"""
    try:
        if not os.path.exists(DEM_COOKIE_FILE):
            login_success = dem_login(quiet=True)
            if not login_success:
                return {"status": "error", "message": "Échec de connexion à DEM"}
        
        # Get the update page first to get the form
        update_page = run_curl([f"{DEM_URL}/patient/fiche_suivi/update/{observation_id}"])
        
        # Extract hidden fields
        id_personne_match = re.search(r'name="id_personne"[^>]*value="(\d+)"', update_page)
        id_personne = id_personne_match.group(1) if id_personne_match else "660"
        
        # Submit update
        import urllib.parse
        encoded_remark = urllib.parse.quote(remark)
        
        result = run_curl([
            "-X", "POST",
            f"{DEM_URL}/patient/fiche_suivi/update_action",
            "--data-urlencode", f"id_admission={patient_id}",
            "--data-urlencode", f"id_personne={id_personne}",
            "--data-urlencode", f"id_f_s={observation_id}",
            "--data-urlencode", f"remarque={remark}"
        ])
        
        if "success" in result.lower() or "error" not in result.lower()[:100].lower():
            return {"status": "success", "message": f"Observation {observation_id} mise à jour", "updated": True, "created": False}
        else:
            return {"status": "error", "message": f"Échec de la mise à jour de l'observation"}
    except Exception as e:
        return {"status": "error", "message": f"Erreur lors de la mise à jour: {str(e)}"}

def _create_new_observation(patient_id, remark, doctor_name):
    """Create a new observation (internal function)"""
    try:
        if not os.path.exists(DEM_COOKIE_FILE):
            login_success = dem_login(quiet=True)
            if not login_success:
                return {"status": "error", "message": "Échec de connexion à DEM"}
        
        # First get the create page to extract hidden fields
        create_page = run_curl([f"{DEM_URL}/patient/fiche_suivi/create/{patient_id}"])
        
        if not create_page or len(create_page) < 100:
            return {"status": "error", "message": f"Impossible d'accéder à la page de création pour le patient {patient_id}"}
        
        # Extract hidden fields
        id_personne_match = re.search(r'name="id_personne"[^>]*value="(\d+)"', create_page)
        id_personne = id_personne_match.group(1) if id_personne_match else "660"
        
        # URL encode the remark
        import urllib.parse
        encoded_remark = urllib.parse.quote(remark)
        
        result = run_curl([
            "-X", "POST",
            f"{DEM_URL}/patient/fiche_suivi/create_action",
            "--data-urlencode", f"id_admission={patient_id}",
            "--data-urlencode", f"id_personne={id_personne}",
            "--data-urlencode", "id_f_s=",
            "--data-urlencode", f"remarque={remark}"
        ])
        
        # Check if observation was created
        if "success" in result.lower() or "error" not in result.lower()[:100].lower():
            return {"status": "success", "message": f"Observation créée pour le patient {patient_id}", "created": True, "updated": False}
        else:
            return {"status": "error", "message": f"Échec de la création de l'observation"}
    except Exception as e:
        return {"status": "error", "message": f"Erreur lors de la création: {str(e)}"}

def export_duty_report(patients_data):
    """Export all duty report patients to DEM as observations"""
    if not os.path.exists(DEM_COOKIE_FILE):
        dem_login(quiet=True)
    
    results = []
    for patient in patients_data:
        patient_id = patient.get("id")
        remark = patient.get("observation_text", "")
        doctor = patient.get("doctor", "CHIKH TOUAMI HAFEDH")
        
        if not remark:
            results.append({
                "patient_id": patient_id,
                "status": "skipped",
                "message": "No observation text"
            })
            continue
            
        result = create_observation(patient_id, remark, doctor)
        results.append({
            "patient_id": patient_id,
            "status": result["status"],
            "message": result.get("message", "")
        })
    
    return results

def discharge_patient(patient_id, doctor_id="660", discharge_date=None, diagnostic=""):
    """Discharge a patient from DEM"""
    if not os.path.exists(DEM_COOKIE_FILE):
        dem_login(quiet=True)
    
    if not discharge_date:
        discharge_date = datetime.now().strftime("%Y-%m-%d")
    
    cmd = [
        "curl", "-s", "-b", DEM_COOKIE_FILE, "-c", DEM_COOKIE_FILE,
        "-X", "POST", "http://192.168.1.13/admin/sortie/ajax_add",
        "-d", f"id_admission={patient_id}",
        "-d", f"medcin_sort={doctor_id}",
        "-d", f"date_sortie={discharge_date}",
        "-d", f"diagnostic_sortie[]={diagnostic}"
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    try:
        resp_json = json.loads(result.stdout)
        if resp_json.get("status") == True or resp_json.get("status") == "true":
            return {"status": "success", "message": f"Patient {patient_id} discharged"}
    except:
        pass
    
    if "sortie" in result.stdout.lower() or "success" in result.stdout.lower():
        return {"status": "success", "message": f"Patient {patient_id} discharged"}
    else:
        return {"status": "error", "message": "Discharge failed", "details": result.stdout[:200]}

def main():
    if len(sys.argv) < 2:
        print("Usage: python dem_bridge.py <command> [args]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "login":
        dem_login()
    elif command == "get-patients":
        service_id = sys.argv[2] if len(sys.argv) > 2 else "125"
        get_service_patients(service_id)
    elif command == "get-patient":
        if len(sys.argv) < 3:
            print("Usage: python dem_bridge.py get-patient <patient_id>")
            sys.exit(1)
        get_patient_data(sys.argv[2])
    elif command == "full-report":
        service_id = sys.argv[2] if len(sys.argv) > 2 else "125"
        get_full_duty_report(service_id)
    elif command == "create-observation":
        if len(sys.argv) < 4:
            print("Usage: python dem_bridge.py create-observation <patient_id> <remark>")
            sys.exit(1)
        patient_id = sys.argv[2]
        remark = sys.argv[3]
        print(json.dumps(create_observation(patient_id, remark)))
    elif command == "export-duty-report":
        # Read patients JSON from stdin
        patients_data = json.load(sys.stdin)
        results = export_duty_report(patients_data)
        print(json.dumps({"status": "success", "results": results}))
    elif command == "discharge":
        if len(sys.argv) < 3:
            print("Usage: python dem_bridge.py discharge <patient_id> [date] [diagnostic]")
            sys.exit(1)
        patient_id = sys.argv[2]
        discharge_date = sys.argv[3] if len(sys.argv) > 3 else None
        diagnostic = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(discharge_patient(patient_id, "660", discharge_date, diagnostic)))
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
