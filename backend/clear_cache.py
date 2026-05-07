from datetime import datetime, timezone
from supabase import create_client
from core.config import get_settings

settings = get_settings()
if settings.supabase_url and settings.supabase_service_key:
    supabase = create_client(settings.supabase_url, settings.supabase_service_key)
    current_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    try:
        supabase.table("daily_discovery").delete().eq("date", current_date).execute()
        print("Cleared daily_discovery cache for today.")
    except Exception as e:
        print(f"Error clearing daily_discovery: {e}")

    try:
        supabase.table("daily_digests").delete().eq("date", current_date).execute()
        print("Cleared daily_digests cache for today.")
    except Exception as e:
        print(f"Error clearing daily_digests: {e}")
else:
    print("Supabase credentials not found.")
