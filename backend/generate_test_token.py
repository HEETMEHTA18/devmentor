import sqlite3
from jose import jwt
from datetime import datetime, timedelta

db_path = "devmentor.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("SELECT id, email FROM users LIMIT 1")
row = cursor.fetchone()
conn.close()

if not row:
    print("No user found in devmentor.db")
else:
    user_id, email = row
    print(f"User ID: {user_id} ({email})")
    payload = {
        "sub": user_id,
        "exp": datetime.utcnow() + timedelta(hours=24)
    }
    token = jwt.encode(payload, "change-me", algorithm="HS256")
    print(f"Token: {token}")
