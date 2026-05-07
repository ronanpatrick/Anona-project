from __future__ import annotations

import os
import time
import json
from groq import Groq, RateLimitError
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from core.config import Settings

ALLOWED_TONES = {"executive", "analyst", "conversationalist", "layman"}
MODEL = "llama-3.1-8b-instant"


class AIService:
    def __init__(self, settings: Settings):
        del settings
        api_key = os.getenv("GROQ_API_KEY", "").strip()
        if not api_key:
            raise RuntimeError("GROQ_API_KEY is missing in .env")
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))

    def summarize_text(self, text: str, tone: str = "analyst", bullet_count: int = 5) -> str:
        if not text.strip():
            raise ValueError("Cannot summarize empty text")

        normalized_tone = tone if tone in ALLOWED_TONES else "analyst"
        prompt = (
            f"Summarize the article in exactly {bullet_count} concise bullet points.\n"
            f"Tone: {normalized_tone}.\n"
            "Rules:\n"
            "- Keep each bullet to one sentence.\n"
            "- Focus on facts, developments, and implications.\n"
            "- Use markdown bullets beginning with '- '.\n"
            "- No intro or outro, only bullet points.\n\n"
            "Article Text:\n"
            f"{text}"
        )
        return self._generate(prompt, max_tokens=450, temperature=0.5)

    def synthesize_topic_story(self, reports: list[dict[str, str]], topic: str, tone: str = "analyst") -> str:
        if not reports:
            raise ValueError("Cannot synthesize an empty report list")

        normalized_tone = tone if tone in ALLOWED_TONES else "analyst"
        combined_reports = []
        for idx, report in enumerate(reports, start=1):
            content_type = (report.get("content_type") or "full_article").strip()
            combined_reports.append(
                "\n".join(
                    [
                        f"[REPORT {idx}]",
                        f"Content Type: {content_type}",
                        f"URL: {report['url']}",
                        f"Title: {report['title']}",
                        f"Publisher: {report['source']}",
                        "Body:",
                        report["text"],
                    ]
                )
            )

        reports_block = "\n\n".join(combined_reports)
        
        prompt = (
            f"You are an expert editor. Synthesize these articles into exactly ONE comprehensive briefing card about the topic: {topic}. "
            "Mention the sources (e.g., 'According to Reuters...').\n"
            "Inputs may include a mix of full article text and shorter search-result snippets/descriptions.\n"
            "Reliability handling:\n"
            "- Treat full article text as higher-confidence context.\n"
            "- Use snippet content when full text is unavailable, but avoid overclaiming and keep wording cautious.\n"
            "Highlight unique facts from different publishers, remove repetitive filler, and ensure the tone matches the user's preference.\n"
            f"Tone preference: {normalized_tone}\n"
            "Output requirements:\n"
            "You MUST return a valid JSON object with a single key 'card'. The value of 'card' must be an object with:\n"
            "- 'topic': (string) {topic}\n"
            "- 'title': (string) A punchy, one-line catchy headline for this summary card. Keep it extremely brief and impactful.\n"
            "- 'summary': (string) The actual summary text. This MUST be formatted as 1-3 markdown bullet points.\n"
            "- 'sources': (array of strings) The publishers explicitly mentioned in the synthesis.\n"
            "- 'urls': (array of strings) The source URLs used to synthesize this card. Must match the exact URLs provided in the reports.\n"
            "- Do not invent facts, citations, or URLs.\n\n"
            "Reports:\n"
            f"{reports_block}"
        )
        return self._generate(prompt, max_tokens=1500, temperature=0.4, json_mode=True)

    def summarize_deep_dive(self, text: str, tone: str = "analyst") -> str:
        if not text.strip():
            raise ValueError("Cannot summarize empty text")

        normalized_tone = tone if tone in ALLOWED_TONES else "analyst"
        prompt = (
            "Create a high-detail deep-dive summary of this single news article.\n"
            f"Tone: {normalized_tone}\n"
            "Format:\n"
            "1) Executive Summary (2-3 sentences)\n"
            "2) Hard Statistics (4-6 bullets with explicit numbers/percentages/dates)\n"
            "3) Direct Quotes (2-4 verbatim quotes with speaker/source if present)\n"
            "4) Technical Jargon Explained (3-5 bullets: term -> plain-language meaning)\n"
            "5) Why It Matters (2 short paragraphs)\n"
            "6) Watchlist (3 bullets on what to monitor next)\n\n"
            "Rules:\n"
            "- Prioritize concrete facts over opinion.\n"
            "- If a section has no evidence in the article, write 'Not available in source text.'\n"
            "- Do not invent data, quotes, or terminology.\n"
            "- Keep output in markdown headings and bullets.\n\n"
            "Article Text:\n"
            f"{text}"
        )
        return self._generate(prompt, max_tokens=1200, temperature=0.6)

    def summarize_discovery_bite(self, title: str, text: str, tone: str = "analyst") -> str:
        source_text = text.strip()
        if not source_text:
            source_text = title.strip()
        if not source_text:
            raise ValueError("Cannot summarize empty discovery content")

        normalized_tone = tone if tone in ALLOWED_TONES else "analyst"
        prompt = (
            "Write a bite-sized summary for this discovery news story.\n"
            f"Tone: {normalized_tone}\n"
            "Rules:\n"
            "- Return exactly 1 short bullet line starting with '- '.\n"
            "- Keep it under 30 words.\n"
            "- Focus on the key why-it-matters angle.\n"
            "- Do not add markdown headings, intros, or URLs.\n\n"
            f"Title: {title.strip()}\n"
            "Article text:\n"
            f"{source_text}"
        )
        return self._generate(prompt, max_tokens=120, temperature=0.4)

    def summarize_discovery_batch(self, articles: list[dict[str, str]], tone: str = "analyst") -> list[str]:
        if not articles:
            return []
            
        normalized_tone = tone if tone in ALLOWED_TONES else "analyst"
        
        items_block = ""
        for i, art in enumerate(articles):
            items_block += f"--- ITEM {i+1} ---\nTitle: {art['title']}\nText: {art['text'][:500]}\n\n"
            
        prompt = (
            "You are a news curator. Summarize these discovery news items into a list of bite-sized bullet points.\n"
            f"Tone: {normalized_tone}\n"
            "Output Requirements:\n"
            "You MUST return a JSON object with a single key 'bites' which is an array of strings.\n"
            "- Each string must be exactly 1 short bullet line starting with '- '.\n"
            "- Keep each bite under 30 words.\n"
            "- Focus on the key why-it-matters angle.\n"
            "- Provide exactly one bite per item provided.\n\n"
            f"{items_block}"
        )
        
        try:
            res = self._generate(prompt, max_tokens=1000, temperature=0.4, json_mode=True)
            data = json.loads(res)
            return data.get("bites", [])
        except Exception as e:
            print(f"DEBUG: Batch discovery failed: {e}")
            return []

    def deep_dive_summary(self, text: str, tone: str = "analyst") -> str:
        return self.summarize_deep_dive(text=text, tone=tone)

    @retry(
        retry=retry_if_exception_type(RateLimitError),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        stop=stop_after_attempt(3),
        reraise=True
    )
    def _generate(self, prompt: str, max_tokens: int, temperature: float, json_mode: bool = False) -> str:
        kwargs = {
            "model": MODEL,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You are a precise news summarization assistant. "
                        "Source context may contain a mix of full articles and short snippets. "
                        "Synthesize the best possible output from available evidence and never invent facts."
                    ) + (" Output valid JSON." if json_mode else ""),
                },
                {"role": "user", "content": prompt},
            ],
        }
        if json_mode:
            kwargs["response_format"] = {"type": "json_object"}

        completion = self.client.chat.completions.create(**kwargs)

        message = completion.choices[0].message.content if completion.choices else ""
        text = (message or "").strip()
        if not text:
            raise RuntimeError("Groq returned an empty response")
        return text

