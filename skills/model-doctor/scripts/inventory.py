#!/usr/bin/env python3
"""Deterministic, read-only inventory of AI model references.

Scans the given files/directories for strings that look like model IDs and
prints file:line hits with a provider guess and a path-based context hint.
Finding strings is this script's whole job — deciding whether a hit is active
configuration, historical documentation, or noise is the reader's job.

No network access, no writes, never leaves the given paths.
"""

import argparse
import json
import re
import sys
from pathlib import Path

# Model-name shapes per provider. These catch candidates for a human/agent to
# judge; they are not a statement of what exists or is current.
PATTERNS = [
    ("anthropic", r"\banthropic\.claude-[\w.:@-]+"),
    ("anthropic", r"\bclaude-[a-z0-9][\w.@-]*"),
    ("openai", r"\bgpt-[a-z0-9][\w.-]*"),
    ("openai", r"\bchatgpt-[\w.-]+"),
    ("openai", r"\bo[134](?:-(?:mini|pro|preview|deep-research))(?:-[\w-]+)?\b"),
    ("openai", r"\bo[134]-\d{4}-\d{2}-\d{2}\b"),
    ("openai", r"\btext-embedding-(?:ada-002|3-(?:small|large))\b"),
    ("openai", r"\btext-davinci-\d+\b"),
    ("openai", r"\b(?:dall-e-\d|whisper-1|tts-1(?:-hd)?|computer-use-preview)\b"),
    ("google", r"\bgemini-[a-z0-9][\w.-]*"),
    ("google", r"\b(?:imagen|veo)-\d[\w.-]*"),
    ("google", r"\bgemma-?\d[\w.-]*"),
    ("meta", r"\bllama-?\d[\w.:-]*"),
    ("mistral", r"\b(?:mistral|mixtral|codestral|ministral|magistral|pixtral)-[\w.-]+"),
    ("deepseek", r"\bdeepseek-[\w.-]+"),
    ("qwen", r"\bqwen[\d.]*-[\w.-]+"),
    ("xai", r"\bgrok-[\w.-]+"),
    ("cohere", r"\bcommand-(?:r|a|light|nightly)[\w.-]*"),
    ("cohere", r"\bembed-(?:english|multilingual)[\w.-]*"),
    ("amazon", r"\bamazon\.(?:nova|titan)[\w.:-]+"),
    ("voyage", r"\bvoyage-[\w.-]+"),
    # provider/model gateway slugs (OpenRouter and similar)
    ("gateway", r"\b(?:openai|anthropic|google|meta-llama|mistralai|deepseek|x-ai|qwen|cohere|amazon|perplexity)/[a-z0-9][\w.:-]+"),
]
COMPILED = [(prov, re.compile(pat, re.IGNORECASE)) for prov, pat in PATTERNS]

# Bare aliases (e.g. `model: sonnet`) and bare reasoning-model names
# (`model = "o1"`) only count on lines that mention a model-ish key,
# to avoid flagging prose and ordinary identifiers.
ALIAS_KEY = re.compile(r"\bmodel\b|_MODEL\b", re.IGNORECASE)
ALIAS = re.compile(r"\b(opus|sonnet|haiku|fable)\b", re.IGNORECASE)
BARE_O = re.compile(r"\bo[134]\b", re.IGNORECASE)

SKIP_DIRS = {
    ".git", "node_modules", "vendor", "third_party", ".venv", "venv",
    "dist", "build", "target", ".next", "out", "__pycache__", ".gradle",
    "Pods", "DerivedData",
}
LOCKFILES = {
    "package-lock.json", "bun.lock", "bun.lockb", "yarn.lock", "pnpm-lock.yaml",
    "Cargo.lock", "poetry.lock", "uv.lock", "Gemfile.lock", "composer.lock",
    "Podfile.lock", "flake.lock",
}
HISTORICAL_NAMES = re.compile(
    r"changelog|history|news|releases|deprecat|migration|journal|retro|postmortem",
    re.IGNORECASE,
)
FIXTURE_PARTS = {
    "fixtures", "snapshots", "__snapshots__", "testdata", "cassettes",
    "evals", "benchmarks", "baselines", "examples",
}
MAX_BYTES = 2_000_000


def context_hint(path: Path) -> str:
    if path.name in LOCKFILES:
        return "lockfile"
    parts = {p.lower() for p in path.parts}
    if parts & FIXTURE_PARTS or path.suffix == ".snap":
        return "fixture"
    if HISTORICAL_NAMES.search(path.name):
        return "historical-doc"
    if "generated" in parts or ".generated." in path.name or path.suffix == ".map" or path.name.endswith(".min.js"):
        return "generated"
    return "config-or-code"


def iter_files(root: Path, include_vendored: bool):
    if root.is_file():
        yield root
        return
    for path in sorted(root.rglob("*")):
        if path.is_dir():
            continue
        rel_parts = set(path.relative_to(root).parts[:-1])
        if not include_vendored and rel_parts & SKIP_DIRS:
            continue
        yield path


def scan_file(path: Path):
    try:
        if path.stat().st_size > MAX_BYTES:
            return
        text = path.read_text(encoding="utf-8", errors="strict")
    except (UnicodeDecodeError, OSError):
        return  # binary or unreadable
    for lineno, line in enumerate(text.splitlines(), 1):
        seen_spans = []
        for provider, rx in COMPILED:
            for m in rx.finditer(line):
                if any(s <= m.start() < e for s, e in seen_spans):
                    continue
                seen_spans.append((m.start(), m.end()))
                yield lineno, line, provider, m.group(0).rstrip(".,;:")
        if ALIAS_KEY.search(line):
            for rx, provider in ((ALIAS, "anthropic-alias"), (BARE_O, "openai")):
                for m in rx.finditer(line):
                    if any(s <= m.start() < e for s, e in seen_spans):
                        continue
                    yield lineno, line, provider, m.group(0)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", default=["."], help="Files or directories to scan (default: current directory)")
    ap.add_argument("--json", action="store_true", help="Emit JSON instead of a table")
    ap.add_argument("--include-vendored", action="store_true", help="Also scan node_modules/vendor/build directories")
    args = ap.parse_args()

    roots = [Path(p).resolve() for p in (args.paths or ["."])]
    home = Path.home().resolve()
    for root in roots:
        if not root.exists():
            print(f"error: {root} does not exist", file=sys.stderr)
            return 2
        if root in (home, Path("/")):
            print(
                f"error: refusing to scan {root} — scope is too broad. "
                "Pass a specific repository or config directory.",
                file=sys.stderr,
            )
            return 2

    hits = []
    for root in roots:
        base = root if root.is_dir() else root.parent
        for path in iter_files(root, args.include_vendored):
            for lineno, line, provider, match in scan_file(path):
                hits.append({
                    "file": str(path),
                    "line": lineno,
                    "match": match,
                    "provider_guess": provider,
                    "context_hint": context_hint(path.relative_to(base) if path.is_relative_to(base) else path),
                    "text": line.strip()[:200],
                })

    hits.sort(key=lambda h: (h["file"], h["line"], h["match"]))

    if args.json:
        json.dump({"hits": hits, "count": len(hits)}, sys.stdout, indent=2)
        print()
    else:
        if not hits:
            print("No model references found.")
            return 0
        width = min(max(len(h["match"]) for h in hits), 40)
        for h in hits:
            print(f"{h['file']}:{h['line']}  [{h['provider_guess']}/{h['context_hint']}]  {h['match']:<{width}}  | {h['text']}")
        print(f"\n{len(hits)} hits in {len({h['file'] for h in hits})} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
