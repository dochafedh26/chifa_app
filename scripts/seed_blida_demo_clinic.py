#!/usr/bin/env python3
"""
Seed or clean fictional Blida clinic demonstration data inside SinaClinic's local SQLite DB.

Every seeded record uses the strict UUID prefix `demo-blida-` so `--clean` removes
only demonstration rows without affecting real patient data.

Usage:
  python scripts/seed_blida_demo_clinic.py --db-path path/to/chifa_local.db --init-schema
  python scripts/seed_blida_demo_clinic.py --db-path path/to/chifa_local.db --dry-run
  python scripts/seed_blida_demo_clinic.py --db-path path/to/chifa_local.db --clean
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path

DEMO_PREFIX = "demo-blida-"
DEFAULT_DOCTOR_ID = 41

SCHEMA_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS patients (
        patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        dob TEXT,
        gender TEXT,
        phone TEXT,
        address TEXT,
        national_id TEXT,
        blood_group TEXT,
        allergies TEXT,
        notes TEXT,
        portal_pin_hash TEXT,
        portal_access_enabled INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS appointments (
        appointment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        appointment_date TEXT NOT NULL,
        status TEXT DEFAULT 'Scheduled',
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS medicalrecords (
        record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        visit_date TEXT,
        chief_complaint TEXT,
        diagnosis TEXT,
        treatment_plan TEXT,
        blood_pressure TEXT,
        heart_rate TEXT,
        temperature TEXT,
        weight TEXT,
        height TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS prescriptions (
        prescription_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        medicalrecord_id INTEGER,
        medication TEXT,
        dosage TEXT,
        frequency TEXT,
        duration TEXT,
        instructions TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS invoices (
        invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        total_amount REAL DEFAULT 0.0,
        paid_amount REAL DEFAULT 0.0,
        status TEXT DEFAULT 'Pending',
        invoice_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
    )
    """,
]

PATIENTS_DATA = [
    ("01", "Mohamed", "Benali", "1974-03-14", "M", "0551 23 45 01", "Cité Ben Boulaïd, Blida", "09740314001", "O+", "Aucune allergie connue", "Suivi HTA chronique"),
    ("02", "Khadidja", "Mansouri", "1982-07-22", "F", "0661 34 56 02", "Boufarik Centre, Blida", "09820722002", "A+", "Pénicilline", "Diabète type 2 équilibré"),
    ("03", "Yacine", "Khelifi", "1991-11-05", "M", "0771 45 67 03", "Ouled Yaïch, Blida", "09911105003", "B+", "Aucune", "Asthme allergique intermittent"),
    ("04", "Meriem", "Bouzid", "1968-01-19", "F", "0552 56 78 04", "Beni Mered, Blida", "09680119004", "O-", "AINS / Aspirine", "Hypothyroïdie substituée"),
    ("05", "Sofiane", "Rahmani", "1987-09-30", "M", "0662 67 89 05", "Centre-Ville, Blida", "09870930005", "A-", "Aucune", "RGO chronique sous IPP"),
    ("06", "Nadia", "Bouchaïb", "1995-04-12", "F", "0772 78 90 06", "Chréa Route Principale, Blida", "09950412006", "AB+", "Sulfamides", "Contrôle post-angine"),
    ("07", "Karim", "Ziani", "1961-12-03", "M", "0553 89 01 07", "El Affroun, Blida", "09611203007", "O+", "Aucune", "Cardiopathie ischémique stable"),
    ("08", "Samira", "Haddad", "1979-06-25", "F", "0663 90 12 08", "Mouzaïa, Blida", "09790625008", "B-", "Iode", "Lombalgie mécanique aiguë"),
    ("09", "Amine", "Ferhat", "2002-02-17", "M", "0773 01 23 09", "Ouled Slama, Blida", "10020217009", "A+", "Aucune", "Bilan pré-sportif"),
    ("10", "Fatima", "Meziane", "1956-08-08", "F", "0554 12 34 10", "Zabana, Blida", "09560808010", "O+", "Bêta-lactamines", "HTA + Dyslipidémie"),
    ("11", "Riad", "Toumi", "1984-05-14", "M", "0664 23 45 11", "Soumaâ, Blida", "09840514011", "B+", "Aucune", "Bronchite aiguë tabagique"),
    ("12", "Imane", "Chérifi", "1998-10-28", "F", "0774 34 56 12", "Oued El Alleug, Blida", "09981028012", "A+", "Aucune", "Anémie ferriprive en cours de correction"),
    ("13", "Nabil", "Belkacem", "1971-04-02", "M", "0555 45 67 13", "Bouinan, Blida", "09710402013", "AB-", "Aucune", "Goutte et hyperuricémie"),
    ("14", "Yasmine", "Amrani", "1990-12-11", "F", "0665 56 78 14", "Meftah, Blida", "09901211014", "O+", "Latex", "Migraine ophtalmique"),
    ("15", "Hamza", "Saïdi", "1976-07-09", "M", "0775 67 89 15", "Beni Tamou, Blida", "09760709015", "A-", "Aucune", "Colique néphrétique récente"),
]

CLINICAL_DATA = [
    ("01", "Céphalées matinales et contrôle TA", "HTA essentielle grade 1", "Poursuite inhibiteur calcique + régime hyposodé", "145/88", "74", "36.8", "81", "176", "Bilan rénal + ionogramme à prévoir", "Amlodipine 5 mg", "1 comprimé", "1 fois/jour (matin)", "30 jours", "Prendre à heure fixe"),
    ("02", "Contrôle glycémique trimestriel", "Diabète type 2 non insulinodépendant", "Maintien metformine + HbA1c dans 3 mois", "126/78", "78", "36.7", "72", "164", "Fond d'oeil annuel à jour", "Metformine 850 mg", "1 comprimé", "2 fois/jour (repas)", "30 jours", "Avaler au milieu des repas"),
    ("03", "Dyspnée sifflante nocturne", "Asthme persistant léger", "Bronchodilatateur de secours + éviction allergènes", "118/74", "84", "36.9", "69", "174", "DEP 460 L/min — technique inhalation vérifiée", "Salbutamol 100 µg (Aérosol)", "2 bouffées", "En cas de crise (max 8/j)", "30 jours", "Bien agiter avant emploi"),
    ("04", "Fatigue et contrôle TSH", "Hypothyroïdie primaire équilibrée", "Maintien lévothyroxine à dose inchangée", "122/76", "68", "36.6", "66", "161", "TSH récente 2.4 mUI/L", "Lévothyroxine 50 µg", "1 comprimé", "1 fois/jour à jeun", "30 jours", "30 min avant le petit-déjeuner"),
    ("05", "Pyrosis et régurgitations acides", "Reflux gastro-oesophagien non compliqué", "IPP le matin + mesures hygiéno-diététiques", "120/75", "72", "36.7", "77", "178", "Surélever tête du lit, éviter dîner tardif", "Oméprazole 20 mg", "1 gélule", "1 fois/jour avant dîner", "28 jours", "Ne pas croquer la gélule"),
    ("06", "Odynophagie fébrile depuis 48h", "Angine érythémato-pultacée", "Antibiothérapie adaptée (allergie sulfamides) + antipyrétique", "114/70", "92", "38.4", "58", "165", "Hydratation abondante", "Amoxicilline + Acide Clavulanique 1 g", "1 sachet", "2 fois/jour", "7 jours", "Prendre au début des repas"),
    ("07", "Contrôle cardiologique trimestriel", "Coronaropathie stable revascularisée", "Poursuite antiagrégant + statine", "134/82", "66", "36.7", "79", "172", "ECG sinusal sans modification", "Atorvastatine 20 mg", "1 comprimé", "1 fois/jour le soir", "30 jours", "Surveillance CPK / transaminases"),
    ("08", "Douleur lombaire aiguë post-effort", "Lombalgie commune sans radiculalgie", "Antalgique palier 1 + décontracturant musculaire", "124/76", "76", "36.8", "68", "163", "Lasègue négatif bilatéral — contre-indication AINS notée", "Paracétamol 1 g", "1 comprimé", "3 fois/jour si douleur", "5 jours", "Minimum 6h entre deux prises"),
    ("09", "Certificat aptitude sport universitaire", "Bilan clinique normal", "Aptitude sport sans restriction", "116/72", "64", "36.6", "71", "180", "Auscultation cardiaque et pulmonaire libre", "Magnésium B6", "1 comprimé", "2 fois/jour", "20 jours", "Cure récupération effort"),
    ("10", "Bilan lipidique et contrôle tensionnel", "HTA + Hypercholestérolémie mixte", "Bithérapie antihypertensive douce + régime", "148/90", "75", "36.8", "74", "158", "Attention allergie bêta-lactamines inscrite", "Losartan 50 mg", "1 comprimé", "1 fois/jour (matin)", "30 jours", "Contrôle TA à domicile J15"),
    ("11", "Toux productive depuis 5 jours", "Bronchite aiguë simple", "Traitement symptomatique + arrêt tabac conseillé", "128/80", "86", "37.6", "76", "175", "Pas de foyer auscultatoire ni détresse", "Acétylcystéine 200 mg", "1 sachet", "3 fois/jour", "7 jours", "Dernière prise avant 17h"),
    ("12", "Asthénie et pâleur cutanéo-muqueuse", "Anémie ferriprive (Hb 9.8 g/dL)", "Supplémentation martiale orale + bilan étiologique", "110/68", "88", "36.7", "55", "166", "Contrôle NFS + ferritinémie à 2 mois", "Fer Fumarrate + Acide Folique", "1 comprimé", "1 fois/jour", "60 jours", "Prendre avec vitamine C, loin du thé"),
    ("13", "Douleur aiguë gros orteil droit", "Crise de goutte inaugurale", "Traitement crise aiguë + hydratation alcaline", "136/84", "80", "37.3", "86", "173", "Uricémie de contrôle à distance de la crise", "Colchicine 1 mg", "1 comprimé", "Selon protocole dégressif", "7 jours", "Arrêter immédiatement si diarrhée"),
    ("14", "Céphalées pulsatiles unilatérales", "Migraine avec aura visuelle", "Traitement de crise précoce + agenda céphalées", "118/74", "74", "36.7", "62", "167", "Examen neurologique normal", "Sumatriptan 50 mg", "1 comprimé", "Dès le début de la céphalée", "10 jours", "Max 2 cp / 24h si besoin"),
    ("15", "Douleur lombaire droite irradiant", "Colique néphrétique non fébrile", "Antalgie + contrôle échographique rénal", "132/82", "85", "36.9", "78", "177", "Absence de fièvre ni anurie", "Phloroglucinol 80 mg", "2 comprimés", "3 fois/jour", "5 jours", "Boissons abondantes hors crise"),
]


def default_db_path() -> Path:
    appdata = os.environ.get("APPDATA") or str(Path.home())
    return Path(appdata) / "com.example" / "chifa" / "chifa_local.db"


def count_demo_rows(conn: sqlite3.Connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    for table in ("patients", "medicalrecords", "prescriptions", "appointments", "invoices"):
        cur = conn.execute(
            f"SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", (table,)
        )
        if cur.fetchone()[0] == 0:
            counts[table] = 0
            continue
        c = conn.execute(
            f"SELECT COUNT(*) FROM {table} WHERE uuid LIKE ?", (f"{DEMO_PREFIX}%",)
        ).fetchone()[0]
        counts[table] = int(c)
    return counts


def clean_demo_data(conn: sqlite3.Connection, dry_run: bool) -> None:
    before = count_demo_rows(conn)
    print(f"[Clean] Enregistrements '{DEMO_PREFIX}*' trouvés : {before}")
    if dry_run:
        print("[Clean] Mode --dry-run : aucune suppression effectuée.")
        return

    with conn:
        for table in ("prescriptions", "medicalrecords", "appointments", "invoices", "patients"):
            cur = conn.execute(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", (table,)
            )
            if cur.fetchone()[0] > 0:
                conn.execute(f"DELETE FROM {table} WHERE uuid LIKE ?", (f"{DEMO_PREFIX}%",))

    after = count_demo_rows(conn)
    print(f"[Clean] Terminé. Enregistrements '{DEMO_PREFIX}*' restants : {after}")


def seed_demo_data(conn: sqlite3.Connection, init_schema: bool, dry_run: bool) -> None:
    if init_schema and not dry_run:
        with conn:
            for stmt in SCHEMA_STATEMENTS:
                conn.execute(stmt)

    if dry_run:
        print(
            "[Seed] Mode --dry-run : "
            f"15 patients, 15 consultations, 15 ordonnances DCI, 10 RDV, 10 factures "
            f"(préfixe UUID '{DEMO_PREFIX}*', aucune écriture disque)."
        )
        return

    now_dt = datetime.now()
    now_iso = now_dt.strftime("%Y-%m-%d %H:%M:%S")
    patient_id_by_idx: dict[str, int] = {}

    with conn:
        for idx, fn, ln, dob, gender, phone, addr, nid, bg, allerg, notes in PATIENTS_DATA:
            p_uuid = f"{DEMO_PREFIX}patient-{idx}"
            conn.execute(
                """
                INSERT OR IGNORE INTO patients (
                    uuid, first_name, last_name, dob, gender, phone, address,
                    national_id, blood_group, allergies, notes,
                    portal_access_enabled, created_at, updated_at, is_deleted, needs_sync, source_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 0, 0, 'demo_seed')
                """,
                (p_uuid, fn, ln, dob, gender, phone, addr, nid, bg, allerg, notes, now_iso, now_iso),
            )
            row = conn.execute("SELECT patient_id FROM patients WHERE uuid = ?", (p_uuid,)).fetchone()
            if row:
                patient_id_by_idx[idx] = int(row[0])

        for pos, item in enumerate(CLINICAL_DATA):
            (
                idx,
                complaint,
                diagnosis,
                plan,
                bp,
                hr,
                temp,
                wt,
                ht,
                c_notes,
                med,
                dosage,
                freq,
                dur,
                instr,
            ) = item
            p_id = patient_id_by_idx[idx]
            visit_dt = (now_dt - timedelta(days=pos)).strftime("%Y-%m-%d %H:%M:%S")

            mr_uuid = f"{DEMO_PREFIX}record-{idx}"
            conn.execute(
                """
                INSERT OR IGNORE INTO medicalrecords (
                    uuid, patient_id, doctor_id, visit_date, chief_complaint, diagnosis,
                    treatment_plan, blood_pressure, heart_rate, temperature, weight, height,
                    notes, created_at, updated_at, is_deleted, needs_sync, source_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'demo_seed')
                """,
                (
                    mr_uuid,
                    p_id,
                    DEFAULT_DOCTOR_ID,
                    visit_dt,
                    complaint,
                    diagnosis,
                    plan,
                    bp,
                    hr,
                    temp,
                    wt,
                    ht,
                    c_notes,
                    visit_dt,
                    visit_dt,
                ),
            )
            mr_row = conn.execute("SELECT record_id FROM medicalrecords WHERE uuid = ?", (mr_uuid,)).fetchone()
            mr_id = int(mr_row[0]) if mr_row else None

            rx_uuid = f"{DEMO_PREFIX}rx-{idx}"
            conn.execute(
                """
                INSERT OR IGNORE INTO prescriptions (
                    uuid, patient_id, doctor_id, medicalrecord_id, medication, dosage,
                    frequency, duration, instructions, created_at, updated_at, is_deleted, needs_sync, source_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'demo_seed')
                """,
                (
                    rx_uuid,
                    p_id,
                    DEFAULT_DOCTOR_ID,
                    mr_id,
                    med,
                    dosage,
                    freq,
                    dur,
                    instr,
                    visit_dt,
                    visit_dt,
                ),
            )

        # 10 appointments spread across today and next 5 days
        for i in range(10):
            idx = f"{i + 1:02d}"
            p_id = patient_id_by_idx[idx]
            appt_uuid = f"{DEMO_PREFIX}appt-{idx}"
            appt_dt = (now_dt + timedelta(days=i // 2, hours=9 + (i % 5))).strftime("%Y-%m-%d %H:%M:%S")
            status = "Completed" if i < 2 else "Scheduled"
            conn.execute(
                """
                INSERT OR IGNORE INTO appointments (
                    uuid, patient_id, doctor_id, appointment_date, status, notes,
                    created_at, updated_at, is_deleted, needs_sync, source_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'demo_seed')
                """,
                (
                    appt_uuid,
                    p_id,
                    DEFAULT_DOCTOR_ID,
                    appt_dt,
                    status,
                    "Consultation de suivi programmée (Démo Blida)",
                    now_iso,
                    now_iso,
                ),
            )

        # 10 invoices
        for i in range(10):
            idx = f"{i + 1:02d}"
            p_id = patient_id_by_idx[idx]
            inv_uuid = f"{DEMO_PREFIX}inv-{idx}"
            total = 1500.0 + (i % 3) * 500.0
            is_paid = i < 7
            paid = total if is_paid else 0.0
            status = "Paid" if is_paid else "Pending"
            inv_dt = (now_dt - timedelta(days=i)).strftime("%Y-%m-%d")
            conn.execute(
                """
                INSERT OR IGNORE INTO invoices (
                    uuid, patient_id, total_amount, paid_amount, status, invoice_date,
                    created_at, updated_at, is_deleted, needs_sync, source_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'demo_seed')
                """,
                (inv_uuid, p_id, total, paid, status, inv_dt, now_iso, now_iso),
            )

    counts = count_demo_rows(conn)
    print(f"[Seed] Jeu de démo Blida prêt : {counts}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed/clean SinaClinic Blida demo clinic SQLite dataset."
    )
    parser.add_argument(
        "--db-path",
        type=Path,
        default=default_db_path(),
        help="Chemin vers chifa_local.db (ex: %%APPDATA%%/com.example/chifa/chifa_local.db).",
    )
    parser.add_argument(
        "--init-schema",
        action="store_true",
        help="Crée les tables si la base SQLite est vierge.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Affiche les opérations sans écrire dans SQLite.",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Supprime uniquement les lignes demo-blida-* sans toucher aux vrais patients.",
    )
    args = parser.parse_args()

    db_path: Path = args.db_path
    if not args.dry_run and not db_path.exists():
        if not args.init_schema:
            print(
                f"Erreur : base SQLite introuvable à {db_path}. "
                "Passez --db-path ou --init-schema pour créer une base de test.",
                file=sys.stderr,
            )
            return 1
        db_path.parent.mkdir(parents=True, exist_ok=True)

    if args.dry_run and not db_path.exists():
        if args.clean:
            print("[Clean] Mode --dry-run (base absente) : 0 ligne à supprimer.")
        else:
            print(
                "[Seed] Mode --dry-run : 15 patients, 15 consultations, "
                "15 ordonnances DCI, 10 RDV, 10 factures (aucune écriture disque)."
            )
        return 0

    conn = sqlite3.connect(str(db_path))
    try:
        if args.clean:
            clean_demo_data(conn, dry_run=args.dry_run)
        else:
            seed_demo_data(conn, init_schema=args.init_schema, dry_run=args.dry_run)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
