#!/usr/bin/env python3
"""Ownership audit: for every rbxassetid the game consumes, ask Open Cloud who owns it.

An asset loads for EVERY developer/player only when it is owned by the project group
(15872767). Assets owned by a personal user account load only for that uploader in
Studio (published games authorize via the experience owner, so they still work there) —
which is why a non-uploader alt sees missing models/icons in Studio. This tool produces
the exact list of personal-owned ids that need migration to the group.

    python3 scripts/ownership_audit.py                 # full report
    python3 scripts/ownership_audit.py --out file.json # also write machine-readable result

Reads ROBLOX_OPEN_CLOUD_KEY from env or .env.local. Read-only: only GETs asset metadata.
"""
import json, re, sys, os, time, pathlib, collections, urllib.request, urllib.error

ROOT = pathlib.Path(__file__).resolve().parent.parent
GROUP_ID = "15872767"
ASSET_API = "https://apis.roblox.com/assets/v1/assets/"


def load_key():
    if os.environ.get("ROBLOX_OPEN_CLOUD_KEY"):
        return os.environ["ROBLOX_OPEN_CLOUD_KEY"]
    envp = ROOT / ".env.local"
    if envp.exists():
        for line in envp.read_text().splitlines():
            m = re.match(r"^ROBLOX_OPEN_CLOUD_KEY=(.*)$", line.strip())
            if m:
                v = m.group(1).strip()
                if (v[:1], v[-1:]) in (('"', '"'), ("'", "'")):
                    v = v[1:-1]
                return v
    sys.exit("ROBLOX_OPEN_CLOUD_KEY not set (env or .env.local)")


def consumed_ids():
    """Map asset_id -> set(source files), same scan as audit_assets.py."""
    out = collections.defaultdict(set)
    for f in list(ROOT.glob("configs/**/*.lua")) + list(ROOT.glob("src/**/*.lua")):
        text = f.read_text(errors="ignore")
        rel = str(f.relative_to(ROOT))
        for m in re.finditer(r"rbxassetid://(\d+)", text):
            out[m.group(1)].add(rel)
        for m in re.finditer(r"[\"'](\d{9,})[\"']", text):
            out[m.group(1)].add(rel)
    return out


def fetch(asset_id, key, retries=4):
    req = urllib.request.Request(ASSET_API + asset_id, headers={"x-api-key": key})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r), None
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                time.sleep(1.5 * (attempt + 1))
                continue
            return None, f"HTTP {e.code}"
        except Exception as e:  # noqa
            time.sleep(1.0 * (attempt + 1))
            last = str(e)
    return None, locals().get("last", "error")


def classify(data):
    creator = (data.get("creationContext") or {}).get("creator") or {}
    if creator.get("groupId") == GROUP_ID:
        return "group"
    if creator.get("groupId"):
        return "other_group"
    if creator.get("userId"):
        return "user"
    return "unknown"


def main():
    key = load_key()
    out_path = None
    if "--out" in sys.argv:
        out_path = sys.argv[sys.argv.index("--out") + 1]

    ids = consumed_ids()
    print(f"Auditing {len(ids)} consumed asset ids via Open Cloud...\n", flush=True)

    results = {}
    buckets = collections.defaultdict(list)
    for i, (aid, srcs) in enumerate(sorted(ids.items()), 1):
        data, err = fetch(aid, key)
        if err:
            cat, info = "error", {"error": err}
        else:
            cat = classify(data)
            info = {
                "type": data.get("assetType"),
                "name": data.get("displayName"),
                "creator": (data.get("creationContext") or {}).get("creator"),
            }
        rec = {"id": aid, "category": cat, "sources": sorted(srcs), **info}
        results[aid] = rec
        buckets[cat].append(rec)
        print(f"\r  {i}/{len(ids)}  [{cat:11}] {aid}", end="", flush=True)
        time.sleep(0.05)
    print("\n")

    order = ["user", "other_group", "error", "unknown", "group"]
    label = {
        "user": "PERSONAL-OWNED  -> NEEDS MIGRATION (breaks on other accounts in Studio)",
        "other_group": "OWNED BY A DIFFERENT GROUP -> NEEDS MIGRATION",
        "error": "COULD NOT RESOLVE (deleted / no access / moderated)",
        "unknown": "UNKNOWN CREATOR SHAPE",
        "group": f"GROUP-OWNED ({GROUP_ID}) -> OK, loads for everyone",
    }
    for cat in order:
        recs = buckets.get(cat, [])
        if not recs:
            continue
        print(f"=== {label[cat]}  ({len(recs)}) ===")
        if cat == "group":
            print(f"  ({len(recs)} ids — fine, omitted)\n")
            continue
        by_type = collections.defaultdict(list)
        for r in recs:
            by_type[r.get("type") or r.get("error") or "?"].append(r)
        for t, rs in sorted(by_type.items()):
            print(f"  -- {t} ({len(rs)})")
            for r in sorted(rs, key=lambda x: x["sources"]):
                nm = (r.get("name") or "")[:28]
                src = ", ".join(s.replace("configs/", "").replace("src/", "") for s in r["sources"][:3])
                owner = r.get("creator") or r.get("error") or ""
                print(f"     {r['id']:<22} {nm:<30} {src}   {owner}")
        print()

    counts = {c: len(buckets.get(c, [])) for c in order}
    need = counts["user"] + counts["other_group"]
    print("---- SUMMARY ----")
    print(f"  total consumed ids : {len(ids)}")
    print(f"  group-owned (OK)   : {counts['group']}")
    print(f"  NEEDS MIGRATION    : {need}  (personal {counts['user']} + other-group {counts['other_group']})")
    print(f"  unresolved/errors  : {counts['error'] + counts['unknown']}")

    if out_path:
        pathlib.Path(out_path).write_text(json.dumps(results, indent=2))
        print(f"\n  wrote {out_path}")


if __name__ == "__main__":
    main()
