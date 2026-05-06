from __future__ import annotations

import os

from groq import Groq

from core.config import Settings

ALLOWED_TONES = {"Professional", "Casual", "Academic", "Friendly", "Direct"}
MODEL = "llama-3.3-70b-versatile"


class AIService:
    def __init__(self, settings: Settings):
        del settings
        api_key = os.getenv("GROQ_API_KEY", "").strip()
        if not api_key:
            raise RuntimeError("GROQ_API_KEY is missing in .env")
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))

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
        return self._generate(prompt, max_tokens=450, temperature=0.5)

    def synthesize_story(self, reports: list[dict[str, str]], tone: str = "Professional") -> str:
        if not reports:
            raise ValueError("Cannot synthesize an empty report list")

        normalized_tone = tone if tone in ALLOWED_TONES else "Professional"
        combined_reports = []
        for idx, report in enumerate(reports, start=1):
            combined_reports.append(
                "\n".join(
                    [
                        f"[REPORT {idx}]",
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
            "Synthesize these reports (up to 10 sources) into one cohesive, high-density story. "
            "Highlight unique facts from different publishers, remove repetitive filler, and ensure the tone matches the user's preference.\n"
            f"Tone preference: {normalized_tone}\n"
            "Output requirements:\n"
            "- Return 5-8 markdown bullet points.\n"
            "- Keep each bullet to one sentence.\n"
            "- Attribute publisher names inline when a fact is source-specific.\n"
            "- Focus on verifiable facts, developments, and implications.\n"
            "- Do not invent facts or citations.\n\n"
            "Reports:\n"
            f"{reports_block}"
        )
        return self._generate(prompt, max_tokens=1200, temperature=0.4)

    def summarize_deep_dive(self, text: str, tone: str = "Professional") -> str:
        if not text.strip():
            raise ValueError("Cannot summarize empty text")

        normalized_tone = tone if tone in ALLOWED_TONES else "Professional"
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

    def summarize_discovery_bite(self, title: str, text: str, tone: str = "Professional") -> str:
        source_text = text.strip()
        if not source_text:
            source_text = title.strip()
        if not source_text:
            raise ValueError("Cannot summarize empty discovery content")

        normalized_tone = tone if tone in ALLOWED_TONES else "Professional"
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

    def deep_dive_summary(self, text: str, tone: str = "Professional") -> str:
        return self.summarize_deep_dive(text=text, tone=tone)

    def _generate(self, prompt: str, max_tokens: int, temperature: float) -> str:
        completion = self.client.chat.completions.create(
            model=MODEL,
            temperature=temperature,
            max_tokens=max_tokens,
            messages=[
                {
                    "role": "system",
                    "content": "You are a precise news summarization assistant.",
                },
                {"role": "user", "content": prompt},
            ],
        )

        message = completion.choices[0].message.content if completion.choices else ""
        text = (message or "").strip()
        if not text:
            raise RuntimeError("Groq returned an empty response")
        return text

