from __future__ import annotations

import google.generativeai as genai

from core.config import Settings

ALLOWED_TONES = {"Professional", "Casual", "Academic", "Friendly", "Direct"}


class AIService:
    def __init__(self, settings: Settings):
        if not settings.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is missing in .env")
        genai.configure(api_key=settings.gemini_api_key)
        self.model = genai.GenerativeModel("gemini-1.5-flash")

    def summarize_text(self, text: str, tone: str = "Professional", bullet_count: int = 5) -> str:
        if not text.strip():
            raise ValueError("Cannot summarize empty text")

        normalized_tone = tone if tone in ALLOWED_TONES else "Professional"
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
        return self._generate(prompt, max_output_tokens=450, temperature=0.5)

    def deep_dive_summary(self, text: str, tone: str = "Professional") -> str:
        if not text.strip():
            raise ValueError("Cannot summarize empty text")

        normalized_tone = tone if tone in ALLOWED_TONES else "Professional"
        prompt = (
            "Create a high-detail deep-dive summary.\n"
            f"Tone: {normalized_tone}\n"
            "Format:\n"
            "1) Executive Summary (2-3 sentences)\n"
            "2) Key Details (6-8 bullets)\n"
            "3) Why It Matters (2 short paragraphs)\n"
            "4) Watchlist (3 bullets on what to monitor next)\n\n"
            "Article Text:\n"
            f"{text}"
        )
        return self._generate(prompt, max_output_tokens=1200, temperature=0.6)

    def _generate(self, prompt: str, max_output_tokens: int, temperature: float) -> str:
        response = self.model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                max_output_tokens=max_output_tokens,
                temperature=temperature,
            ),
        )
        if not getattr(response, "text", ""):
            raise RuntimeError("Gemini returned an empty response")
        return response.text.strip()

