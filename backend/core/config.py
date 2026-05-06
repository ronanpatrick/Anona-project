import os
from dataclasses import dataclass
from functools import lru_cache

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_service_key: str
    supabase_anon_key: str
    newsdata_api_key: str
    newsapi_api_key: str
    gemini_api_key: str
    request_timeout_seconds: int
    max_article_chars: int


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings(
        supabase_url=os.getenv("SUPABASE_URL", "").strip(),
        supabase_service_key=os.getenv("SUPABASE_SERVICE_KEY", "").strip(),
        supabase_anon_key=os.getenv("SUPABASE_ANON_KEY", "").strip(),
        newsdata_api_key=os.getenv("NEWSDATA_API_KEY", "").strip(),
        newsapi_api_key=os.getenv("NEWSAPI_API_KEY", "").strip(),
        gemini_api_key=os.getenv("GEMINI_API_KEY", "").strip(),
        request_timeout_seconds=int(os.getenv("REQUEST_TIMEOUT_SECONDS", "12")),
        max_article_chars=int(os.getenv("MAX_ARTICLE_CHARS", "12000")),
    )

