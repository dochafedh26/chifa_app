import pymysql

connection = pymysql.connect(
    host='127.0.0.1',
    user='mediinfectDb',
    password='MyNewPass@2026',
    database='medinfect',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

target_dcis = [
    ('PARACETAMOL', '%PARACETAMOL%'),
    ('IBUPROFENE', '%IBUPROFENE%'),
    ('AMOXICILLINE', '%AMOXICILLINE%'),
    ('AMOXICILLINE + ACIDE CLAVULANIQUE', '%CLAVULAN%'),
    ('CEFIXIME', '%CEFIXIME%'),
    ('AZITHROMYCINE', '%AZITHROMYCINE%'),
    ('CLARITHROMYCINE', '%CLARITHROMYCINE%'),
    ('CIPROFLOXACINE', '%CIPROFLOXACINE%'),
    ('METRONIDAZOLE', '%METRONIDAZOLE%'),
    ('PREDNISOLONE', '%PREDNISOLONE%'),
    ('GENTAMICINE', '%GENTAMICINE%'),
    ('VANCOMYCINE', '%VANCOMYCINE%')
]

try:
    with connection.cursor() as cursor:
        print(f"{'DCI Search Pattern':<35} | {'Count':<5} | {'Example Brand Names'}")
        print("-" * 85)
        for dci_label, pattern in target_dcis:
            cursor.execute("""
                SELECT COUNT(*) as cnt 
                FROM medalgeriemedics 
                WHERE dci LIKE %s
            """, (pattern,))
            cnt = cursor.fetchone()['cnt']
            
            # Fetch up to 5 examples
            cursor.execute("""
                SELECT name, formulation, dosage 
                FROM medalgeriemedics 
                WHERE dci LIKE %s 
                LIMIT 5
            """, (pattern,))
            examples = cursor.fetchall()
            examples_str = ", ".join([f"{r['name']} {r['dosage'] or ''}" for r in examples])
            
            print(f"{dci_label:<35} | {cnt:<5} | {examples_str}")
            
finally:
    connection.close()
