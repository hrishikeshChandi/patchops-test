import json
import os
import re
import httpx
from groq import Groq

__all__ = ['call_llm', 'parse_json_response', 'extract_code_block', 'safe_call_llm_json']

def get_client() -> Groq:
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        raise ValueError("GROQ_API_KEY environment variable is not set")
    http_client = httpx.Client()
    return Groq(api_key=api_key, http_client=http_client)

def call_llm(prompt: str, max_tokens: int = 2000) -> str:
    client = get_client()
    response = client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens
    )
    text = response.choices[0].message.content
    if not text or not text.strip():
        raise ValueError("Groq returned empty response")
    return text.strip()

def parse_json_response(text: str) -> dict:
    cleaned_text = text.strip()
    cleaned_text = re.sub(r'^[a-zA-Z]*\n?', '', cleaned_text)
    cleaned_text = cleaned_text.replace('', '')
    start_index = cleaned_text.find('{')
    if start_index == -1:
        raise json.JSONDecodeError("No '{' found in the response.", cleaned_text, 0)
    cleaned_text = cleaned_text[start_index:]
    end_index = cleaned_text.rfind('}')
    if end_index != -1:
        cleaned_text = cleaned_text[:end_index + 1]
    return json.loads(cleaned_text)

def extract_code_block(text: str) -> str:
    if "python" in text:
        parts = text.split("python")
        if len(parts) > 1:
            code_part = parts[1].split("")[0]
            return code_part.strip()
    elif "" in text:
        parts = text.split("")
        if len(parts) > 1:
            code_part = parts[1]
            code_part = re.sub(r'^[a-z]+\n', '', code_part, flags=re.IGNORECASE)
            return code_part.strip()
    return text.strip()

def safe_call_llm_json(prompt: str, max_tokens: int = 2000, retries: int = 2) -> dict:
    raw = "<no response>"
    for attempt in range(retries + 1):
        try:
            current_prompt = prompt
            if attempt > 0:
                current_prompt += (
                    "\n\nCRITICAL INSTRUCTION: Your response must be ONLY a valid JSON object.\n"
                    "No explanation. No markdown. No json fences. Start with { end with }."
                )
            raw = call_llm(current_prompt, max_tokens)
            if not raw or not raw.strip():
                raise ValueError("Empty response from LLM")
            parsed_json = parse_json_response(raw)
            return parsed_json
        except Exception as e:
            if attempt == retries:
                return {
                    "error": f"Failed after {retries} attempts: {str(e)}",
                    "raw": raw
                }
    return {}
