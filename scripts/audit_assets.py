#!/usr/bin/env python3
"""Asset audit: every rbxassetid consumed in configs/src must be traceable.

An id is TRACEABLE when it appears in a scripts/*.json manifest (meaning it was
uploaded by a pipeline script and its source lives in assets/) or in the known-
legacy allowlist (scripts/migration/asset_orphans_allowlist.json — Studio-era
uploads being remapped by the group migration).

    python3 scripts/audit_assets.py            # report
    python3 scripts/audit_assets.py --strict   # exit 1 on NEW orphans (CI)

Why: untracked Studio-side uploads are how the game accumulated 100+ asset ids
with no local source and no record of what they were — discovered the hard way
during the group-ownership migration (2026-06-11).
"""
import json, re, sys, pathlib, collections

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWLIST = ROOT / "scripts/migration/asset_orphans_allowlist.json"

def consumed_ids():
    out = collections.defaultdict(set)
    for f in list(ROOT.glob("configs/**/*.lua")) + list(ROOT.glob("src/**/*.lua")):
        text = f.read_text(errors="ignore")
        for m in re.finditer(r"rbxassetid://(\d+)", text):
            out[m.group(1)].add(str(f.relative_to(ROOT)))
        for m in re.finditer(r"[\"'](\d{9,})[\"']", text):
            out[m.group(1)].add(str(f.relative_to(ROOT)))
    return out

def manifest_ids():
    known = set()
    for f in list(ROOT.glob("scripts/*.json")) + list(ROOT.glob("scripts/migration/*.json")):
        try:
            data = json.loads(f.read_text())
        except Exception:
            continue
        def walk(v):
            if isinstance(v, dict):
                for x in v.values(): walk(x)
            elif isinstance(v, list):
                for x in v: walk(x)
            elif isinstance(v, (int, str)):
                m = re.search(r"(\d{9,})", str(v))
                if m: known.add(m.group(1))
        walk(data)
    return known

def main():
    strict = "--strict" in sys.argv
    allow = set()
    if ALLOWLIST.exists():
        allow = set(json.loads(ALLOWLIST.read_text()))
    consumed = consumed_ids()
    known = manifest_ids()
    orphans = {i: fs for i, fs in consumed.items() if i not in known and i not in allow}
    print(f"consumed ids: {len(consumed)} | manifest-traceable: {len(known & set(consumed))} "
          f"| allowlisted legacy: {len(allow & set(consumed))} | NEW orphans: {len(orphans)}")
    for i, fs in sorted(orphans.items()):
        print(f"  ORPHAN {i}  <- {', '.join(sorted(fs))}")
    if orphans:
        print("\nFix: upload via a scripts/upload_*.js pipeline (writes the manifest), or add to")
        print("the allowlist with a comment in the migration audit if it is a known legacy id.")
        if strict:
            sys.exit(1)

if __name__ == "__main__":
    main()
