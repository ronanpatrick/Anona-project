from __future__ import annotations

from pathlib import Path
import os

from dotenv import load_dotenv
from groq import Groq


def main() -> None:
    env_path = Path.cwd() / ".env"
    load_dotenv(dotenv_path=env_path)

    api_key = os.getenv("GROQ_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError(f"GROQ_API_KEY is missing in {env_path}")

    client = Groq(api_key=api_key)
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": "Hello"}],
        max_tokens=16,
        temperature=0,
    )
    content = (response.choices[0].message.content or "").strip() if response.choices else ""
    print(content or "(empty response)")


if __name__ == "__main__":
    main()
