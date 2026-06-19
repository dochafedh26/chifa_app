import pymysql

connection = pymysql.connect(
    host='127.0.0.1',
    user='mediinfectDb',
    password='MyNewPass@2026',
    database='medinfect',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

try:
    with connection.cursor() as cursor:
        # Check column names
        cursor.execute("DESCRIBE medalgeriemedics")
        columns = cursor.fetchall()
        print("Columns in medalgeriemedics:")
        for col in columns:
            print(f"  {col['Field']}: {col['Type']}")
        
        # Get count of total medications
        cursor.execute("SELECT COUNT(*) as total FROM medalgeriemedics")
        total = cursor.fetchone()['total']
        print(f"\nTotal rows in medalgeriemedics: {total}")
        
        # Find distinct DCI/molecules to see what types of medicines we have
        cursor.execute("""
            SELECT dci, COUNT(*) as cnt 
            FROM medalgeriemedics 
            WHERE dci IS NOT NULL AND dci != ''
            GROUP BY dci 
            ORDER BY cnt DESC 
            LIMIT 50
        """)
        top_dcis = cursor.fetchall()
        print("\nTop 50 distinct DCIs in the database:")
        for i, row in enumerate(top_dcis, 1):
            print(f"{i:2d}. {row['dci']} (count: {row['cnt']})")
            
finally:
    connection.close()
