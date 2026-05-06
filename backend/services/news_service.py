from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

import requests
import trafilatura

from core.config import Settings


@dataclass
class NewsArticle:
    title: str
    url: str
    source: str
    description: str = ""
    published_at: str = ""
    image_url: str = ""


class NewsService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.timeout = settings.request_timeout_seconds

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

        for raw_url in urls:
            url = raw_url.strip()
            if not url or url in seen:
                continue
            seen.add(url)

            try:
                page = trafilatura.fetch_url(url)
                if not page:
                    continue

                extracted = trafilatura.extract(
                    page,
                    include_comments=False,
                    include_tables=False,
                    favor_precision=True,
                )
            except Exception:
                continue

            if not extracted:
                continue

            cleaned = self.clean_text(extracted)[: self.settings.max_article_chars]
            if len(cleaned) < min_chars:
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

        # NewsData free tier rejects larger sizes and can return 422 for malformed boolean query strings.
        # Query each topic independently so requests handles URL encoding for each term safely.
        size = min(max(limit, 1), 5)

        for topic in topics_to_search:
            try:
                response = requests.get(
                    "https://newsdata.io/api/1/news",
                    params={
                        "apikey": self.settings.newsdata_api_key,
                        "q": topic,
                        "country": country,
                        "language": "en",
                        "size": size,
                    },
                    timeout=self.timeout,
                )
                response.raise_for_status()
                payload = response.json()
            except requests.RequestException:
                continue
            except ValueError:
                continue

            if payload.get("status") != "success":
                continue

            for item in payload.get("results", []):
                url = (item.get("link") or "").strip()
                if not url:
                    continue
                articles.append(
                    NewsArticle(
                        title=(item.get("title") or "Untitled").strip(),
                        url=url,
                        source=(item.get("source_id") or "NewsData").strip(),
                        description=(item.get("description") or "").strip(),
                        published_at=(item.get("pubDate") or "").strip(),
                        image_url=(item.get("image_url") or "").strip(),
                    )
                )
        return articles

    def _fetch_newsapi(self, topics: list[str], country: str, limit: int) -> list[NewsArticle]:
        response = requests.get(
            "https://newsapi.org/v2/top-headlines",
            params={
                "apiKey": self.settings.newsapi_api_key,
                "q": " OR ".join(topics),
                "country": country,
                "pageSize": min(max(limit, 10), 100),
            },
            timeout=self.timeout,
        )
        response.raise_for_status()
        payload = response.json()
        if payload.get("status") != "ok":
            return []

        articles: list[NewsArticle] = []
        for item in payload.get("articles", []):
            url = (item.get("url") or "").strip()
            if not url:
                continue
            source = item.get("source") or {}
            articles.append(
                NewsArticle(
                    title=(item.get("title") or "Untitled").strip(),
                    url=url,
                    source=(source.get("name") or "NewsAPI").strip(),
                    description=(item.get("description") or "").strip(),
                    published_at=(item.get("publishedAt") or "").strip(),
                    image_url=(item.get("urlToImage") or "").strip(),
                )
            )
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

