import sqlite3
from config import DB_PATH

def get_connection():
    return sqlite3.connect(DB_PATH)

def safe_query(query, params=()):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(query, params)
    result = cursor.fetchall()
    conn.close()
    return result

def query_user(user_id):
    return safe_query("SELECT * FROM users WHERE id = ?", (user_id,))

def query_report(report_id):
    return safe_query("SELECT * FROM reports WHERE id = ?", (report_id,))
