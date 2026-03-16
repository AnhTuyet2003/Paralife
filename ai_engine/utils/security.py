import os
from cryptography.fernet import Fernet
from dotenv import load_dotenv

load_dotenv()

def get_or_create_encryption_key():
    """Lấy hoặc tạo encryption key"""
    encryption_key = os.getenv("ENCRYPTION_KEY")
    
    # Nếu không có key hoặc key không hợp lệ
    if not encryption_key or len(encryption_key) < 32:
        print("⚠️ ENCRYPTION_KEY không hợp lệ. Tạo key mới...")
        new_key = Fernet.generate_key().decode()
        print(f"✅ Key mới đã tạo. Thêm vào file .env:")
        print(f"   ENCRYPTION_KEY={new_key}")
        return new_key
    
    return encryption_key

try:
    ENCRYPTION_KEY = get_or_create_encryption_key()
    cipher = Fernet(ENCRYPTION_KEY.encode())
except Exception as e:
    print(f"❌ Lỗi khởi tạo Fernet: {e}")
    # Tạo key tạm thời để server chạy được
    ENCRYPTION_KEY = Fernet.generate_key().decode()
    cipher = Fernet(ENCRYPTION_KEY.encode())
    print(f"⚠️ Đang dùng key tạm thời. Hãy thêm vào .env:")
    print(f"   ENCRYPTION_KEY={ENCRYPTION_KEY}")

def encrypt_data(plaintext: str) -> str:
    """Encrypt a string"""
    try:
        return cipher.encrypt(plaintext.encode()).decode()
    except Exception as e:
        print(f"❌ Encryption failed: {e}")
        raise ValueError(f"Failed to encrypt: {str(e)}")

def decrypt_data(encrypted_text: str) -> str:
    """Decrypt a string"""
    try:
        decrypted = cipher.decrypt(encrypted_text.encode()).decode()
        print(f"✅ Decrypted key: {decrypted[:10]}...{decrypted[-5:]}")
        return decrypted
    except Exception as e:
        print(f"❌ Decryption failed: {e}")
        raise ValueError(f"Failed to decrypt: {str(e)}")