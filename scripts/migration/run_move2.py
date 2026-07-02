#!/usr/bin/env python3
"""Move 2: re-upload queued assets to the group, emit old->new map. Idempotent:
entries already in move2_id_map.json are skipped; the map is written after every
success so interruption loses nothing."""
import json, pathlib, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
QUEUE = json.load(open(ROOT / "scripts/migration/move2_upload_queue.json"))
MAP_PATH = ROOT / "scripts/migration/move2_id_map.json"
GROUP = "15872767"
KEY = next(l.split("=", 1)[1].strip() for l in open(ROOT / ".env.local")
           if l.startswith("ROBLOX_OPEN_CLOUD_KEY"))

id_map = json.load(open(MAP_PATH)) if MAP_PATH.exists() else {}

def curl(args):
    out = subprocess.run(["curl", "-s", *args], capture_output=True, text=True, timeout=60)
    return out.stdout

def upload(entry):
    t = "Audio" if entry["type"] == "Audio" else "Decal"
    f = ROOT / entry["file"]
    mime = {"png": "image/png", "jpg": "image/jpeg", "mp3": "audio/mpeg",
            "ogg": "audio/ogg", "wav": "audio/wav"}[f.suffix[1:].lower()]
    req = json.dumps({"assetType": t, "displayName": entry["name"],
                      "description": f"group migration re-upload of {entry['old_id']}",
                      "creationContext": {"creator": {"groupId": GROUP}}})
    body = curl(["-X", "POST", "https://apis.roblox.com/assets/v1/assets",
                 "-H", f"x-api-key: {KEY}",
                 "-F", f"request={req}", "-F", f"fileContent=@{f};type={mime}"])
    op = json.loads(body)
    if "operationId" not in op:
        return None, body
    for _ in range(12):
        time.sleep(2)
        st = json.loads(curl(["-H", f"x-api-key: {KEY}",
            f"https://apis.roblox.com/assets/v1/operations/{op['operationId']}"]))
        if st.get("done"):
            r = st.get("response", {})
            return r.get("assetId"), (r.get("moderationResult") or {}).get("moderationState")
    return None, "operation timeout"

fails = dict(id_map.get("_failed", {}))
done = 0
for e in QUEUE:
    if e["old_id"] in id_map:
        continue
    new_id, mod = upload(e)
    if new_id:
        id_map[e["old_id"]] = {"new_id": new_id, "name": e["name"],
                               "type": e["type"], "file": e["file"], "moderation": mod}
        fails.pop(e["old_id"], None)
        done += 1
        print(f"  ok {e['name']} {e['old_id']} -> {new_id} [{mod}]")
    else:
        fails[e["old_id"]] = {"name": e["name"], "error": str(mod)[:200]}
        print(f"  FAIL {e['name']}: {str(mod)[:120]}")
    id_map["_failed"] = fails
    json.dump(id_map, open(MAP_PATH, "w"), indent=1, sort_keys=True)
    time.sleep(1)

mapped = len([k for k in id_map if k != "_failed"])
print(f"\nmap: {mapped}/{len(QUEUE)} | new this run: {done} | failed: {len(fails)}")
