from fastapi import Header, HTTPException
from firebase_admin import auth, credentials
import firebase_admin
import os

# Init Firebase Admin SDK
if not firebase_admin._apps:
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT", ".\\config\\serviceAccountKey.json")
    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)

async def verify_firebase_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing header")
    token = authorization.split(" ")[1]
    try:
        # Verify token
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        print(f"Token Error: {e}")
        raise HTTPException(status_code=401, detail="Invalid Token")