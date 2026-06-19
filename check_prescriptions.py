#!/usr/bin/env python3
"""
Script to check data in modern_prescriptions table
"""
import pymysql
import sys

def check_prescriptions():
    """Connect to MySQL and query modern_prescriptions table"""

    # Try common XAMPP configurations
    configs = [
        {"host": "localhost", "port": 3306, "user": "root", "password": "", "database": "rnhgnubg_chifa"},
        {"host": "127.0.0.1", "port": 3306, "user": "root", "password": "", "database": "rnhgnubg_chifa"},
        {"host": "localhost", "port": 3306, "user": "root", "password": "root", "database": "rnhgnubg_chifa"},
        {"host": "localhost", "port": 3306, "user": "root", "password": "", "database": "chifa"},
    ]

    conn = None
    for config in configs:
        try:
            print(f"Attempting to connect with: {config['host']}:{config['port']}, user={config['user']}, db={config['database']}")
            conn = pymysql.connect(
                host=config['host'],
                port=config['port'],
                user=config['user'],
                password=config['password'],
                database=config['database'],
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            print("✓ Connection successful!")
            break
        except Exception as e:
            print(f"✗ Connection failed: {e}")
            continue

    if not conn:
        print("Could not connect to database with any configuration")
        return False

    try:
        with conn.cursor() as cursor:
            # Get total count
            cursor.execute("SELECT COUNT(*) as count FROM modern_prescriptions WHERE is_deleted = 0;")
            result = cursor.fetchone()
            total_count = result['count']
            print(f"\n📊 Total prescriptions (not deleted): {total_count}")

            # Get sample data (first 10 records)
            cursor.execute("""
                SELECT id, SUBSTRING(prescription, 1, 80) as prescription_preview, 
                       updated_at, needs_sync, source_id
                FROM modern_prescriptions
                WHERE is_deleted = 0
                ORDER BY id DESC
                LIMIT 10
            """)
            sample_data = cursor.fetchall()

            print("\n📋 Sample prescriptions (first 10):")
            print("-" * 80)
            for i, row in enumerate(sample_data, 1):
                print(f"{i}. ID: {row['id']}")
                print(f"   Prescription: {row['prescription_preview']}...")
                print(f"   Updated: {row['updated_at']}, Sync: {row['needs_sync']}, Source: {row['source_id']}")
                print("-" * 80)

            # Show all if there are less than 20
            if total_count <= 20:
                cursor.execute("""
                    SELECT id, prescription, updated_at, needs_sync, source_id
                    FROM modern_prescriptions
                    WHERE is_deleted = 0
                    ORDER BY id DESC
                """)
                all_data = cursor.fetchall()
                print("\n📋 All prescriptions:")
                for i, row in enumerate(all_data, 1):
                    print(f"{i:3d}. {row['prescription'][:100]}")

            return True

    except Exception as e:
        print(f"Error querying data: {e}")
        return False
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("🔍 Checking modern_prescriptions table\n")
    print("=" * 80)
    success = check_prescriptions()
    print("=" * 80)
    sys.exit(0 if success else 1)
