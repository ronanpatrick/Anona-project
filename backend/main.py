from __future__ import annotations

import asyncio
import re
from datetime import datetime, timezone
from typing import Literal

import requests
import trafilatura
import uvicorn
import yfinance as yf
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
    user_id: str | None = None
    tone: ToneType = "Professional"
    country: str = "us"
    limit: int = Field(default=5, ge=1, le=10)


class ArticleSummary(BaseModel):
    title: str
    sources: list[str]
    urls: list[str]
    summary: str
    image_url: str | None = None


class DigestResponse(BaseModel):
    articles: list[ArticleSummary]
    count: int


class DeepDiveResponse(BaseModel):
    url: str
    analysis: str


class MarketSnapshotItem(BaseModel):
    symbol: str
    short_name: str
    current_price: float
    change_percent: float


class SportsScoreboardGame(BaseModel):
    sport: str
    event_id: str
    away_team: str
    away_logo: str | None = None
    away_score: str
    home_team: str
    home_logo: str | None = None
    home_score: str
    status: str
    state: str
    start_time: str | None = None


_DEFAULT_MARKET_INDICES = ["^GSPC", "^DJI", "^IXIC"]
_INDEX_SHORT_NAMES = {
    "^GSPC": "S&P 500",
    "^DJI": "Dow Jones",
    "^IXIC": "Nasdaq Composite",
}
_SUPPORTED_SPORTS: dict[str, tuple[str, str]] = {
    "nba": ("basketball", "nba"),
    "nfl": ("football", "nfl"),
    "mlb": ("baseball", "mlb"),
    "nhl": ("hockey", "nhl"),
}
_SPORT_ALIASES = {
    "basketball": "nba",
    "nba": "nba",
    "football": "nfl",
    "nfl": "nfl",
    "baseball": "mlb",
    "mlb": "mlb",
    "hockey": "nhl",
    "nhl": "nhl",
}
_TEAM_SPORT_HINTS = {
    "lakers": "nba",
    "warriors": "nba",
    "yankees": "mlb",
    "red sox": "mlb",
}


_STORY_STOPWORDS = {
    "after",
    "amid",
    "also",
    "an",
    "and",
    "are",
    "at",
    "for",
    "from",
    "has",
    "have",
    "into",
    "its",
    "new",
    "over",
    "said",
    "says",
    "that",
    "the",
    "their",
    "this",
    "was",
    "were",
    "with",
}


def _verify_user_if_present(authorization: str | None) -> str | None:
    if not authorization:
        return None
    if not supabase_client:
        raise HTTPException(status_code=500, detail="Supabase is not configured")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    try:
        user_response = supabase_client.auth.get_user(token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"User verification failed: {exc}") from exc
    user = getattr(user_response, "user", None)
    if not user:
        raise HTTPException(status_code=401, detail="User verification failed")
    user_id = str(getattr(user, "id", "")).strip()
    return user_id or None


def _require_supabase() -> Client:
    if not supabase_client:
        raise HTTPException(status_code=500, detail="Supabase is not configured")
    return supabase_client


def _resolve_digest_user_id(
    request_user_id: str | None,
    authorization: str | None,
    query_user_id: str | None = None,
) -> str:
    token_user_id = _verify_user_if_present(authorization)
    body_user_id = (request_user_id or "").strip() or None
    fallback_query_user_id = (query_user_id or "").strip() or None

    if token_user_id and body_user_id and token_user_id != body_user_id:
        raise HTTPException(status_code=401, detail="Token user_id does not match request user_id")
    if token_user_id and fallback_query_user_id and token_user_id != fallback_query_user_id:
        raise HTTPException(status_code=401, detail="Token user_id does not match query user_id")

    user_id = token_user_id or body_user_id or fallback_query_user_id
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id is required in token, request body, or query")
    return user_id


def _today_digest_date() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _get_cached_daily_digest(user_id: str, current_date: str) -> DigestResponse | None:
    client = _require_supabase()
    try:
        result = (
            client.table("daily_digests")
            .select("digest_data")
            .eq("user_id", user_id)
            .eq("date", current_date)
            .maybe_single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Daily digest cache lookup failed: {exc}") from exc

    row = getattr(result, "data", None)
    if not isinstance(row, dict):
        return None
    digest_data = row.get("digest_data")
    if not isinstance(digest_data, dict):
        return None
    try:
        return DigestResponse.model_validate(digest_data)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Stored daily digest is invalid: {exc}") from exc


def _digest_response_json(response: DigestResponse) -> dict:
    if hasattr(response, "model_dump"):
        return response.model_dump()
    return response.dict()


def _store_daily_digest(user_id: str, current_date: str, digest: DigestResponse) -> None:
    client = _require_supabase()
    payload = {
        "user_id": user_id,
        "date": current_date,
        "digest_data": _digest_response_json(digest),
    }
    try:
        client.table("daily_digests").insert(payload).execute()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Daily digest cache write failed: {exc}") from exc


def _article_summary_json(article: ArticleSummary) -> dict:
    if hasattr(article, "model_dump"):
        return article.model_dump()
    return article.dict()


def _get_cached_daily_discovery(user_id: str, current_date: str) -> list[ArticleSummary] | None:
    client = _require_supabase()
    try:
        result = (
            client.table("daily_discovery")
            .select("discovery_data")
            .eq("user_id", user_id)
            .eq("date", current_date)
            .maybe_single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Daily discovery cache lookup failed: {exc}") from exc

    row = getattr(result, "data", None)
    if not isinstance(row, dict):
        return None
    discovery_data = row.get("discovery_data")
    if not isinstance(discovery_data, list):
        return None
    try:
        return [ArticleSummary.model_validate(item) for item in discovery_data if isinstance(item, dict)]
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Stored daily discovery is invalid: {exc}") from exc


def _store_daily_discovery(user_id: str, current_date: str, discovery: list[ArticleSummary]) -> None:
    client = _require_supabase()
    payload = {
        "user_id": user_id,
        "date": current_date,
        "discovery_data": [_article_summary_json(item) for item in discovery],
    }
    try:
        client.table("daily_discovery").insert(payload).execute()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Daily discovery cache write failed: {exc}") from exc


def _normalize_topic_terms(items: list[str] | None) -> list[str]:
    if not items:
        return []
    deduped: list[str] = []
    seen: set[str] = set()
    for item in items:
        term = item.strip().lower()
        if not term or term in seen:
            continue
        seen.add(term)
        deduped.append(term)
    return deduped


def _normalize_stock_symbols(items: list[str] | None) -> list[str]:
    if not items:
        return []
    deduped: list[str] = []
    seen: set[str] = set()
    for item in items:
        raw = item.strip().upper()
        if not raw:
            continue
        if not re.fullmatch(r"\^?[A-Z0-9.\-]{1,12}", raw):
            continue
        if raw in seen:
            continue
        seen.add(raw)
        deduped.append(raw)
    return deduped


def _load_user_stock_tickers(user_id: str | None) -> list[str]:
    if not user_id or not supabase_client:
        return []
    try:
        row = (
            supabase_client.table("user_preferences")
            .select("stock_tickers")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        return []
    data = getattr(row, "data", None)
    if not isinstance(data, dict):
        return []
    stock_tickers = data.get("stock_tickers")
    if not isinstance(stock_tickers, list):
        return []
    return _normalize_stock_symbols([item for item in stock_tickers if isinstance(item, str)])


def _normalize_sport_key(value: str) -> str | None:
    normalized = value.strip().lower()
    if not normalized:
        return None
    return _SPORT_ALIASES.get(normalized)


def _normalize_team_token(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def _load_user_sports_profile(user_id: str | None) -> tuple[list[str], list[str]]:
    if not user_id or not supabase_client:
        return (["nba", "nfl"], [])
    try:
        row = (
            supabase_client.table("user_preferences")
            .select("sports_teams")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        return (["nba", "nfl"], [])

    data = getattr(row, "data", None)
    if not isinstance(data, dict):
        return (["nba", "nfl"], [])

    raw_sports_teams = data.get("sports_teams")
    if not isinstance(raw_sports_teams, list):
        return (["nba", "nfl"], [])

    sports: list[str] = []
    seen_sports: set[str] = set()
    favorite_teams: list[str] = []
    seen_teams: set[str] = set()

    for raw_item in raw_sports_teams:
        if not isinstance(raw_item, str):
            continue
        item = raw_item.strip()
        if not item:
            continue

        left, separator, right = item.partition(":")
        if separator:
            sport = _normalize_sport_key(left)
            team_name = right.strip()
            if sport and sport not in seen_sports:
                seen_sports.add(sport)
                sports.append(sport)
            if team_name:
                normalized_team = _normalize_team_token(team_name)
                if normalized_team not in seen_teams:
                    seen_teams.add(normalized_team)
                    favorite_teams.append(team_name)
            continue

        sport = _normalize_sport_key(item)
        if sport and sport not in seen_sports:
            seen_sports.add(sport)
            sports.append(sport)
            continue

        normalized_team = _normalize_team_token(item)
        if normalized_team not in seen_teams:
            seen_teams.add(normalized_team)
            favorite_teams.append(item)
        hinted_sport = _TEAM_SPORT_HINTS.get(normalized_team)
        if hinted_sport and hinted_sport not in seen_sports:
            seen_sports.add(hinted_sport)
            sports.append(hinted_sport)

    if not sports:
        sports = ["nba", "nfl"]
    return sports, favorite_teams


def _coerce_float(value: object) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        number = float(value)
    elif isinstance(value, str):
        normalized = value.strip().replace(",", "")
        if not normalized:
            return None
        try:
            number = float(normalized)
        except ValueError:
            return None
    else:
        return None
    if number != number:
        return None
    return number


def _mapping_lookup(mapping: object, keys: tuple[str, ...]) -> object:
    if mapping is None:
        return None
    for key in keys:
        value = None
        if hasattr(mapping, "get"):
            value = mapping.get(key)
        elif isinstance(mapping, dict):
            value = mapping.get(key)
        if value is not None:
            return value
    return None


def _load_ticker_info(ticker: yf.Ticker) -> dict[str, object] | None:
    try:
        info = ticker.info
    except Exception:
        return None
    if not isinstance(info, dict):
        return None
    return info


def _resolve_market_short_name(symbol: str, info: dict[str, object] | None) -> str:
    if symbol in _INDEX_SHORT_NAMES:
        return _INDEX_SHORT_NAMES[symbol]
    if isinstance(info, dict):
        short_name = str(info.get("shortName") or info.get("longName") or "").strip()
        if short_name:
            return short_name
    return symbol


def _build_market_symbols(user_tickers: list[str]) -> list[str]:
    combined = [*_DEFAULT_MARKET_INDICES, *user_tickers]
    deduped: list[str] = []
    seen: set[str] = set()
    for symbol in combined:
        if symbol in seen:
            continue
        seen.add(symbol)
        deduped.append(symbol)
    return deduped


def _fetch_sports_games_for_league(sport: str) -> list[SportsScoreboardGame]:
    sport_route = _SUPPORTED_SPORTS.get(sport)
    if not sport_route:
        return []

    sport_name, league_name = sport_route
    url = f"https://site.api.espn.com/apis/site/v2/sports/{sport_name}/{league_name}/scoreboard"
    response = requests.get(url, timeout=settings.request_timeout_seconds)
    response.raise_for_status()
    payload = response.json()
    events = payload.get("events")
    if not isinstance(events, list):
        return []

    games: list[SportsScoreboardGame] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        competition = None
        competitions = event.get("competitions")
        if isinstance(competitions, list) and competitions:
            competition = competitions[0]
        if not isinstance(competition, dict):
            continue

        competitors = competition.get("competitors")
        if not isinstance(competitors, list) or not competitors:
            continue

        away_competitor = None
        home_competitor = None
        for competitor in competitors:
            if not isinstance(competitor, dict):
                continue
            home_away = str(competitor.get("homeAway") or "").strip().lower()
            if home_away == "away":
                away_competitor = competitor
            elif home_away == "home":
                home_competitor = competitor

        if away_competitor is None or home_competitor is None:
            continue

        away_team = away_competitor.get("team") if isinstance(away_competitor.get("team"), dict) else {}
        home_team = home_competitor.get("team") if isinstance(home_competitor.get("team"), dict) else {}
        event_status = event.get("status") if isinstance(event.get("status"), dict) else {}
        status_type = event_status.get("type") if isinstance(event_status.get("type"), dict) else {}

        detail_text = str(status_type.get("shortDetail") or status_type.get("detail") or "Scheduled").strip()
        state_key = str(status_type.get("state") or "").strip().lower()
        state = "upcoming"
        if state_key == "in":
            state = "live"
        elif state_key == "post":
            state = "final"

        games.append(
            SportsScoreboardGame(
                sport=sport,
                event_id=str(event.get("id") or "").strip(),
                away_team=str(away_team.get("displayName") or away_team.get("shortDisplayName") or "").strip(),
                away_logo=str(away_team.get("logo") or "").strip() or None,
                away_score=str(away_competitor.get("score") or "0").strip(),
                home_team=str(home_team.get("displayName") or home_team.get("shortDisplayName") or "").strip(),
                home_logo=str(home_team.get("logo") or "").strip() or None,
                home_score=str(home_competitor.get("score") or "0").strip(),
                status=detail_text or "Scheduled",
                state=state,
                start_time=str(event.get("date") or "").strip() or None,
            )
        )

    return games


def _is_favorite_game(game: SportsScoreboardGame, favorite_teams: set[str]) -> bool:
    if not favorite_teams:
        return False
    away_tokens = _normalize_team_token(game.away_team)
    home_tokens = _normalize_team_token(game.home_team)
    for team in favorite_teams:
        if team and (team in away_tokens or team in home_tokens):
            return True
    return False


def _fetch_market_snapshot_item(symbol: str) -> MarketSnapshotItem | None:
    ticker = yf.Ticker(symbol)
    fast_info = getattr(ticker, "fast_info", None)

    current_price = _coerce_float(
        _mapping_lookup(
            fast_info,
            ("lastPrice", "last_price", "regularMarketPrice", "regular_market_price"),
        )
    )
    previous_close = _coerce_float(
        _mapping_lookup(
            fast_info,
            (
                "previousClose",
                "previous_close",
                "regularMarketPreviousClose",
                "regular_market_previous_close",
            ),
        )
    )

    info: dict[str, object] | None = None
    if current_price is None or previous_close is None or symbol not in _INDEX_SHORT_NAMES:
        info = _load_ticker_info(ticker)

    if current_price is None and isinstance(info, dict):
        current_price = _coerce_float(
            info.get("regularMarketPrice")
            or info.get("currentPrice")
            or info.get("navPrice")
            or info.get("bid")
        )
    if previous_close is None and isinstance(info, dict):
        previous_close = _coerce_float(
            info.get("regularMarketPreviousClose")
            or info.get("previousClose")
            or info.get("navPreviousClose")
        )

    if current_price is None or previous_close is None:
        history = ticker.history(period="5d", interval="1d", auto_adjust=False)
        if not history.empty and "Close" in history:
            close_values = [_coerce_float(value) for value in history["Close"].tolist()]
            closes = [value for value in close_values if value is not None]
            if current_price is None and closes:
                current_price = closes[-1]
            if previous_close is None:
                if len(closes) >= 2:
                    previous_close = closes[-2]
                elif closes:
                    previous_close = closes[-1]

    if current_price is None or previous_close is None or previous_close == 0:
        return None

    change_percent = ((current_price - previous_close) / previous_close) * 100
    return MarketSnapshotItem(
        symbol=symbol,
        short_name=_resolve_market_short_name(symbol, info),
        current_price=current_price,
        change_percent=change_percent,
    )


def _load_user_excluded_topics(user_id: str | None) -> list[str]:
    if not user_id or not supabase_client:
        return []
    try:
        row = (
            supabase_client.table("user_preferences")
            .select("selected_topics,sports_teams,stock_tickers")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        return []
    if not getattr(row, "data", None) or not isinstance(row.data, dict):
        return []

    selected = row.data.get("selected_topics") or []
    sports = row.data.get("sports_teams") or []
    stocks = row.data.get("stock_tickers") or []

    collected: list[str] = []
    for group in (selected, sports, stocks):
        if not isinstance(group, list):
            continue
        for item in group:
            if isinstance(item, str):
                collected.append(item)
    return _normalize_topic_terms(collected)


def _story_tokens(article: NewsArticle) -> set[str]:
    haystack = f"{article.title} {article.description}".lower()
    tokens = re.findall(r"[a-z0-9]+", haystack)
    return {
        token
        for token in tokens
        if len(token) >= 2 and token not in _STORY_STOPWORDS and not token.isdigit()
    }


def _derive_topics_from_articles(articles: list[NewsArticle], max_topics: int) -> list[str]:
    token_counts: dict[str, int] = {}
    for article in articles:
        for token in _story_tokens(article):
            token_counts[token] = token_counts.get(token, 0) + 1

    ranked_tokens = sorted(token_counts.items(), key=lambda item: item[1], reverse=True)
    derived = [token for token, _ in ranked_tokens[:max_topics]]
    return derived or ["trending"]


def _topic_tokens(topic: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", topic.lower()) if token not in _STORY_STOPWORDS}


def _cluster_by_topics(
    articles: list[NewsArticle],
    topics: list[str],
    max_clusters: int,
    max_sources_per_cluster: int = 10,
) -> list[tuple[str, list[NewsArticle]]]:
    normalized_topics = [topic.strip() for topic in topics if topic and topic.strip()]
    if not normalized_topics:
        normalized_topics = _derive_topics_from_articles(articles, max_topics=max_clusters)

    topic_token_map = {topic: _topic_tokens(topic) for topic in normalized_topics}
    grouped: dict[str, list[NewsArticle]] = {topic: [] for topic in normalized_topics}

    for article in articles:
        article_tokens = _story_tokens(article)
        best_topic: str | None = None
        best_score = 0.0
        for topic, tokens in topic_token_map.items():
            if not tokens:
                continue
            score = float(len(article_tokens & tokens))
            if score > best_score:
                best_score = score
                best_topic = topic

        if best_topic:
            grouped[best_topic].append(article)
        elif len(normalized_topics) == 1:
            grouped[normalized_topics[0]].append(article)
        else:
            smallest_topic = min(normalized_topics, key=lambda topic: len(grouped[topic]))
            grouped[smallest_topic].append(article)

    ranked_topics = sorted(normalized_topics, key=lambda topic: len(grouped[topic]), reverse=True)
    selected_clusters: list[tuple[str, list[NewsArticle]]] = []
    for topic in ranked_topics[:max_clusters]:
        cluster_articles = grouped[topic]
        deduped_articles: list[NewsArticle] = []
        seen_urls: set[str] = set()
        for article in cluster_articles:
            normalized_url = article.url.strip().lower()
            if not normalized_url or normalized_url in seen_urls:
                continue
            seen_urls.add(normalized_url)
            deduped_articles.append(article)
            if len(deduped_articles) >= max_sources_per_cluster:
                break
        if deduped_articles:
            selected_clusters.append((topic, deduped_articles))
    return selected_clusters


async def _scrape_single_url(url: str, min_chars: int) -> tuple[str, str] | None:
    try:
        page = await asyncio.to_thread(trafilatura.fetch_url, url)
        if not page:
            return None
        extracted = await asyncio.to_thread(
            trafilatura.extract,
            page,
            include_comments=False,
            include_tables=False,
            favor_precision=True,
        )
    except Exception:
        return None

    if not extracted:
        return None

    cleaned = news_service.clean_text(extracted)[: settings.max_article_chars]
    if len(cleaned) < min_chars:
        return None
    return url, cleaned


async def _scrape_urls_parallel(
    urls: list[str],
    max_articles: int,
    min_chars: int = 220,
) -> list[dict[str, str]]:
    unique_urls: list[str] = []
    seen_urls: set[str] = set()
    for raw_url in urls:
        url = raw_url.strip()
        normalized = url.lower()
        if not url or normalized in seen_urls:
            continue
        seen_urls.add(normalized)
        unique_urls.append(url)

    semaphore = asyncio.Semaphore(10)

    async def _bounded_scrape(url: str) -> tuple[str, str] | None:
        async with semaphore:
            return await _scrape_single_url(url, min_chars=min_chars)

    raw_results = await asyncio.gather(*(_bounded_scrape(url) for url in unique_urls), return_exceptions=True)
    scraped: list[dict[str, str]] = []
    for item in raw_results:
        if isinstance(item, Exception) or item is None:
            continue
        url, text = item
        scraped.append({"url": url, "text": text})
        if len(scraped) >= max_articles:
            break
    return scraped


def _scrape_urls_parallel_bridge(
    urls: list[str],
    max_articles: int,
    min_chars: int = 220,
) -> list[dict[str, str]]:
    return asyncio.run(_scrape_urls_parallel(urls=urls, max_articles=max_articles, min_chars=min_chars))


def _build_summaries(
    articles: list[NewsArticle],
    topics: list[str],
    tone: ToneType,
    limit: int,
) -> list[ArticleSummary]:
    clusters = _cluster_by_topics(
        articles=articles,
        topics=topics,
        max_clusters=limit,
        max_sources_per_cluster=10,
    )
    if not clusters:
        return []

    urls_to_scrape = [article.url for _, cluster in clusters for article in cluster]
    scraped = _scrape_urls_parallel_bridge(urls=urls_to_scrape, max_articles=len(urls_to_scrape))
    scraped_by_url = {item["url"]: item["text"] for item in scraped}

    summaries: list[ArticleSummary] = []
    for topic_name, cluster in clusters:
        candidates: list[dict[str, str]] = []
        for article in cluster:
            text = scraped_by_url.get(article.url)
            if not text:
                continue
            candidates.append(
                {
                    "url": article.url,
                    "title": article.title,
                    "source": article.source.strip() or "Unknown",
                    "image_url": article.image_url.strip(),
                    "text": text,
                }
            )

        reports: list[dict[str, str]] = []
        seen_urls: set[str] = set()
        seen_sources: set[str] = set()
        for item in candidates:
            normalized_url = item["url"].strip().lower()
            normalized_source = item["source"].strip().lower()
            if not normalized_url or normalized_url in seen_urls or normalized_source in seen_sources:
                continue
            seen_urls.add(normalized_url)
            seen_sources.add(normalized_source)
            reports.append(item)
            if len(reports) >= 10:
                break

        if len(reports) < 10:
            for item in candidates:
                normalized_url = item["url"].strip().lower()
                if not normalized_url or normalized_url in seen_urls:
                    continue
                seen_urls.add(normalized_url)
                reports.append(item)
                if len(reports) >= 10:
                    break

        if not reports:
            continue

        print(f"Grouping {topic_name}: found {len(reports)} articles for synthesis.")
        summary = ai_service.synthesize_story(reports=reports, tone=tone)
        sources: list[str] = []
        source_seen: set[str] = set()
        for report in reports:
            source = report["source"].strip()
            normalized_source = source.lower()
            if not source or normalized_source in source_seen:
                continue
            source_seen.add(normalized_source)
            sources.append(source)

        urls: list[str] = []
        url_seen: set[str] = set()
        for report in reports:
            url = report["url"].strip()
            normalized_url = url.lower()
            if not url or normalized_url in url_seen:
                continue
            url_seen.add(normalized_url)
            urls.append(url)

        if len(sources) < 2 and len(candidates) > len(reports):
            for item in candidates:
                source = item["source"].strip()
                normalized_source = source.lower()
                if not source or normalized_source in source_seen:
                    continue
                source_seen.add(normalized_source)
                sources.append(source)
                if len(sources) >= 2:
                    break

        image_url: str | None = None
        for item in reports:
            candidate_url = item.get("image_url", "").strip()
            has_valid_scheme = candidate_url.startswith(("http://", "https://"))
            if has_valid_scheme:
                image_url = candidate_url
                break
        if image_url is None:
            for item in candidates:
                candidate_url = item.get("image_url", "").strip()
                has_valid_scheme = candidate_url.startswith(("http://", "https://"))
                if has_valid_scheme:
                    image_url = candidate_url
                    break

        summaries.append(
            ArticleSummary(
                title=cluster[0].title,
                sources=sources,
                urls=urls,
                summary=summary,
                image_url=image_url,
            )
        )
    return summaries


def _friendly_empty_digest() -> DigestResponse:
    return DigestResponse(
        articles=[
            ArticleSummary(
                title="No scrapeable articles right now",
                sources=["Anona"],
                urls=[],
                summary="We could not scrape article content at the moment. Please try again shortly.",
                image_url=None,
            )
        ],
        count=1,
    )


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str | bool]:
    return {"status": "ok", "supabase_configured": bool(supabase_client)}


@app.post("/get-daily-digest", response_model=DigestResponse, tags=["digest"])
def get_daily_digest(
    request: DailyDigestRequest,
    authorization: str | None = Header(default=None),
    user_id: str | None = Query(default=None),
) -> DigestResponse:
    user_id = _resolve_digest_user_id(request.user_id, authorization, query_user_id=user_id)
    current_date = _today_digest_date()
    cached_digest = _get_cached_daily_digest(user_id=user_id, current_date=current_date)
    if cached_digest:
        return cached_digest

    if not request.topics:
        raise HTTPException(status_code=400, detail="Topics list cannot be empty")

    try:
        articles = news_service.fetch_news(
            topics=request.topics,
            country=request.country,
            limit=50,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        summaries = _build_summaries(
            articles=articles,
            topics=request.topics,
            tone=request.tone,
            limit=request.limit,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc
    digest_response = (
        DigestResponse(articles=summaries, count=len(summaries)) if summaries else _friendly_empty_digest()
    )

    try:
        _store_daily_digest(user_id=user_id, current_date=current_date, digest=digest_response)
    except HTTPException as cache_write_error:
        cached_after_write_failure = _get_cached_daily_digest(user_id=user_id, current_date=current_date)
        if cached_after_write_failure:
            return cached_after_write_failure
        raise cache_write_error

    return digest_response


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
        analysis = ai_service.summarize_deep_dive(text=scraped[0]["text"], tone=tone)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc
    return DeepDiveResponse(url=url, analysis=analysis)


@app.get("/get-discovery-news", response_model=list[ArticleSummary], tags=["discovery"])
def get_discovery_news(
    excluded_topics: list[str] | None = Query(default=None),
    tone: ToneType = Query(default="Professional"),
    country: str = Query(default="us"),
    limit: int = Query(default=5, ge=3, le=5),
    authorization: str | None = Header(default=None),
    user_id: str | None = Query(default=None),
) -> list[ArticleSummary]:
    user_id = _resolve_digest_user_id(request_user_id=None, authorization=authorization, query_user_id=user_id)
    current_date = _today_digest_date()
    cached_discovery = _get_cached_daily_discovery(user_id=user_id, current_date=current_date)
    if cached_discovery is not None:
        return cached_discovery

    user_excluded_topics = _load_user_excluded_topics(user_id)
    combined_excluded_topics = _normalize_topic_terms([*(excluded_topics or []), *user_excluded_topics])

    discovery_queries = [
        "top headlines",
        "breaking news",
        "world",
        "innovation",
        "science discovery",
        "space",
        "global economy",
        "public health",
    ]

    try:
        articles = news_service.fetch_news(
            topics=discovery_queries,
            country=country,
            limit=30,
            exclude_topics=combined_excluded_topics,
            discovery=True,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    if not articles:
        _store_daily_discovery(user_id=user_id, current_date=current_date, discovery=[])
        return []

    urls_to_scrape = [article.url for article in articles[: max(limit * 2, limit)]]
    scraped = _scrape_urls_parallel_bridge(urls=urls_to_scrape, max_articles=len(urls_to_scrape), min_chars=120)
    scraped_by_url = {item["url"]: item["text"] for item in scraped}

    summaries: list[ArticleSummary] = []
    seen_urls: set[str] = set()
    for article in articles:
        normalized_url = article.url.strip().lower()
        if not normalized_url or normalized_url in seen_urls:
            continue
        seen_urls.add(normalized_url)

        source_text = scraped_by_url.get(article.url, "").strip()
        if not source_text:
            source_text = article.description.strip() or article.title.strip()
        if not source_text:
            continue

        try:
            bite_sized_summary = ai_service.summarize_discovery_bite(
                title=article.title,
                text=source_text,
                tone=tone,
            )
        except Exception as exc:
            raise HTTPException(status_code=503, detail=f"Summarization failed: {exc}") from exc

        summaries.append(
            ArticleSummary(
                title=article.title,
                sources=[article.source.strip() or "Unknown"],
                urls=[article.url],
                summary=bite_sized_summary,
                image_url=article.image_url.strip() or None,
            )
        )
        if len(summaries) >= limit:
            break

    try:
        _store_daily_discovery(user_id=user_id, current_date=current_date, discovery=summaries)
    except HTTPException as cache_write_error:
        cached_after_write_failure = _get_cached_daily_discovery(user_id=user_id, current_date=current_date)
        if cached_after_write_failure is not None:
            return cached_after_write_failure
        raise cache_write_error

    return summaries


@app.get("/get-market-snapshot", response_model=list[MarketSnapshotItem], tags=["market"])
def get_market_snapshot(
    authorization: str | None = Header(default=None),
    user_id: str | None = Query(default=None),
) -> list[MarketSnapshotItem]:
    resolved_user_id = _resolve_digest_user_id(
        request_user_id=None,
        authorization=authorization,
        query_user_id=user_id,
    )
    user_tickers = _load_user_stock_tickers(resolved_user_id)
    symbols = _build_market_symbols(user_tickers)

    snapshot: list[MarketSnapshotItem] = []
    for symbol in symbols:
        try:
            item = _fetch_market_snapshot_item(symbol)
        except Exception as exc:
            if symbol in _DEFAULT_MARKET_INDICES:
                raise HTTPException(
                    status_code=503,
                    detail=f"Market snapshot fetch failed for {symbol}: {exc}",
                ) from exc
            continue
        if item is not None:
            snapshot.append(item)

    if not snapshot:
        raise HTTPException(status_code=503, detail="Unable to fetch market snapshot")

    return snapshot


@app.get("/get-sports-scoreboard", response_model=dict[str, list[SportsScoreboardGame]], tags=["sports"])
def get_sports_scoreboard(
    authorization: str | None = Header(default=None),
    user_id: str | None = Query(default=None),
) -> dict[str, list[SportsScoreboardGame]]:
    resolved_user_id = _resolve_digest_user_id(
        request_user_id=None,
        authorization=authorization,
        query_user_id=user_id,
    )
    selected_sports, favorite_teams = _load_user_sports_profile(resolved_user_id)
    favorite_tokens = {_normalize_team_token(team) for team in favorite_teams if team.strip()}

    response: dict[str, list[SportsScoreboardGame]] = {"your_teams": []}
    your_team_ids: set[str] = set()
    successful_fetches = 0

    for sport in selected_sports:
        if sport not in _SUPPORTED_SPORTS:
            continue
        try:
            games = _fetch_sports_games_for_league(sport)
        except requests.RequestException:
            response[sport] = []
            continue
        successful_fetches += 1
        response[sport] = games
        for game in games:
            game_id = f"{game.sport}:{game.event_id}"
            if game_id in your_team_ids:
                continue
            if _is_favorite_game(game, favorite_tokens):
                your_team_ids.add(game_id)
                response["your_teams"].append(game)

    if successful_fetches == 0:
        raise HTTPException(status_code=503, detail="Unable to fetch sports scoreboard")

    return response


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

