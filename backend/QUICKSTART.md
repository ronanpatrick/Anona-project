# Phase 3: Backend AI Pipeline - Quick Start Guide

## What We Built

A complete FastAPI backend that:
- ✅ Fetches news from NewsData.io API
- ✅ Scrapes full article text using trafilatura
- ✅ Summarizes articles with Google Gemini 1.5 Flash
- ✅ Provides three intelligent API endpoints
- ✅ Supports tone preferences (Professional, Casual, Academic, Friendly)
- ✅ Includes comprehensive error handling

## File Structure

```
backend/
├── main.py                 # Complete FastAPI application
├── requirements.txt        # Python dependencies
├── .env.example           # Environment variable template
├── .env                   # Your actual API keys (not in git)
└── README.md              # Full documentation
```

## Quick Setup (3 Steps)

### Step 1: Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### Step 2: Configure Environment
Copy `.env.example` to `.env` and add your API keys:
```bash
SUPABASE_URL=your_url
SUPABASE_SERVICE_KEY=your_key
NEWSDATA_API_KEY=your_key
GEMINI_API_KEY=your_key
```

Get keys from:
- **Gemini**: https://aistudio.google.com/app/apikeys
- **NewsData.io**: https://newsdata.io/pricing (free tier: 200 requests/day)
- **Supabase**: Your project dashboard

### Step 3: Run the Server
```bash
python main.py
```

Access at: http://localhost:8000

## API Endpoints

### 1. Daily Digest `/get-daily-digest` (POST)
**Get summarized news on topics you care about**

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

Returns: List of articles with 5-bullet summaries

### 2. Deep Dive `/get-deep-dive` (GET)
**Get comprehensive analysis of a single article**

```bash
curl "http://localhost:8000/get-deep-dive?url=https://example.com/article"
```

Returns: Executive summary + key points + analysis + takeaways

### 3. Discovery `/get-discovery-news` (GET)
**Discover trending news outside your usual topics**

```bash
curl "http://localhost:8000/get-discovery-news?tone=Friendly&limit=5"
```

Returns: List of trending articles with summaries

## How It Works

```
User Request
    ↓
[NewsService] → Fetch from NewsData.io API
    ↓
[Trafilatura] → Scrape full article text
    ↓
[AIService] → Summarize with Gemini 1.5 Flash
    ↓
JSON Response with summaries
```

## Key Features

| Feature | Details |
|---------|---------|
| **News Source** | NewsData.io (200+ publishers) |
| **Web Scraping** | Trafilatura (removes ads, extracts content) |
| **AI Model** | Google Gemini 1.5 Flash (fast, cost-effective) |
| **Tone Support** | Professional, Casual, Academic, Friendly |
| **Error Handling** | Graceful fallbacks for failed scrapes |
| **CORS** | Enabled for frontend integration |

## Development

### View API Docs
- Interactive Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Run with Auto-Reload
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Test an Endpoint
```bash
# Health check
curl http://localhost:8000/health

# Daily digest with tech news
curl -X POST http://localhost:8000/get-daily-digest \
  -H "Content-Type: application/json" \
  -d '{"topics": ["technology"], "limit": 2}'
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Unable to fetch news" | Check NewsData API key and quota |
| "Unable to scrape URL" | Some sites block scrapers; try another article |
| "Unable to generate summary" | Check Gemini API key and quota |
| Import errors | Run `pip install -r requirements.txt` again |

## Next Steps

1. **Frontend Integration**: Connect the frontend to these endpoints
2. **User Preferences**: Store topic/tone preferences in Supabase
3. **Caching**: Add Redis/database caching for faster responses
4. **Analytics**: Track which summaries users engage with most

## Architecture Notes

- **Single file design**: All code in `main.py` for simplicity (can be refactored into modules later)
- **Async-ready**: FastAPI handles concurrent requests automatically
- **Type hints**: Full type annotations for IDE support
- **Error resilience**: Gracefully handles API failures and invalid URLs

## API Usage Limits

- **NewsData.io Free**: 200 requests/day
- **Gemini API**: Check your quota at https://aistudio.google.com/app/apikeys
- **Recommendation**: Cache responses to avoid redundant calls

---

**Phase 3 Complete!** ✨ Your backend is ready for Phase 4 integration testing.
