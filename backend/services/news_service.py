from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

import requests
import trafilatura

from core.config import Settings

NEWSDATA_MAX_SIZE = 10
NEWSAPI_MAX_PAGE_SIZE = 10


@dataclass
class NewsArticle:
    title: str
    url: str
    source: str
    topic: str = ""
    description: str = ""
    published_at: str = ""
    image_url: str = ""


class NewsService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.timeout = settings.request_timeout_seconds
        self._news_cache: dict[str, tuple[float, list[NewsArticle]]] = {}

    def fetch_news(
        self,
        topics: list[str],
        country: str = "us",
        limit: int = 10,
        exclude_topics: list[str] | None = None,
        discovery: bool = False,
    ) -> list[NewsArticle]:
        if not topics and not discovery:
            raise ValueError("topics cannot be empty unless discovery=True")
        if not self.settings.newsdata_api_key and not self.settings.newsapi_api_key:
            raise RuntimeError("No news provider key configured in .env")

        query_topics = topics or ["trending", "breaking", "innovation", "world"]
        exclude_topics = [item.strip().lower() for item in (exclude_topics or []) if item]
        
        cache_key = f"{','.join(sorted(query_topics))}|{country}|{limit}|{discovery}"
        import time
        if cache_key in self._news_cache:
            timestamp, cached_articles = self._news_cache[cache_key]
            if time.time() - timestamp < 3600:
                filtered = self._exclude_topics(cached_articles, exclude_topics)
                return filtered[:limit]

        combined: list[NewsArticle] = []
        if self.settings.newsdata_api_key:
            try:
                combined.extend(self._fetch_newsdata(query_topics, country, limit))
            except requests.RequestException:
                pass
        if self.settings.newsapi_api_key:
            try:
                combined.extend(self._fetch_newsapi(query_topics, country, limit))
            except requests.RequestException:
                pass

        if not combined:
            return []

        deduped = self._dedupe_by_url(combined)
        self._news_cache[cache_key] = (time.time(), deduped)
        filtered = self._exclude_topics(deduped, exclude_topics)
        return filtered[:limit]

    def scrape_urls(
        self,
        urls: Iterable[str],
        max_articles: int = 5,
        min_chars: int = 220,
    ) -> list[dict[str, str]]:
        scraped: list[dict[str, str]] = []
        seen: set[str] = set()
        
        # Robust User-Agent to avoid simple bot detection
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        }

        for raw_url in urls:
            url = raw_url.strip()
            if not url or url in seen:
                continue
            seen.add(url)

            try:
                # Try trafilatura's fetch first (it has some internal smarts)
                page = trafilatura.fetch_url(url)
                
                # If trafilatura fails, try a manual request with headers
                if not page:
                    print(f"DEBUG: trafilatura.fetch_url failed for {url}, trying requests fallback...")
                    resp = requests.get(url, headers=headers, timeout=self.timeout, allow_redirects=True)
                    if resp.status_code == 200:
                        page = resp.text
                    else:
                        print(f"DEBUG: requests fallback also failed with status {resp.status_code}")

                if not page:
                    continue

                extracted = trafilatura.extract(
                    page,
                    include_comments=False,
                    include_tables=False,
                    favor_precision=True,
                )
            except Exception as e:
                print(f"DEBUG: Scraping error for {url}: {e}")
                continue

            if not extracted:
                continue

            cleaned = self.clean_text(extracted)[: self.settings.max_article_chars]
            if len(cleaned) < min_chars:
                print(f"DEBUG: Scraped content too short ({len(cleaned)} chars) for {url}")
                continue

            scraped.append({"url": url, "text": cleaned})
            if len(scraped) >= max_articles:
                break

        return scraped

    @staticmethod
    def clean_text(text: str) -> str:
        flattened = re.sub(r"\s+", " ", text).strip()
        return flattened



    def _fetch_newsdata(self, topics: list[str], country: str, limit: int) -> list[NewsArticle]:
        articles: list[NewsArticle] = []
        topics_to_search = [topic.strip() for topic in topics if topic and topic.strip()]
        if not topics_to_search:
            return []

        size = NEWSDATA_MAX_SIZE

        for topic in topics_to_search:
            try:
                print(f"DEBUG: Attempting to call News API for topic: {topic}")
                response = requests.get(
                    "https://newsdata.io/api/1/news",
                    params={
                        "apikey": self.settings.newsdata_api_key,
                        "q": f"{topic} news",
                        "prioritydomain": "top",
                        "language": "en",
                        "size": size,
                    },
                    timeout=self.timeout,
                )
                print(f"DEBUG API Status: {response.status_code} - {response.text}")
                response.raise_for_status()
                payload = response.json()
            except Exception as e:
                import traceback

                print(f"DEBUG API Exception: {e}")
                traceback.print_exc()
                continue

            if payload.get("status") != "success":
                continue

            raw_search_results = payload.get("results", [])
            trusted_articles: list[NewsArticle] = []
            for item in raw_search_results:
                article_url = (item.get("link") or "").strip()
                if not article_url:
                    continue
                candidate_article = NewsArticle(
                    title=(item.get("title") or "Untitled").strip(),
                    url=article_url,
                    source=(item.get("source_id") or "NewsData").strip(),
                    topic=topic,
                    description=(item.get("description") or "").strip(),
                    published_at=(item.get("pubDate") or "").strip(),
                    image_url=(item.get("image_url") or "").strip(),
                )
                if "transcript" in article_url.lower() or "earnings" in candidate_article.title.lower():
                    print(f"DEBUG: Rejecting junk source: {article_url}")
                    continue
                trusted_articles.append(candidate_article)
                if len(trusted_articles) >= 3:
                    break
            print(f"DEBUG: Filtered down to {len(trusted_articles)} trusted sources from {len(raw_search_results)} raw results.")
            articles.extend(trusted_articles)
        return articles

    def _fetch_newsapi(self, topics: list[str], country: str, limit: int) -> list[NewsArticle]:
        articles: list[NewsArticle] = []
        topics_to_search = [topic.strip() for topic in topics if topic and topic.strip()]
        if not topics_to_search:
            return []

        page_size = NEWSAPI_MAX_PAGE_SIZE
        for topic in topics_to_search:
            try:
                print(f"DEBUG: Attempting to call News API for topic: {topic}")
                response = requests.get(
                    "https://newsapi.org/v2/everything",
                    params={
                        "apiKey": self.settings.newsapi_api_key,
                        "q": f"{topic} news",

                        "language": "en",
                        "sortBy": "publishedAt",
                        "pageSize": min(page_size, 100),
                    },
                    timeout=self.timeout,
                )
                print(f"DEBUG API Status: {response.status_code} - {response.text}")
                response.raise_for_status()
                payload = response.json()
            except Exception as e:
                import traceback

                print(f"DEBUG API Exception: {e}")
                traceback.print_exc()
                continue
            if payload.get("status") != "ok":
                continue

            raw_search_results = payload.get("articles", [])
            trusted_articles: list[NewsArticle] = []
            for item in raw_search_results:
                article_url = (item.get("url") or "").strip()
                if not article_url:
                    continue
                source = item.get("source") or {}
                candidate_article = NewsArticle(
                    title=(item.get("title") or "Untitled").strip(),
                    url=article_url,
                    source=(source.get("name") or "NewsAPI").strip(),
                    topic=topic,
                    description=(item.get("description") or "").strip(),
                    published_at=(item.get("publishedAt") or "").strip(),
                    image_url=(item.get("urlToImage") or "").strip(),
                )
                if "transcript" in article_url.lower() or "earnings" in candidate_article.title.lower():
                    print(f"DEBUG: Rejecting junk source: {article_url}")
                    continue
                trusted_articles.append(candidate_article)
                if len(trusted_articles) >= 3:
                    break
            print(f"DEBUG: Filtered down to {len(trusted_articles)} trusted sources from {len(raw_search_results)} raw results.")
            articles.extend(trusted_articles)
        return articles

    @staticmethod
    def _dedupe_by_url(articles: list[NewsArticle]) -> list[NewsArticle]:
        deduped: list[NewsArticle] = []
        seen: set[str] = set()
        for article in articles:
            key = article.url.strip().lower()
            if not key or key in seen:
                continue
            seen.add(key)
            deduped.append(article)
        return deduped

    @staticmethod
    def _exclude_topics(articles: list[NewsArticle], excluded: list[str]) -> list[NewsArticle]:
        if not excluded:
            return articles

        filtered: list[NewsArticle] = []
        for article in articles:
            haystack = f"{article.title} {article.description}".lower()
            if any(term in haystack for term in excluded):
                continue
            filtered.append(article)
        return filtered

