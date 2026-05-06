from __future__ import annotations

from typing import Literal

import uvicorn
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from supabase import Client, create_client

from core.config import get_settings
from services.ai_service import AIService
from services.news_service import NewsArticle, NewsService

ToneType = Literal["Professional", "Casual", "Academic", "Friendly", "Direct"]

settings = get_settings()
news_service = NewsService(settings)
ai_service = AIService(settings)

supabase_client: Client | None = None
if settings.supabase_url and settings.supabase_service_key:
    supabase_client = create_client(settings.supabase_url, settings.supabase_service_key)

app = FastAPI(
    title="Anona Backend",
    description="Backend AI pipeline for fetching, scraping, and summarizing news.",
    version="0.3.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class DailyDigestRequest(BaseModel):
    topics: list[str]
    tone: ToneType = "Professional"
    country: str = "us"
    limit: int = Field(default=5, ge=1, le=10)


class ArticleSummary(BaseModel):
    title: str
    source: str
    url: str
    summary: str


class DigestResponse(BaseModel):
    articles: list[ArticleSummary]
    count: int


class DeepDiveResponse(BaseModel):
    url: str
    analysis: str


def _verify_user_if_present(authorization: str | None) -> None:
    if not authorization:
        return
    if not supabase_client:
        raise HTTPException(status_code=500, detail="Supabase is not configured")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    try:
        user_response = supabase_client.auth.get_user(token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"User verification failed: {exc}") from exc
    if not getattr(user_response, "user", None):
        raise HTTPException(status_code=401, detail="User verification failed")


def _build_summaries(
    articles: list[NewsArticle],
    tone: ToneType,
    limit: int,
) -> list[ArticleSummary]:
    urls = [article.url for article in articles]
    scraped = news_service.scrape_urls(urls, max_articles=limit)
    scraped_by_url = {item["url"]: item["text"] for item in scraped}

    summaries: list[ArticleSummary] = []
    for article in articles:
        text = scraped_by_url.get(article.url)
        if not text:
            continue
        summary = ai_service.summarize_text(text=text, tone=tone, bullet_count=5)
        summaries.append(
            ArticleSummary(
                title=article.title,
                source=article.source,
                url=article.url,
                summary=summary,
            )
        )
        if len(summaries) >= limit:
            break
    return summaries


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str | bool]:
    return {"status": "ok", "supabase_configured": bool(supabase_client)}


@app.post("/get-daily-digest", response_model=DigestResponse, tags=["digest"])
def get_daily_digest(
    request: DailyDigestRequest,
    authorization: str | None = Header(default=None),
) -> DigestResponse:
    _verify_user_if_present(authorization)
    if not request.topics:
        raise HTTPException(status_code=400, detail="Topics list cannot be empty")

    try:
        articles = news_service.fetch_news(
            topics=request.topics,
            country=request.country,
            limit=max(request.limit * 3, 15),
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        summaries = _build_summaries(articles=articles, tone=request.tone, limit=min(5, request.limit))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc
    return DigestResponse(articles=summaries, count=len(summaries))


@app.get("/get-deep-dive", response_model=DeepDiveResponse, tags=["analysis"])
def get_deep_dive(
    url: str = Query(min_length=10),
    tone: ToneType = Query(default="Professional"),
    authorization: str | None = Header(default=None),
) -> DeepDiveResponse:
    _verify_user_if_present(authorization)

    scraped = news_service.scrape_urls([url], max_articles=1, min_chars=150)
    if not scraped:
        raise HTTPException(status_code=400, detail="Unable to scrape article content")

    try:
        analysis = ai_service.deep_dive_summary(text=scraped[0]["text"], tone=tone)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc
    return DeepDiveResponse(url=url, analysis=analysis)


@app.get("/get-discovery-news", response_model=DigestResponse, tags=["discovery"])
def get_discovery_news(
    excluded_topics: list[str] | None = Query(default=None),
    tone: ToneType = Query(default="Professional"),
    country: str = Query(default="us"),
    limit: int = Query(default=5, ge=1, le=10),
    authorization: str | None = Header(default=None),
) -> DigestResponse:
    _verify_user_if_present(authorization)

    try:
        articles = news_service.fetch_news(
            topics=[],
            country=country,
            limit=max(limit * 3, 15),
            exclude_topics=excluded_topics or [],
            discovery=True,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        summaries = _build_summaries(articles=articles, tone=tone, limit=min(5, limit))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc
    return DigestResponse(articles=summaries, count=len(summaries))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

