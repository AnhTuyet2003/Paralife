import os
from supabase import create_client, Client

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

# Singleton instance
supabase_storage: Client = create_client(supabase_url, supabase_key)