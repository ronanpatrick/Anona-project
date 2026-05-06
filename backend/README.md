# Anona Backend - Phase 3: AI News Pipeline

## Overview

The Anona backend is a FastAPI server that fetches, scrapes, and intelligently summarizes news using Google's Gemini 1.5 Flash API. The backend supports personalized news digests, deep-dive analysis, and discovery content.

## Architecture

### Core Components

1. **main.py** - FastAPI application with all endpoints and core logic
   - Configuration management (Settings class)
   - NewsService for API calls and web scraping
   - AIService for Gemini-powered summarization
   - FastAPI endpoints and request/response models

2. **Dependencies**
   - `fastapi` - Web framework
   - `uvicorn` - ASGI server
   - `python-dotenv` - Environment variable management
   - `requests` - HTTP client for news APIs
   - `trafilatura` - Web scraping for full article text
   - `google-generativeai` - Gemini API client
   - `supabase` - Supabase client (for future user verification)

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file in the backend directory with:

```
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_supabase_service_key
NEWSDATA_API_KEY=your_newsdata_api_key
GEMINI_API_KEY=your_google_gemini_api_key
```

**Note:** Get your keys from:
- **NewsData.io**: https://newsdata.io/ (free tier available)
- **Google Gemini**: https://aistudio.google.com/app/apikeys
- **Supabase**: Your Anona project dashboard

### 3. Run the Server

```bash
python main.py
```

The server will start on `http://localhost:8000`

**Documentation:**
- Interactive API docs: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

### Health Check

**GET** `/health`

Returns server status.

```bash
curl http://localhost:8000/health
```

Response:
```json
{"status": "ok"}
```

---

### Daily Digest

**POST** `/get-daily-digest`

Fetches and summarizes trending news on user-specified topics.

**Request Body:**
```json
{
  "topics": ["technology", "artificial intelligence"],
  "tone": "Professional",
  "country": "us",
  "limit": 5
}
```

**Parameters:**
- `topics` (list[str], required): Topics to search for
- `tone` (string, default: "Professional"): Summary tone - one of `Professional`, `Casual`, `Academic`, `Friendly`
- `country` (string, default: "us"): Country code for news (e.g., "us", "gb", "ca")
- `limit` (int, default: 5): Number of articles to return (max 10)

**Response:**
```json
{
  "articles": [
    {
      "title": "Article Title",
      "source": "TechNews",
      "url": "https://example.com/article",
      "summary": "• Key point 1\n• Key point 2\n• Key point 3\n• Key point 4\n• Key point 5"
    }
  ],
  "count": 1
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/get-daily-digest \
  -H "Content-Type: application/json" \
  -d '{
    "topics": ["technology", "ai"],
    "tone": "Casual",
    "country": "us",
    "limit": 3
  }'
```

---

### Deep Dive Analysis

**GET** `/get-deep-dive`

Generates a comprehensive, detailed analysis of a single article.

**Query Parameters:**
- `url` (string, required): The article URL to analyze

**Response:**
```json
{
  "url": "https://example.com/article",
  "analysis": "**Executive Summary**: ...\n\n**Key Points**: ...\n\n**Analysis**: ...\n\n**Takeaways**: ..."
}
```

**Example:**
```bash
curl "http://localhost:8000/get-deep-dive?url=https://example.com/article"
```

---

### Discovery News

**GET** `/get-discovery-news`

Fetches trending, viral, and innovative news outside typical user topics.

**Query Parameters:**
- `excluded_topics` (list[str], optional): Topics to exclude
- `tone` (string, default: "Professional"): Summary tone
- `country` (string, default: "us"): Country code
- `limit` (int, default: 10): Number of articles to return

**Response:** Same as Daily Digest

**Example:**
```bash
curl "http://localhost:8000/get-discovery-news?tone=Friendly&limit=5&country=gb"
```

---

## How It Works

### 1. News Fetching

The `NewsService` class queries the NewsData.io API with user-specified topics. It returns a list of articles with URLs, titles, and source information.

### 2. Web Scraping

For each article, the `scrape_article()` method:
- Fetches the full web page using `trafilatura.fetch_url()`
- Extracts the main article text using `trafilatura.extract()`
- Cleans the text (removes extra whitespace, normalizes formatting)
- Returns clean text ready for AI processing

### 3. AI Summarization

The `AIService` class uses Google's Gemini 1.5 Flash API to:
- Generate concise 5-bullet summaries (quick digests)
- Create detailed multi-section analyses (deep dives)
- Apply tone preferences (Professional, Casual, Academic, Friendly)

**Summarize** prompt generates bullet points:
```
Summarize the article in exactly 5 bullet points.
Tone: Professional

Guidelines:
- Each bullet should be concise (1-2 sentences max)
- Capture the key insights and main points
- Use simple, clear language
- Do not include source attribution or URLs
```

**Deep Dive** prompt generates detailed analysis:
```
Provide a comprehensive deep-dive analysis with:
1. Executive Summary
2. Key Points (5-7 bullets)
3. Analysis (2-3 paragraphs)
4. Takeaways (3-4 insights)
```

### 4. Response Delivery

All endpoints return structured JSON responses with article metadata and AI-generated content.

## Error Handling

- **400 Bad Request**: Missing required parameters or invalid URLs
- **503 Service Unavailable**: News API is unreachable or rate-limited
- **Other Errors**: Logged to console; returns friendly error message

## Rate Limiting & Best Practices

- **NewsData.io**: Free tier = 200 requests/day
- **Gemini API**: Check your quota at https://aistudio.google.com/app/apikeys
- **Scraping**: Respects HTTP timeouts; skips articles that fail to scrape

### Optimization Tips

1. Cache summarized articles to avoid re-processing
2. Batch requests for discovery news
3. Set appropriate timeouts for scraping
4. Monitor API usage to stay within limits

## Future Enhancements

- [ ] Supabase integration for user preferences
- [ ] Database caching of summaries
- [ ] Custom tone templates
- [ ] Multi-language support
- [ ] Keyword extraction from articles
- [ ] User feedback loop for summary quality

## Troubleshooting

**Issue**: "Unable to fetch news at this time"
- Check `NEWSDATA_API_KEY` is valid
- Verify API quota at newsdata.io
- Check internet connection

**Issue**: "Unable to scrape the provided URL"
- URL may have paywalls or JavaScript rendering
- Try with a different article
- Some sites block trafilatura

**Issue**: "Unable to generate summary"
- Check `GEMINI_API_KEY` is valid
- Verify Gemini API quota
- Article text may be empty or too short

## Development

To start the development server with auto-reload:

```bash
pip install --upgrade uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

To run with specific configuration:

```bash
uvicorn main:app --host 127.0.0.1 --port 8000 --workers 4
```
