#!/usr/bin/env python3
"""Small health check for the project wiki."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WIKI = ROOT / "docs" / "wiki"


def extract_links(text: str) -> list[str]:
    return re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)


def main() -> int:
    if not WIKI.exists():
        print("wiki: missing docs/wiki")
        return 1

    pages = sorted(path for path in WIKI.glob("*.md") if path.is_file())
    if not pages:
        print("wiki: no markdown pages")
        return 1

    missing: list[str] = []
    for page in pages:
        text = page.read_text(encoding="utf-8")
        if not text.startswith("# "):
            missing.append(f"{page.relative_to(ROOT)}: missing top-level title")
        for link in extract_links(text):
            if "://" in link or link.startswith("#"):
                continue
            target = (page.parent / link).resolve()
            if "#" in link:
                target = (page.parent / link.split("#", 1)[0]).resolve()
            if not target.exists():
                missing.append(f"{page.relative_to(ROOT)}: broken link {link}")

    print(f"wiki: {len(pages)} pages")
    if missing:
        for item in missing:
            print(f"wiki: {item}")
        return 1

    print("wiki: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

