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
        # Check current columns to see if they already exist
        cursor.execute("DESCRIBE medalgeriemedics")
        columns = [col['Field'] for col in cursor.fetchall()]
        
        alter_queries = []
        if 'posologie_adulte' not in columns:
            alter_queries.append("ADD COLUMN posologie_adulte TEXT DEFAULT NULL")
            print("Will add posologie_adulte column.")
        else:
            print("posologie_adulte column already exists.")
            
        if 'posologie_pediatrique' not in columns:
            alter_queries.append("ADD COLUMN posologie_pediatrique TEXT DEFAULT NULL")
            print("Will add posologie_pediatrique column.")
        else:
            print("posologie_pediatrique column already exists.")
            
        if alter_queries:
            query = f"ALTER TABLE medalgeriemedics {', '.join(alter_queries)}"
            cursor.execute(query)
            connection.commit()
            print("Alter table query executed successfully.")
        else:
            print("No alter table query needed.")
            
finally:
    connection.close()
