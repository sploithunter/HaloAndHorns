"""Small Spawn client for the assessment; credentials stay outside the checkout."""
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TARGET = json.loads((ROOT / "target.json").read_text())


def request(path, data=None, method=None, content_type="application/json"):
    token = os.environ.get("SPAWN_TOKEN") or Path(
        os.environ.get("SPAWN_TOKEN_FILE", str(Path.home() / ".spawn/token"))
    ).read_text().strip()
    body = data if isinstance(data, bytes) else None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        TARGET["origin"] + path, data=body, method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": content_type},
    )
    with urllib.request.urlopen(req, timeout=90) as response:
        return json.load(response)


def upload(path):
    path = Path(path)
    data = path.read_bytes()
    name = "value." + hashlib.sha256(data).hexdigest() + path.suffix
    base = "/api/sdk/v1/" + TARGET["worldId"] + "/assets/"
    content_type = "model/gltf-binary" if path.suffix == ".glb" else "application/octet-stream"
    if len(data) < 4_400_000:
        return request(base + name, data, "PUT", content_type)
    target = request(base + "upload-target", {"name": name, "sizeBytes": len(data)})
    req = urllib.request.Request(target["uploadUrl"], data=data, method="PUT",
                                 headers={"Content-Type": content_type, "Content-Length": str(len(data))})
    with urllib.request.urlopen(req, timeout=120) as response:
        response.read()
    return request(base + name, {"tempPath": target["tempPath"]}, "PUT")


if __name__ == "__main__":
    import sys
    if sys.argv[1] == "upload":
        print(json.dumps(upload(sys.argv[2])))
    elif sys.argv[1] == "get":
        print(json.dumps(request(sys.argv[2]), indent=2))
