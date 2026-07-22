#!/usr/bin/env python3
"""
Ecomono Compress — rule-based + optional API semantic pass.

Usage:
    python3 -m scripts.compress <filepath>
    python3 -m scripts.compress --api <filepath>   (enable Groq semantic pass)
    python3 -m scripts.compress --api --model groq/meta-llama/llama-4-scout-17b-16e-instruct <filepath>

Phase 1: rule-based mechanical compression (instant, 0 tokens)
Phase 2: optional semantic pass via cheap API (fast, ~2s, cents)
"""

import re
import os
import json
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Phase 1: Rule-based mechanical compression
# ---------------------------------------------------------------------------

# Patterns whose entire match is removed from output
REMOVE_WHOLE = re.compile(
    r"\b("
    r"just|really|basically|actually|simply|essentially|generally|literally"
    r"|honestly|absolutely|definitely|certainly|surely|indeed|obviously"
    r"|frankly|personally|admittedly|arguably|reportedly|supposedly"
    r"|practically|virtually|relatively|comparatively|seemingly"
    r")\b",
    re.IGNORECASE,
)

# Hedging phrases (entire clause removed)
HEDGING_PATTERNS = [
    re.compile(r"\bit('s| is)? (worth|important|critical|essential) (to|that)\b", re.IGNORECASE),
    re.compile(r"\byou (might |could |should )?consider\b", re.IGNORECASE),
    re.compile(r"\bit would be (good|great|nice|better|best) to\b", re.IGNORECASE),
    re.compile(r"\byou could (also |try |consider )?\b", re.IGNORECASE),
    re.compile(r"\b(?:i('d| would)? )?recommend\b", re.IGNORECASE),
]

# Pleasantries and polite openers
PLEASANTRIES = re.compile(
    r"\b("
    r"sure|of course|happy to|glad(ly)?|my pleasure|no problem|please"
    r"|with pleasure|absolutely|by all means|feel free|you're welcome"
    r")\b",
    re.IGNORECASE,
)

# "You should", "make sure to", "remember to", etc.
PERMISSIVE_OPENERS = re.compile(
    r"\b(?:you should|you('ll| will) want to|make sure to|be sure to|"
    r"remember to|don't forget to|keep in mind to|ensure that you|"
    r"please (make sure|remember|ensure))\b",
    re.IGNORECASE,
)

# Connective fluff
CONNECTIVES = re.compile(
    r"\b("
    r"however|furthermore|moreover|additionally|in addition"
    r"|nevertheless|nonetheless|consequently|accordingly"
    r"|therefore|thus|hence|besides|likewise"
    r")\b",
    re.IGNORECASE,
)

# Phrase replacements (order matters — longer first)
PHRASE_REPLACE = [
    (re.compile(r"\bin order to\b", re.IGNORECASE), "to"),
    (re.compile(r"\bwith the aim of\b", re.IGNORECASE), "to"),
    (re.compile(r"\bfor the purpose of\b", re.IGNORECASE), "to"),
    (re.compile(r"\bthe reason is because\b", re.IGNORECASE), "because"),
    (re.compile(r"\bdue to the fact that\b", re.IGNORECASE), "because"),
    (re.compile(r"\bas a result of\b", re.IGNORECASE), "from"),
    (re.compile(r"\bin the event that\b", re.IGNORECASE), "if"),
    (re.compile(r"\bon a regular basis\b", re.IGNORECASE), "regularly"),
    (re.compile(r"\bat this point in time\b", re.IGNORECASE), "now"),
    (re.compile(r"\bin the near future\b", re.IGNORECASE), "soon"),
    (re.compile(r"\bprior to\b", re.IGNORECASE), "before"),
    (re.compile(r"\bsubsequent to\b", re.IGNORECASE), "after"),
    (re.compile(r"\ba number of\b", re.IGNORECASE), "some"),
    (re.compile(r"\bthe majority of\b", re.IGNORECASE), "most"),
    (re.compile(r"\ba majority of\b", re.IGNORECASE), "most"),
    (re.compile(r"\bis able to\b", re.IGNORECASE), "can"),
    (re.compile(r"\bare able to\b", re.IGNORECASE), "can"),
    (re.compile(r"\bhas the ability to\b", re.IGNORECASE), "can"),
    (re.compile(r"\bin excess of\b", re.IGNORECASE), "over"),
]

# Word-level replacements
WORD_REPLACE = {
    "utilize": "use",
    "utilizes": "uses",
    "utilized": "used",
    "utilizing": "using",
    "implement": "build",
    "implements": "builds",
    "implemented": "built",
    "implementing": "building",
    "facilitate": "help",
    "facilitates": "helps",
    "facilitated": "helped",
    "leverage": "use",
    "leverages": "uses",
    "leveraged": "used",
    "optimize": "tune",
    "optimizes": "tunes",
    "optimized": "tuned",
    "validate": "check",
    "validates": "checks",
    "validated": "checked",
    "demonstrate": "show",
    "demonstrates": "shows",
    "demonstrated": "showed",
    "initialize": "init",
    "initializes": "inits",
    "initialized": "inited",
    "configuration": "config",
    "configurations": "configs",
    "functionality": "function",
    "functionalities": "functions",
    "additional": "more",
    "sufficient": "enough",
    "numerous": "many",
    "subsequent": "next",
    "preceding": "prior",
    "approximately": "about",
    "sufficiently": "enough",
    "predominantly": "mostly",
    "henceforth": "then",
    "heretofore": "before",
    "notwithstanding": "despite",
}

# Patterns for I-prefixed preferences: "I [verb]" → keep verb, drop I
I_PREFER = re.compile(
    r"\bI (prefer|preferred|like|liked|want|wanted|recommend|recommended|"
    r"strongly (suggest|recommend)|suggest|suggested|tend to|tend|usually|"
    r"would (prefer|like|recommend|suggest|use|say)|"
    r"am (a|an|the|all|very|pretty|quite|extremely|really)|"
    r"think|believe|feel|suppose|assume|guess|imagine)\b",
    re.IGNORECASE,
)

# Softening: "maybe", "perhaps", "probably", "usually", "typically", "often",
# "sometimes", "occasionally" — in instructions these hedge unnecessarily
SOFTENERS = re.compile(
    r"\b(perhaps|maybe|probably|usually|typically|often|sometimes|"
    r"occasionally|frequently|generally|mostly|largely|"
    r"in most cases|in many cases|as a rule)\b",
    re.IGNORECASE,
)

# Instruction patterns: "You can", "You could", "You'll want to" -> remove
YOU_CAN = re.compile(r"\byou (can|could|may|might|will|would|'ll|'d)\b", re.IGNORECASE)

# Intensifiers before verbs: "strongly prefer", "really like", "very much prefer"
# These weaken in instruction context — remove the intensifier, keep verb
INTENSIFIERS = re.compile(
    r"\b("
    r"strongly|highly|greatly|really|very|quite|extremely|"
    r"definitely|certainly|absolutely|deeply|truly|sincerely|"
    r"rather|somewhat|pretty|fairly"
    r")\s+(?=\w)",
    re.IGNORECASE,
)

# Passive voice: "is responsible for", "is used to", etc.
PASSIVE = [
    (re.compile(r"\bis responsible for\b", re.IGNORECASE), ""),
    (re.compile(r"\bis used (for|to)\b", re.IGNORECASE), ""),
    (re.compile(r"\bare responsible for\b", re.IGNORECASE), ""),
    (re.compile(r"\bare used (for|to)\b", re.IGNORECASE), ""),
    (re.compile(r"\bhas been\b", re.IGNORECASE), ""),
    (re.compile(r"\bhave been\b", re.IGNORECASE), ""),
    (re.compile(r"\bis designed to\b", re.IGNORECASE), ""),
    (re.compile(r"\bthe purpose of (this|the)\b", re.IGNORECASE), ""),
]

# Redundant verbs: "helps to", "allows to", "enables to"
REDUNDANT_VERBS = [
    (re.compile(r"\b(helps?|allows?|enables?) (to|you)\b", re.IGNORECASE), ""),
    (re.compile(r"\b(provides?|offers?) (a|an|the )? (way|means|method) to\b", re.IGNORECASE), ""),
]

def rule_compress(text: str) -> str:
    """Apply mechanical compression rules. Returns compressed text."""
    # ---- Phase: phrase-level removals (before word-level to avoid partial matches) ----

    # 1. Remove permissive openers first: "you should", "make sure to", etc.
    text = PERMISSIVE_OPENERS.sub("", text)

    # 2. Remove "I [prefer/like/want/...]" → keep verb without I
    text = I_PREFER.sub(lambda m: m.group(1).lower(), text)

    # 3. Remove intensifiers before verbs (do this before I_PREFER so "I strongly prefer" → "I prefer")
    text = INTENSIFIERS.sub("", text)

    # 4. Remove "you can/could/may" etc.
    text = YOU_CAN.sub("", text)

    # 4. Remove hedging clauses
    for pat in HEDGING_PATTERNS:
        text = pat.sub("", text)

    # 5. Remove passive voice constructions
    for pat, repl in PASSIVE:
        text = pat.sub(repl, text)

    # 6. Remove redundant verb constructions
    for pat, repl in REDUNDANT_VERBS:
        text = pat.sub(repl, text)

    # ---- Phase: word-level removals ----

    # 7. Remove pleasantries (after permissive openers so "sure" doesn't break "make sure to")
    text = PLEASANTRIES.sub("", text)

    # 8. Remove softeners
    text = SOFTENERS.sub("", text)

    # 9. Remove known filler words
    text = REMOVE_WHOLE.sub("", text)

    # 10. Remove connective fluff
    text = CONNECTIVES.sub("", text)

    # ---- Phase: replacements ----

    # 11. Phrase replacements
    for pat, repl in PHRASE_REPLACE:
        text = pat.sub(repl, text)

    # 12. Word replacements
    for old, new in WORD_REPLACE.items():
        text = re.sub(r"\b" + re.escape(old) + r"\b", new, text, flags=re.IGNORECASE)

    # 13. Article removal — aggressive: remove all "the " (acceptable for compressed prose)
    text = re.sub(r"\bthe\s+", "", text)

    # 14. Clean up multiple spaces, leading/trailing spaces
    text = re.sub(r" +", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip()

    return text


# ---------------------------------------------------------------------------
# Phase 2: Optional semantic pass via Groq API
# ---------------------------------------------------------------------------

API_KEY_FILE = "/run/secrets/opencode/groq-api-key"
DEFAULT_MODEL = "llama-3.1-8b-instant"
API_BASE = "https://api.groq.com/openai/v1"


def call_semantic_api(text: str, model: str = DEFAULT_MODEL) -> str:
    """Send text to cheap model for semantic compression refinement."""
    key = _read_api_key()
    if not key:
        raise RuntimeError("Groq API key not found")

    prompt = f"""Compress this markdown into ecomono format: ultra-terse, zero filler, full technical accuracy.

Rules:
- Keep EXACT same headings as input. Do NOT add, remove, or change any headings.
- Do NOT modify code blocks (```...```), inline code (`...`), URLs, file paths, commands
- Drop articles, filler, pleasantries, hedging
- Use fragments where clear
- Short synonyms: "use" not "utilize", "build" not "implement"
- Keep ALL technical terms, symbols, and proper nouns exact
- Do NOT reorganize or add new sections
- Return ONLY the compressed markdown — no explanation, no outer fence

Input:
{text}
"""

    data = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 8192,
        "temperature": 0.1,
    }

    try:
        import urllib.request
        req = urllib.request.Request(
            f"{API_BASE}/chat/completions",
            data=json.dumps(data).encode(),
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
                "User-Agent": "ecomono-compress/2.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
        return result["choices"][0]["message"]["content"].strip()
    except Exception as e:
        raise RuntimeError(f"API call failed: {e}")


def _read_api_key() -> str | None:
    """Read Groq API key from secret file or env var."""
    key = os.environ.get("GROQ_API_KEY")
    if key:
        return key
    path = Path(API_KEY_FILE)
    if path.exists():
        return path.read_text().strip()
    return None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

SENSITIVE_BASENAME = re.compile(
    r"(?ix)^("
    r"\.env(\..+)?|\.netrc|credentials(\..+)?"
    r"|secrets?(\..+)?|passwords?(\..+)?"
    r"|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?"
    r"|authorized_keys|known_hosts"
    r"|.*\.(pem|key|p12|pfx|crt|cer|jks|keystore|asc|gpg)"
    r")$"
)
SENSITIVE_DIRS = frozenset({".ssh", ".aws", ".gnupg", ".kube", ".docker"})
SENSITIVE_TOKENS = ("secret", "credential", "password", "passwd", "apikey", "accesskey", "token", "privatekey")


def is_sensitive(path: Path) -> bool:
    """Heuristic: refuse to send files that contain secrets to API."""
    if SENSITIVE_BASENAME.match(path.name):
        return True
    parts_lower = {p.lower() for p in path.parts}
    if parts_lower & SENSITIVE_DIRS:
        return True
    name_flat = re.sub(r"[_\-\s.]", "", path.name.lower())
    return any(tok in name_flat for tok in SENSITIVE_TOKENS)


def compress_file(filepath: Path, use_api: bool = False, model: str = DEFAULT_MODEL) -> dict:
    """Run compression. Returns {'status': ..., 'path': ..., 'backup': ..., 'tokens_saved': ...}"""
    MAX_SIZE = 500_000

    if not filepath.exists():
        return {"status": "error", "reason": f"File not found: {filepath}"}
    if not filepath.is_file():
        return {"status": "error", "reason": f"Not a file: {filepath}"}
    if filepath.stat().st_size > MAX_SIZE:
        return {"status": "error", "reason": f"File too large (>{MAX_SIZE//1000}KB)"}
    if filepath.name.endswith(".original.md"):
        return {"status": "skip", "reason": "Backup file, skipping"}
    if is_sensitive(filepath) and use_api:
        return {"status": "error", "reason": f"Sensitive filename: {filepath.name}. Refusing API send."}

    original = filepath.read_text(errors="ignore")
    if not original.strip():
        return {"status": "error", "reason": "Empty file"}

    backup = filepath.with_name(filepath.stem + ".original.md")
    if backup.exists():
        return {"status": "error", "reason": f"Backup exists: {backup}. Remove or rename first."}

    # Phase 1: Rule-based
    compressed = rule_compress(original)

    # Phase 2: Optional semantic pass
    if use_api:
        try:
            compressed = call_semantic_api(compressed, model=model)
        except RuntimeError as e:
            print(f"⚠️  Semantic pass skipped: {e}", file=sys.stderr)
            # Continue with rule-based result

    # Check for no-op
    if compressed.strip() == original.strip():
        return {"status": "skip", "reason": "Output identical to input (already compressed)"}

    # Write backup
    backup.write_text(original)
    # Verify backup
    if backup.read_text(errors="ignore") != original:
        backup.unlink(missing_ok=True)
        return {"status": "error", "reason": "Backup write verification failed"}

    # Write compressed
    filepath.write_text(compressed)

    # Estimate savings
    orig_tokens = len(original.split())
    compressed_tokens = len(compressed.split())
    saved = orig_tokens - compressed_tokens
    pct = (saved / orig_tokens * 100) if orig_tokens > 0 else 0

    return {
        "status": "ok",
        "path": str(filepath),
        "backup": str(backup),
        "original_tokens": orig_tokens,
        "compressed_tokens": compressed_tokens,
        "tokens_saved": saved,
        "percent": round(pct, 1),
        "used_api": use_api,
    }


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Ecomono Compress")
    parser.add_argument("filepath", help="File to compress")
    parser.add_argument("--api", action="store_true", help="Enable Groq semantic pass")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model for semantic pass")
    args = parser.parse_args()

    result = compress_file(Path(args.filepath), use_api=args.api, model=args.model)

    if result["status"] == "ok":
        print(json.dumps(result, indent=2))
        sys.exit(0)
    elif result["status"] == "skip":
        print(f"⏭️  {result['reason']}")
        sys.exit(0)
    else:
        print(f"❌ {result['reason']}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
