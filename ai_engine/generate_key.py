from cryptography.fernet import Fernet

key = Fernet.generate_key().decode()
print("=" * 60)
print("🔑 ENCRYPTION KEY MỚI ĐÃ TẠO")
print("=" * 60)
print(f"\nENCRYPTION_KEY={key}\n")
print("=" * 60)
print("📋 Copy dòng trên vào file .env của bạn")
print("=" * 60)
