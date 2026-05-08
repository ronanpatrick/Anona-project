

***

```markdown
# Anona

## What is Anona?
Anona is a personalized news summary application designed to cut through information overload. 
It delivers curated daily news digests, in-depth deep-dive article analyses, discovery content, 
live market snapshots, and unified sports scoreboards. By leveraging AI, Anona provides concise, 
tailored updates based on user preferences and tone requirements.

## How it Works
The Anona project is split into two main components: a Python-based AI backend and a mobile frontend. 

1. **The Backend (FastAPI + AI Pipeline):** The server handles all the heavy lifting for news curation.
It utilizes the NewsData.io API to fetch trending articles based on user-specified topics. It then uses
Trafilatura to cleanly scrape the full article text, bypassing ads and boilerplate. Finally, 
Groq AI processes the text to generate concise summaries or detailed deep-dive analyses
in the user's preferred tone (Professional, Casual, Academic, or Friendly).
   
2. **The Frontend (Mobile App):**
The mobile application connects directly to the backend's RESTful API. It provides the user interface
for authenticating, setting topic and tone preferences, reading the daily 5-bullet digests, 
and viewing live market and sports dashboards.

## Setup Instructions

To run the full Anona project locally, you will need to set up both the backend and the frontend.

### Prerequisites
* Python 3.8+
* Flutter SDK
* API Keys for: NewsData.io, Google Gemini (AI Studio), and Supabase

### 1. Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install the required Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Create a `.env` file in the `backend` folder and add your API keys:
   ```env
   SUPABASE_URL="your_supabase_url"
   SUPABASE_SERVICE_KEY="your_supabase_service_key"
   NEWSDATA_API_KEY="your_newsdata_key"
   GEMINI_API_KEY="your_gemini_key"
   GROQ_API_KEY="your_groq_key"
   SPORTS_API_KEY="your_sports_key"
   ```
4. Start the FastAPI development server:
   ```bash
   python main.py
   ```
   *The server will run on `http://localhost:8000`. You can view the interactive API documentation at `http://localhost:8000/docs`.*

### 2. Frontend Setup

1. Open a new terminal and navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install the Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in the `frontend` folder (use `.env.example` as a template if available) to point to your local backend URL.
4. Run the application on your connected device or emulator:
   ```bash
   flutter run
   ```

## Repository Structure
* `/backend`: Contains the FastAPI application, web scraping logic, and the Gemini AI summarization services.
* `/frontend`: Contains the mobile application scaffolding and UI components.
```
