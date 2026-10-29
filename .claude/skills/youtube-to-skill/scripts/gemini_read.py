"""Have Gemini watch a YouTube video natively and run the shared extraction prompt.

Usage: GEMINI_API_KEY=... python3 -I gemini_read.py <youtube-url>
Optional: GEMINI_MODEL (default below).
"""

import json
import os
import pathlib
import sys
import urllib.request

DEFAULT_MODEL = "gemini-2.5-pro"
PROMPT_FILE = pathlib.Path(__file__).resolve().parent.parent / "references" / "extraction-prompt.md"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: gemini_read.py <youtube-url>")
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY is not set")

    model = os.environ.get("GEMINI_MODEL", DEFAULT_MODEL)
    body = {
        "contents": [
            {
                "parts": [
                    {"file_data": {"file_uri": sys.argv[1]}},
                    {"text": PROMPT_FILE.read_text(encoding="utf-8")},
                ]
            }
        ]
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.load(resp)

    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    text = "".join(p.get("text", "") for p in parts)
    if not text:
        sys.exit(f"empty response from Gemini: {json.dumps(data)[:500]}")
    print(text)


if __name__ == "__main__":
    main()
