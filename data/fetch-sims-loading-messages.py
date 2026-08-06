#!/usr/bin/env python3
"""Rebuild the Sims / SimCity loading-message corpus from its public sources.

Writes, next to this script:
  sims-loading-messages.json  structured, grouped by game and expansion pack
  sims-loading-messages.txt   flat list, deduped, one message per line

Sources
  The Sims 1 / 2 / Stories / 3
    The Sims Wiki, "Loading screen messages", fetched as raw wikitext through
    the MediaWiki API so the per-game and per-pack grouping is preserved.
  SimCity 4
    The in-game list as compiled by the community; it is where the joke starts
    ("Reticulating Splines" first appeared in SimCity 2000) and it shares only
    that one line with the Sims lists.

Normalization (everything else is verbatim, typos included):
  - trailing "..." / "…" stripped, because every consumer appends its own
  - whitespace collapsed, wiki markup removed
  - the flat list is deduped case-insensitively, first occurrence wins

Usage: python3 fetch-sims-loading-messages.py
"""

from __future__ import annotations

import collections
import json
import pathlib
import re
import urllib.request

HERE = pathlib.Path(__file__).parent

WIKI_API = (
    "https://sims.fandom.com/api.php?action=parse"
    "&page=Loading%20screen%20messages&prop=wikitext&format=json&formatversion=2"
)
WIKI_PAGE = "https://sims.fandom.com/wiki/Loading_screen_messages"

SIMCITY_RAW = "https://gist.githubusercontent.com/erikcox/7e96d031d00d7ecb1a2f/raw"
SIMCITY_PAGE = "https://gist.github.com/erikcox/7e96d031d00d7ecb1a2f"

UA = {"User-Agent": "useful-ai/sims-loading-verbs (+https://github.com/pvinis/useful-ai)"}

RELEASED = {
    "The Sims": 2000,
    "The Sims 2": 2004,
    "The Sims Stories": 2007,
    "The Sims 3": 2009,
}


def get(url: str) -> str:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def clean(raw: str) -> str:
    """Turn one wikitext bullet into a plain loading message."""
    s = raw.strip()
    s = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", s)  # [[target|label]]
    s = re.sub(r"\[\[([^\]]+)\]\]", r"\1", s)  # [[target]]
    s = s.replace("'''", "").replace("''", "")
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\{\{[^}]*\}\}", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s.rstrip(". …").strip() if s.endswith(("...", "…")) else s


def parse_wiki(wikitext: str) -> "collections.OrderedDict[str, collections.OrderedDict]":
    """== Game == / === Pack === / * message  ->  {game: {pack: [messages]}}"""
    games: collections.OrderedDict[str, collections.OrderedDict] = collections.OrderedDict()
    game = pack = None
    for line in wikitext.split("\n"):
        if m := re.match(r"^==([^=].*?)==\s*$", line):
            game, pack = clean(m.group(1)), None
        elif m := re.match(r"^===(.*?)===\s*$", line):
            pack = clean(m.group(1))
        elif (m := re.match(r"^\*\s*(.+)$", line)) and game:
            if message := clean(m.group(1)):
                games.setdefault(game, collections.OrderedDict()).setdefault(
                    pack or "Base game", []
                ).append(message)
    return games


def main() -> None:
    sets = []

    for game, packs in parse_wiki(json.loads(get(WIKI_API))["parse"]["wikitext"]).items():
        sets.append(
            {
                "id": re.sub(r"[^a-z0-9]+", "-", game.lower()).strip("-"),
                "title": game,
                "released": RELEASED.get(game),
                "source": WIKI_PAGE,
                "count": sum(len(v) for v in packs.values()),
                "packs": packs,
            }
        )

    simcity = [clean(line) for line in get(SIMCITY_RAW).split("\n") if line.strip()]
    sets.append(
        {
            "id": "simcity-4",
            "title": "SimCity 4",
            "released": 2003,
            "source": SIMCITY_PAGE,
            "count": len(simcity),
            "packs": {"Base game": simcity},
        }
    )

    flat, seen = [], set()
    for s in sets:
        for messages in s["packs"].values():
            for message in messages:
                if (key := message.lower()) not in seen:
                    seen.add(key)
                    flat.append(message)

    payload = {
        "name": "Sims / SimCity loading messages",
        "description": (
            "Loading-screen messages ('startup strings') from the Maxis life-sim "
            "and city-sim games, for use as spinner verbs in an AI coding CLI."
        ),
        "note": (
            "The Sims 4 has no loading-message list. The strings ran from The Sims "
            "through The Sims 3; The Sims 4 kept only 'Reticulating splines' as a nod. "
            "The joke itself starts in SimCity 2000."
        ),
        "normalization": (
            "Verbatim apart from stripped trailing ellipses, collapsed whitespace, "
            "and removed wiki markup. Original spellings and typos are preserved."
        ),
        "rights": (
            "The messages are EA / Maxis's writing, reproduced here as a reference "
            "list already documented publicly on The Sims Wiki. Homage, not a claim."
        ),
        "generated_by": "data/fetch-sims-loading-messages.py",
        "total_unique": len(flat),
        "sets": sets,
    }

    (HERE / "sims-loading-messages.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (HERE / "sims-loading-messages.txt").write_text(
        "\n".join(flat) + "\n", encoding="utf-8"
    )

    for s in sets:
        print(f"{s['title']}: {s['count']}")
    print(f"total unique: {len(flat)}")


if __name__ == "__main__":
    main()
