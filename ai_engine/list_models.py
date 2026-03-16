import os
from dotenv import load_dotenv
from google import genai

load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

def list_available_models():
    print("🔍 Checking available Gemini models...\n")
    
    client = genai.Client(api_key=GEMINI_API_KEY)
    
    # List all models
    models = client.models.list()
    
    print("📋 Available models:\n")
    
    embedding_models = []
    for model in models:
        if 'embed' in model.name.lower() or 'text-embedding' in model.name.lower():
            embedding_models.append(model.name)
            print(f"✅ {model.name}")
            if hasattr(model, 'supported_generation_methods'):
                print(f"   Methods: {model.supported_generation_methods}")
    
    if not embedding_models:
        print("❌ No embedding models found!")
        print("\n📋 All available models:")
        for model in models:
            print(f"  - {model.name}")
    
    return embedding_models

if __name__ == "__main__":
    list_available_models()
