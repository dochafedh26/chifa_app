import pymysql

connection = pymysql.connect(
    host='127.0.0.1',
    user='mediinfectDb',
    password='MyNewPass@2026',
    database='medinfect',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

# List of target medications and their daily pediatric posologies
updates = [
    # 1. Paracetamol (daily standard weight-based dose)
    ("40-60mg/kg", "%PARACETAMOL%"),
    # 2. Ibuprofene
    ("20-30mg/kg", "%IBUPROFENE%"),
    # 3. Amoxicilline
    ("50-100mg/kg", "%AMOXICILLINE%"),
    # 4. Amoxicilline + Acide Clavulanique
    ("40-80mg/kg", "%CLAVULAN%"),
    # 5. Cefixime
    ("8mg/kg", "%CEFIXIME%"),
    # 6. Azithromycine
    ("10-20mg/kg", "%AZITHROMYCINE%"),
    # 7. Clarithromycine
    ("15mg/kg", "%CLARITHROMYCINE%"),
    # 8. Ciprofloxacine
    ("20-30mg/kg", "%CIPROFLOXACINE%"),
    # 9. Metronidazole
    ("30-40mg/kg", "%METRONIDAZOLE%"),
    # 10. Prednisolone
    ("1-2mg/kg", "%PREDNISOLONE%"),
    # 11. Gentamicine
    ("3-5mg/kg", "%GENTAMICINE%"),
    # 12. Vancomycine
    ("40-60mg/kg", "%VANCOMYCINE%")
]

try:
    with connection.cursor() as cursor:
        print("Starting updates...")
        for poso, pattern in updates:
            # We overwrite any existing or empty posology for these specific target DCIs to match real values
            cursor.execute("""
                UPDATE medalgeriemedics 
                SET posologie = %s 
                WHERE dci LIKE %s
            """, (poso, pattern))
            rows_affected = cursor.rowcount
            print(f"Updated DCI LIKE '{pattern}' to '{poso}': {rows_affected} rows affected.")
            
        connection.commit()
        print("Database commit successful.")
            
finally:
    connection.close()
