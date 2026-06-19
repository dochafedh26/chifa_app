import pymysql

connection = pymysql.connect(
    host='127.0.0.1',
    user='chiffa',
    password='MyNewPass@2025',
    database='clinic',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT id, name, dci FROM medalgeriemedics WHERE name LIKE %s", ('%flazol%',))
        rows = cursor.fetchall()
        for r in rows:
            print(r)
finally:
    connection.close()
